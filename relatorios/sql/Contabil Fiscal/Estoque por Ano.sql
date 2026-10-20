-----#########################


WITH PARAMETROS AS (
    SELECT
        CAST(YEAR( :ano ) AS INTEGER) AS "Ano_Base",
        CASE
            WHEN CAST(YEAR( :ano ) AS INTEGER) = YEAR(CURRENT_DATE) THEN MONTH(CURRENT_DATE)
            ELSE 12
        END AS "Mes_Limite"
    FROM DUMMY
),
MESES AS (
    SELECT 1 AS "Mes" FROM DUMMY
    UNION ALL SELECT 2 FROM DUMMY
    UNION ALL SELECT 3 FROM DUMMY
    UNION ALL SELECT 4 FROM DUMMY
    UNION ALL SELECT 5 FROM DUMMY
    UNION ALL SELECT 6 FROM DUMMY
    UNION ALL SELECT 7 FROM DUMMY
    UNION ALL SELECT 8 FROM DUMMY
    UNION ALL SELECT 9 FROM DUMMY
    UNION ALL SELECT 10 FROM DUMMY
    UNION ALL SELECT 11 FROM DUMMY
    UNION ALL SELECT 12 FROM DUMMY
),
ITENS AS (
    SELECT DISTINCT
        IFNULL(T1."BPLid",99) AS "Filial",
        T0."ItemCode" AS "Código",
        T2."ItemName" AS "Descrição",
        T2."InvntryUom" AS "Unidade de Medida",
        T3."NcmCode" AS "NCM",
        '' AS "Cest"
    FROM SBO_HLMOTOBIKE_PRD.OINM T0
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OWHS T1 ON T1."WhsCode" = T0."Warehouse"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OITM T2 ON T2."ItemCode" = T0."ItemCode"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.ONCM T3 ON T3."AbsEntry" = T2."NCMCode"
    WHERE 
        IFNULL(T1."BPLid",99) NOT IN (4) AND 
        T0."ItemCode" LIKE 'RV%'
),
BASE AS (
    SELECT
        I."Filial",
        I."Código",
        I."Descrição",
        I."Unidade de Medida",
        I."NCM",
        I."Cest",
        M."Mes",

        CASE
            WHEN M."Mes" <= P."Mes_Limite" THEN
                COALESCE(
                    SUM(
                        CASE
                            WHEN TO_DATE(T0."DocDate") <=
                                 LAST_DAY(
                                     TO_DATE(
                                         P."Ano_Base" || '-' ||
                                         LPAD(M."Mes", 2, '0') || '-01'
                                     )
                                 )
                            THEN T0."InQty" - T0."OutQty"
                            ELSE 0
                        END
                    ),
                    0
                )
            ELSE 0
        END AS "Saldo_Mes",

        CASE
            WHEN M."Mes" <= P."Mes_Limite" THEN
                COALESCE(
                    SUM(
                        CASE
                            WHEN TO_DATE(T0."DocDate") <=
                                 LAST_DAY(
                                     TO_DATE(
                                         P."Ano_Base" || '-' ||
                                         LPAD(M."Mes", 2, '0') || '-01'
                                     )
                                 )
                            THEN T0."TransValue"
                            ELSE 0
                        END
                    ),
                    0
                )
            ELSE 0
        END AS "Valor_Mes"

    FROM ITENS I

    CROSS JOIN MESES M
    CROSS JOIN PARAMETROS P

    LEFT JOIN (
        SBO_HLMOTOBIKE_PRD.OINM T0
        INNER JOIN SBO_HLMOTOBIKE_PRD.OWHS W
            ON W."WhsCode" = T0."Warehouse"
    )
        ON T0."ItemCode" = I."Código"
       AND IFNULL(W."BPLid", 99) = I."Filial"

    GROUP BY
        I."Filial",
        I."Código",
        I."Descrição",
        I."Unidade de Medida",
        I."NCM",
        I."Cest",
        M."Mes",
        P."Ano_Base",
        P."Mes_Limite"
)
SELECT
    CASE
        WHEN "Filial"=1 THEN 'Matriz'
        WHEN "Filial"=2 THEN 'Filial'
        WHEN "Filial"=3 THEN 'E-commerce'
        WHEN "Filial"=4 THEN '2W'
        WHEN "Filial"=99 THEN 'DHFS'
        ELSE 'Validar' END AS "Filial",
    "Código",
    "Descrição",
    "Unidade de Medida",
    "NCM",
    "Cest",
    SUM(CASE WHEN "Mes" = 1 THEN "Saldo_Mes" ELSE 0 END) AS "Jan_Saldo",
    SUM(CASE WHEN "Mes" = 1 THEN "Valor_Mes" ELSE 0 END) AS "Jan_Valor",

    SUM(CASE WHEN "Mes" = 2 THEN "Saldo_Mes" ELSE 0 END) AS "Fev_Saldo",
    SUM(CASE WHEN "Mes" = 2 THEN "Valor_Mes" ELSE 0 END) AS "Fev_Valor",

    SUM(CASE WHEN "Mes" = 3 THEN "Saldo_Mes" ELSE 0 END) AS "Mar_Saldo",
    SUM(CASE WHEN "Mes" = 3 THEN "Valor_Mes" ELSE 0 END) AS "Mar_Valor",

    SUM(CASE WHEN "Mes" = 4 THEN "Saldo_Mes" ELSE 0 END) AS "Abr_Saldo",
    SUM(CASE WHEN "Mes" = 4 THEN "Valor_Mes" ELSE 0 END) AS "Abr_Valor",

    SUM(CASE WHEN "Mes" = 5 THEN "Saldo_Mes" ELSE 0 END) AS "Mai_Saldo",
    SUM(CASE WHEN "Mes" = 5 THEN "Valor_Mes" ELSE 0 END) AS "Mai_Valor",

    SUM(CASE WHEN "Mes" = 6 THEN "Saldo_Mes" ELSE 0 END) AS "Jun_Saldo",
    SUM(CASE WHEN "Mes" = 6 THEN "Valor_Mes" ELSE 0 END) AS "Jun_Valor",

    SUM(CASE WHEN "Mes" = 7 THEN "Saldo_Mes" ELSE 0 END) AS "Jul_Saldo",
    SUM(CASE WHEN "Mes" = 7 THEN "Valor_Mes" ELSE 0 END) AS "Jul_Valor",

    SUM(CASE WHEN "Mes" = 8 THEN "Saldo_Mes" ELSE 0 END) AS "Ago_Saldo",
    SUM(CASE WHEN "Mes" = 8 THEN "Valor_Mes" ELSE 0 END) AS "Ago_Valor",

    SUM(CASE WHEN "Mes" = 9 THEN "Saldo_Mes" ELSE 0 END) AS "Set_Saldo",
    SUM(CASE WHEN "Mes" = 9 THEN "Valor_Mes" ELSE 0 END) AS "Set_Valor",

    SUM(CASE WHEN "Mes" = 10 THEN "Saldo_Mes" ELSE 0 END) AS "Out_Saldo",
    SUM(CASE WHEN "Mes" = 10 THEN "Valor_Mes" ELSE 0 END) AS "Out_Valor",

    SUM(CASE WHEN "Mes" = 11 THEN "Saldo_Mes" ELSE 0 END) AS "Nov_Saldo",
    SUM(CASE WHEN "Mes" = 11 THEN "Valor_Mes" ELSE 0 END) AS "Nov_Valor",

    SUM(CASE WHEN "Mes" = 12 THEN "Saldo_Mes" ELSE 0 END) AS "Dez_Saldo",
    SUM(CASE WHEN "Mes" = 12 THEN "Valor_Mes" ELSE 0 END) AS "Dez_Valor"
FROM BASE
GROUP BY
    "Filial",
    "Código",
    "Descrição",
    "Unidade de Medida",
    "NCM",
    "Cest"
HAVING
    SUM(CASE WHEN "Mes" = 1 THEN "Saldo_Mes" ELSE 0 END) <> 0
    OR SUM(CASE WHEN "Mes" = 2 THEN "Saldo_Mes" ELSE 0 END) <> 0
    OR SUM(CASE WHEN "Mes" = 3 THEN "Saldo_Mes" ELSE 0 END) <> 0
    OR SUM(CASE WHEN "Mes" = 4 THEN "Saldo_Mes" ELSE 0 END) <> 0
    OR SUM(CASE WHEN "Mes" = 5 THEN "Saldo_Mes" ELSE 0 END) <> 0
    OR SUM(CASE WHEN "Mes" = 6 THEN "Saldo_Mes" ELSE 0 END) <> 0
    OR SUM(CASE WHEN "Mes" = 7 THEN "Saldo_Mes" ELSE 0 END) <> 0
    OR SUM(CASE WHEN "Mes" = 8 THEN "Saldo_Mes" ELSE 0 END) <> 0
    OR SUM(CASE WHEN "Mes" = 9 THEN "Saldo_Mes" ELSE 0 END) <> 0
    OR SUM(CASE WHEN "Mes" = 10 THEN "Saldo_Mes" ELSE 0 END) <> 0
    OR SUM(CASE WHEN "Mes" = 11 THEN "Saldo_Mes" ELSE 0 END) <> 0
    OR SUM(CASE WHEN "Mes" = 12 THEN "Saldo_Mes" ELSE 0 END) <> 0
ORDER BY
"Código",
    "Filial"  ;