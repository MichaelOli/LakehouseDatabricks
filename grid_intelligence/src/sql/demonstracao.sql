-- Prova das regras da aula. Este arquivo le bronze e silver de proposito.
-- O relatorio executivo e o Genie ficam so na gold.
-- Rode com --param catalogo=grid_dev. O nome do catalogo entra so nesse parametro.

USE CATALOG IDENTIFIER(:catalogo);

-- 1. RN-01: a bronze guarda o evento curto. A silver fica com duracao >= 3 min.
SELECT
  (SELECT count(*) FROM bronze.interrupcoes) AS bronze,
  (SELECT count(*) FROM bronze.interrupcoes WHERE duracao_minutos < 3) AS abaixo_de_3_min,
  (SELECT count(*) FROM silver.interrupcoes_validas) AS silver;

-- 2. Consumo descartado, com o motivo.
WITH classe AS (
  SELECT
    c.consumo_kwh,
    u.classe_consumo,
    row_number() OVER (PARTITION BY c.id_uc, c.data ORDER BY c.ingerido_em DESC) AS ordem
  FROM bronze.consumo_diario c
  JOIN silver.unidades_consumidoras u ON c.id_uc = u.id_uc
)
SELECT
  CASE
    WHEN consumo_kwh IS NULL THEN 'nulo'
    WHEN consumo_kwh < 0 THEN 'negativo'
    WHEN consumo_kwh > CASE classe_consumo
      WHEN 'residencial' THEN 150
      WHEN 'comercial' THEN 800
      WHEN 'rural' THEN 400
      WHEN 'poder_publico' THEN 2000
      WHEN 'industrial' THEN 8000
    END THEN 'acima do teto da classe'
    WHEN ordem > 1 THEN 'duplicata'
    ELSE 'permanece'
  END AS motivo,
  count(*) AS linhas
FROM classe
GROUP BY 1
ORDER BY linhas DESC;

-- 3. RN-04: o DEC da metric view e o mesmo calculo manual.
WITH manual AS (
  SELECT
    nome_conjunto,
    sum(uc_horas_interrompidas) / sum(total_ucs) AS dec_manual
  FROM gold.continuidade_conjunto_mes
  WHERE mes_apuracao = DATE '2026-07-01'
  GROUP BY nome_conjunto
),
medida AS (
  SELECT `Conjunto` AS nome_conjunto, MEASURE(`DEC`) AS dec_medida
  FROM gold.continuidade_metricas
  WHERE `Mes` = DATE '2026-07-01'
  GROUP BY ALL
)
SELECT
  m.nome_conjunto,
  round(m.dec_manual, 4) AS dec_manual,
  round(v.dec_medida, 4) AS dec_medida,
  abs(m.dec_manual - v.dec_medida) < 0.0001 AS bate
FROM manual m
JOIN medida v ON m.nome_conjunto = v.nome_conjunto
ORDER BY m.nome_conjunto;

-- 4. Os dois eixos lado a lado. Alta exige os dois e o sinal recente.
SELECT
  prioridade_inspecao,
  count(*) AS ucs,
  sum(CASE WHEN variacao_da_uc <= -0.25 AND abs(variacao_do_conjunto) <= 0.10 THEN 1 ELSE 0 END) AS dois_eixos,
  sum(CASE WHEN sinal_violacao_recente THEN 1 ELSE 0 END) AS com_sinal
FROM gold.prioridade_inspecao_uc
GROUP BY prioridade_inspecao
ORDER BY prioridade_inspecao;

-- 5. Bronze mascarada ao lado da silver anonimizada.
SELECT
  b.id_chamado,
  b.transcricao AS bronze,
  s.transcricao_anonimizada AS silver
FROM bronze.chamados b
JOIN silver.chamados_enriquecidos s ON b.id_chamado = s.id_chamado
LIMIT 5;

-- 6. A noite com mais chamados, contra a media das mesmas horas nos outros dias.
WITH por_hora AS (
  SELECT
    data_chamado,
    hour(abertura) AS hora,
    count(*) AS chamados
  FROM silver.chamados_enriquecidos
  GROUP BY data_chamado, hour(abertura)
),
pico AS (
  SELECT data_chamado
  FROM por_hora
  WHERE hora BETWEEN 18 AND 23
  GROUP BY data_chamado
  ORDER BY sum(chamados) DESC
  LIMIT 1
)
SELECT
  p.hora,
  coalesce(sum(CASE WHEN p.data_chamado = pico.data_chamado THEN p.chamados END), 0) AS na_noite,
  round(avg(CASE WHEN p.data_chamado <> pico.data_chamado THEN p.chamados END), 2) AS media_dos_outros_dias
FROM por_hora p
CROSS JOIN pico
WHERE p.hora BETWEEN 18 AND 23
GROUP BY p.hora
ORDER BY p.hora;

-- 7. O consumo anual sobe cerca de 30%.
SELECT
  year(data) AS ano,
  round(sum(consumo_kwh), 0) AS kwh
FROM silver.consumo_diario
GROUP BY year(data)
ORDER BY ano;

-- 8. Chamados de verao contra o resto do ano.
SELECT
  CASE WHEN month(data_chamado) IN (12, 1, 2) THEN 'verao' ELSE 'resto' END AS periodo,
  count(*) AS chamados,
  count(DISTINCT date_trunc('month', data_chamado)) AS meses
FROM silver.chamados_enriquecidos
GROUP BY 1;
