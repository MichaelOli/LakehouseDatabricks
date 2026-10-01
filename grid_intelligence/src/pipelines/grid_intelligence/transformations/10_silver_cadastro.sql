-- O cadastro traz TIMESTAMP_NTZ. A feature entra na tabela para o tipo passar como chegou.
CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_silver}.unidades_consumidoras
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  * EXCEPT (classe_consumo, bairro),
  lower(trim(classe_consumo)) AS classe_consumo,
  CASE
    WHEN bairro IS NULL OR trim(bairro) = '' THEN 'nao informado'
    ELSE bairro
  END AS bairro
FROM STREAM(${catalogo}.${schema_bronze}.unidades_consumidoras)
WHERE id_uc IS NOT NULL
  AND id_conjunto IS NOT NULL
