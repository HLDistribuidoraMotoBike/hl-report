/*===============================================
Objetivo: prazo medio (ponderado pelo valor) entre a
emissao da nota (TaxDate) e a baixa, para:
- Recebimento de clientes (ORCT x OINV)
- Pagamento a fornecedores (OVPM x OPCH)

Filtros:
- Data da baixa (data_ini / data_fim)

Regras:
- Baixa e nota nao canceladas; modelo 39; filial 3 fora
- Visao analitica/sintetica = agrupamento da tela
  (report_config: agrupamento por Indicador > Parceiro).
  As colunas de quantidade / valor medio / media ponderada
  vem nulas na linha e sao calculadas nos grupos.
===============================================*/

WITH BAIXAS AS (
    SELECT
        'Recebimento de clientes' AS "Indicador",
        N."DocEntry" AS "Nota",
        N."Serial" AS "NumeroNF",
        N."CardCode" AS "CodigoPN",
        N."CardName" AS "NomePN",
        L."InstId" AS "Parcela",
        N."TaxDate" AS "Emissao",
        P."DocEntry" AS "Baixa",
        P."DocDate" AS "DataBaixa",
        L."SumApplied" AS "Valor",
        DAYS_BETWEEN(N."TaxDate", P."DocDate") AS "Prazo"
    FROM SBO_HLMOTOBIKE_PRD.ORCT P
    INNER JOIN SBO_HLMOTOBIKE_PRD.RCT2 L
        ON L."DocNum" = P."DocEntry"
       AND L."InvType" = '13'
    INNER JOIN SBO_HLMOTOBIKE_PRD.OINV N
        ON N."DocEntry" = L."DocEntry"
    WHERE P."Canceled" = 'N'
      AND N."CANCELED" = 'N'
      AND N."Model" = '39'
      AND N."BPLId" <> 3
      AND P."DocDate" BETWEEN :data_ini AND :data_fim
      AND L."SumApplied" > 0

    UNION ALL

    SELECT
        'Pagamento a fornecedores' AS "Indicador",
        N."DocEntry" AS "Nota",
        N."Serial" AS "NumeroNF",
        N."CardCode" AS "CodigoPN",
        N."CardName" AS "NomePN",
        L."InstId" AS "Parcela",
        N."TaxDate" AS "Emissao",
        P."DocEntry" AS "Baixa",
        P."DocDate" AS "DataBaixa",
        L."SumApplied" AS "Valor",
        DAYS_BETWEEN(N."TaxDate", P."DocDate") AS "Prazo"
    FROM SBO_HLMOTOBIKE_PRD.OVPM P
    INNER JOIN SBO_HLMOTOBIKE_PRD.VPM2 L
        ON L."DocNum" = P."DocEntry"
       AND L."InvType" = '18'
    INNER JOIN SBO_HLMOTOBIKE_PRD.OPCH N
        ON N."DocEntry" = L."DocEntry"
    WHERE P."Canceled" = 'N'
      AND N."CANCELED" = 'N'
      AND N."BPLId" <> 3
      AND P."DocDate" BETWEEN :data_ini AND :data_fim
      AND L."SumApplied" > 0
)
SELECT
    B."Indicador",
    B."CodigoPN" AS "Codigo PN",
    B."NomePN" AS "Parceiro",
    B."Nota" AS "DocEntry nota",
    B."NumeroNF" AS "Numero NF",
    B."Parcela",
    CAST(B."Emissao" AS DATE) AS "Data emissao",
    B."Baixa" AS "DocEntry baixa",
    CAST(B."DataBaixa" AS DATE) AS "Data baixa",
    CAST(NULL AS BIGINT) AS "Quantidade de notas",
    CAST(NULL AS BIGINT) AS "Quantidade de baixas",
    CAST(ROUND(B."Valor", 2) AS DECIMAL(19,2)) AS "Valor baixado",
    CAST(NULL AS DECIMAL(19,2)) AS "Valor medio por baixa (R$)",
    B."Prazo" AS "Prazo individual (dias)",
    CAST(NULL AS DECIMAL(19,2)) AS "Media ponderada (dias)"
FROM BAIXAS B
ORDER BY
    B."Indicador",
    B."NomePN",
    B."DataBaixa",
    B."Nota",
    B."Parcela"
