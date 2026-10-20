/*===============================================
Objetivo: Todos os adiantamentos que foram pagos
mas não foram compensados com nota fiscal

Filtros:
- Data
- Fornecedor
- Status: Aberto ou Pago

Filtro nativo:
- Desconsiderar Adiantamentos Devolvidos
===============================================*/

WITH
filtro AS (
  SELECT
    TO_DATE(CASE WHEN COALESCE(CAST(:DocDateINI AS NVARCHAR), '') = ''
                 THEN CURRENT_DATE ELSE CAST(:DocDateINI AS NVARCHAR) END) AS dt_ini,
    TO_DATE(CASE WHEN COALESCE(CAST(:DocDateFIM AS NVARCHAR), '') = ''
                 THEN CURRENT_DATE ELSE CAST(:DocDateFIM AS NVARCHAR) END) AS dt_fim
  FROM DUMMY),

ODPO_BASE AS (
    SELECT
        'HL' AS "Filial",
        ODPO."DocEntry",
        ODPO."DocNum",
        ODPO."DocDate",
        ODPO."DocDueDate",
        CASE
          WHEN ODPO."DocStatus"='O' THEN 'Aberto'
          WHEN ODPO."DocStatus"='C' THEN 'Baixado'
          ELSE 'Validar' END AS "DocStatus",
        ODPO."CardCode",
        ODPO."CardName",
        REPLACE(REPLACE(REPLACE(
            TO_NVARCHAR(ODPO."DocTotal", '999,999,990.00'),
            ',','|'),'.', ','),'|','.') AS "DocTotal",
        ODPO."Comments"
    FROM SBO_HLMOTOBIKE_PRD.ODPO
    LEFT JOIN SBO_HLMOTOBIKE_PRD.RPC1 ON RPC1."BaseEntry" = ODPO."DocEntry"
    CROSS JOIN filtro
    WHERE ODPO."CANCELED" = 'N'
        AND IFNULL(RPC1."DocEntry", 0) = 0
        AND ODPO."CardCode" LIKE '%' || :validFor || '%'
        AND ODPO."TaxDate" >= filtro.dt_ini
        AND ODPO."TaxDate" <= filtro.dt_fim
        AND ODPO."DocStatus" LIKE '%' || :stat || '%'

    UNION ALL

    SELECT
        'DHFS' AS "Filial",
        ODPO."DocEntry",
        ODPO."DocNum",
        ODPO."DocDate",
        ODPO."DocDueDate",
        CASE
          WHEN ODPO."DocStatus"='O' THEN 'Aberto'
          WHEN ODPO."DocStatus"='C' THEN 'Baixado'
          ELSE 'Validar' END AS "DocStatus",
        ODPO."CardCode",
        ODPO."CardName",
        REPLACE(REPLACE(REPLACE(
            TO_NVARCHAR(ODPO."DocTotal", '999,999,990.00'),
            ',','|'),'.', ','),'|','.') AS "DocTotal",
        ODPO."Comments"
    FROM SBO_DHFS_PROD.ODPO
    LEFT JOIN SBO_DHFS_PROD.RPC1 ON RPC1."BaseEntry" = ODPO."DocEntry"
    CROSS JOIN filtro
    WHERE ODPO."CANCELED" = 'N'
        AND IFNULL(RPC1."DocEntry", 0) = 0
        AND ODPO."CardCode" LIKE '%' || :validFor || '%'
        AND ODPO."TaxDate" >= filtro.dt_ini
        AND ODPO."TaxDate" <= filtro.dt_fim
        AND ODPO."DocStatus" LIKE '%' || :stat || '%'),

PCH9_BASE AS (
    SELECT DISTINCT
        'HL' AS "Filial",
        PCH9."DocEntry",
        PCH9."BaseAbs"
    FROM SBO_HLMOTOBIKE_PRD.PCH9
    JOIN SBO_HLMOTOBIKE_PRD.OPCH
      ON OPCH."DocEntry" = PCH9."DocEntry"
     AND OPCH."CANCELED" = 'N'

    UNION ALL

    SELECT DISTINCT
        'DHFS' AS "Filial",
        PCH9."DocEntry",
        PCH9."BaseAbs"
    FROM SBO_DHFS_PROD.PCH9
    JOIN SBO_DHFS_PROD.OPCH
      ON OPCH."DocEntry" = PCH9."DocEntry"
     AND OPCH."CANCELED" = 'N'),

OPCH_BASE AS (
    SELECT
        'HL' AS "Filial",
        OPCH."DocEntry",
        OPCH."DocNum",
        OPCH."DocDate",
        OPCH."DocTotal",
        OPCH."NfeValue",
        OPCH."Serial"
    FROM SBO_HLMOTOBIKE_PRD.OPCH
    WHERE OPCH."CANCELED" = 'N'

    UNION ALL

    SELECT
        'DHFS' AS "Filial",
        OPCH."DocEntry",
        OPCH."DocNum",
        OPCH."DocDate",
        OPCH."DocTotal",
        OPCH."NfeValue",
        OPCH."Serial"
    FROM SBO_DHFS_PROD.OPCH
    WHERE OPCH."CANCELED" = 'N'),

DP_PAY AS (
    SELECT
        'HL' AS "Filial",
        VPM2."DocEntry"   AS "DocEntry",
        REPLACE(REPLACE(REPLACE(
            TO_NVARCHAR(VPM2."SumApplied", '999,999,990.00'),
            ',','|'),'.', ','),'|','.') AS "PaidAmount",
        REPLACE(REPLACE(REPLACE(
            TO_NVARCHAR(VPM2."AppliedFC", '999,999,990.00'),
            ',','|'),'.', ','),'|','.') AS "PaidAmountFC",
        REPLACE(REPLACE(REPLACE(
            TO_NVARCHAR(VPM2."DocRate", '990.0000'),
            ',','|'),'.', ','),'|','.') AS "DocRate",
        OVPM."DocDate" AS "PaymentDate"
    FROM SBO_HLMOTOBIKE_PRD.VPM2
    JOIN SBO_HLMOTOBIKE_PRD.OVPM ON OVPM."DocEntry" = VPM2."DocNum"
    WHERE VPM2."InvType" = 204
      AND OVPM."Canceled" = 'N'

    UNION ALL

    SELECT
        'DHFS' AS "Filial",
        VPM2."DocEntry"   AS "DocEntry",
        REPLACE(REPLACE(REPLACE(
            TO_NVARCHAR(VPM2."SumApplied", '999,999,990.00'),
            ',','|'),'.', ','),'|','.') AS "PaidAmount",
        REPLACE(REPLACE(REPLACE(
            TO_NVARCHAR(VPM2."AppliedFC", '999,999,990.00'),
            ',','|'),'.', ','),'|','.') AS "PaidAmountFC",
        REPLACE(REPLACE(REPLACE(
            TO_NVARCHAR(VPM2."DocRate", '990.0000'),
            ',','|'),'.', ','),'|','.') AS "DocRate",
        OVPM."DocDate" AS "PaymentDate"
    FROM SBO_DHFS_PROD.VPM2
    JOIN SBO_DHFS_PROD.OVPM ON OVPM."DocEntry" = VPM2."DocNum"
    WHERE VPM2."InvType" = 204
      AND OVPM."Canceled" = 'N')

SELECT
    ODPO."Filial",
    ODPO."DocNum"                AS "Id Adiant.",
    TO_VARCHAR(TO_DATE(ODPO."DocDate"), 'DD/MM/YYYY')    AS "Data Adiantamento",
    TO_VARCHAR(TO_DATE(ODPO."DocDueDate"), 'DD/MM/YYYY') AS "Dt. Vencimento",
    ODPO."DocStatus"             AS "Status",
    ODPO."CardCode"              AS "Fornecedor",
    ODPO."CardName"              AS "Nome Fornecedor",
    ODPO."DocTotal"              AS "ValorTotal Adiant.",
    ODPO."Comments"              AS "Obs. Adiant.",

    DP_PAY."PaidAmount"          AS "Vlr. Pago R$",
    DP_PAY."PaidAmountFC"        AS "Vlr. Pago US$",
    DP_PAY."DocRate"             AS "Taxa Dólar",
    TO_VARCHAR(TO_DATE(DP_PAY."PaymentDate"), 'DD/MM/YYYY') AS "Dt. Pagamento",

    OPCH."Serial"                AS "NF",
    OPCH."DocNum"                AS "Id NF",
    TO_VARCHAR(TO_DATE(OPCH."DocDate"), 'DD/MM/YYYY')    AS "Dt. NF",
    OPCH."NfeValue"              AS "Vlr. NF"

FROM ODPO_BASE ODPO
LEFT JOIN PCH9_BASE PCH9
       ON PCH9."BaseAbs" = ODPO."DocEntry"
      AND PCH9."Filial"  = ODPO."Filial"
LEFT JOIN OPCH_BASE OPCH
       ON OPCH."DocEntry" = PCH9."DocEntry"
      AND OPCH."Filial"   = PCH9."Filial"
LEFT JOIN DP_PAY
       ON DP_PAY."DocEntry" = ODPO."DocEntry"
      AND DP_PAY."Filial"   = ODPO."Filial"

ORDER BY ODPO."Filial", ODPO."DocEntry", DP_PAY."PaymentDate", OPCH."DocEntry";