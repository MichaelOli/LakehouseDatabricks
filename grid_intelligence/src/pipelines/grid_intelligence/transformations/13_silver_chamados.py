# Extracao por regra, no ramo usar_ia = false. O que ela nao pega:
# - Ironia e negacao. "Que otimo, mais um dia sem luz" pode sair como positivo.
# - Sinonimo fora da lista. "ta tudo apagado" entra. "fiquei no breu" nao.
# - Motivo composto. Falta de energia e conta alta viram um rotulo so.
# - Nome escrito diferente da coluna. Apelido nao casa no replace, e o texto passa identificado.
#
# O ramo usar_ia = true chama ai_mask, ai_analyze_sentiment, ai_classify e ai_extract.
# Nenhum nome de modelo aparece aqui. As colunas dos dois ramos sao as mesmas.

from pyspark import pipelines as dp
from pyspark.sql import functions as F

catalogo = spark.conf.get("catalogo")
schema_bronze = spark.conf.get("schema_bronze")
schema_silver = spark.conf.get("schema_silver")
usar_ia = spark.conf.get("usar_ia") == "true"

bronze_chamados = f"{catalogo}.{schema_bronze}.chamados"
silver_cadastro = f"{catalogo}.{schema_silver}.unidades_consumidoras"
tabela_anonimizados = f"{catalogo}.{schema_silver}.chamados_anonimizados"
tabela_enriquecidos = f"{catalogo}.{schema_silver}.chamados_enriquecidos"

RISCO = r"(?i)oxigenio|dialise|remedio|crianca|hospital|faisca|incendio|idoso"
OUVIDORIA = r"(?i)ouvidoria|aneel|procon|processo"
MOTIVO = """
CASE
  WHEN transcricao_anonimizada RLIKE '(?i)dialise|oxigenio|remedio na geladeira|crianca pequena'
    THEN 'religacao_urgente'
  WHEN transcricao_anonimizada RLIKE '(?i)escuro|sem energia|apagou|falta de energia|sem luz'
    THEN 'falta_energia'
  WHEN transcricao_anonimizada RLIKE '(?i)piscando|oscila|queimou|tensao'
    THEN 'oscilacao_tensao'
  WHEN transcricao_anonimizada RLIKE '(?i)releitura|estimativa|nao bate'
    THEN 'erro_leitura'
  WHEN transcricao_anonimizada RLIKE '(?i)conta veio|dobro|fatura subiu|trezentos reais'
    THEN 'fatura_alta'
  WHEN transcricao_anonimizada RLIKE '(?i)poste|galho|lampada da rua'
    THEN 'poste_avariado'
  WHEN transcricao_anonimizada RLIKE '(?i)religacao|religar|paguei'
    THEN 'religacao'
  ELSE 'duvida_cadastral'
END
"""
ROTULOS = """'{
  "religacao_urgente": "Religacao com pessoa em risco na frase, como dialise, oxigenio, remedio ou crianca",
  "falta_energia": "Falta de energia, casa no escuro ou luz que apagou",
  "oscilacao_tensao": "Tensao oscilando, luz piscando ou aparelho queimado",
  "erro_leitura": "Releitura, estimativa ou conta que nao bate com o medidor",
  "fatura_alta": "Fatura alta, valor que dobrou ou conta que veio cara",
  "poste_avariado": "Poste, galho na rede ou lampada da rua",
  "religacao": "Pedido para religar depois do pagamento, sem pessoa em risco",
  "duvida_cadastral": "Duvida de cadastro ou outro assunto"
}'"""


def chamados_com_cadastro():
    chamados = spark.read.table(bronze_chamados)
    cadastro = spark.read.table(silver_cadastro).select(
        "id_uc", "id_cliente", "id_conjunto", "nome_conjunto", "bairro", "classe_consumo"
    )
    return chamados.join(cadastro, "id_uc", "left")


def colunas_do_chamado(transcricao_anonimizada, anonimizado_por):
    return [
        "id_chamado",
        "id_uc",
        "id_cliente",
        "id_conjunto",
        "nome_conjunto",
        "bairro",
        "classe_consumo",
        "abertura",
        F.to_date("abertura").alias("data_chamado"),
        F.date_format("abertura", "HH:mm:ss").alias("hora_chamado"),
        "canal",
        "duracao_segundos",
        transcricao_anonimizada.alias("transcricao_anonimizada"),
        F.lit(anonimizado_por).alias("anonimizado_por"),
    ]


def com_sinais(df, enriquecido_por):
    texto = F.col("transcricao_anonimizada")
    risco = texto.rlike(RISCO)
    return (
        df.withColumn("risco_a_saude", risco)
        .withColumn("ameacou_ouvidoria", texto.rlike(OUVIDORIA))
        .withColumn(
            "urgencia",
            F.when(risco, "alta")
            .when(F.col("motivo").isin("falta_energia", "religacao_urgente", "poste_avariado"), "media")
            .otherwise("baixa"),
        )
        .withColumn("enriquecido_por", F.lit(enriquecido_por))
    )


if usar_ia:

    @dp.materialized_view(
        name=tabela_anonimizados,
        table_properties={"delta.feature.timestampNtz": "supported"},
    )
    def chamados_anonimizados():
        df = chamados_com_cadastro()
        texto = F.expr(
            "ai_mask(transcricao, array('person', 'phone', 'address', 'ssn', 'email'))"
        )
        return df.select(*colunas_do_chamado(texto, "ia"))

    @dp.materialized_view(
        name=tabela_enriquecidos,
        table_properties={"delta.feature.timestampNtz": "supported"},
    )
    def chamados_enriquecidos():
        df = spark.read.table(tabela_anonimizados).select(
            "*",
            F.expr("ai_analyze_sentiment(transcricao_anonimizada)").alias("sentimento"),
            F.expr(
                f"""ai_classify(
                  transcricao_anonimizada,
                  {ROTULOS},
                  map('instructions', 'Ligacoes para uma distribuidora de energia brasileira', 'version', '2.0')
                ):response[0]::string"""
            ).alias("motivo"),
            F.expr(
                """ai_extract(
                  transcricao_anonimizada,
                  '{"equipamento": "equipamento da rede citado, como poste, transformador, medidor ou cabo"}'
                ):response:equipamento::string"""
            ).alias("equipamento_citado"),
        )
        return com_sinais(df, "ia")

else:

    @dp.materialized_view(
        name=tabela_anonimizados,
        table_properties={"delta.feature.timestampNtz": "supported"},
    )
    def chamados_anonimizados():
        df = chamados_com_cadastro()
        texto = F.expr(
            r"""
            regexp_replace(
              regexp_replace(
                replace(transcricao, nome_solicitante, '[MASCARADO]'),
                '[0-9]{3}\\.[0-9]{3}\\.[0-9]{3}-[0-9]{2}',
                '[MASCARADO]'),
              '\\([0-9]{2}\\)\\s*9?[0-9]{4}-?[0-9]{4}',
              '[MASCARADO]')
            """
        )
        return df.select(*colunas_do_chamado(texto, "regras_de_texto"))

    @dp.materialized_view(
        name=tabela_enriquecidos,
        table_properties={"delta.feature.timestampNtz": "supported"},
    )
    def chamados_enriquecidos():
        df = spark.read.table(tabela_anonimizados).select(
            "*",
            F.when(F.col("transcricao_anonimizada").rlike(r"(?i)absurdo|indign|reclam|pessimo|horrivel|nunca mais"), "negative")
            .when(F.col("transcricao_anonimizada").rlike(r"(?i)obrigad|otimo|excelente|agradeco"), "positive")
            .otherwise("neutral")
            .alias("sentimento"),
            F.expr(MOTIVO).alias("motivo"),
            F.expr(
                r"nullif(regexp_extract(transcricao_anonimizada, '(?i)(transformador|poste|medidor|cabo|disjuntor|religador)', 1), '')"
            ).alias("equipamento_citado"),
        )
        return com_sinais(df, "regras_de_texto")
