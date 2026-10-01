-- Teto diario por classe, do lado de quem recebe a telemetria.
-- Fica acima do p99 observado e abaixo da leitura que uma ligacao dessa classe nao entrega.

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.consumo_diario
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  c.* EXCEPT (_rescued_data),
  u.id_conjunto,
  u.nome_conjunto,
  u.bairro,
  u.classe_consumo
FROM ${catalogo}.${schema_bronze}.consumo_diario c
JOIN ${catalogo}.${schema_silver}.unidades_consumidoras u
  ON c.id_uc = u.id_uc
WHERE c.consumo_kwh IS NOT NULL
  AND c.consumo_kwh >= 0
  AND c.consumo_kwh <= CASE u.classe_consumo
    WHEN 'residencial' THEN 150
    WHEN 'comercial' THEN 800
    WHEN 'rural' THEN 400
    WHEN 'poder_publico' THEN 2000
    WHEN 'industrial' THEN 8000
  END
QUALIFY row_number() OVER (
  PARTITION BY c.id_uc, c.data
  ORDER BY c.ingerido_em DESC
) = 1;

-- Janela ancorada no maior dia do dataset, nao em current_date().
-- Recente: 30 dias. Baseline: os 90 dias imediatamente anteriores.
-- A carga cresce ~30% ao ano. A media de todo o historico acusaria alta em toda UC.

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.baseline_consumo
AS
WITH marcado AS (
  SELECT
    id_uc,
    id_conjunto,
    nome_conjunto,
    bairro,
    classe_consumo,
    data,
    consumo_kwh,
    sinal_violacao_medidor,
    max(data) OVER () AS dia_ancora
  FROM ${catalogo}.${schema_silver}.consumo_diario
),
por_uc AS (
  SELECT
    id_uc,
    id_conjunto,
    max(nome_conjunto) AS nome_conjunto,
    max(bairro) AS bairro,
    max(classe_consumo) AS classe_consumo,
    avg(CASE
      WHEN data > date_sub(dia_ancora, 30) AND data <= dia_ancora THEN consumo_kwh
    END) AS consumo_medio_recente_kwh,
    avg(CASE
      WHEN data > date_sub(dia_ancora, 120) AND data <= date_sub(dia_ancora, 30) THEN consumo_kwh
    END) AS consumo_medio_baseline_kwh,
    count(CASE
      WHEN data > date_sub(dia_ancora, 30) AND data <= dia_ancora THEN 1
    END) AS dias_no_periodo_recente,
    count(CASE
      WHEN data > date_sub(dia_ancora, 120) AND data <= date_sub(dia_ancora, 30) THEN 1
    END) AS dias_no_baseline,
    max(CASE
      WHEN data > date_sub(dia_ancora, 30) AND data <= dia_ancora AND sinal_violacao_medidor THEN 1
      ELSE 0
    END) = 1 AS sinal_violacao_recente
  FROM marcado
  GROUP BY id_uc, id_conjunto
),
por_conjunto AS (
  SELECT
    id_conjunto,
    avg(CASE
      WHEN data > date_sub(dia_ancora, 30) AND data <= dia_ancora THEN consumo_kwh
    END) AS media_recente_conjunto,
    avg(CASE
      WHEN data > date_sub(dia_ancora, 120) AND data <= date_sub(dia_ancora, 30) THEN consumo_kwh
    END) AS media_baseline_conjunto
  FROM marcado
  GROUP BY id_conjunto
)
SELECT
  u.id_uc,
  u.id_conjunto,
  u.nome_conjunto,
  u.bairro,
  u.classe_consumo,
  u.consumo_medio_baseline_kwh,
  u.consumo_medio_recente_kwh,
  u.dias_no_baseline,
  u.dias_no_periodo_recente,
  (u.consumo_medio_recente_kwh - u.consumo_medio_baseline_kwh)
    / nullif(u.consumo_medio_baseline_kwh, 0) AS variacao_da_uc,
  (c.media_recente_conjunto - c.media_baseline_conjunto)
    / nullif(c.media_baseline_conjunto, 0) AS variacao_do_conjunto,
  u.sinal_violacao_recente
FROM por_uc u
JOIN por_conjunto c ON u.id_conjunto = c.id_conjunto
