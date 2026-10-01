CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.saude_cliente (
  id_cliente STRING COMMENT 'Cliente. O grao e a pessoa, nao a UC: ela pode ter varias unidades',
  id_conjunto STRING COMMENT 'Conjunto da ligacao do chamado mais recente',
  nome_conjunto STRING COMMENT 'Nome desse conjunto',
  bairro STRING COMMENT 'Bairro da ligacao do chamado mais recente',
  qtd_chamados BIGINT COMMENT 'Quantidade de ligacoes do cliente',
  qtd_ucs_com_chamado BIGINT COMMENT 'Quantas UCs desse cliente geraram chamado',
  qtd_chamados_negativos BIGINT COMMENT 'Ligacoes com sentimento negativo',
  proporcao_negativa DOUBLE COMMENT 'Parte dos chamados com sentimento negativo',
  qtd_mencoes_ouvidoria BIGINT COMMENT 'Ligacoes que citaram ouvidoria, ANEEL, Procon ou processo',
  qtd_chamados_risco_saude BIGINT COMMENT 'Ligacoes com relato de risco a saude',
  qtd_urgencia_alta BIGINT COMMENT 'Ligacoes classificadas com urgencia alta',
  reincidente BOOLEAN COMMENT 'Teve 3 ou mais chamados em alguma janela de 30 dias',
  motivo_predominante STRING COMMENT 'Motivo mais frequente. mode() para o rotulo nao mudar a cada leitura',
  ultimo_equipamento_citado STRING COMMENT 'Equipamento citado no chamado mais recente',
  ultima_fala STRING COMMENT 'Transcricao ja anonimizada do chamado mais recente',
  primeiro_chamado_em TIMESTAMP_NTZ COMMENT 'Abertura do primeiro chamado',
  ultimo_chamado_em TIMESTAMP_NTZ COMMENT 'Abertura do chamado mais recente',
  risco_ouvidoria STRING COMMENT 'alto se citou ouvidoria, medio se reincide negativo ou relata risco a saude, baixo no resto'
)
COMMENT 'Clientes em rota de reclamacao. A ultima fala e o texto anonimizado, sem o dado pessoal de quem ligou.'
-- abertura vem sem fuso. Habilitar TIMESTAMP_NTZ evita converter o tipo na gold.
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS
WITH chamados AS (
  SELECT
    *,
    count(*) OVER (
      PARTITION BY id_cliente
      ORDER BY cast(data_chamado AS timestamp)
      RANGE BETWEEN INTERVAL 30 DAYS PRECEDING AND CURRENT ROW
    ) AS chamados_em_30_dias
  FROM ${catalogo}.${schema_silver}.chamados_enriquecidos
  WHERE id_cliente IS NOT NULL
)
SELECT
  id_cliente,
  max_by(id_conjunto, abertura) AS id_conjunto,
  max_by(nome_conjunto, abertura) AS nome_conjunto,
  max_by(bairro, abertura) AS bairro,
  count(*) AS qtd_chamados,
  count(DISTINCT id_uc) AS qtd_ucs_com_chamado,
  count_if(sentimento = 'negative') AS qtd_chamados_negativos,
  count_if(sentimento = 'negative') / count(*) AS proporcao_negativa,
  count_if(ameacou_ouvidoria) AS qtd_mencoes_ouvidoria,
  count_if(risco_a_saude) AS qtd_chamados_risco_saude,
  count_if(urgencia = 'alta') AS qtd_urgencia_alta,
  max(chamados_em_30_dias) >= 3 AS reincidente,
  mode(motivo) AS motivo_predominante,
  max_by(equipamento_citado, abertura) AS ultimo_equipamento_citado,
  max_by(transcricao_anonimizada, abertura) AS ultima_fala,
  min(abertura) AS primeiro_chamado_em,
  max(abertura) AS ultimo_chamado_em,
  CASE
    WHEN count_if(ameacou_ouvidoria) > 0 THEN 'alto'
    WHEN max(chamados_em_30_dias) >= 3 AND count_if(sentimento = 'negative') > 0 THEN 'medio'
    WHEN count_if(risco_a_saude) > 0 THEN 'medio'
    ELSE 'baixo'
  END AS risco_ouvidoria
FROM chamados
GROUP BY id_cliente
