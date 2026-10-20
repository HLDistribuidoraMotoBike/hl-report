-- Rentabilidade E-commerce
-- Filtros: :marca (texto parcial), :data_ini (YYYY-MM-DD), :data_fim (YYYY-MM-DD)
-- Tipo: indicador
-- Template: RentabilidadeEcommerce.html

WITH 
-- ============================================================
-- CTE 1: Custo de importação por item/documento de compra
-- ============================================================
Importacao AS (
    SELECT 
        OPCH."DocEntry",
        OITM."ItemCode",
        CASE
            WHEN LEFT(OITM."U_HL_GRP_TRIB", 5) = '01.00' OR OCRD."QryGroup30"='Y' THEN
                OITM."U_HL_NM_CSTSTD" - (
                    (SUM(IMPS."VLR ICMS" + IMPS."VLR PIS" + IMPS."VLR COFINS" + IMPS."VLR IPI") 
                    - SUM(PCH1."LineTotal") * (IFNULL(AMMJ."U_HL_NM_PERCENTUAL" / 100, 0))) 
                    / SUM(PCH1."Quantity")
                )
            ELSE
                (SUM(PCH1."LineTotal") 
                + SUM(
                    CASE WHEN IMPS."INCLUSO_CUSTO_PIS"     = 'N' THEN IMPS."VLR PIS"    ELSE 0 END +
                    CASE WHEN IMPS."INCLUSO_CUSTO_COFINS"  = 'N' THEN IMPS."VLR COFINS" ELSE 0 END +
                    CASE WHEN IMPS."INCLUSO_CUSTO_IPI"     = 'N' THEN IMPS."VLR IPI"    ELSE 0 END +
                    CASE WHEN IMPS."INCLUSO_CUSTO_ICMS"    = 'N' THEN IMPS."VLR ICMS"   ELSE 0 END +
                    CASE WHEN IMPS."INCLUSO_CUSTO_ICMSST"  = 'N' THEN IMPS."VLR ICMSST" ELSE 0 END
                ) 
                - SUM(
                    CASE WHEN IMPS."INCLUSO_CUSTO_PIS"     = 'Y' THEN IMPS."VLR PIS"    ELSE 0 END +
                    CASE WHEN IMPS."INCLUSO_CUSTO_COFINS"  = 'Y' THEN IMPS."VLR COFINS" ELSE 0 END +
                    CASE WHEN IMPS."INCLUSO_CUSTO_IPI"     = 'Y' THEN IMPS."VLR IPI"    ELSE 0 END +
                    CASE WHEN IMPS."INCLUSO_CUSTO_ICMS"    = 'Y' THEN IMPS."VLR ICMS"   ELSE 0 END +
                    CASE WHEN IMPS."INCLUSO_CUSTO_ICMSST"  = 'Y' THEN IMPS."VLR ICMSST" ELSE 0 END
                )) / SUM(PCH1."Quantity")
        END AS "Custo com Credito",
        CASE
            WHEN IMPS."INCLUSO_CUSTO_ICMSST"='N' 
                THEN SUM(IMPS."VLR ICMSST") / SUM(PCH1."Quantity") 
            ELSE 0.00 
        END AS "Credito de ST"
    FROM 
        SBO_HLMOTOBIKE_PRD.OITM 
        LEFT JOIN SBO_HLMOTOBIKE_PRD.PCH1  ON PCH1."ItemCode"  = OITM."ItemCode"
        LEFT JOIN SBO_HLMOTOBIKE_PRD.OPCH  ON OPCH."DocEntry"  = PCH1."DocEntry"
        LEFT JOIN SBO_HLMOTOBIKE_PRD.PCH12 ON PCH12."DocEntry" = OPCH."DocEntry"
        LEFT JOIN SBO_HLMOTOBIKE_PRD.ONCM  ON ONCM."AbsEntry"  = OITM."NCMCode"
        LEFT JOIN SBO_HLMOTOBIKE_PRD.OCRD  ON OCRD."CardCode"  = OITM."CardCode"
        LEFT JOIN "SBO_HLMOTOBIKE_PRD"."@HL_AMMJ" AS AMMJ ON AMMJ."Code" = ONCM."NcmCode"
        LEFT JOIN "SBO_HLMOTOBIKE_PRD"."DETIMP_OPCH" AS IMPS ON 
            IMPS."ItemCode" = OITM."ItemCode" AND 
            IMPS."DocEntry" = OPCH."DocEntry" AND    
            IMPS."LineNum"  = PCH1."LineNum"
    WHERE 
        OPCH."CANCELED" = 'N' AND 
        PCH12."MainUsage" IN ('14', '16', '58') AND
        OPCH."DocEntry" NOT IN (232391)
    GROUP BY 
        OPCH."DocEntry",
        OITM."ItemCode",
        AMMJ."U_HL_NM_PERCENTUAL",
        OITM."U_HL_NM_CSTSTD",
        OITM."U_HL_GRP_TRIB",
        IMPS."INCLUSO_CUSTO_ICMSST",
        OCRD."QryGroup30"
),

-- ============================================================
-- CTE 2/3/4: Relação saída x entrada para ICMS Transferência
-- ============================================================
Saida AS (
    SELECT
        OINV."DocEntry"   AS "DocEntry_Saida",
        INV1."LineNum"    AS "LineNum_Saida",
        OINV."CreateDate" AS "CreateDate_Saida",
        OINV."DocTime"    AS "DocTime_Saida",
        INV1."ItemCode"   AS "ItemCode_Saida",
        INV1."Price"      AS "Price_Saida",
        INV1."Quantity"   AS "Quantity_Saida"
    FROM SBO_HLMOTOBIKE_PRD.OINV
    INNER JOIN SBO_HLMOTOBIKE_PRD.INV1 ON INV1."DocEntry" = OINV."DocEntry"
    WHERE OINV."CANCELED" = 'N'
),
Entrada AS (
    SELECT
        OPCH."DocEntry"   AS "DocEntry_Entrada",
        PCH1."LineNum"    AS "LineNum_Entrada",
        OPCH."CreateDate" AS "CreateDate_Entrada",
        OPCH."DocTime"    AS "DocTime_Entrada",
        PCH1."ItemCode"   AS "ItemCode_Entrada",
        PCH1."Price"      AS "Price_Entrada",
        PCH1."Quantity"   AS "Quantity_Entrada",
        IMPS."VLR ICMS"   AS "VLR_ICMS"
    FROM SBO_HLMOTOBIKE_PRD.OPCH
    INNER JOIN SBO_HLMOTOBIKE_PRD.PCH1  ON PCH1."DocEntry"  = OPCH."DocEntry"
    LEFT JOIN  SBO_HLMOTOBIKE_PRD.PCH12 ON PCH12."DocEntry" = OPCH."DocEntry"
    LEFT JOIN  "SBO_HLMOTOBIKE_PRD"."DETIMP_OPCH" AS IMPS
           ON IMPS."DocEntry" = OPCH."DocEntry"
          AND IMPS."LineNum"  = PCH1."LineNum"
    WHERE OPCH."CANCELED" = 'N'
      AND OPCH."BPLId"    = 3
      AND PCH12."MainUsage" = 56
),
Relacao AS (
    SELECT
        s."DocEntry_Saida",   s."LineNum_Saida",
        s."CreateDate_Saida", s."DocTime_Saida",
        s."ItemCode_Saida",   s."Price_Saida",   s."Quantity_Saida",
        e."DocEntry_Entrada", e."LineNum_Entrada",
        e."CreateDate_Entrada", e."DocTime_Entrada",
        e."ItemCode_Entrada", e."Price_Entrada",  e."Quantity_Entrada",
        e."VLR_ICMS",
        ROW_NUMBER() OVER (
            PARTITION BY s."DocEntry_Saida", s."LineNum_Saida"
            ORDER BY e."CreateDate_Entrada", e."DocTime_Entrada"
        ) AS "RN"
    FROM Saida s
    LEFT JOIN Entrada e
        ON  e."CreateDate_Entrada" BETWEEN s."CreateDate_Saida" AND ADD_DAYS(s."CreateDate_Saida", 1)
        AND (
                e."CreateDate_Entrada" > s."CreateDate_Saida"
             OR (    e."CreateDate_Entrada" = s."CreateDate_Saida"
                 AND e."DocTime_Entrada"   >= s."DocTime_Saida")
            )
        AND e."ItemCode_Entrada" = s."ItemCode_Saida"
),

-- ============================================================
-- CTE 5: Descontos Pirelli por item/período
-- ============================================================
pirelli AS (
    SELECT
        ACDP."Code",
        ACDP."U_HL_DT_INICIO",
        ACDP."U_HL_DT_FIM",
        ADDP."U_HL_DS_ITEMCODE",
        ADDP."U_HL_NM_DESCONTO"
    FROM "SBO_HLMOTOBIKE_PRD"."@HL_ACDP" AS ACDP
    LEFT JOIN "SBO_HLMOTOBIKE_PRD"."@HL_ADDP" AS ADDP ON ADDP."Code" = ACDP."Code"
),

-- ============================================================
-- CTE 6: ICMS por linha de produto (Regime, Transferência, Próprio)
-- Granularidade: DocEntry + LineNum
-- ============================================================
IcmsPorLinha AS (
    SELECT
        CABN."DocEntry",
        DETN."LineNum",
        DETN."ItemCode",
        DETN."Quantity",
        CASE
            WHEN IFNULL(APAR."Code",'') <> '' THEN ICMS."VLRIP"
            ELSE 0
        END AS "Icms Proprio",
        CASE
            WHEN IFNULL(APAR."Code",'') <> '' THEN REGI."VLR_ICMS"
            WHEN CADP."ProductSrc" IN (1)     THEN (DETN."Quantity" * REGI."Price_Entrada") * 0.0150
            WHEN CADP."ProductSrc" IN (0,5,6) THEN (DETN."Quantity" * REGI."Price_Entrada") * 0.1200
            ELSE                                   (DETN."Quantity" * REGI."Price_Entrada") * 0.0400
        END AS "Icms Transferencia",
        CASE
            WHEN CADP."ProductSrc" IN (0,5,6) AND CADC."State1" = 'MG' THEN ICMS."VLRBASEIP" * 0.0600
            WHEN CADP."ProductSrc" IN (1,2,3) AND CADC."State1" = 'MG' THEN ICMS."VLRBASEIP" * 0.1400
            WHEN CADC."State1" <> 'MG' AND IFNULL(APAR."Code",'') <> '' THEN ICMS."VLRBASEIP" * 0.0000
            WHEN CADC."State1" <> 'MG' AND IFNULL(APAR."Code",'')  = '' THEN ICMS."VLRBASEIP" * 0.0130
            ELSE 0
        END AS "Icms Regime"
    FROM SBO_HLMOTOBIKE_PRD.OINV AS CABN
    LEFT JOIN SBO_HLMOTOBIKE_PRD.INV1 AS DETN ON DETN."DocEntry" = CABN."DocEntry"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OCRD AS CADC ON CADC."CardCode" = CABN."CardCode"
    LEFT JOIN "SBO_HLMOTOBIKE_PRD"."@HL_APAU" AS TABU ON TABU."Code" = CADC."State1"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OITM AS CADP ON CADP."ItemCode" = DETN."ItemCode"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.ONCM AS CADN ON CADN."AbsEntry" = CADP."NCMCode"
    LEFT JOIN "SBO_HLMOTOBIKE_PRD"."@HL_APAR" AS APAR ON APAR."Code" = CADN."NcmCode"
    LEFT JOIN "RELACAO" AS REGI
           ON REGI."ItemCode_Saida"  = DETN."ItemCode"
          AND REGI."DocEntry_Saida"  = CABN."DocEntry"
          AND REGI."RN" = 1
    LEFT JOIN (
        SELECT
            IMPS."DocEntry", IMPS."LineNum",
            SUM(IMPS."TaxSum")  AS "VLRIP",
            IMPS."TaxRate",
            SUM(IMPS."BaseSum") AS "VLRBASEIP"
        FROM SBO_HLMOTOBIKE_PRD.INV4 AS IMPS
        LEFT JOIN SBO_HLMOTOBIKE_PRD.OSTT AS IMPD ON IMPD."AbsId" = IMPS."staType"
        WHERE IMPS."TaxStatus" = 'Y'
          AND IMPD."AbsId" IN ('10','11','12','25','30','33')
        GROUP BY IMPS."DocEntry", IMPS."LineNum", IMPS."TaxRate"
    ) AS ICMS ON ICMS."DocEntry" = CABN."DocEntry" AND ICMS."LineNum" = DETN."LineNum"
),

-- ============================================================
-- CTE 7: DIFAL por linha de produto
-- Granularidade: DocEntry + LineNum
-- ============================================================
DifalPorLinha AS (
    SELECT
        CABN."DocEntry",
        DETN."LineNum",
        DETN."ItemCode",
        CASE
            WHEN CADC."State1" <> 'MG' THEN
                CASE
                    WHEN IFNULL(CADP."FuelCode", -1) <> -1 THEN 0
                    WHEN TABU."U_HL_DS_TPC" = 'Unica' THEN
                        ICMS."VLRBASEIP" * ((TABU."U_HL_NM_ALQINTERNA" - ICMS."TaxRate") / 100)
                    ELSE
                        ((ICMS."VLRBASEIP" - ICMS."VLRIP") / (1 - TABU."U_HL_NM_ALQINTERNA" / 100))
                        * (TABU."U_HL_NM_ALQINTERNA" / 100)
                        - ICMS."VLRIP"
                END
            ELSE 0
        END AS "Difal"
    FROM SBO_HLMOTOBIKE_PRD.OINV AS CABN
    LEFT JOIN SBO_HLMOTOBIKE_PRD.INV1 AS DETN ON DETN."DocEntry" = CABN."DocEntry"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OCRD AS CADC ON CADC."CardCode" = CABN."CardCode"
    LEFT JOIN "SBO_HLMOTOBIKE_PRD"."@HL_APAU" AS TABU ON TABU."Code" = CADC."State1"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OITM AS CADP ON CADP."ItemCode" = DETN."ItemCode"
    LEFT JOIN (
        SELECT
            IMPS."DocEntry", IMPS."LineNum",
            SUM(IMPS."TaxSum")  AS "VLRIP",
            IMPS."TaxRate",
            SUM(IMPS."BaseSum") AS "VLRBASEIP"
        FROM SBO_HLMOTOBIKE_PRD.INV4 AS IMPS
        LEFT JOIN SBO_HLMOTOBIKE_PRD.OSTT AS IMPD ON IMPD."AbsId" = IMPS."staType"
        WHERE IMPS."TaxStatus" = 'Y'
          AND IMPD."AbsId" IN ('10','11','12','25','30','33')
        GROUP BY IMPS."DocEntry", IMPS."LineNum", IMPS."TaxRate"
    ) AS ICMS ON ICMS."DocEntry" = CABN."DocEntry" AND ICMS."LineNum" = DETN."LineNum"
),

-- ============================================================
-- CTE 8: Impostos (PIS/COFINS/ICMS/IPI) por linha — SBO_HLMOTOBIKE_PRD.DETIMP_OINV
-- ============================================================
ImpostosPorLinha AS (
    SELECT
        "DocEntry",
        "LineNum",
        IFNULL("VLR ICMS",   0.00) AS "VLR ICMS",
        IFNULL("VLR PIS",    0.00) AS "VLR PIS",
        IFNULL("VLR COFINS", 0.00) AS "VLR COFINS",
        IFNULL("VLR IPI",    0.00) AS "VLR IPI"
    FROM "SBO_HLMOTOBIKE_PRD"."DETIMP_OINV"
),

-- ============================================================
-- CTE 9: Custo STD total da NF — base do rateio proporcional
-- ============================================================
CustoTotalNF AS (
    SELECT
        INV1."DocEntry",
        SUM(OITM."U_HL_NM_CSTSTD_SEMST" * INV1."Quantity") AS "CustoTotalNF"
    FROM SBO_HLMOTOBIKE_PRD.INV1
    INNER JOIN SBO_HLMOTOBIKE_PRD.OITM ON OITM."ItemCode" = INV1."ItemCode"
    GROUP BY INV1."DocEntry"
),

-- ============================================================
-- CTE 10: Tabela de frete Amazon (sem JOIN ainda — referência)
-- ============================================================
TabelaFrete AS (
    SELECT
        CAST(REPLACE("U_HL_UDF_NM_PESO_INI", ',', '.') AS DECIMAL(10,2)) AS "Peso Inicial",
        CAST(REPLACE("U_HL_UDF_NM_PESO_FIM", ',', '.') AS DECIMAL(10,2)) AS "Peso Fim",
        CAST(REPLACE("U_HL_UDF_NM_FRETE_01", ',', '.') AS DECIMAL(10,2)) AS "Vlr Frete 01",
        CAST(REPLACE("U_HL_UDF_NM_FRETE_02", ',', '.') AS DECIMAL(10,2)) AS "Vlr Frete 02",
        CAST(REPLACE("U_HL_UDF_NM_FRETE_03", ',', '.') AS DECIMAL(10,2)) AS "Vlr Frete 03",
        CAST(REPLACE("U_HL_UDF_NM_FRETE_04", ',', '.') AS DECIMAL(10,2)) AS "Vlr Frete 04",
        CAST(REPLACE("U_HL_UDF_NM_FRETE_05", ',', '.') AS DECIMAL(10,2)) AS "Vlr Frete 05"
    FROM "SBO_HLMOTOBIKE_PRD"."@HL_TAB_FRETE_ML"
),

-- ============================================================
-- CTE 11: Estoque e compras por item (nível de documento)
-- ============================================================
EstoquePorDoc AS (
    SELECT
        INV1."DocEntry",
        INV1."ItemCode",
        MIN(ESTQ."DISPONIVEL") AS "Estoque",
        CASE WHEN COUNT(ESTQ."ItemCode") > 1 THEN 0 ELSE SUM(ESTQ."COMPRA") END AS "Compras"
    FROM SBO_HLMOTOBIKE_PRD.INV1
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OWHS ON OWHS."WhsCode" = INV1."WhsCode"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OBPL ON OBPL."BPLId"   = OWHS."BPLid"
    LEFT JOIN (
        SELECT
            ESTQ."ItemCode",
            OBPL."U_HL_UDF_NM_MATRIZ",
            SUM(ESTQ."OnHand")                          AS "SALDO_ESTOQUE",
            SUM(ESTQ."IsCommited")                      AS "PED_VENDA",
            SUM(ESTQ."OnHand") - SUM(ESTQ."IsCommited") AS "DISPONIVEL",
            SUM(ESTQ."OnOrder")                         AS "COMPRA"
        FROM SBO_HLMOTOBIKE_PRD.OITW AS ESTQ
        LEFT JOIN SBO_HLMOTOBIKE_PRD.OWHS ON OWHS."WhsCode" = ESTQ."WhsCode"
        LEFT JOIN SBO_HLMOTOBIKE_PRD.OBPL ON OBPL."BPLId"   = OWHS."BPLid"
        WHERE ESTQ."WhsCode" LIKE '%OPERAC'
           OR ESTQ."WhsCode" LIKE '%PULMAO'
        GROUP BY ESTQ."ItemCode", OBPL."U_HL_UDF_NM_MATRIZ"
    ) AS ESTQ ON ESTQ."ItemCode" = INV1."ItemCode"
             AND OBPL."U_HL_UDF_NM_MATRIZ" = ESTQ."U_HL_UDF_NM_MATRIZ"
    GROUP BY INV1."DocEntry", INV1."ItemCode"
),

-- ============================================================
-- CTE 12: Última nota de importação por ItemCode (base do custo c/ crédito)
-- ============================================================
UltimaImportacao AS (
    SELECT T1."ItemCode", T1."Custo com Credito", T1."Credito de ST"
    FROM Importacao AS T1
    INNER JOIN (
        SELECT "ItemCode", MAX("DocEntry") AS "MaxDocEntry"
        FROM Importacao
        GROUP BY "ItemCode"
    ) AS ULTM ON ULTM."ItemCode" = T1."ItemCode" AND ULTM."MaxDocEntry" = T1."DocEntry"
),

-- ============================================================
-- CTE 13: Linha de produto expandida com todos os valores unitários
--         e fator de rateio para despesas consolidadas da NF
-- ============================================================
LinhaProduto AS (
    SELECT
        -- Identificadores
        CABN."DocEntry",
        INV1."LineNum",
        INV1."ItemCode",
        CABN."NumAtCard",
        CABN."Serial"       AS "NF",
        CABN."SeriesStr"    AS "SERIE",
        INV12."StateS"      AS "UF",
        CABN."TaxDate"      AS "DATA",
        CASE
            WHEN LENGTH(CABN."DocTime") = 1 THEN '00:0' || CABN."DocTime"
            WHEN LENGTH(CABN."DocTime") = 2 THEN '00:'  || CABN."DocTime"
            WHEN LENGTH(CABN."DocTime") = 3 THEN '0' || LEFT(CABN."DocTime",1) || ':' || RIGHT(CABN."DocTime",2)
            ELSE LEFT(CABN."DocTime",2) || ':' || RIGHT(CABN."DocTime",2)
        END AS "Hora",
        CABN."SlpCode",
        CAST(OITM."ItemName" AS VARCHAR)  AS "Produto",
        CAST(OMRC."FirmName"  AS VARCHAR) AS "Marca",

        -- Quantidade da linha
        INV1."Quantity",

        -- Custo STD unitário e total da linha
        OITM."U_HL_NM_CSTSTD_SEMST"                                    AS "CustoSTD_Unit",
        OITM."U_HL_NM_CSTSTD_SEMST" * INV1."Quantity"                  AS "CSTSTD_Linha",
        IFNULL(IMPT."Custo com Credito", 0.00) * INV1."Quantity"        AS "CstCredito_Linha",
        IFNULL(INV1."Quantity" * pirelli."U_HL_NM_DESCONTO", 0)         AS "CreditoPirelli_Linha",

        -- Peso da linha
        OITM."IWeight1" * INV1."Quantity"                               AS "Peso_Linha",
        -- Peso total da NF (para cálculo de frete Amazon)
        PESOTOTAL."PesoTotalNF",

        -- Valor de venda total da NF (para rateio)
        CABN."U_HL_UDF_NM_VLRVEND"                                     AS "VlrVendido_NF",

        -- Fator de rateio proporcional ao custo STD (0 a 1)
        CASE
            WHEN IFNULL(CTNF."CustoTotalNF", 0) = 0 THEN 0
            ELSE (OITM."U_HL_NM_CSTSTD_SEMST" * INV1."Quantity") / CTNF."CustoTotalNF"
        END AS "FatorRateio",

        -- DocTotal da NF (usado para % de ICMS)
        CASE WHEN CABN."DocTotal" = 0.00 THEN 1 ELSE CABN."DocTotal" END AS "DocTotal_NF",

        -- Impostos por linha (PIS/COFINS/ICMS/IPI)
        IFNULL(DIMPS."VLR ICMS",   0.00) AS "VLR ICMS",
        IFNULL(DIMPS."VLR PIS",    0.00) AS "VLR PIS",
        IFNULL(DIMPS."VLR COFINS", 0.00) AS "VLR COFINS",
        IFNULL(DIMPS."VLR IPI",    0.00) AS "VLR IPI",

        -- ICMS regime/transferência/próprio por linha
        IFNULL(ICML."Icms Regime",       0.00) AS "Icms Regime",
        IFNULL(ICML."Icms Transferencia",0.00) AS "Icms Transferencia",
        IFNULL(ICML."Icms Proprio",      0.00) AS "Icms Proprio",

        -- DIFAL por linha
        IFNULL(DIFL."Difal", 0.00) AS "Difal",

        -- Estoque e compras por item/doc
        IFNULL(ESTQ."Estoque", 0)  AS "Estoque",
        IFNULL(ESTQ."Compras", 0)  AS "Compras",

        -- Referências para cálculo de frete Amazon (usadas abaixo)
        OSLP."SlpName",
        CABN."U_HL_UDF_NM_FRETE"   AS "Frete_NF",
        CABN."U_HL_UDF_NM_COMISSAO" AS "Comissao_NF",

        -- Tabela de frete Amazon (pelo peso total da NF)
        FRETE."Vlr Frete 01",
        FRETE."Vlr Frete 02",
        FRETE."Vlr Frete 03",
        FRETE."Vlr Frete 04",
        FRETE."Vlr Frete 05"

    FROM SBO_HLMOTOBIKE_PRD.OINV AS CABN
    INNER JOIN SBO_HLMOTOBIKE_PRD.INV1   ON INV1."DocEntry"  = CABN."DocEntry"
    LEFT JOIN  SBO_HLMOTOBIKE_PRD.INV12  ON INV12."DocEntry" = CABN."DocEntry"
    LEFT JOIN  SBO_HLMOTOBIKE_PRD.OITM   ON OITM."ItemCode"  = INV1."ItemCode"
    LEFT JOIN  SBO_HLMOTOBIKE_PRD.OMRC   ON OMRC."FirmCode"  = OITM."FirmCode"
    LEFT JOIN  SBO_HLMOTOBIKE_PRD.ONCM   ON ONCM."AbsEntry"  = OITM."NCMCode"
    LEFT JOIN  "SBO_HLMOTOBIKE_PRD"."@HL_APAR" AS APAR ON APAR."Code" = ONCM."NcmCode"
    LEFT JOIN  SBO_HLMOTOBIKE_PRD.OSLP   ON OSLP."SlpCode"  = CABN."SlpCode"

    -- Crédito Pirelli
    LEFT JOIN pirelli ON pirelli."U_HL_DS_ITEMCODE" = INV1."ItemCode"
                     AND CABN."DocDate" BETWEEN pirelli."U_HL_DT_INICIO" AND pirelli."U_HL_DT_FIM"

    -- Custo com crédito (última importação)
    LEFT JOIN UltimaImportacao AS IMPT ON IMPT."ItemCode" = INV1."ItemCode"

    -- Custo total da NF (base de rateio)
    LEFT JOIN CustoTotalNF AS CTNF ON CTNF."DocEntry" = CABN."DocEntry"

    -- Peso total da NF (para frete Amazon)
    LEFT JOIN (
        SELECT INV1."DocEntry", SUM(OITM."IWeight1" * INV1."Quantity") AS "PesoTotalNF"
        FROM SBO_HLMOTOBIKE_PRD.INV1
        INNER JOIN SBO_HLMOTOBIKE_PRD.OITM ON OITM."ItemCode" = INV1."ItemCode"
        GROUP BY INV1."DocEntry"
    ) AS PESOTOTAL ON PESOTOTAL."DocEntry" = CABN."DocEntry"

    -- Impostos por linha
    LEFT JOIN ImpostosPorLinha AS DIMPS
           ON DIMPS."DocEntry" = CABN."DocEntry"
          AND DIMPS."LineNum"  = INV1."LineNum"

    -- ICMS por linha
    LEFT JOIN IcmsPorLinha AS ICML
           ON ICML."DocEntry" = CABN."DocEntry"
          AND ICML."LineNum"  = INV1."LineNum"

    -- DIFAL por linha
    LEFT JOIN DifalPorLinha AS DIFL
           ON DIFL."DocEntry" = CABN."DocEntry"
          AND DIFL."LineNum"  = INV1."LineNum"

    -- Estoque por doc/item
    LEFT JOIN EstoquePorDoc AS ESTQ
           ON ESTQ."DocEntry" = CABN."DocEntry"
          AND ESTQ."ItemCode" = INV1."ItemCode"

    -- Tabela de frete Amazon (pelo peso total da NF)
    LEFT JOIN TabelaFrete AS FRETE
           ON CAST(REPLACE(PESOTOTAL."PesoTotalNF", ',', '.') AS DECIMAL(10,2))
              BETWEEN FRETE."Peso Inicial" AND FRETE."Peso Fim"

    WHERE CABN."VATRegNum" = '37950696000399'
      AND CABN."CANCELED"  IN ('N','Y')
      AND CABN."DocEntry"  IN (
            SELECT INV1."DocEntry"
            FROM SBO_HLMOTOBIKE_PRD.INV1
            LEFT JOIN SBO_HLMOTOBIKE_PRD.OITM ON OITM."ItemCode" = INV1."ItemCode"
            LEFT JOIN SBO_HLMOTOBIKE_PRD.OMRC ON OMRC."FirmCode"  = OITM."FirmCode"
            WHERE OMRC."FirmName" LIKE '%' || :marca || '%'
          )
)

-- ============================================================
-- QUERY FINAL: Uma linha por produto/linha de NF
-- ============================================================
SELECT
    LP."DocEntry",
    OSLP."SlpName"                          AS "Loja",
    LP."NumAtCard"                          AS "Pedido Ecommerce",
    CAST(LP."NF"    AS VARCHAR)             AS "NF",
    CAST(LP."SERIE" AS VARCHAR)             AS "Serie",
    LP."UF",
    LP."DATA"                               AS "Data Emissao",
    LP."Hora"                               AS "Hora Emissao",
    LP."ItemCode"                           AS "Item Code",
    LP."Produto"                            AS "Produto",
    LP."Marca",
    LP."Quantity"                           AS "Quantidade",

    -- ── Valor anunciado rateado pelo custo STD ──────────────────
    -- ⚠️ Rateio: VlrVendido_NF é o valor total anunciado da NF (U_HL_UDF_NM_VLRVEND).
    --    Como é um único valor por NF (não existe por linha), distribui-se
    --    proporcionalmente ao peso do custo STD de cada produto na NF.
    LP."VlrVendido_NF" * LP."FatorRateio"  AS "Vlr Anunciado",

    -- ── Comissão rateada ────────────────────────────────────────
    -- Amazon: 12% sobre o valor anunciado rateado
    -- Demais: valor de comissão da NF rateado proporcionalmente
    CASE
        WHEN LP."SlpName" LIKE '%AMAZON%'
            THEN (LP."VlrVendido_NF" * LP."FatorRateio") * (12.00 / 100.00)
        ELSE LP."Comissao_NF" * LP."FatorRateio"
    END                                     AS "Comissao",

    -- ── Peso da linha ───────────────────────────────────────────
    LP."Peso_Linha"                         AS "Peso",

    -- ── Frete rateado ───────────────────────────────────────────
    -- Amazon: frete calculado pela tabela sobre peso total da NF, rateado por custo STD
    -- Demais: frete da NF rateado proporcionalmente
    CASE
        WHEN LP."SlpName" LIKE '%AMAZON%' THEN
            (CASE
                WHEN CAST(REPLACE(LP."PesoTotalNF", ',', '.') AS DECIMAL(10,2)) > 10.00 THEN
                    (CAST(CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) - 10 AS INT)
                        * CASE WHEN LP."VlrVendido_NF" >= 200 THEN 4.00 ELSE 3.00 END)
                    + LP."Vlr Frete 01"
                ELSE
                    CASE
                        WHEN LP."VlrVendido_NF" BETWEEN 79     AND 99.99  THEN LP."Vlr Frete 01"
                        WHEN LP."VlrVendido_NF" BETWEEN 100    AND 119.99 THEN LP."Vlr Frete 02"
                        WHEN LP."VlrVendido_NF" BETWEEN 120    AND 149.99 THEN LP."Vlr Frete 03"
                        WHEN LP."VlrVendido_NF" BETWEEN 150    AND 199.99 THEN LP."Vlr Frete 04"
                        WHEN LP."VlrVendido_NF" >= 200                    THEN LP."Vlr Frete 05"
                        ELSE 7.00
                    END
            END) * LP."FatorRateio"
        ELSE LP."Frete_NF" * LP."FatorRateio"
    END                                     AS "Frete",

    -- ── Custos de mercadoria ─────────────────────────────────────
    LP."CSTSTD_Linha"                       AS "Total Custo Mercadorias",
    LP."CstCredito_Linha"                   AS "Total Custo Mercadoria Com Credito",
    LP."CreditoPirelli_Linha"               AS "Total Cred. Pirelli",

    -- ── Valor de NF rateado ──────────────────────────────────────
    LP."DocTotal_NF" * LP."FatorRateio"     AS "Vlr de NF",

    -- ── Impostos por linha ───────────────────────────────────────
    LP."VLR ICMS"                           AS "Vlr. Icms destacado",
    LP."Difal"                              AS "Difal",
    LP."VLR PIS"                            AS "Vlr. Pis",
    LP."VLR COFINS"                         AS "Vlr Cofins",
    LP."VLR IPI"                            AS "Vlr IPI",
    LP."Icms Regime"                        AS "ICMS Presumido",
    LP."Icms Transferencia"                 AS "ICMS Transferencia",

    -- ── % ICMS Presumido sobre NF rateada ────────────────────────
    CASE
        WHEN (LP."DocTotal_NF" * LP."FatorRateio") = 0 THEN 0
        ELSE LP."Icms Regime" / (LP."DocTotal_NF" * LP."FatorRateio") * 100
    END                                     AS "% de ICMS Presumido",

    LP."Icms Regime" + LP."Difal" + LP."Icms Transferencia"
                                            AS "ICMS Presumido + Difal + Transferencia",

    CASE
        WHEN (LP."DocTotal_NF" * LP."FatorRateio") = 0 THEN 0
        ELSE (LP."Icms Regime" + LP."Difal" + LP."Icms Transferencia")
             / (LP."DocTotal_NF" * LP."FatorRateio") * 100
    END                                     AS "% de ICMS",

    -- ── Despesas operacionais ────────────────────────────────────
    -- (Comissão + Frete) — calculados acima com rateio
    (CASE
        WHEN LP."SlpName" LIKE '%AMAZON%'
            THEN (LP."VlrVendido_NF" * LP."FatorRateio") * (12.00 / 100.00)
        ELSE LP."Comissao_NF" * LP."FatorRateio"
    END)
    +
    (CASE
        WHEN LP."SlpName" LIKE '%AMAZON%' THEN
            (CASE
                WHEN CAST(REPLACE(LP."PesoTotalNF", ',', '.') AS DECIMAL(10,2)) > 10.00 THEN
                    (CAST(CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) - 10 AS INT)
                        * CASE WHEN LP."VlrVendido_NF" >= 200 THEN 4.00 ELSE 3.00 END)
                    + LP."Vlr Frete 01"
                ELSE
                    CASE
                        WHEN LP."VlrVendido_NF" BETWEEN 79  AND 99.99  THEN LP."Vlr Frete 01"
                        WHEN LP."VlrVendido_NF" BETWEEN 100 AND 119.99 THEN LP."Vlr Frete 02"
                        WHEN LP."VlrVendido_NF" BETWEEN 120 AND 149.99 THEN LP."Vlr Frete 03"
                        WHEN LP."VlrVendido_NF" BETWEEN 150 AND 199.99 THEN LP."Vlr Frete 04"
                        WHEN LP."VlrVendido_NF" >= 200                 THEN LP."Vlr Frete 05"
                        ELSE 7.00
                    END
            END) * LP."FatorRateio"
        ELSE LP."Frete_NF" * LP."FatorRateio"
    END)                                    AS "Total Desp. Operacional",

    -- ── Total de Impostos ────────────────────────────────────────
    LP."VLR PIS" + LP."VLR COFINS" + LP."VLR IPI"
    + LP."Icms Regime" + LP."Difal" + LP."Icms Transferencia"
                                            AS "Total Impostos (Pis + Cofins + IPI + ICMS(Presumido/Difal/Transferencia))",

    -- ── Receita Bruta (Vlr Anunciado - Impostos - Despesas Op.) ─
    (LP."VlrVendido_NF" * LP."FatorRateio")
    - (LP."VLR PIS" + LP."VLR COFINS" + LP."VLR IPI"
        + LP."Icms Regime" + LP."Difal" + LP."Icms Transferencia")
    - (CASE
        WHEN LP."SlpName" LIKE '%AMAZON%'
            THEN (LP."VlrVendido_NF" * LP."FatorRateio") * (12.00 / 100.00)
        ELSE LP."Comissao_NF" * LP."FatorRateio"
       END)
    - (CASE
        WHEN LP."SlpName" LIKE '%AMAZON%' THEN
            (CASE
                WHEN CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) > 10.00 THEN
                    (CAST(CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) - 10 AS INT)
                        * CASE WHEN LP."VlrVendido_NF" >= 200 THEN 4.00 ELSE 3.00 END)
                    + LP."Vlr Frete 01"
                ELSE
                    CASE
                        WHEN LP."VlrVendido_NF" BETWEEN 79  AND 99.99  THEN LP."Vlr Frete 01"
                        WHEN LP."VlrVendido_NF" BETWEEN 100 AND 119.99 THEN LP."Vlr Frete 02"
                        WHEN LP."VlrVendido_NF" BETWEEN 120 AND 149.99 THEN LP."Vlr Frete 03"
                        WHEN LP."VlrVendido_NF" BETWEEN 150 AND 199.99 THEN LP."Vlr Frete 04"
                        WHEN LP."VlrVendido_NF" >= 200                 THEN LP."Vlr Frete 05"
                        ELSE 7.00
                    END
            END) * LP."FatorRateio"
        ELSE LP."Frete_NF" * LP."FatorRateio"
       END)                                 AS "Receita",

    -- ── Receita Líquida com Custo STD ───────────────────────────
    (LP."VlrVendido_NF" * LP."FatorRateio")
    - (LP."VLR PIS" + LP."VLR COFINS" + LP."VLR IPI"
        + LP."Icms Regime" + LP."Difal" + LP."Icms Proprio")
    - (CASE
        WHEN LP."SlpName" LIKE '%AMAZON%'
            THEN (LP."VlrVendido_NF" * LP."FatorRateio") * (12.00 / 100.00)
        ELSE LP."Comissao_NF" * LP."FatorRateio"
       END)
    - (CASE
        WHEN LP."SlpName" LIKE '%AMAZON%' THEN
            (CASE
                WHEN CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) > 10.00 THEN
                    (CAST(CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) - 10 AS INT)
                        * CASE WHEN LP."VlrVendido_NF" >= 200 THEN 4.00 ELSE 3.00 END)
                    + LP."Vlr Frete 01"
                ELSE
                    CASE
                        WHEN LP."VlrVendido_NF" BETWEEN 79  AND 99.99  THEN LP."Vlr Frete 01"
                        WHEN LP."VlrVendido_NF" BETWEEN 100 AND 119.99 THEN LP."Vlr Frete 02"
                        WHEN LP."VlrVendido_NF" BETWEEN 120 AND 149.99 THEN LP."Vlr Frete 03"
                        WHEN LP."VlrVendido_NF" BETWEEN 150 AND 199.99 THEN LP."Vlr Frete 04"
                        WHEN LP."VlrVendido_NF" >= 200                 THEN LP."Vlr Frete 05"
                        ELSE 7.00
                    END
            END) * LP."FatorRateio"
        ELSE LP."Frete_NF" * LP."FatorRateio"
       END)
    - LP."CSTSTD_Linha"                     AS "Receita Liquido Com Cst STD",

    -- ── Receita Líquida com Crédito ──────────────────────────────
    (LP."VlrVendido_NF" * LP."FatorRateio" + LP."CreditoPirelli_Linha")
    - (LP."VLR PIS" + LP."VLR COFINS" + LP."VLR IPI"
        + LP."Icms Regime" + LP."Difal" + LP."Icms Transferencia")
    - (CASE
        WHEN LP."SlpName" LIKE '%AMAZON%'
            THEN (LP."VlrVendido_NF" * LP."FatorRateio") * (12.00 / 100.00)
        ELSE LP."Comissao_NF" * LP."FatorRateio"
       END)
    - (CASE
        WHEN LP."SlpName" LIKE '%AMAZON%' THEN
            (CASE
                WHEN CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) > 10.00 THEN
                    (CAST(CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) - 10 AS INT)
                        * CASE WHEN LP."VlrVendido_NF" >= 200 THEN 4.00 ELSE 3.00 END)
                    + LP."Vlr Frete 01"
                ELSE
                    CASE
                        WHEN LP."VlrVendido_NF" BETWEEN 79  AND 99.99  THEN LP."Vlr Frete 01"
                        WHEN LP."VlrVendido_NF" BETWEEN 100 AND 119.99 THEN LP."Vlr Frete 02"
                        WHEN LP."VlrVendido_NF" BETWEEN 120 AND 149.99 THEN LP."Vlr Frete 03"
                        WHEN LP."VlrVendido_NF" BETWEEN 150 AND 199.99 THEN LP."Vlr Frete 04"
                        WHEN LP."VlrVendido_NF" >= 200                 THEN LP."Vlr Frete 05"
                        ELSE 7.00
                    END
            END) * LP."FatorRateio"
        ELSE LP."Frete_NF" * LP."FatorRateio"
       END)
    - LP."CstCredito_Linha"                 AS "Receita Liquido Com Credito",

    -- ── Markup sobre Custo STD ───────────────────────────────────
    CASE
        WHEN LP."CSTSTD_Linha" = 0 THEN 0
        ELSE
            (
                (LP."VlrVendido_NF" * LP."FatorRateio")
                - (LP."VLR PIS" + LP."VLR COFINS" + LP."VLR IPI"
                    + LP."Icms Regime" + LP."Difal" + LP."Icms Proprio")
                - (CASE
                    WHEN LP."SlpName" LIKE '%AMAZON%'
                        THEN (LP."VlrVendido_NF" * LP."FatorRateio") * 0.12
                    ELSE LP."Comissao_NF" * LP."FatorRateio"
                   END)
                - (CASE
                    WHEN LP."SlpName" LIKE '%AMAZON%' THEN
                        (CASE
                            WHEN CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) > 10.00 THEN
                                (CAST(CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) - 10 AS INT)
                                    * CASE WHEN LP."VlrVendido_NF" >= 200 THEN 4.00 ELSE 3.00 END)
                                + LP."Vlr Frete 01"
                            ELSE
                                CASE
                                    WHEN LP."VlrVendido_NF" BETWEEN 79  AND 99.99  THEN LP."Vlr Frete 01"
                                    WHEN LP."VlrVendido_NF" BETWEEN 100 AND 119.99 THEN LP."Vlr Frete 02"
                                    WHEN LP."VlrVendido_NF" BETWEEN 120 AND 149.99 THEN LP."Vlr Frete 03"
                                    WHEN LP."VlrVendido_NF" BETWEEN 150 AND 199.99 THEN LP."Vlr Frete 04"
                                    WHEN LP."VlrVendido_NF" >= 200                 THEN LP."Vlr Frete 05"
                                    ELSE 7.00
                                END
                        END) * LP."FatorRateio"
                    ELSE LP."Frete_NF" * LP."FatorRateio"
                   END)
            ) / LP."CSTSTD_Linha"
    END                                     AS "Mkp Receita Com Cst STD",

    -- ── Markup sobre Custo com Crédito ───────────────────────────
    CASE
        WHEN LP."CstCredito_Linha" = 0 THEN 0
        ELSE
            (
                (LP."VlrVendido_NF" * LP."FatorRateio" + LP."CreditoPirelli_Linha")
                - (LP."VLR PIS" + LP."VLR COFINS" + LP."VLR IPI"
                    + LP."Icms Regime" + LP."Difal" + LP."Icms Transferencia")
                - (CASE
                    WHEN LP."SlpName" LIKE '%AMAZON%'
                        THEN (LP."VlrVendido_NF" * LP."FatorRateio") * 0.12
                    ELSE LP."Comissao_NF" * LP."FatorRateio"
                   END)
                - (CASE
                    WHEN LP."SlpName" LIKE '%AMAZON%' THEN
                        (CASE
                            WHEN CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) > 10.00 THEN
                                (CAST(CAST(REPLACE(LP."PesoTotalNF",',','.') AS DECIMAL(10,2)) - 10 AS INT)
                                    * CASE WHEN LP."VlrVendido_NF" >= 200 THEN 4.00 ELSE 3.00 END)
                                + LP."Vlr Frete 01"
                            ELSE
                                CASE
                                    WHEN LP."VlrVendido_NF" BETWEEN 79  AND 99.99  THEN LP."Vlr Frete 01"
                                    WHEN LP."VlrVendido_NF" BETWEEN 100 AND 119.99 THEN LP."Vlr Frete 02"
                                    WHEN LP."VlrVendido_NF" BETWEEN 120 AND 149.99 THEN LP."Vlr Frete 03"
                                    WHEN LP."VlrVendido_NF" BETWEEN 150 AND 199.99 THEN LP."Vlr Frete 04"
                                    WHEN LP."VlrVendido_NF" >= 200                 THEN LP."Vlr Frete 05"
                                    ELSE 7.00
                                END
                        END) * LP."FatorRateio"
                    ELSE LP."Frete_NF" * LP."FatorRateio"
                   END)
            ) / LP."CstCredito_Linha"
    END                                     AS "Mkp Receita Com Credito",

    -- ── Estoque e Compras ─────────────────────────────────────────
    LP."Estoque",
    LP."Compras"

FROM LinhaProduto AS LP
LEFT JOIN SBO_HLMOTOBIKE_PRD.OSLP ON OSLP."SlpCode" = LP."SlpCode"

WHERE LP."DATA" BETWEEN :data_ini AND :data_fim
  AND LP."Produto" <> ''