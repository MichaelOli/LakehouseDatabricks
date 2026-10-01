CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.continuidade_conjunto_mes (
  id_conjunto STRING COMMENT 'Codigo do conjunto, a unidade de agregacao do regulador',
  nome_conjunto STRING COMMENT 'Nome do conjunto, como o gestor reconhece a regiao',
  municipio STRING COMMENT 'Municipio do conjunto',
  mes_apuracao DATE COMMENT 'Mes de apuracao. O indicador e mensal',
  total_ucs BIGINT COMMENT 'Total de UCs do conjunto. Denominador de DEC e FEC, nao so as atingidas',
  uc_horas_interrompidas DOUBLE COMMENT 'Soma de horas vezes UCs atingidas. Numerador do DEC, aditivo',
  uc_interrupcoes BIGINT COMMENT 'Soma de UCs atingidas. Numerador do FEC, aditivo',
  qtd_interrupcoes BIGINT COMMENT 'Quantidade de eventos no mes',
  qtd_interrupcoes_climaticas BIGINT COMMENT 'Eventos com causa climatica',
  qtd_interrupcoes_programadas BIGINT COMMENT 'Eventos com aviso previo',
  maior_duracao_horas DOUBLE COMMENT 'Duracao, em horas, do pior evento do mes'
)
COMMENT 'Insumos aditivos de continuidade por conjunto e mes. DEC e FEC nao ficam aqui: a definicao unica e a metric view.'
AS SELECT
  i.id_conjunto,
  u.nome_conjunto,
  u.municipio,
  i.mes_apuracao,
  u.total_ucs,
  sum(i.uc_horas_interrompidas) AS uc_horas_interrompidas,
  sum(i.qtd_ucs_afetadas) AS uc_interrupcoes,
  count(*) AS qtd_interrupcoes,
  count_if(i.causa_climatica) AS qtd_interrupcoes_climaticas,
  count_if(i.tipo = 'programada') AS qtd_interrupcoes_programadas,
  max(i.duracao_horas) AS maior_duracao_horas
FROM ${catalogo}.${schema_silver}.interrupcoes_validas i
JOIN (
  SELECT id_conjunto, nome_conjunto, municipio, count(*) AS total_ucs
  FROM ${catalogo}.${schema_silver}.unidades_consumidoras
  GROUP BY id_conjunto, nome_conjunto, municipio
) u ON i.id_conjunto = u.id_conjunto
GROUP BY i.id_conjunto, u.nome_conjunto, u.municipio, i.mes_apuracao, u.total_ucs
