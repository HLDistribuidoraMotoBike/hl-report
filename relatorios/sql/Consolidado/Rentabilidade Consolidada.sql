-- Rentabilidade Consolidada (Email)
-- Fonte: HL_RENTABILIDADE (mesma base usada no dashboard "Rentabilidade Consolidado")
--
-- Retorna 4 blocos de linhas, diferenciados pela coluna "Grupo":
--   'Canal'    -> resumo por Canal / Setor Vend. (Atacado quebra em Bike/Moto;
--                 E-commerce nao usa Setor, entao fica uma linha unica)
--   'Venda'    -> uma linha por NF, dentro de cada Canal/Setor
--   'Marca'    -> uma linha por Marca, dentro de cada Canal/Setor
--   'Vendedor' -> uma linha por Vendedor, dentro de cada Canal/Setor
-- O processador Python monta o resumo com o bloco 'Canal' e, para os
-- blocos 'Venda'/'Marca'/'Vendedor', rankeia Top 10 melhor e Top 10
-- pior margem dentro de cada Canal/Setor.
--
-- Filtros: :data_ini (YYYY-MM-DD), :data_fim (YYYY-MM-DD)

WITH Base AS (
    SELECT
        "Canal"                                              AS "Canal",
        CASE WHEN "Canal" = 'Atacado' THEN "Setor" ELSE NULL END
                                                              AS "Setor",
        "DocEntry"                                           AS "DocEntry",
        CAST("Serial" AS VARCHAR)                             AS "NF",
        "FirmName"                                            AS "Marca",
        "Vendedor"                                            AS "Vendedor",
        "ValorTotal", "CreditoPirelli", "CreditoPresumido",
        "Comissao", "FreteProporcional", "IcmsVenda", "StVenda",
        "PisVenda", "CofinsVenda", "IpiVenda", "DifalCalculado",
        "CustoTransferencia", "CustoComCreditoTotal",
        "ReceitaLiquidaComCreditoPirelli"
    FROM "SBO_HLMOTOBIKE_PRD"."HL_RENTABILIDADE"
    WHERE "TIPO_ORIGEM" IN ('VENDA','VENDA_100_ESPECIAL')
      AND "DocDate" BETWEEN :data_ini AND :data_fim
)

-- ── Resumo por Canal / Setor Vend. ──────────────────────────────
SELECT
    'Canal' AS "Grupo", "Canal", "Setor", CAST(NULL AS VARCHAR) AS "Identificador",
    COUNT(DISTINCT "DocEntry")                                              AS "Vendas",
    SUM("ValorTotal")                                                       AS "Vlr Total",
    SUM("CreditoPirelli")                                                   AS "Credito Pirelli",
    SUM("CreditoPresumido")                                                 AS "Credito Presumido",
    SUM(IFNULL("ValorTotal",0)+IFNULL("CreditoPirelli",0)+IFNULL("CreditoPresumido",0)) AS "Total Receita",
    SUM(IFNULL("Comissao",0)+IFNULL("FreteProporcional",0)+IFNULL("IcmsVenda",0)
        +IFNULL("StVenda",0)+IFNULL("PisVenda",0)+IFNULL("CofinsVenda",0)
        +IFNULL("IpiVenda",0)+IFNULL("DifalCalculado",0)+IFNULL("CustoTransferencia",0)) AS "Total Despesa",
    SUM("CustoComCreditoTotal")                                             AS "Total Custo Merc.",
    SUM("ReceitaLiquidaComCreditoPirelli")                                  AS "Receita Liquida",
    ROUND(CASE WHEN SUM("ValorTotal") = 0 THEN 0
               ELSE SUM("ReceitaLiquidaComCreditoPirelli") / SUM("ValorTotal") * 100 END, 2) AS "Margem Pct"
FROM Base
GROUP BY "Canal", "Setor"

UNION ALL

-- ── Por Venda (NF) ───────────────────────────────────────────────
SELECT
    'Venda' AS "Grupo", "Canal", "Setor", "NF" AS "Identificador",
    COUNT(DISTINCT "DocEntry")                                              AS "Vendas",
    SUM("ValorTotal")                                                       AS "Vlr Total",
    SUM("CreditoPirelli")                                                   AS "Credito Pirelli",
    SUM("CreditoPresumido")                                                 AS "Credito Presumido",
    SUM(IFNULL("ValorTotal",0)+IFNULL("CreditoPirelli",0)+IFNULL("CreditoPresumido",0)) AS "Total Receita",
    SUM(IFNULL("Comissao",0)+IFNULL("FreteProporcional",0)+IFNULL("IcmsVenda",0)
        +IFNULL("StVenda",0)+IFNULL("PisVenda",0)+IFNULL("CofinsVenda",0)
        +IFNULL("IpiVenda",0)+IFNULL("DifalCalculado",0)+IFNULL("CustoTransferencia",0)) AS "Total Despesa",
    SUM("CustoComCreditoTotal")                                             AS "Total Custo Merc.",
    SUM("ReceitaLiquidaComCreditoPirelli")                                  AS "Receita Liquida",
    ROUND(CASE WHEN SUM("ValorTotal") = 0 THEN 0
               ELSE SUM("ReceitaLiquidaComCreditoPirelli") / SUM("ValorTotal") * 100 END, 2) AS "Margem Pct"
FROM Base
GROUP BY "Canal", "Setor", "NF", "DocEntry"

UNION ALL

-- ── Por Marca ─────────────────────────────────────────────────────
SELECT
    'Marca' AS "Grupo", "Canal", "Setor", "Marca" AS "Identificador",
    COUNT(DISTINCT "DocEntry")                                              AS "Vendas",
    SUM("ValorTotal")                                                       AS "Vlr Total",
    SUM("CreditoPirelli")                                                   AS "Credito Pirelli",
    SUM("CreditoPresumido")                                                 AS "Credito Presumido",
    SUM(IFNULL("ValorTotal",0)+IFNULL("CreditoPirelli",0)+IFNULL("CreditoPresumido",0)) AS "Total Receita",
    SUM(IFNULL("Comissao",0)+IFNULL("FreteProporcional",0)+IFNULL("IcmsVenda",0)
        +IFNULL("StVenda",0)+IFNULL("PisVenda",0)+IFNULL("CofinsVenda",0)
        +IFNULL("IpiVenda",0)+IFNULL("DifalCalculado",0)+IFNULL("CustoTransferencia",0)) AS "Total Despesa",
    SUM("CustoComCreditoTotal")                                             AS "Total Custo Merc.",
    SUM("ReceitaLiquidaComCreditoPirelli")                                  AS "Receita Liquida",
    ROUND(CASE WHEN SUM("ValorTotal") = 0 THEN 0
               ELSE SUM("ReceitaLiquidaComCreditoPirelli") / SUM("ValorTotal") * 100 END, 2) AS "Margem Pct"
FROM Base
GROUP BY "Canal", "Setor", "Marca"

UNION ALL

-- ── Por Vendedor ──────────────────────────────────────────────────
SELECT
    'Vendedor' AS "Grupo", "Canal", "Setor", "Vendedor" AS "Identificador",
    COUNT(DISTINCT "DocEntry")                                              AS "Vendas",
    SUM("ValorTotal")                                                       AS "Vlr Total",
    SUM("CreditoPirelli")                                                   AS "Credito Pirelli",
    SUM("CreditoPresumido")                                                 AS "Credito Presumido",
    SUM(IFNULL("ValorTotal",0)+IFNULL("CreditoPirelli",0)+IFNULL("CreditoPresumido",0)) AS "Total Receita",
    SUM(IFNULL("Comissao",0)+IFNULL("FreteProporcional",0)+IFNULL("IcmsVenda",0)
        +IFNULL("StVenda",0)+IFNULL("PisVenda",0)+IFNULL("CofinsVenda",0)
        +IFNULL("IpiVenda",0)+IFNULL("DifalCalculado",0)+IFNULL("CustoTransferencia",0)) AS "Total Despesa",
    SUM("CustoComCreditoTotal")                                             AS "Total Custo Merc.",
    SUM("ReceitaLiquidaComCreditoPirelli")                                  AS "Receita Liquida",
    ROUND(CASE WHEN SUM("ValorTotal") = 0 THEN 0
               ELSE SUM("ReceitaLiquidaComCreditoPirelli") / SUM("ValorTotal") * 100 END, 2) AS "Margem Pct"
FROM Base
GROUP BY "Canal", "Setor", "Vendedor"

ORDER BY "Grupo", "Canal", "Setor";
