# Databricks notebook source
# MAGIC %md
# MAGIC # Relatorio executivo
# MAGIC
# MAGIC Le somente a gold. O dia de referencia e o ultimo dia com movimento
# MAGIC em Campinas, nao a data de hoje.

# COMMAND ----------

dbutils.widgets.text("catalogo", "grid_dev")
dbutils.widgets.text("usar_ia", "false")
catalogo = dbutils.widgets.get("catalogo")
usar_ia = dbutils.widgets.get("usar_ia")

# COMMAND ----------

dia = spark.sql(f"""
SELECT max(data) AS dia
FROM {catalogo}.gold.painel_operacional_dia
WHERE nome_conjunto LIKE 'Campinas%'
  AND (qtd_interrupcoes > 0 OR qtd_chamados > 0 OR qtd_risco_saude > 0)
""").collect()[0]["dia"]

if dia is None:
    raise Exception(
        "Nenhum dia com movimento em Campinas. Confira gold.painel_operacional_dia."
    )

# COMMAND ----------

operacao = spark.sql(f"""
SELECT
  nome_conjunto,
  qtd_interrupcoes,
  round(uc_horas_interrompidas, 1) AS horas_uc,
  round(maior_duracao_horas, 2) AS maior_evento_horas,
  qtd_chamados,
  qtd_risco_saude,
  qtd_mencoes_ouvidoria,
  acao_recomendada
FROM {catalogo}.gold.painel_operacional_dia
WHERE data = DATE '{dia}'
  AND nome_conjunto LIKE 'Campinas%'
ORDER BY nome_conjunto
""").toPandas()

base = spark.sql(f"""
SELECT
  nome_conjunto,
  round(avg(qtd_interrupcoes), 2) AS interrupcoes_media,
  round(avg(uc_horas_interrompidas), 1) AS horas_uc_media,
  round(avg(qtd_chamados), 2) AS chamados_media
FROM {catalogo}.gold.painel_operacional_dia
WHERE nome_conjunto LIKE 'Campinas%'
  AND data >= date_sub(DATE '{dia}', 30)
  AND data < DATE '{dia}'
GROUP BY nome_conjunto
ORDER BY nome_conjunto
""").toPandas()

continuidade = spark.sql(f"""
SELECT `Conjunto` AS conjunto, round(MEASURE(`DEC`), 2) AS dec, round(MEASURE(`FEC`), 2) AS fec
FROM {catalogo}.gold.continuidade_metricas
WHERE `Mes` = CAST(date_trunc('month', DATE '{dia}') AS DATE)
  AND `Conjunto` LIKE 'Campinas%'
GROUP BY ALL
ORDER BY conjunto
""").toPandas()

bairros = spark.sql(f"""
SELECT bairro, count(*) AS ucs
FROM {catalogo}.gold.prioridade_inspecao_uc
WHERE prioridade_inspecao = 'alta'
  AND nome_conjunto LIKE 'Campinas%'
GROUP BY bairro
ORDER BY ucs DESC
""").toPandas()

clientes = spark.sql(f"""
SELECT count(*) AS clientes, coalesce(sum(qtd_mencoes_ouvidoria), 0) AS mencoes
FROM {catalogo}.gold.saude_cliente
WHERE risco_ouvidoria = 'alto'
  AND nome_conjunto LIKE 'Campinas%'
""").collect()[0]

# COMMAND ----------

def tabela(frame):
    if frame.empty:
        return "sem linhas"
    return frame.to_string(index=False)

fatos = f"""
Dia de referencia: {dia}. Regiao: conjuntos cujo nome comeca com Campinas.
Operacao do dia:
{tabela(operacao)}
Media dos 30 dias anteriores:
{tabela(base)}
Continuidade do mes, via MEASURE:
{tabela(continuidade)}
UCs em prioridade alta de inspecao, por bairro:
{tabela(bairros)}
Clientes com risco de ouvidoria alto: {clientes['clientes']}. Mencoes: {clientes['mencoes']}.
""".strip()

print(fatos)

# COMMAND ----------

regras = (
    "Escreva no maximo 250 palavras, em tres partes: o que aconteceu, "
    "a continuidade do mes e o que fazer. Use somente os numeros fornecidos. "
    "Nao invente causa, nome nem quantidade. Queda de consumo e prioridade de "
    "inspecao. Nunca chame isso de fraude, furto, roubo ou irregularidade."
)

if usar_ia == "true":
    pedido = (regras + "\n\n" + fatos).replace("'", " ")
    texto = spark.sql(f"SELECT ai_gen('{pedido}') AS texto").collect()[0]["texto"]
else:
    linhas = [
        f"O que aconteceu em {dia}",
        "",
    ]
    for _, linha in operacao.iterrows():
        media = base[base["nome_conjunto"] == linha["nome_conjunto"]]
        contra = ""
        if not media.empty:
            contra = (
                f" Nos 30 dias anteriores a media foi de {media.iloc[0]['interrupcoes_media']} "
                f"interrupcoes, {media.iloc[0]['horas_uc_media']} horas-UC e "
                f"{media.iloc[0]['chamados_media']} chamados."
            )
        maior = linha["maior_evento_horas"]
        if maior is None or maior != maior:
            maior_txt = "sem evento"
        else:
            maior_txt = f"maior evento de {maior} horas"
        linhas.append(
            f"{linha['nome_conjunto']}: {int(linha['qtd_interrupcoes'])} interrupcoes, "
            f"{linha['horas_uc']} horas-UC, {maior_txt}, "
            f"{int(linha['qtd_chamados'])} chamados, {int(linha['qtd_risco_saude'])} com risco a saude "
            f"e {int(linha['qtd_mencoes_ouvidoria'])} mencoes a ouvidoria.{contra} "
            f"Acao: {linha['acao_recomendada']}."
        )
    linhas.append("")
    linhas.append("Continuidade do mes")
    linhas.append("")
    for _, linha in continuidade.iterrows():
        linhas.append(f"{linha['conjunto']}: DEC {linha['dec']} e FEC {linha['fec']}.")
    linhas.append("")
    linhas.append("O que fazer")
    linhas.append("")
    if bairros.empty:
        linhas.append("Nenhuma UC de Campinas esta em prioridade alta de inspecao.")
    else:
        resumo = ", ".join(f"{r.bairro} ({int(r.ucs)})" for r in bairros.itertuples())
        linhas.append(f"Prioridade alta de inspecao por bairro: {resumo}.")
    linhas.append(
        f"{int(clientes['clientes'])} clientes de Campinas estao com risco de ouvidoria alto, "
        f"somando {int(clientes['mencoes'])} mencoes."
    )
    texto = "\n".join(linhas)

print(texto)
dbutils.notebook.exit(texto)
