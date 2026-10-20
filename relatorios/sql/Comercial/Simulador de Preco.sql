-- Simulador de Preço por RL% (Comercial) — alíquotas, custo e Pirelli por item
-- Consulta principal do relatório; a conta do preço é feita no template Simulador.html.
-- Cascata de TaxCode = HL_PRC_POPULA_ALTP (Tcd 43 -> 44 -> 30 -> 29, uso 13), só leitura.
-- UF = endereço de entrega padrão do cliente (CRD1 'S' = OCRD.ShipToDef).
-- Coeficientes "K_*" são frações do preço da linha (LineTotal), igual ao SAP:
--   ICMS = P*K_ICMS | PIS/COFINS sobre (P - ICMS) | IPI/ST/FCP por fora (InGrossRev='Y')
-- Sem determinações por cliente (regime/montadora/e-commerce) nem presumido/DIFAL/CBS/IBS — decisão 16/10/2026.
-- Custo = último HL_CUSTO_CREDITO_COMPRA (fallback U_HL_NM_CSTSTD), como na HL_RENTABILIDADE.
-- Filtros: :cardcode, :itens (lista ",RV000001,RV000002,")

WITH CLI AS (
    SELECT C."CardCode", C."CardName",
           COALESCE(NULLIF(A."State", ''), C."State1") AS UF
    FROM "SBO_HLMOTOBIKE_PRD".OCRD C
    LEFT JOIN "SBO_HLMOTOBIKE_PRD".CRD1 A ON A."CardCode" = C."CardCode" AND A."AdresType" = 'S' AND A."Address" = C."ShipToDef"
    WHERE C."CardCode" = :cardcode
),
PROD AS (
    SELECT ITM."ItemCode", ITM."ItemName", ITM."U_HL_GRP_TRIB", ITM."U_HL_NM_CSTSTD",
           CAST(NCG."GroupCode" AS NVARCHAR) AS NCM_GROUP,
           CLI.UF, CLI."CardCode", CLI."CardName",
           CAST(CST."GroupCode" AS NVARCHAR) AS GRUPO_EST,
           CADG."Name" AS GRP_TRIB_NOME
    FROM "SBO_HLMOTOBIKE_PRD".OITM ITM
    CROSS JOIN CLI
    LEFT JOIN "SBO_HLMOTOBIKE_PRD".ONCM NCM ON NCM."AbsEntry" = ITM."NCMCode"
    LEFT JOIN "SBO_HLMOTOBIKE_PRD".ONCG NCG ON NCG."GroupCode" = NCM."Group"
    LEFT JOIN "SBO_HLMOTOBIKE_PRD".OCST CST ON CST."Code" = CLI.UF
    LEFT JOIN "SBO_HLMOTOBIKE_PRD"."@HL_GRP_TRIB" CADG ON CADG."Code" = ITM."U_HL_GRP_TRIB"
    WHERE LOCATE(:itens, ',' || ITM."ItemCode" || ',') > 0
),
DET AS (
    -- uma linha por (item, determinação candidata); ORDEM = prioridade da cascata da ALTP
    SELECT P."ItemCode", O.ORDEM, D."DispOrder", T3."EfctFrom", T5."TaxCode"
    FROM PROD P
    INNER JOIN (SELECT 43 AS TCD, 1 AS ORDEM FROM DUMMY UNION ALL SELECT 44, 2 FROM DUMMY
                UNION ALL SELECT 30, 3 FROM DUMMY UNION ALL SELECT 29, 4 FROM DUMMY) O ON 1 = 1
    INNER JOIN "SBO_HLMOTOBIKE_PRD".TCD2 D ON D."Tcd1Id" = O.TCD
                     AND D."KeyFld_1_V" = P."U_HL_GRP_TRIB"
                     AND ( (O.TCD = 43 AND D."KeyFld_2_V" = P.UF AND D."KeyFld_3_V" = P.NCM_GROUP AND D."KeyFld_4_V" = '1')
                        OR (O.TCD = 44 AND D."KeyFld_2_V" = P.UF AND D."KeyFld_3_V" = '1')
                        OR (O.TCD = 30 AND D."KeyFld_2_V" = P.GRUPO_EST AND D."KeyFld_3_V" = P.NCM_GROUP)
                        OR (O.TCD = 29 AND D."KeyFld_2_V" = P.GRUPO_EST) )
    INNER JOIN "SBO_HLMOTOBIKE_PRD".TCD3 T3 ON T3."Tcd2Id" = D."AbsId"
                      AND (T3."EfctFrom" IS NULL OR T3."EfctFrom" <= CURRENT_DATE)
                      AND (T3."EfctTo"   IS NULL OR T3."EfctTo"   >= CURRENT_DATE)
    INNER JOIN "SBO_HLMOTOBIKE_PRD".TCD5 T5 ON T5."Tcd3Id" = T3."AbsId" AND T5."UsageCode" = '13'
),
TAXCODE AS (
    SELECT "ItemCode", "TaxCode" FROM (
        SELECT "ItemCode", "TaxCode",
               ROW_NUMBER() OVER (PARTITION BY "ItemCode" ORDER BY ORDEM, "DispOrder", "EfctFrom" DESC) AS RN
        FROM DET
    ) WHERE RN = 1
),
TAXAS AS (
    SELECT T."ItemCode", T."TaxCode",
        MAX(CASE WHEN NF."Code" = 'ICMS'    THEN OA."Rate"       END) AS RATE_ICMS,
        MAX(CASE WHEN NF."Code" = 'ICMS'    THEN OA."Code"       END) AS COD_ICMS,
        MAX(CASE WHEN NF."Code" = 'PIS'     THEN OA."Code"       END) AS COD_PIS,
        MAX(CASE WHEN NF."Code" = 'COFINS'  THEN OA."Code"       END) AS COD_COFINS,
        MAX(CASE WHEN NF."Code" = 'IPI'     THEN OA."Code"       END) AS COD_IPI,
        MAX(CASE WHEN NF."Code" = 'ICMS-ST' THEN OA."Code"       END) AS COD_ST,
        MAX(CASE WHEN NF."Code" = 'FCP-ST'  THEN OA."Code"       END) AS COD_FCP,
        MAX(CASE WHEN NF."Code" = 'PIS'     THEN OA."Rate"       END) AS RATE_PIS,
        MAX(CASE WHEN NF."Code" = 'COFINS'  THEN OA."Rate"       END) AS RATE_COFINS,
        MAX(CASE WHEN NF."Code" = 'IPI'     THEN OA."Rate"       END) AS RATE_IPI,
        MAX(CASE WHEN NF."Code" = 'IPI'     THEN OA."InGrossRev" END) AS GROSS_IPI,
        MAX(CASE WHEN NF."Code" = 'ICMS-ST' THEN OA."Rate"       END) AS RATE_ICMS_ST,
        MAX(CASE WHEN NF."Code" = 'ICMS-ST' THEN OA."U_Lucro"    END) AS MVA,
        MAX(CASE WHEN NF."Code" = 'ICMS-ST' THEN OA."U_Reducao1" END) AS REDUCAO1_ICMS_ST,
        MAX(CASE WHEN NF."Code" = 'ICMS-ST' THEN OA."U_ReduICMS" END) AS REDU_ICMS_ST,
        MAX(CASE WHEN NF."Code" = 'ICMS-ST' THEN OA."InGrossRev" END) AS GROSS_ICMS_ST,
        MAX(CASE WHEN NF."Code" = 'FCP-ST'  THEN OA."Rate"       END) AS RATE_FCP,
        MAX(CASE WHEN NF."Code" = 'FCP-ST'  THEN OA."U_Lucro"    END) AS LUCRO_FCP,
        MAX(CASE WHEN NF."Code" = 'FCP-ST'  THEN OA."U_ReduICMS" END) AS REDU_ICMS_FCP,
        MAX(CASE WHEN NF."Code" = 'FCP-ST'  THEN OA."InGrossRev" END) AS GROSS_FCP
    FROM TAXCODE T
    LEFT JOIN "SBO_HLMOTOBIKE_PRD".STC1 S  ON S."STCCode" = T."TaxCode"
    LEFT JOIN "SBO_HLMOTOBIKE_PRD".OSTA OA ON OA."Code" = S."STACode" AND OA."Type" = S."STAType"
    LEFT JOIN "SBO_HLMOTOBIKE_PRD".OSTT OT ON OT."AbsId" = OA."Type"
    LEFT JOIN "SBO_HLMOTOBIKE_PRD".ONFT NF ON NF."AbsId" = OT."NfTaxId"
    GROUP BY T."ItemCode", T."TaxCode"
),
CUSTO AS (
    SELECT "ItemCode", "CustoComCredito", "DocDate_Compra" FROM (
        SELECT C."ItemCode", C."CustoComCredito", C."DocDate_Compra",
               ROW_NUMBER() OVER (PARTITION BY C."ItemCode" ORDER BY C."DocDate_Compra" DESC, C."DocEntry_Compra" DESC) AS RN
        FROM "SBO_HLMOTOBIKE_PRD".HL_CUSTO_CREDITO_COMPRA C
        WHERE C."CANCELED" = 'N' AND C."DocDate_Compra" <= CURRENT_DATE
          AND LOCATE(:itens, ',' || C."ItemCode" || ',') > 0
    ) WHERE RN = 1
),
PIRELLI AS (
    SELECT ADDP."U_HL_DS_ITEMCODE" AS "ItemCode", MAX(ADDP."U_HL_NM_DESCONTO") AS DESCONTO_UNIT
    FROM "SBO_HLMOTOBIKE_PRD"."@HL_ACDP" ACDP
    JOIN "SBO_HLMOTOBIKE_PRD"."@HL_ADDP" ADDP ON ADDP."Code" = ACDP."Code"
    WHERE CURRENT_DATE BETWEEN ACDP."U_HL_DT_INICIO" AND ACDP."U_HL_DT_FIM"
      AND LOCATE(:itens, ',' || ADDP."U_HL_DS_ITEMCODE" || ',') > 0
    GROUP BY ADDP."U_HL_DS_ITEMCODE"
)
SELECT
    P."CardCode", P."CardName", P.UF,
    P."ItemCode", P."ItemName", P."U_HL_GRP_TRIB" AS "GrupoTrib", P.GRP_TRIB_NOME AS "GrupoTribNome",
    X."TaxCode",
    IFNULL(X.RATE_ICMS, 0)   AS "AlqICMS",
    IFNULL(X.RATE_PIS, 0)    AS "AlqPIS",
    IFNULL(X.RATE_COFINS, 0) AS "AlqCOFINS",
    CASE WHEN X.GROSS_IPI = 'Y' THEN IFNULL(X.RATE_IPI, 0) ELSE 0 END AS "AlqIPI",
    IFNULL(X.RATE_ICMS_ST, 0) AS "AlqICMSST", IFNULL(X.MVA, 0) AS "MVA",
    -- detalhe para o quadro de impostos da tela
    X.COD_ICMS AS "CodICMS", X.COD_PIS AS "CodPIS", X.COD_COFINS AS "CodCOFINS",
    X.COD_IPI AS "CodIPI", X.COD_ST AS "CodST", X.COD_FCP AS "CodFCP",
    IFNULL(X.REDUCAO1_ICMS_ST, 0) AS "RedBaseST", IFNULL(X.REDU_ICMS_ST, 0) AS "RedICMSST",
    IFNULL(X.RATE_FCP, 0) AS "AlqFCP", IFNULL(X.LUCRO_FCP, 0) AS "MVAFCP", IFNULL(X.REDU_ICMS_FCP, 0) AS "RedFCP",
    -- coeficientes sobre o preço da linha (fração)
    IFNULL(X.RATE_ICMS, 0) / 100 AS K_ICMS,
    (1 - IFNULL(X.RATE_ICMS, 0) / 100) * (IFNULL(X.RATE_PIS, 0) + IFNULL(X.RATE_COFINS, 0)) / 100 AS K_PISCOFINS,
    CASE WHEN X.GROSS_IPI = 'Y' THEN IFNULL(X.RATE_IPI, 0) / 100 ELSE 0 END AS K_IPI,
    CASE WHEN X.GROSS_ICMS_ST = 'Y' AND X.RATE_ICMS_ST IS NOT NULL AND X.MVA IS NOT NULL AND X.RATE_ICMS IS NOT NULL
         THEN GREATEST(0,
                (1 + CASE WHEN X.GROSS_IPI = 'Y' THEN IFNULL(X.RATE_IPI, 0) ELSE 0 END / 100)
              * (1 + X.MVA / 100)
              * (1 - IFNULL(X.REDUCAO1_ICMS_ST, 0) / 100)
              * (X.RATE_ICMS_ST / 100)
              - (X.RATE_ICMS / 100) * (1 - IFNULL(X.REDU_ICMS_ST, 0) / 100))
         ELSE 0 END AS K_ST,
    CASE WHEN X.GROSS_FCP = 'Y' AND X.RATE_FCP IS NOT NULL AND X.LUCRO_FCP IS NOT NULL
         THEN (1 + CASE WHEN X.GROSS_IPI = 'Y' THEN IFNULL(X.RATE_IPI, 0) ELSE 0 END / 100)
            * (1 + X.LUCRO_FCP / 100)
            * (1 - IFNULL(X.REDU_ICMS_FCP, 0) / 100)
            * (X.RATE_FCP / 100)
         ELSE 0 END AS K_FCP,
    COALESCE(C."CustoComCredito", P."U_HL_NM_CSTSTD") AS "CustoUnit",
    CASE WHEN C."CustoComCredito" IS NOT NULL THEN 'Compra ' || TO_VARCHAR(C."DocDate_Compra", 'DD/MM/YYYY') ELSE 'Custo STD' END AS "OrigemCusto",
    IFNULL(PI.DESCONTO_UNIT, 0) AS "PirelliUnit",
    -- sugestão de comissão (regra do atacado na HL_RENTABILIDADE); o comercial pode alterar
    CASE WHEN P.GRP_TRIB_NOME LIKE '%Pneu de Moto%' OR P.GRP_TRIB_NOME LIKE '%Camara de Ar Exceto Bike%'
           OR P.GRP_TRIB_NOME LIKE '%Pneumatico de Bike%' OR P.GRP_TRIB_NOME LIKE '%Outros Pneu%'
           OR P.GRP_TRIB_NOME LIKE '%Lubrificante%' THEN 2.5 ELSE 5 END AS "ComissaoSugerida"
FROM PROD P
LEFT JOIN TAXAS X   ON X."ItemCode" = P."ItemCode"
LEFT JOIN CUSTO C   ON C."ItemCode" = P."ItemCode"
LEFT JOIN PIRELLI PI ON PI."ItemCode" = P."ItemCode"
ORDER BY P."ItemCode"
