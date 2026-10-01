CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.prioridade_inspecao_uc (
  id_uc STRING COMMENT 'Unidade consumidora candidata a visita',
  id_conjunto STRING COMMENT 'Conjunto da UC',
  nome_conjunto STRING COMMENT 'Nome do conjunto',
  bairro STRING COMMENT 'Bairro da UC',
  classe_consumo STRING COMMENT 'Classe de consumo da ligacao',
  prioridade_inspecao STRING COMMENT 'alta, media ou baixa. E prioridade de visita, nao um juizo sobre a pessoa',
  caiu_contra_si BOOLEAN COMMENT 'O consumo recente caiu contra o baseline da propria UC alem do limiar',
  vizinhanca_estavel BOOLEAN COMMENT 'A variacao do conjunto ficou dentro da faixa de estabilidade',
  atende_os_dois_eixos BOOLEAN COMMENT 'Caiu contra si e a vizinhanca seguiu estavel',
  sinal_violacao_recente BOOLEAN COMMENT 'O medidor registrou violacao na janela recente',
  variacao_da_uc DOUBLE COMMENT 'Variacao percentual da UC entre as duas janelas',
  variacao_do_conjunto DOUBLE COMMENT 'Variacao percentual do conjunto entre as duas janelas',
  consumo_medio_baseline_kwh DOUBLE COMMENT 'Media diaria de kWh da UC nos 90 dias de baseline',
  consumo_medio_recente_kwh DOUBLE COMMENT 'Media diaria de kWh da UC nos 30 dias recentes',
  dias_no_baseline BIGINT COMMENT 'Dias com leitura na janela de baseline',
  dias_no_periodo_recente BIGINT COMMENT 'Dias com leitura na janela recente',
  motivo_observado STRING COMMENT 'O que o dado mostrou, em linguagem de negocio, para o inspetor ler antes da visita'
)
COMMENT 'Fila de visita tecnica. Queda de consumo tambem e mudanca de morador, imovel vazio, defeito de medidor ou erro de leitura.'
AS SELECT
  id_uc,
  id_conjunto,
  nome_conjunto,
  bairro,
  classe_consumo,
  CASE
    WHEN caiu_contra_si AND vizinhanca_estavel AND sinal_violacao_recente THEN 'alta'
    WHEN caiu_contra_si AND vizinhanca_estavel THEN 'media'
    WHEN sinal_violacao_recente THEN 'media'
    ELSE 'baixa'
  END AS prioridade_inspecao,
  caiu_contra_si,
  vizinhanca_estavel,
  caiu_contra_si AND vizinhanca_estavel AS atende_os_dois_eixos,
  sinal_violacao_recente,
  variacao_da_uc,
  variacao_do_conjunto,
  consumo_medio_baseline_kwh,
  consumo_medio_recente_kwh,
  dias_no_baseline,
  dias_no_periodo_recente,
  CASE
    WHEN caiu_contra_si AND vizinhanca_estavel AND sinal_violacao_recente
      THEN 'consumo caiu contra o proprio historico, a vizinhanca seguiu estavel e o medidor registrou violacao'
    WHEN caiu_contra_si AND vizinhanca_estavel
      THEN 'consumo caiu contra o proprio historico enquanto a vizinhanca seguiu estavel'
    WHEN sinal_violacao_recente
      THEN 'o medidor registrou violacao sem queda relevante de consumo'
    ELSE 'consumo caiu junto com a vizinhanca, compativel com evento de rede'
  END AS motivo_observado
FROM (
  SELECT
    *,
    variacao_da_uc <= ${queda_uc_limiar} AS caiu_contra_si,
    abs(variacao_do_conjunto) <= ${estabilidade_conjunto_limiar} AS vizinhanca_estavel
  FROM ${catalogo}.${schema_silver}.baseline_consumo
  WHERE consumo_medio_baseline_kwh IS NOT NULL
    AND consumo_medio_recente_kwh IS NOT NULL
)
WHERE variacao_da_uc <= ${queda_uc_limiar}
   OR sinal_violacao_recente
