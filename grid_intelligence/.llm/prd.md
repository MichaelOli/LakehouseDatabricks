# PRD — Grid Intelligence

Plataforma de dados e IA da **Luz do Vale Distribuidora S.A.**, distribuidora fictícia de energia elétrica. Este documento é a referência dos prompts seguintes. O que não está aqui não entra no projeto.

## Domínio

A distribuidora opera sob regulação da ANEEL. Três dores, todas mensuráveis em dinheiro, orientam o que a plataforma entrega:

1. **Continuidade do fornecimento.** Interromper além do limite regulatório gera compensação financeira automática ao consumidor. Em 2024 as distribuidoras brasileiras pagaram mais de R$ 1,1 bilhão em compensações.
2. **Perdas não técnicas (PNT).** Energia distribuída e não faturada. Em 2025 somaram cerca de R$ 11,5 bilhões, dos quais cerca de R$ 7,9 bilhões foram repassados à tarifa.
3. **Atendimento ao cliente.** Milhares de ligações viram transcrição e ninguém lê. Dentro delas está o aviso antecipado da reclamação na ouvidoria.

## Glossário

Estes termos não têm sinônimo no projeto.

| Termo | Definição |
| --- | --- |
| **UC — Unidade Consumidora** | O ponto de entrega de energia. Não é sinônimo de cliente: um cliente pode ter várias UCs. |
| **Conjunto** | Subdivisão geográfica da área de concessão. É a unidade de agregação do regulador. |
| **DEC** | Duração Equivalente de Interrupção por UC — tempo médio, em horas, sem fornecimento. |
| **FEC** | Frequência Equivalente de Interrupção por UC — número médio de interrupções. |
| **PNT** | Perdas Não Técnicas. |
| **Prioridade de inspeção** | Classificação de quanto uma UC merece visita técnica. |

## Regras de negócio

Os identificadores abaixo são os que este projeto define. Números ausentes (RN-02, RN-03, RN-05, RN-08) não foram especificados e não devem ser inventados.

- **RN-01** — Só interrupções com 3 minutos ou mais entram na apuração de DEC e FEC. A regra vive na camada de transformação, nunca no relatório.
- **RN-04** — DEC e FEC têm uma única definição no sistema, consumida por dashboard, agente e relatório.
- **RN-06** — Uma UC é candidata a inspeção quando o consumo cai em dois eixos simultâneos: contra o próprio baseline e enquanto a vizinhança permanece estável. Só o primeiro eixo apontaria o bairro inteiro depois de um apagão.
- **RN-07** — A saída da detecção é prioridade de inspeção — alta, média, baixa. Nunca um rótulo de fraude, furto ou culpa. Queda de consumo também é mudança de morador, imóvel desocupado, defeito de medidor e erro de leitura. Nenhuma coluna, variável ou comentário pode usar as palavras "fraude", "furto" ou "culpado" como rótulo de saída.
- **RN-09** — Dado pessoal em transcrição é mascarado antes de qualquer análise de conteúdo.
- **RN-10** — O texto original identificado é preservado com acesso restrito. Duas proteções coexistem: uma na leitura, outra na análise.
- **RN-11** — A camada de ingestão não filtra, não corrige e não aplica regra de negócio. Leitura inválida de medidor é um fato sobre o medidor.
- **RN-12** — Todo registro ingerido carrega origem e momento de ingestão.
- **RN-13** — O agente conversacional acessa apenas a camada de negócio.
- **RN-14** — As entidades da camada gold carregam descrição em linguagem de negócio. Bronze e silver não precisam.

## Modelo de informação

Quatro bases sintéticas em Parquet, com quatro anos de histórico, crescimento de 30% ao ano na carga e sazonalidade de verão no atendimento (dezembro a março recebem quase o dobro de ligações). O dataset traz defeitos propositais — consumo nulo, negativo, fisicamente impossível, linhas duplicadas e interrupções abaixo de 3 minutos — para a qualidade e a RN-01 terem o que fazer.

| Base | Grão | Volume |
| --- | --- | --- |
| `unidades_consumidoras` | uma por ponto de entrega | 4.000 |
| `interrupcoes` | uma por evento de rede | 1.383 |
| `consumo_diario` | uma por UC por dia | cerca de 5,85 milhões |
| `chamados` | uma por ligação, com transcrição | 2.801 |

Camadas, isoladas por catálogo (`dev` e `prod`), com os mesmos nomes de schema nos dois ambientes:

| Camada | Papel |
| --- | --- |
| `raw` | Volume `landing`. Arquivo como chegou. Sem regra de negócio. |
| `bronze` | Ingestão fiel do volume. Não filtra nem corrige (RN-11). Cada registro carrega origem e momento de ingestão (RN-12). |
| `silver` | Transformação: cadastro limpo, regra dos 3 minutos, deduplicação, baseline de consumo, mascaramento do texto. |
| `gold` | Entidades de negócio, com descrição (RN-14). Única camada que o agente lê (RN-13). |

O nome da tabela não repete a camada: `bronze.chamados`, nunca `bronze_chamados`.

## Entregas de negócio previstas

Ainda não construídas. A gold materializa quatro entregas, e a metric view de DEC/FEC é a definição única que dashboard, agente e relatório consomem (RN-04).

1. **Continuidade.** DEC e FEC por conjunto, só com interrupções de 3 minutos ou mais (RN-01), a partir de uma metric view só.
2. **Prioridade de inspeção.** Alta, média ou baixa, quando o consumo da UC cai contra o próprio baseline e a vizinhança segue estável (RN-06, RN-07).
3. **Atendimento.** Transcrição mascarada para análise e texto original com acesso restrito (RN-09, RN-10).
4. **Cadastro da concessão.** UC, cliente e conjunto, para que as três entregas acima agreguem na unidade do regulador sem tratar UC como sinônimo de cliente.

Em cima da gold, na ordem dos prompts seguintes: dashboard AI/BI, agente conversacional em português e relatório executivo.
