WITH ESTQ AS (
    SELECT
        OITW."ItemCode",
        SUM(OITW."OnHand") AS "OnHand",
        SUM(OITW."IsCommited") AS "IsCommited",
        SUM(OITW."OnOrder") AS "OnOrder"
    FROM SBO_HLMOTOBIKE_PRD.OITW
    WHERE OITW."WhsCode" LIKE '%OPERAC%'
    GROUP BY OITW."ItemCode"
)

SELECT 
    OITM."ItemCode" AS "Codigo",
    OITM."ItemName" AS "Descricao",
    OITM."SWW" AS "Cod.Fabricante",
    OITM."CodeBars" "Cod.Barras",
    CASE
        WHEN OITM."frozenFor" = 'Y' THEN 'Inativo'
        ELSE 'Ativo' END AS "Status",
    CASE
        WHEN OITM."QryGroup1" ='Y' THEN 'Bloq. P/ Compra'
        ELSE 'Ativo P/ Compra' END AS "Status de Compra",
    OITM."U_HL_DS_ENDERECO" AS "Endereco",
    OMRC."FirmName" AS "Marca",
    ESTQ."OnHand" AS "Saldo Estoque",
    ESTQ."IsCommited" AS "Reserva",
    ESTQ."OnOrder" AS "Saldo em Compra"

FROM SBO_HLMOTOBIKE_PRD.OITM
LEFT JOIN ESTQ ON ESTQ."ItemCode" = OITM."ItemCode"
LEFT JOIN SBO_HLMOTOBIKE_PRD.OMRC ON OMRC."FirmCode" = OITM."FirmCode"

WHERE OITM."Series"='74'
ORDER BY OITM."ItemCode"
