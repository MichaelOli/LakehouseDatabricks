-- Tres blocos agregados a parte e unidos com FULL OUTER JOIN.
-- Dia com interrupcao e sem chamado existe, e o contrario tambem.
-- A prioridade nao tem data: a contagem atual do conjunto se repete em cada dia.

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.painel_operacional_dia (
  id_conjunto STRING COMMENT 'Conjunto',
  nome_conjunto STRING COMMENT 'Nome do conjunto',
  municipio STRING COMMENT 'Municipio do conjunto',
  data DATE COMMENT 'Dia do recorte operacional',
  qtd_interrupcoes BIGINT COMMENT 'Eventos validos de continuidade nesse dia',
  uc_horas_interrompidas DOUBLE COMMENT 'Horas-UC interrompidas no dia',
  maior_duracao_horas DOUBLE COMMENT 'Pior evento do dia, em horas',
  qtd_chamados BIGINT COMMENT 'Ligacoes abertas no dia',
  qtd_risco_saude BIGINT COMMENT 'Ligacoes com relato de risco a saude',
  qtd_mencoes_ouvidoria BIGINT COMMENT 'Ligacoes que citaram ouvidoria, ANEEL, Procon ou processo',
  qtd_urgencia_alta BIGINT COMMENT 'Ligacoes com urgencia alta',
  consumo_total_kwh DOUBLE COMMENT 'Energia registrada no dia, em kWh',
  qtd_ucs_com_leitura BIGINT COMMENT 'UCs com leitura valida no dia',
  ucs_prioridade_alta BIGINT COMMENT 'UCs do conjunto na prioridade alta da fila atual',
  total_ucs BIGINT COMMENT 'UCs do conjunto',
  acao_recomendada STRING COMMENT 'O que olhar primeiro: risco a saude, ouvidoria, rede e so entao a visita'
)
COMMENT 'O que aconteceu no conjunto nesse dia e qual acao vem primeiro.'
AS
WITH interrupcoes AS (
  SELECT
    id_conjunto,
    data_evento AS data,
    count(*) AS qtd_interrupcoes,
    sum(uc_horas_interrompidas) AS uc_horas_interrompidas,
    max(duracao_horas) AS maior_duracao_horas
  FROM ${catalogo}.${schema_silver}.interrupcoes_validas
  GROUP BY id_conjunto, data_evento
),
chamados AS (
  SELECT
    id_conjunto,
    data_chamado AS data,
    count(*) AS qtd_chamados,
    count_if(risco_a_saude) AS qtd_risco_saude,
    count_if(ameacou_ouvidoria) AS qtd_mencoes_ouvidoria,
    count_if(urgencia = 'alta') AS qtd_urgencia_alta
  FROM ${catalogo}.${schema_silver}.chamados_enriquecidos
  GROUP BY id_conjunto, data_chamado
),
consumo AS (
  SELECT
    id_conjunto,
    data,
    sum(consumo_kwh) AS consumo_total_kwh,
    count(DISTINCT id_uc) AS qtd_ucs_com_leitura
  FROM ${catalogo}.${schema_silver}.consumo_diario
  GROUP BY id_conjunto, data
),
conjuntos AS (
  SELECT id_conjunto, nome_conjunto, municipio, count(*) AS total_ucs
  FROM ${catalogo}.${schema_silver}.unidades_consumidoras
  GROUP BY id_conjunto, nome_conjunto, municipio
),
prioridade AS (
  SELECT id_conjunto, count_if(prioridade_inspecao = 'alta') AS ucs_prioridade_alta
  FROM ${catalogo}.${schema_gold}.prioridade_inspecao_uc
  GROUP BY id_conjunto
)
SELECT
  coalesce(i.id_conjunto, ch.id_conjunto, co.id_conjunto) AS id_conjunto,
  cj.nome_conjunto,
  cj.municipio,
  coalesce(i.data, ch.data, co.data) AS data,
  coalesce(i.qtd_interrupcoes, 0) AS qtd_interrupcoes,
  coalesce(i.uc_horas_interrompidas, 0) AS uc_horas_interrompidas,
  i.maior_duracao_horas,
  coalesce(ch.qtd_chamados, 0) AS qtd_chamados,
  coalesce(ch.qtd_risco_saude, 0) AS qtd_risco_saude,
  coalesce(ch.qtd_mencoes_ouvidoria, 0) AS qtd_mencoes_ouvidoria,
  coalesce(ch.qtd_urgencia_alta, 0) AS qtd_urgencia_alta,
  coalesce(co.consumo_total_kwh, 0) AS consumo_total_kwh,
  coalesce(co.qtd_ucs_com_leitura, 0) AS qtd_ucs_com_leitura,
  coalesce(p.ucs_prioridade_alta, 0) AS ucs_prioridade_alta,
  cj.total_ucs,
  CASE
    WHEN coalesce(ch.qtd_risco_saude, 0) > 0 THEN 'atender quem relatou risco a saude'
    WHEN coalesce(ch.qtd_mencoes_ouvidoria, 0) > 0 THEN 'retornar quem citou a ouvidoria'
    WHEN coalesce(i.qtd_interrupcoes, 0) > 0 THEN 'avaliar o impacto na rede'
    WHEN coalesce(p.ucs_prioridade_alta, 0) > 0 THEN 'enviar visita tecnica'
    ELSE 'sem acao imediata'
  END AS acao_recomendada
FROM interrupcoes i
FULL OUTER JOIN chamados ch
  ON i.id_conjunto = ch.id_conjunto AND i.data = ch.data
FULL OUTER JOIN consumo co
  ON coalesce(i.id_conjunto, ch.id_conjunto) = co.id_conjunto
 AND coalesce(i.data, ch.data) = co.data
LEFT JOIN conjuntos cj
  ON coalesce(i.id_conjunto, ch.id_conjunto, co.id_conjunto) = cj.id_conjunto
LEFT JOIN prioridade p
  ON coalesce(i.id_conjunto, ch.id_conjunto, co.id_conjunto) = p.id_conjunto
