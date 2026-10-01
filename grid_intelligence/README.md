# Grid Intelligence

Plataforma da concessionária Luz do Vale. O dado entra em Parquet, passa por bronze, silver e gold, e chega em quatro entregas: continuidade, prioridade de inspeção, atendimento e o painel do dia. Um dashboard, um espaço Genie e um relatório executivo leem só a gold.

Dev e prod ficam isolados pelo catálogo (`grid_dev` e `grid_intelligence`). Os schemas `raw`, `bronze`, `silver` e `gold` têm o mesmo nome nos dois.

## Pré-requisitos

- Databricks CLI autenticada no profile `grid_intelligence`.
- Warehouse serverless `1d496deecacf10fd`.
- Os Parquet já estão no volume `raw.landing` do catálogo de dev.

Todo comando de CLI leva `--profile grid_intelligence`.

## Sequência

Na pasta `grid_intelligence`:

```bash
databricks bundle validate --strict --target dev --profile grid_intelligence
databricks bundle deploy --target dev --profile grid_intelligence
databricks bundle run grid_intelligence_job --target dev --profile grid_intelligence
python src/genie/aplicar_space.py grid_dev
```

O job libera a leitura da bronze, atualiza o pipeline, recoloca a máscara, recria a metric view e gera o relatório. Em dev, `usar_ia` é `false`: a silver de texto usa regras e o relatório sai de um modelo fixo. Em prod o padrão é `true`, com as funções `ai_*`.

A demonstração das regras:

```bash
databricks experimental aitools tools query --profile grid_intelligence \
  --param catalogo=grid_dev src/sql/demonstracao.sql
```

## Pastas

- `src/pipelines/grid_intelligence/transformations/`: bronze, silver e gold do pipeline.
- `src/sql/`: máscara, metric view e as queries da demonstração.
- `src/dashboards/`: painel Lakeview. Catálogo e schema entram pelo bundle.
- `src/genie/`: definição do espaço e o script que aplica o catálogo.
- `src/notebooks/`: relatório executivo.
- `resources/`: schemas, volume, pipeline, job e dashboard.
- `prompts/`: o roteiro da aula. `.llm/prd.md`: o produto.

## Regras que o código não negocia

- A bronze não filtra nem corrige.
- Evento abaixo de 3 minutos fica na bronze e sai da silver.
- DEC e FEC só nascem na metric view, com `MEASURE`.
- Prioridade de inspeção usa os dois eixos. Não é acusação, e o texto não usa fraude, furto nem culpado.
- Nome, telefone e transcrição da bronze ficam mascarados fora do grupo `atendimento`.
- O agente e o relatório leem somente a gold.
- Catálogo só em `databricks.yml`. Schema só pela referência ao recurso.

## Recomeçar do zero

Destrutivo. O comando não pede confirmação. `CASCADE` remove schemas, tabelas, volumes e os arquivos dentro deles.

```bash
databricks experimental aitools tools query --profile grid_intelligence \
  "DROP CATALOG IF EXISTS grid_dev CASCADE"
```

Confirme antes de rodar. O mesmo padrão vale para o catálogo de produção, com o mesmo efeito.
