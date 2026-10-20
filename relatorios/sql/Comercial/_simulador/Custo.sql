-- Simulador de Preço — detalhe do custo com crédito (últimas compras do item na HL_CUSTO_CREDITO_COMPRA)
-- A 1ª linha (Ordem = 1) é a compra usada no simulador. Filtro: :itemcode
SELECT TOP 6
    ROW_NUMBER() OVER (ORDER BY C."DocDate_Compra" DESC, C."DocEntry_Compra" DESC) AS "Ordem",
    C."DocEntry_Compra" AS "DocEntry", O."DocNum", O."Serial" AS "NumNF", O."CardCode", O."CardName",
    TO_VARCHAR(C."DocDate_Compra", 'DD/MM/YYYY') AS "Data",
    C."ItemCode", C."ItemName", C."GrupoTributario", C."NcmCode",
    C."Quantity", C."LineTotalAdj",
    C."VlrICMS", C."InclusoCustoICMS", C."InclusoReceitaICMS",
    C."VlrPIS", C."AlqPIS", C."InclusoCustoPIS", C."InclusoReceitaPIS",
    C."VlrCOFINS", C."AlqCOFINS", C."InclusoCustoCOFINS", C."InclusoReceitaCOFINS",
    C."VlrIPI", C."InclusoCustoIPI", C."InclusoReceitaIPI",
    C."VlrICMSST", C."InclusoCustoICMSST", C."InclusoReceitaICMSST",
    C."ImpostosPorFora", C."TotalCredito", C."CustoComCredito",
    C."CustoSTD", C."PercentualMajorado", C."VlrMajorado",
    CASE WHEN LEFT(C."GrupoTributario", 5) = '01.00' OR F."QryGroup30" = 'Y' THEN 'STD' ELSE 'COMPRA' END AS "Regra",
    CASE WHEN LEFT(C."GrupoTributario", 5) = '01.00' THEN 'grupo tributário 01.00' WHEN F."QryGroup30" = 'Y' THEN 'fornecedor padrão com propriedade 30' ELSE '' END AS "MotivoRegra"
FROM "SBO_HLMOTOBIKE_PRD".HL_CUSTO_CREDITO_COMPRA C
LEFT JOIN "SBO_HLMOTOBIKE_PRD".OPCH O ON O."DocEntry" = C."DocEntry_Compra"
LEFT JOIN "SBO_HLMOTOBIKE_PRD".OITM I ON I."ItemCode" = C."ItemCode"
LEFT JOIN "SBO_HLMOTOBIKE_PRD".OCRD F ON F."CardCode" = I."CardCode"
WHERE C."ItemCode" = :itemcode
  AND C."CANCELED" = 'N' AND C."DocDate_Compra" <= CURRENT_DATE
ORDER BY C."DocDate_Compra" DESC, C."DocEntry_Compra" DESC
