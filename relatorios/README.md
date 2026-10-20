# Relatórios

Cada relatório é um arquivo SQL numa **pasta** (a pasta é o que se libera para um grupo em Admin → Grupos).
Id do relatório = `Pasta/Nome` (endereço da tela: `/r/Pasta/Nome`).

```
sql/<Pasta>/<Nome>.sql           consulta; filtros como :nome_do_filtro (viram parâmetros, na ordem)
sql/<Pasta>/_<sub>/<Nome>.sql    consulta auxiliar de um indicador (fora do menu; id "Pasta/_sub/Nome")
sql/<Nome>.sql                   pasta "Geral"
config/<Pasta>/<Nome>.json       configuração (opcional — sem ela: lista com filtros data_ini, data_fim, marca, loja)
templates/<Arquivo>.html         página própria de um indicador
```

## SQL

- Linhas que começam com `--` são removidas antes de executar.
- `:nome` vira parâmetro com o valor do filtro de mesmo `id`; filtro não informado vale `''` (trate vazio como "todos").
- Colunas `MES_<n>_LABEL` vazias recebem `AAAA-MM` de n meses atrás (pivot de meses).

## Config (`config/<Pasta>/<Nome>.json`)

| Campo | Uso |
|---|---|
| `tipo` | `lista` (tela padrão) ou `indicador` (página própria em `templates/`) |
| `titulo` | nome no menu e na tela (padrão: nome do arquivo) |
| `schema` | troca o schema do HANA só para este relatório (ex.: `SBO_MATRIZ`) |
| `filtros` | `[{id, label, tipo: date\|number\|select\|text, opcoes?, placeholder?}]` — `data_ini`/`data_fim` já vêm com o 1º dia do mês / hoje |
| `template` | (indicador) arquivo em `templates/` (padrão: `<Nome>.html`) |
| `modo: "pivot"` | lista com meses em colunas: `colunas_fixas`, `colunas_mes_label`, `colunas_mes_qtd` |
| `colunas_congeladas` | quantas colunas da esquerda ficam fixas ao rolar (lista e pivot) |
| `agrupamento` | grupos com totais — ver abaixo |

### Agrupamento

```json
"agrupamento": {
  "niveis": ["Indicador", {"coluna": "Codigo PN", "rotulo": "Parceiro"}],
  "agregacoes": {"Valor baixado": "soma", "Prazo": {"tipo": "media_ponderada", "peso": "Valor baixado", "casas": 1}},
  "expandido": false, "total_geral": true, "ocultar_colunas_agrupadas": true, "ocultar_colunas_detalhe": true,
  "titulo": "Cabeçalho da 1ª coluna"
}
```

Tipos: `soma`, `contagem`, `distintos` (coluna pode ser lista), `media`, `media_ponderada` (`peso`), `min`, `max`,
`razao` (`numerador` / `denominador` = nomes de outras colunas agregadas). Excel exporta abas "Resumo" e "Analítico".

## Página de indicador (`templates/`)

HTML completo montado com Jinja: variáveis `nome`, `rel_id` e `config` (`{{ config | tojson }}`). Busca os dados com
`fetch('/api/executar/<Pasta>/<Nome>?filtro=...')` → `{ok, total, colunas, data}` ou `{ok: false, erro}`. O app abre a
página num iframe dentro do menu e cuida do login dessas chamadas; links `href="/"` ("← Voltar") somem dentro do app.
Um template pode usar `{% extends "base.html" %}` (base do Report antigo, sem cabeçalho).
