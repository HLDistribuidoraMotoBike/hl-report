
WITH 
bounds              AS (
  SELECT
    TO_DATE(
      CASE WHEN COALESCE(CAST( :DataInicio AS NVARCHAR), '') = ''
           THEN '20210101'        -- default que você preferir
           ELSE CAST( :DataInicio  AS NVARCHAR)
      END
    ) AS dt_ini,
    TO_DATE(
      CASE WHEN COALESCE(CAST( :DataFim AS NVARCHAR), '') = ''
           THEN '20351231'
           ELSE CAST( :DataFim AS NVARCHAR)
      END
    ) AS dt_fim
  FROM DUMMY),
oper                AS (
  SELECT I12."DocEntry", U."Usage"
  FROM SBO_HLMOTOBIKE_PRD.INV12 I12
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OUSG U ON U."ID" = I12."MainUsage"
  GROUP BY I12."DocEntry", U."Usage"),
base_faturamento    AS (
    /* Base de FATURAMENTO (OINV/INV1) com filtros e cálculos */
    SELECT
        CASE
        WHEN COALESCE(NULLIF(CAST(OBPL."U_HL_UDF_NM_MATRIZ" AS NVARCHAR), ''), '0') = '1'
            THEN 'HL - Distribudiora'
        WHEN COALESCE(NULLIF(CAST(OBPL."U_HL_UDF_NM_MATRIZ" AS NVARCHAR), ''), '0') = '2'
            THEN '2W - Distribuidora'
        ELSE 'VALIDAR' END AS "Matriz",
    CABN."DocNum",
    CAST(CABN."Serial" AS NVARCHAR(50)) AS "NF",
    CABN."CardCode"                                    AS "COD CLIENTE",
    CABN."CardName"                                    AS "RAZAO",
    CADC."U_RBH_CPF_CNPJ"                              AS "CPF/CNPJ",
    OCNT."Name"                                        AS "CIDADE",
    REPLACE_REGEXPR('[^a-zA-Z0-9 ]' IN OCNT."Name" WITH '') AS "Cidade Sem Acento",
    CADC."State1"                                      AS "ESTADO",
    CASE WHEN OP."Usage" = 'VENDAS FULFILMET'
         THEN 'MERCADO LIVRE - FULFILMET'
         ELSE VEND."SlpName"
    END                                                AS "VENDEDOR",
    CABN."TaxDate"                                     AS "DATA",
    DETN."ItemCode"                                    AS "COD INTEM",
    DETN."Dscription"                                  AS "DESCRICAO",
    MARC."FirmName"                                    AS "MARCA",
    CADF."AliasName"                                   AS "FABRICANTE",
    CASE
      WHEN CADP."ItmsGrpCod" = '379' THEN 'MOTO'
      WHEN CADP."ItmsGrpCod" = '380' THEN 'BIKE'
      ELSE CASE
            WHEN CADP."QryGroup2" = 'Y' THEN 'AMBOS-BIKE'
            WHEN CADP."QryGroup3" = 'Y' THEN 'AMBOS-MOTO'
            ELSE 'VALIDAR' END
    END                                                AS "APLICACAO",
    DETN."Quantity"                                    AS "QTD",
    DETN."Price"                                       AS "VLR UNIT",
    DETN."LineTotal"                                   AS "VLR TOTAL",
    (COALESCE(DETN."VatSumSy",0) + COALESCE(DETN."StckDstSum",0))               AS "VLR IMPOSTOS",
    (COALESCE(DETN."DistribSum",0) + COALESCE(DETD."LineTotal",0))              AS "OTR. DESPESAS",
    (COALESCE(DETN."LineTotal",0)
     + COALESCE(DETN."VatSumSy",0) + COALESCE(DETN."StckDstSum",0)
     + COALESCE(DETN."DistribSum",0) + COALESCE(DETD."LineTotal",0))            AS "VLR FINAL",
    TO_DECIMAL(REPLACE(NULLIF(CAST(CADP."U_HL_NM_CSTSTD" AS NVARCHAR), ''), ',', '.'), 19, 6) AS "CUSTO STD UNIT",
    (TO_DECIMAL(REPLACE(NULLIF(CAST(CADP."U_HL_NM_CSTSTD" AS NVARCHAR), ''), ',', '.'), 19, 6) * COALESCE(DETN."Quantity",0)) AS "STD TOTAL",
    CASE
        WHEN COALESCE(NULLIF(CAST(OHEM."dept" AS NVARCHAR), ''), '10') ='10' THEN 'E-commerce'
        WHEN COALESCE(NULLIF(CAST(OHEM."dept" AS NVARCHAR), ''), '10') ='3' THEN 'Atacado-Moto'
        WHEN COALESCE(NULLIF(CAST(OHEM."dept" AS NVARCHAR), ''), '10') ='7' THEN 'Atacado-Bike'
        ELSE 'Validar' END AS "Departamento",
    CASE
      WHEN (COALESCE(CABN."U_HL_UDF_NM_VLRVEND",0) > 0 OR DETN."U_HL_UDF_NM_DESC" = '1')
        THEN 'Vend. Especial'
      ELSE 'Vend. Normal'
    END                                                AS "Identificacao Venda",
    CASE
      WHEN COALESCE(CABN."U_HL_UDF_NM_VLRVEND",0) > 0
        THEN (
          (COALESCE(DETN."LineTotal",0)
           + COALESCE(DETN."VatSumSy",0) + COALESCE(DETN."StckDstSum",0)
           + COALESCE(DETN."DistribSum",0) + COALESCE(DETD."LineTotal",0))
          / CASE WHEN COALESCE(CABN."NfeValue",1)=0 THEN 1 ELSE CABN."NfeValue" END
        ) * CASE WHEN COALESCE(CABN."U_HL_UDF_NM_VLRVEND",1)=0 THEN 1 ELSE CABN."U_HL_UDF_NM_VLRVEND" END
      WHEN DETN."U_HL_UDF_NM_DESC"='1'
        THEN 2 * (
          COALESCE(DETN."LineTotal",0)
          + COALESCE(DETN."VatSumSy",0) + COALESCE(DETN."StckDstSum",0)
          + COALESCE(DETN."DistribSum",0) + COALESCE(DETD."LineTotal",0)
        )
      ELSE (
        COALESCE(DETN."LineTotal",0)
        + COALESCE(DETN."VatSumSy",0) + COALESCE(DETN."StckDstSum",0)
        + COALESCE(DETN."DistribSum",0) + COALESCE(DETD."LineTotal",0)
      )
    END                                                AS "Vlr. Original"
  FROM SBO_HLMOTOBIKE_PRD.OINV CABN
  JOIN SBO_HLMOTOBIKE_PRD.INV1 DETN ON DETN."DocEntry" = CABN."DocEntry"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.INV2 DETD ON DETD."DocEntry" = CABN."DocEntry" AND DETD."LineNum" = DETN."LineNum"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OCRD CADC ON CADC."CardCode" = CABN."CardCode"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OSLP VEND ON VEND."SlpCode"  = CABN."SlpCode"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OITM CADP ON CADP."ItemCode" = DETN."ItemCode"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OCRD CADF ON CADF."CardCode" = CADP."CardCode"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OMRC MARC ON MARC."FirmCode" = CADP."FirmCode"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OCNT ON OCNT."AbsId" = CADC."County"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OBPL ON OBPL."BPLId" = CABN."BPLId"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OHEM ON OHEM."salesPrson" = CABN."SlpCode"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.NFN1 ON NFN1."SeqCode" = CABN."SeqCode"
  LEFT JOIN oper OP ON OP."DocEntry" = CABN."DocEntry"
  CROSS JOIN bounds b
  WHERE CABN."CANCELED" = 'N'
    AND OP."Usage" <> 'VENDAS FORA ESTABELE'
    AND (OP."Usage" LIKE 'VENDAS%' OR OP."Usage" IS NULL)
    AND (   NFN1."SeqName" LIKE '%NFe%'
         OR NFN1."SeqName" LIKE 'Fil%'
         OR NFN1."SeqName" LIKE 'Eco%'
         OR COALESCE(NFN1."SeqName",'VAZIO') = 'VAZIO')
    AND CABN."TaxDate" >= b.dt_ini
    AND CABN."TaxDate" <= b.dt_fim
    AND COALESCE(NULLIF(CAST(CABN."Model" AS NVARCHAR), ''), '0') IN ('39')
    AND DETN."ItemCode" LIKE 'RV%'),
baseTransferencia   AS (
    /* Base de TRANSFERÊNCIA (OWTR/WTR1) espelhando as colunas */
  SELECT
    CASE
      WHEN COALESCE(NULLIF(CAST(OBPL."U_HL_UDF_NM_MATRIZ" AS NVARCHAR), ''), '0') = '1'
        THEN 'HL - Distribudiora'
      WHEN COALESCE(NULLIF(CAST(OBPL."U_HL_UDF_NM_MATRIZ" AS NVARCHAR), ''), '0') = '2'
        THEN '2W - Distribuidora'
      ELSE 'VALIDAR'
    END AS "Matriz",
    T."DocNum",
    ''                                                 AS "NF",
    T."CardCode"                                       AS "COD CLIENTE",
    T."CardName"                                       AS "RAZAO",
    C."U_RBH_CPF_CNPJ"                                 AS "CPF/CNPJ",
    OCNT."Name"                                        AS "CIDADE",
    REPLACE_REGEXPR('[^a-zA-Z0-9 ]' IN OCNT."Name" WITH '') AS "Cidade Sem Acento",
    C."State1"                                         AS "ESTADO",
    OSLP."SlpName"                                     AS "VENDEDOR",
    T."DocDate"                                        AS "DATA",
    L."ItemCode"                                       AS "COD INTEM",
    L."Dscription"                                     AS "DESCRICAO",
    MARC."FirmName"                                    AS "MARCA",
    CADF."AliasName"                                   AS "FABRICANTE",
    CASE
      WHEN OITM."ItmsGrpCod" = '379' THEN 'MOTO'
      WHEN OITM."ItmsGrpCod" = '380' THEN 'BIKE'
      ELSE 'AMBOS'
    END                                                AS "APLICACAO",
    L."Quantity"                                       AS "QTD",
    CAST(0 AS DECIMAL(19,6))                           AS "VLR UNIT",
    CAST(0 AS DECIMAL(19,6))                           AS "VLR TOTAL",
    CAST(0 AS DECIMAL(19,6))                           AS "VLR IMPOSTOS",
    CAST(0 AS DECIMAL(19,6))                           AS "OTR. DESPESAS",
    CAST(0 AS DECIMAL(19,6))                           AS "VLR FINAL",
    TO_DECIMAL(REPLACE(NULLIF(CAST(OITM."U_HL_NM_CSTSTD" AS NVARCHAR), ''), ',', '.'), 19, 6) AS "CUSTO STD UNIT",
    (TO_DECIMAL(REPLACE(NULLIF(CAST(OITM."U_HL_NM_CSTSTD" AS NVARCHAR), ''), ',', '.'), 19, 6) * COALESCE(L."Quantity",0)) AS "STD TOTAL",
    CASE
        WHEN COALESCE(NULLIF(CAST(OHEM."dept" AS NVARCHAR), ''), '10') ='10' THEN 'E-commerce'
        WHEN COALESCE(NULLIF(CAST(OHEM."dept" AS NVARCHAR), ''), '10') ='3' THEN 'Atacado-Moto'
        WHEN COALESCE(NULLIF(CAST(OHEM."dept" AS NVARCHAR), ''), '10') ='7' THEN 'Atacado-Bike'
        ELSE 'Validar' END AS "Departamento",
    'Vend. 100% Especial'                              AS "Identificacao Venda",
    CAST(L."LineTotal" AS DECIMAL(19,6))                           AS "Vlr. Original"  -- não se aplica em transferência
  FROM SBO_HLMOTOBIKE_PRD.OWTR T
  JOIN SBO_HLMOTOBIKE_PRD.WTR1 L       ON L."DocEntry" = T."DocEntry"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OSLP    ON OSLP."SlpCode" = T."SlpCode"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OBPL    ON OBPL."BPLId"   = T."BPLId"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OCRD C  ON C."CardCode"   = T."CardCode"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OCNT    ON OCNT."AbsId"   = C."County"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OITM    ON OITM."ItemCode"= L."ItemCode"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OMRC MARC ON MARC."FirmCode" = OITM."FirmCode"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OCRD CADF ON CADF."CardCode" = OITM."CardCode"
  LEFT JOIN SBO_HLMOTOBIKE_PRD.OHEM    ON OHEM."salesPrson" = T."SlpCode"
  CROSS JOIN bounds b
  WHERE T."CANCELED" = 'N'
    AND T."DocDate"  >= b.dt_ini
    AND T."DocDate"  <= b.dt_fim
    AND T."DataVers" = '1'
    AND L."WhsCode"  = '01PERDID'
    AND T."CardCode" IS NOT NULL
    AND T."CardCode" <> ''
    AND L."ItemCode" LIKE 'RV%'),
unificado           AS (
    /* União com origem */
  SELECT 'FATURAMENTO'   AS "Fonte", F.*
  FROM base_faturamento F
  UNION ALL
  SELECT 'TRANSFERENCIA' AS "Fonte", T.*
  FROM baseTransferencia T)

SELECT *
FROM unificado
ORDER BY "DATA", "DocNum", "Fonte";