CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_silver}.interrupcoes_validas
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  to_date(inicio) AS data_evento,
  to_date(date_trunc('MONTH', inicio)) AS mes_apuracao,
  duracao_minutos / 60.0 AS duracao_horas,
  duracao_minutos / 60.0 * qtd_ucs_afetadas AS uc_horas_interrompidas,
  causa = 'climatica' AS causa_climatica
FROM STREAM(${catalogo}.${schema_bronze}.interrupcoes)
-- O religador desarma e religa em segundos. A luz pisca.
-- O consumidor nao fica sem energia, e o evento nao entra no indicador.
WHERE duracao_minutos >= ${duracao_minima_interrupcao_min}
