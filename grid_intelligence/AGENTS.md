# Declarative Automation Bundles Project

This project uses Declarative Automation Bundles (DABs) for deployment. Add project-specific instructions below.

## For AI Agents: Use Databricks AI Tools

**BEFORE any other action, read the `databricks-core` skill.**

It sets you up to work with this project reliably: CLI authentication, profile
selection, data discovery, and the bundle deployment workflow. Without it,
results are often slower and less accurate.

If this skill is not available (Databricks AI Tools are not installed), you can install them for your coding agent in seconds:

```bash
databricks aitools install
```

If the CLI is not installed, see https://docs.databricks.com/dev-tools/cli/install

---

## Project Instructions

- Responda em português do Brasil.
- Todo comando Databricks usa `--profile grid_intelligence`. Não escolha outro profile.
- O catálogo vive só em `databricks.yml` (`${var.catalog}`). No pipeline, o nome chega por configuração. Em SQL de job, use `:catalogo` com `IDENTIFIER`.
- O schema vive em `resources/grid_schemas.yml`. No bundle, use `${resources.schemas.<camada>.name}`.
- Dev e prod se separam pelo catálogo, não por prefixo de schema. `experimental.skip_name_prefix_for_schema` fica ligado.
- Não filtre nem corrija na bronze. Não recalcule DEC ou FEC fora da metric view. Não descreva UC com fraude, furto ou culpado.
- Genie e o relatório executivo leem somente a gold.
- Funções de IA entram como `ai_*`, sem nome de modelo.
- `DROP CATALOG ... CASCADE` está documentado no README e só roda com confirmação explícita.
