-- Fluxo de Produtos — Consolidado HLMoto + DHFS
-- Filtros: :validFor (Y/N/''), :lib_compra (Y/N/''), :marca (texto), :filial (HL/DHFS/'')

WITH
bounds AS (
    SELECT
        ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -13)), 1) AS dt_ini,
        ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,   0)), 1) AS dt_fim
    FROM DUMMY
),

-- ══════════════════════════════════════════════════════════════
-- VENDAS HL — só entra se filial = '' ou 'HL'
-- ══════════════════════════════════════════════════════════════
mov_hl AS (
    SELECT OI."DocDate", I1."ItemCode", I1."Quantity"
    FROM SBO_HLMOTOBIKE_PRD.INV1 I1
    JOIN  SBO_HLMOTOBIKE_PRD.OINV OI ON OI."DocEntry" = I1."DocEntry" AND OI."CANCELED" = 'N'
    CROSS JOIN bounds b
    WHERE OI."DocDate" >= b.dt_ini AND OI."DocDate" < b.dt_fim
      AND 1 = (CASE WHEN :filial IN ('','HL') THEN 1 ELSE 0 END)
      AND OI."CardCode" NOT IN ('C000001','C000002','C000003')
      AND EXISTS (
          SELECT 1 FROM SBO_HLMOTOBIKE_PRD.INV12 D
          JOIN SBO_HLMOTOBIKE_PRD.OUSG U ON U."ID" = D."MainUsage"
          WHERE D."DocEntry" = OI."DocEntry"
            AND (U."Descr" LIKE '%Venda%' OR U."Descr" LIKE '%Bonificação%')
            AND U."ID" <> 59
      )
    UNION ALL
    SELECT T."DocDate", L."ItemCode", L."Quantity"
    FROM SBO_HLMOTOBIKE_PRD.OWTR T
    JOIN  SBO_HLMOTOBIKE_PRD.WTR1 L ON L."DocEntry" = T."DocEntry"
    CROSS JOIN bounds b
    WHERE T."CANCELED" = 'N' AND T."DocDate" >= b.dt_ini AND T."DocDate" < b.dt_fim
      AND T."DataVers" = '1' AND L."WhsCode" = '01PERDID'
      AND T."CardCode" IS NOT NULL AND T."CardCode" <> ''
      AND 1 = (CASE WHEN :filial IN ('','HL') THEN 1 ELSE 0 END)
      AND T."CardCode" NOT IN ('C000001','C000002','C000003')
),

-- ══════════════════════════════════════════════════════════════
-- VENDAS DHFS — só entra se filial = '' ou 'DHFS'
-- ══════════════════════════════════════════════════════════════
mov_dhfs AS (
    SELECT OI."DocDate", I1."ItemCode", I1."Quantity"
    FROM SBO_DHFS_PROD.INV1 I1
    JOIN  SBO_DHFS_PROD.OINV OI ON OI."DocEntry" = I1."DocEntry" AND OI."CANCELED" = 'N'
    CROSS JOIN bounds b
    WHERE OI."DocDate" >= b.dt_ini AND OI."DocDate" < b.dt_fim
      AND 1 = (CASE WHEN :filial IN ('','DHFS') THEN 1 ELSE 0 END)
      AND OI."CardCode" NOT IN ('C000001','C000002','C000003')
      AND EXISTS (
          SELECT 1 FROM SBO_DHFS_PROD.INV12 D
          JOIN SBO_DHFS_PROD.OUSG U ON U."ID" = D."MainUsage"
          WHERE D."DocEntry" = OI."DocEntry"
            AND (U."Descr" LIKE '%Venda%' OR U."Descr" LIKE '%Bonificação%')
            AND U."ID" <> 59
      )
    UNION ALL
    SELECT T."DocDate", L."ItemCode", L."Quantity"
    FROM SBO_DHFS_PROD.OWTR T
    JOIN  SBO_DHFS_PROD.WTR1 L ON L."DocEntry" = T."DocEntry"
    CROSS JOIN bounds b
    WHERE T."CANCELED" = 'N' AND T."DocDate" >= b.dt_ini AND T."DocDate" < b.dt_fim
      AND T."CardCode" IS NOT NULL AND T."CardCode" <> ''
      AND 1 = (CASE WHEN :filial IN ('','DHFS') THEN 1 ELSE 0 END)
      AND T."CardCode" NOT IN ('C000001','C000002','C000003')
),

-- ══════════════════════════════════════════════════════════════
-- PIVOT VENDAS HL
-- ══════════════════════════════════════════════════════════════
vendas_hl AS (
    SELECT
        M."ItemCode",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE,   0)) AS VARCHAR), 7) AS "MES_0_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -1)) AS VARCHAR), 7) AS "MES_1_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -2)) AS VARCHAR), 7) AS "MES_2_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -3)) AS VARCHAR), 7) AS "MES_3_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -4)) AS VARCHAR), 7) AS "MES_4_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -5)) AS VARCHAR), 7) AS "MES_5_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -6)) AS VARCHAR), 7) AS "MES_6_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -7)) AS VARCHAR), 7) AS "MES_7_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -8)) AS VARCHAR), 7) AS "MES_8_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -9)) AS VARCHAR), 7) AS "MES_9_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -10)) AS VARCHAR), 7) AS "MES_10_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -11)) AS VARCHAR), 7) AS "MES_11_LABEL",
        LEFT(CAST(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -12)) AS VARCHAR), 7) AS "MES_12_LABEL",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -1)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,   0)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M0",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -2)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -1)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M1",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -3)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -2)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M2",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -4)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -3)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M3",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -5)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -4)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M4",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -6)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -5)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M5",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -7)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -6)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M6",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -8)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -7)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M7",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -9)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -8)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M8",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -10)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -9)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M9",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -11)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -10)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M10",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -12)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -11)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M11",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -13)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -12)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M12"
    FROM mov_hl M GROUP BY M."ItemCode"
),

-- ══════════════════════════════════════════════════════════════
-- PIVOT VENDAS DHFS
-- ══════════════════════════════════════════════════════════════
vendas_dhfs AS (
    SELECT
        M."ItemCode",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -1)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,   0)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M0",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -2)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -1)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M1",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -3)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -2)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M2",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -4)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -3)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M3",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -5)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -4)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M4",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -6)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -5)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M5",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -7)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -6)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M6",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -8)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -7)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M7",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -9)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -8)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M8",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -10)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE,  -9)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M9",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -11)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -10)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M10",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -12)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -11)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M11",
        SUM(CASE WHEN M."DocDate" >= ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -13)),1) AND M."DocDate" < ADD_DAYS(LAST_DAY(ADD_MONTHS(CURRENT_DATE, -12)),1) THEN M."Quantity" ELSE 0 END) AS "QTD_M12"
    FROM mov_dhfs M GROUP BY M."ItemCode"
),

-- ══════════════════════════════════════════════════════════════
-- CUSTO MÉDIO HL
-- ══════════════════════════════════════════════════════════════
custo_hl AS (
    SELECT W."ItemCode", W."AvgPrice" AS "PrecoMatriz", W2."AvgPrice" AS "PrecoFilial"
    FROM SBO_HLMOTOBIKE_PRD.OITW W
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OITW W2 ON W2."ItemCode" = W."ItemCode" AND W2."WhsCode" = '02OPERAC'
    WHERE W."WhsCode" = '01OPERAC'
),

-- ══════════════════════════════════════════════════════════════
-- ESTOQUE CONSOLIDADO — uma linha por ItemCode
-- Soma HL + DHFS respeitando filtro de filial via CASE
-- ══════════════════════════════════════════════════════════════
estoque AS (
    SELECT
        "ItemCode",
        SUM("PED_COMP")      AS "PED_COMP",
        SUM("SALDO_ESTOQUE") AS "SALDO_ESTOQUE",
        SUM("PED_VENDA")     AS "PED_VENDA"
    FROM (
        -- HL
        SELECT
            CADP."ItemCode",
            SUM(CASE WHEN :filial IN ('','HL') THEN E."OnOrder"    ELSE 0 END) AS "PED_COMP",
            SUM(CASE WHEN :filial IN ('','HL') THEN E."OnHand"     ELSE 0 END) AS "SALDO_ESTOQUE",
            SUM(CASE WHEN :filial IN ('','HL') THEN E."IsCommited" ELSE 0 END) AS "PED_VENDA"
        FROM SBO_HLMOTOBIKE_PRD.OITW E
        LEFT JOIN SBO_HLMOTOBIKE_PRD.OITM CADP ON CADP."ItemCode" = E."ItemCode"
        WHERE (E."WhsCode" LIKE '%OPERAC' OR E."WhsCode" LIKE '%PULMAO')
          AND CADP."ItemCode" IS NOT NULL
        GROUP BY CADP."ItemCode"

        UNION ALL

        -- DHFS
        SELECT
            CADP."ItemCode",
            SUM(CASE WHEN :filial IN ('','DHFS') THEN E."OnOrder"    ELSE 0 END) AS "PED_COMP",
            SUM(CASE WHEN :filial IN ('','DHFS') THEN E."OnHand"     ELSE 0 END) AS "SALDO_ESTOQUE",
            SUM(CASE WHEN :filial IN ('','DHFS') THEN E."IsCommited" ELSE 0 END) AS "PED_VENDA"
        FROM SBO_DHFS_PROD.OITW E
        LEFT JOIN SBO_DHFS_PROD.OITM CADP ON CADP."ItemCode" = E."ItemCode"
        WHERE E."WhsCode" IN ('01','02')
          AND CADP."ItemCode" IS NOT NULL
        GROUP BY CADP."ItemCode"
    ) AS EST_UNION
    GROUP BY "ItemCode"
),

-- ══════════════════════════════════════════════════════════════
-- COMPRAS HL — última nota por item
-- ══════════════════════════════════════════════════════════════
compras_hl AS (
    SELECT P1."ItemCode", MAX(OP."DocDate") AS "DATA_COMP", SUM(P1."Quantity") AS "QTD"
    FROM SBO_HLMOTOBIKE_PRD.PCH1 P1
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OPCH OP ON OP."DocEntry" = P1."DocEntry"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OITM IT ON IT."ItemCode"  = P1."ItemCode"
    INNER JOIN (
        SELECT IT2."ItemCode", MAX(OP2."DocEntry") AS "DocEntry"
        FROM SBO_HLMOTOBIKE_PRD.OITM IT2
        LEFT JOIN SBO_HLMOTOBIKE_PRD.PCH1   P2  ON P2."ItemCode"  = IT2."ItemCode"
        LEFT JOIN SBO_HLMOTOBIKE_PRD.OPCH   OP2 ON OP2."DocEntry" = P2."DocEntry"
        INNER JOIN SBO_HLMOTOBIKE_PRD.PCH12 P12 ON P12."DocEntry" = P2."DocEntry"
            AND P12."MainUsage" IN (SELECT "ID" FROM SBO_HLMOTOBIKE_PRD.OUSG WHERE "Usage" LIKE '%COMPRAS%' OR "Usage" LIKE '%IMPORTACAO%')
        WHERE IT2."ItemCode" LIKE 'RV%' AND OP2."CANCELED" = 'N'
        GROUP BY IT2."ItemCode"
    ) AS ULT ON ULT."ItemCode" = P1."ItemCode" AND ULT."DocEntry" = OP."DocEntry"
    WHERE P1."ItemCode" LIKE 'RV%'
      AND 1 = (CASE WHEN :filial IN ('','HL') THEN 1 ELSE 0 END)
    GROUP BY IT."SuppCatNum", OP."CardCode", P1."ItemCode"
),

-- ══════════════════════════════════════════════════════════════
-- COMPRAS DHFS — última nota por item
-- ══════════════════════════════════════════════════════════════
compras_dhfs AS (
    SELECT P1."ItemCode", MAX(OP."DocDate") AS "DATA_COMP", SUM(P1."Quantity") AS "QTD"
    FROM SBO_DHFS_PROD.PCH1 P1
    LEFT JOIN SBO_DHFS_PROD.OPCH OP ON OP."DocEntry" = P1."DocEntry"
    LEFT JOIN SBO_DHFS_PROD.OITM IT ON IT."ItemCode"  = P1."ItemCode"
    INNER JOIN (
        SELECT IT2."ItemCode", MAX(OP2."DocEntry") AS "DocEntry"
        FROM SBO_DHFS_PROD.OITM IT2
        LEFT JOIN SBO_DHFS_PROD.PCH1   P2  ON P2."ItemCode"  = IT2."ItemCode"
        LEFT JOIN SBO_DHFS_PROD.OPCH   OP2 ON OP2."DocEntry" = P2."DocEntry"
        INNER JOIN SBO_DHFS_PROD.PCH12 P12 ON P12."DocEntry" = P2."DocEntry"
            AND P12."MainUsage" IN (SELECT "ID" FROM SBO_DHFS_PROD.OUSG WHERE "Usage" LIKE '%COMPRAS%' OR "Usage" LIKE '%IMPORTACAO%')
        WHERE IT2."ItemCode" LIKE 'RV%' AND OP2."CANCELED" = 'N'
        GROUP BY IT2."ItemCode"
    ) AS ULT ON ULT."ItemCode" = P1."ItemCode" AND ULT."DocEntry" = OP."DocEntry"
    WHERE P1."ItemCode" LIKE 'RV%'
      AND 1 = (CASE WHEN :filial IN ('','DHFS') THEN 1 ELSE 0 END)
    GROUP BY IT."SuppCatNum", OP."CardCode", P1."ItemCode"
),

-- ══════════════════════════════════════════════════════════════
-- FULFILMENT ML (apenas HL)
-- ══════════════════════════════════════════════════════════════
fulfilment AS (
    SELECT DETN."ItemCode",
        SUM(DETN."Quantity")        AS "Total transferido",
        IFNULL(DEVV."Devolvido", 0) AS "Devolvido"
    FROM SBO_HLMOTOBIKE_PRD.OINV  AS CABN
    LEFT JOIN SBO_HLMOTOBIKE_PRD.INV1  AS DETN ON DETN."DocEntry" = CABN."DocEntry"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.INV12 AS DETE ON DETE."DocEntry" = CABN."DocEntry"
    LEFT JOIN (
        SELECT DETN2."ItemCode", SUM(DETN2."Quantity") AS "Devolvido"
        FROM SBO_HLMOTOBIKE_PRD.ORIN  AS C2
        LEFT JOIN SBO_HLMOTOBIKE_PRD.RIN1  AS DETN2 ON DETN2."DocEntry" = C2."DocEntry"
        LEFT JOIN SBO_HLMOTOBIKE_PRD.RIN12 AS DETE2 ON DETE2."DocEntry" = C2."DocEntry"
        WHERE C2."CANCELED" = 'N' AND DETE2."MainUsage" IN ('36','45')
        GROUP BY DETN2."ItemCode"
    ) AS DEVV ON DEVV."ItemCode" = DETN."ItemCode"
    WHERE CABN."CANCELED" = 'N' AND DETE."MainUsage" IN ('36','45')
    GROUP BY DETN."ItemCode", DEVV."Devolvido"
)

-- ══════════════════════════════════════════════════════════════
-- SELECT FINAL
-- ══════════════════════════════════════════════════════════════
SELECT
    PROD."ItemCode"                                                                     AS "CODIGO",
    PROD."ItemName"                                                                     AS "DESCRICAO",
    MARC."FirmName"                                                                     AS "MARCA",
    CADF."AliasName"                                                                    AS "FABRICANTE",
    PROD."U_HL_ID_FAMILIA"                                                              AS "FAMILIA",
    PROD."SuppCatNum"                                                                   AS "COD. FABRICANTE",
    CASE WHEN PROD."ItmsGrpCod"='379' THEN 'MOTO'
         WHEN PROD."ItmsGrpCod"='380' THEN 'BIKE' ELSE 'AMBOS' END                    AS "APLICACAO",
    CASE WHEN PROD."validFor"  ='Y' THEN 'ATIVO'   ELSE 'INATIVO' END                  AS "STATUS",
    CASE WHEN PROD."QryGroup1" ='Y' THEN 'INATIVO'  ELSE 'ATIVO'  END                  AS "LIB. COMPRA",
    TO_DECIMAL(IFNULL(PROD."PurPackUn",              0), 4, 2)                         AS "QTD CAIXA",
    REPLACE(CAST(TO_DECIMAL(IFNULL(VLRV."Price",                 0),4,2) AS VARCHAR),'.',',') AS "VLR VENDA",
    REPLACE(CAST(TO_DECIMAL(IFNULL(PROD."U_HL_NM_FOB",          0),4,2) AS VARCHAR),'.',',') AS "VALOR FOB",
    REPLACE(CAST(TO_DECIMAL(IFNULL(PROD."U_HL_NM_CSTSTD",       0),4,2) AS VARCHAR),'.',',') AS "VLR STD",
    REPLACE(CAST(TO_DECIMAL(IFNULL(PROD."U_HL_NM_CSTSTD_SEMST", 0),4,2) AS VARCHAR),'.',',') AS "VLR STD S/ST",
    REPLACE(CAST(TO_DECIMAL(IFNULL(CM."PrecoMatriz",             0),4,2) AS VARCHAR),'.',',') AS "CST MEDIO MATRIZ",
    REPLACE(CAST(TO_DECIMAL(IFNULL(CM."PrecoFilial",             0),4,2) AS VARCHAR),'.',',') AS "CST MEDIO FILIAL",

    -- Fulfilment só faz sentido para HL
    CASE WHEN :filial IN ('','HL')
         THEN CAST(IFNULL(FL."Total transferido" - FL."Devolvido", 0) AS INT)
         ELSE 0 END                                                                     AS "SALD. FULL",

    -- Estoque consolidado respeitando filtro de filial
    CAST(IFNULL(EST."PED_COMP",      0) AS INT)                                        AS "SALD. COMPRA",
    CAST(IFNULL(EST."SALDO_ESTOQUE", 0) AS INT)                                        AS "ESTOQUE",
    CAST(IFNULL(EST."PED_VENDA",     0) AS INT)                                        AS "RESERVA VENDA",
    CAST(IFNULL(EST."SALDO_ESTOQUE", 0) - IFNULL(EST."PED_VENDA", 0) AS INT)          AS "DISPONIVEL",

    -- Última compra: respeita filtro de filial
    CASE
        WHEN :filial = 'HL'   THEN CAST(CAST(CHL."DATA_COMP"   AS DATE) AS VARCHAR)
        WHEN :filial = 'DHFS' THEN CAST(CAST(CDHFS."DATA_COMP" AS DATE) AS VARCHAR)
        -- Sem filtro: retorna a mais recente entre as duas
        WHEN IFNULL(CHL."DATA_COMP",'1900-01-01') >= IFNULL(CDHFS."DATA_COMP",'1900-01-01')
             THEN CAST(CAST(CHL."DATA_COMP"   AS DATE) AS VARCHAR)
        ELSE      CAST(CAST(CDHFS."DATA_COMP" AS DATE) AS VARCHAR)
    END                                                                                 AS "ULTIMA COMPRA",

    -- Qtd última compra: respeita filtro de filial
    CASE
        WHEN :filial = 'HL'   THEN CAST(IFNULL(CHL."QTD",   0) AS INT)
        WHEN :filial = 'DHFS' THEN CAST(IFNULL(CDHFS."QTD", 0) AS INT)
        ELSE CAST(IFNULL(CHL."QTD",0) + IFNULL(CDHFS."QTD",0) AS INT)
    END                                                                                 AS "QTD ULT. COMPRA",

    -- Labels dos meses (sempre da HL como referência de calendário)
    VHL."MES_0_LABEL",  VHL."MES_1_LABEL",  VHL."MES_2_LABEL",  VHL."MES_3_LABEL",
    VHL."MES_4_LABEL",  VHL."MES_5_LABEL",  VHL."MES_6_LABEL",  VHL."MES_7_LABEL",
    VHL."MES_8_LABEL",  VHL."MES_9_LABEL",  VHL."MES_10_LABEL", VHL."MES_11_LABEL",
    VHL."MES_12_LABEL",

    -- Vendas por mês respeitando filtro de filial
    CAST(IFNULL(VHL."QTD_M0", 0)+IFNULL(VDHFS."QTD_M0", 0) AS INT) AS "QTD_M0",
    CAST(IFNULL(VHL."QTD_M1", 0)+IFNULL(VDHFS."QTD_M1", 0) AS INT) AS "QTD_M1",
    CAST(IFNULL(VHL."QTD_M2", 0)+IFNULL(VDHFS."QTD_M2", 0) AS INT) AS "QTD_M2",
    CAST(IFNULL(VHL."QTD_M3", 0)+IFNULL(VDHFS."QTD_M3", 0) AS INT) AS "QTD_M3",
    CAST(IFNULL(VHL."QTD_M4", 0)+IFNULL(VDHFS."QTD_M4", 0) AS INT) AS "QTD_M4",
    CAST(IFNULL(VHL."QTD_M5", 0)+IFNULL(VDHFS."QTD_M5", 0) AS INT) AS "QTD_M5",
    CAST(IFNULL(VHL."QTD_M6", 0)+IFNULL(VDHFS."QTD_M6", 0) AS INT) AS "QTD_M6",
    CAST(IFNULL(VHL."QTD_M7", 0)+IFNULL(VDHFS."QTD_M7", 0) AS INT) AS "QTD_M7",
    CAST(IFNULL(VHL."QTD_M8", 0)+IFNULL(VDHFS."QTD_M8", 0) AS INT) AS "QTD_M8",
    CAST(IFNULL(VHL."QTD_M9", 0)+IFNULL(VDHFS."QTD_M9", 0) AS INT) AS "QTD_M9",
    CAST(IFNULL(VHL."QTD_M10",0)+IFNULL(VDHFS."QTD_M10",0) AS INT) AS "QTD_M10",
    CAST(IFNULL(VHL."QTD_M11",0)+IFNULL(VDHFS."QTD_M11",0) AS INT) AS "QTD_M11",
    CAST(IFNULL(VHL."QTD_M12",0)+IFNULL(VDHFS."QTD_M12",0) AS INT) AS "QTD_M12"

FROM SBO_HLMOTOBIKE_PRD.OITM AS PROD
LEFT JOIN SBO_HLMOTOBIKE_PRD.OCRD AS CADF ON CADF."CardCode" = PROD."CardCode"
LEFT JOIN SBO_HLMOTOBIKE_PRD.OMRC AS MARC ON MARC."FirmCode" = PROD."FirmCode"
LEFT JOIN SBO_HLMOTOBIKE_PRD.ITM1 AS VLRV ON VLRV."ItemCode" = PROD."ItemCode"
    AND VLRV."PriceList" = (
        SELECT CAST("ListNum" AS INT) FROM SBO_HLMOTOBIKE_PRD.OPLN
        WHERE "ListName" LIKE '%TB_BASE_VALOR%'
    )
LEFT JOIN custo_hl    AS CM    ON CM."ItemCode"    = PROD."ItemCode"
LEFT JOIN vendas_hl   AS VHL   ON VHL."ItemCode"   = PROD."ItemCode"
LEFT JOIN vendas_dhfs AS VDHFS ON VDHFS."ItemCode" = PROD."ItemCode"
LEFT JOIN estoque     AS EST   ON EST."ItemCode" = PROD."ItemCode"
LEFT JOIN compras_hl   AS CHL   ON CHL."ItemCode"  = PROD."ItemCode"
LEFT JOIN compras_dhfs AS CDHFS ON CDHFS."ItemCode"= PROD."ItemCode"
LEFT JOIN fulfilment   AS FL    ON FL."ItemCode"   = PROD."ItemCode"

WHERE PROD."ItmsGrpCod" IN ('379','380','381')
  AND PROD."validFor"  LIKE (CASE WHEN :validFor   ='Y' THEN 'Y' WHEN :validFor   ='N' THEN 'N' ELSE '%%' END)
  AND PROD."QryGroup1" LIKE (CASE WHEN :lib_compra ='Y' THEN 'Y' WHEN :lib_compra ='N' THEN 'N' ELSE '%%' END)
  AND MARC."FirmName"  LIKE (CASE WHEN :marca='' THEN '%%' ELSE :marca END)

ORDER BY PROD."ItemCode"
