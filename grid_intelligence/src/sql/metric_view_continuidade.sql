-- O bloco $$ nao recebe substituicao de parametro. Catalogo e schema ficam no USE.
-- Nenhum ponto e virgula dentro do $$. O executor corta o script no ; e nao entende o literal.
-- DEC divide a soma dos meses pela soma das bases e devolve media mensal.
-- DEC Acumulado divide pela base media do periodo. Num mes so as duas coincidem.
-- Total de UCs tambem divide pelo numero de meses, senao a base aparece multiplicada.

USE CATALOG IDENTIFIER(:catalogo);
USE SCHEMA IDENTIFIER(:schema_gold);

CREATE OR REPLACE VIEW continuidade_metricas
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
source: continuidade_conjunto_mes
comment: "Definicao unica de DEC e FEC por conjunto e mes."
dimensions:
  - name: Conjunto
    expr: nome_conjunto
    comment: "Nome do conjunto, a regiao que o regulador acompanha"
    synonyms:
      - regiao
      - area
  - name: Codigo do Conjunto
    expr: id_conjunto
    comment: "Codigo do conjunto"
  - name: Municipio
    expr: municipio
    comment: "Municipio do conjunto"
  - name: Mes
    expr: mes_apuracao
    comment: "Mes de apuracao dos indicadores"
    synonyms:
      - mes de apuracao
      - competencia
measures:
  - name: DEC
    expr: SUM(uc_horas_interrompidas) / SUM(total_ucs)
    format:
      type: number
      decimal_places:
        type: exact
        places: 2
    comment: "Horas medias sem energia por UC do conjunto. Em varios meses, e a media mensal."
    synonyms:
      - horas sem luz
      - duracao equivalente de interrupcao
  - name: FEC
    expr: SUM(uc_interrupcoes) / SUM(total_ucs)
    format:
      type: number
      decimal_places:
        type: exact
        places: 2
    comment: "Numero medio de interrupcoes por UC do conjunto."
    synonyms:
      - vezes sem luz
      - frequencia equivalente de interrupcao
  - name: DEC Acumulado
    expr: SUM(uc_horas_interrompidas) / (SUM(total_ucs) / COUNT(DISTINCT mes_apuracao))
    format:
      type: number
      decimal_places:
        type: exact
        places: 2
    comment: "Horas sem energia por UC somadas no periodo. O denominador e a base media, nao a soma dos meses."
    synonyms:
      - dec do periodo
      - horas acumuladas sem luz
  - name: Interrupcoes
    expr: SUM(qtd_interrupcoes)
    format:
      type: number
      decimal_places:
        type: exact
        places: 0
    comment: "Quantidade de eventos de continuidade"
  - name: Interrupcoes Climaticas
    expr: SUM(qtd_interrupcoes_climaticas)
    format:
      type: number
      decimal_places:
        type: exact
        places: 0
    comment: "Eventos com causa climatica"
  - name: Proporcao Climatica
    expr: SUM(qtd_interrupcoes_climaticas) / NULLIF(SUM(qtd_interrupcoes), 0)
    format:
      type: percentage
      decimal_places:
        type: exact
        places: 1
    comment: "Parte dos eventos com causa climatica. Mes sem evento nao divide por zero."
  - name: Interrupcoes Programadas
    expr: SUM(qtd_interrupcoes_programadas)
    format:
      type: number
      decimal_places:
        type: exact
        places: 0
    comment: "Eventos com aviso previo"
  - name: Horas UC Interrompidas
    expr: SUM(uc_horas_interrompidas)
    format:
      type: number
      decimal_places:
        type: exact
        places: 1
    comment: "Numerador do DEC, somavel em qualquer recorte"
  - name: Maior Interrupcao
    expr: MAX(maior_duracao_horas)
    format:
      type: number
      decimal_places:
        type: exact
        places: 2
    comment: "Pior evento do recorte, em horas"
  - name: Total de UCs
    expr: SUM(total_ucs) / COUNT(DISTINCT mes_apuracao)
    format:
      type: number
      decimal_places:
        type: exact
        places: 0
    comment: "Base media de UCs do conjunto no periodo"
$$;
