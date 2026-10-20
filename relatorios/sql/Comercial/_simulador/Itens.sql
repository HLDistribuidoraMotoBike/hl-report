-- Simulador de Preço — busca de item (mesma série da tabela de venda: OITM.Series = 74)
-- Filtro: :busca
SELECT TOP 30
    I."ItemCode", I."ItemName", M."FirmName" AS "Marca"
FROM "SBO_HLMOTOBIKE_PRD".OITM I
LEFT JOIN "SBO_HLMOTOBIKE_PRD".OMRC M ON M."FirmCode" = I."FirmCode"
WHERE I."Series" = 74
  AND I."frozenFor" <> 'Y'
  AND ( UPPER(I."ItemCode") LIKE '%' || UPPER(:busca) || '%'
     OR UPPER(I."ItemName") LIKE '%' || UPPER(:busca) || '%' )
ORDER BY CASE WHEN UPPER(I."ItemCode") = UPPER(:busca) THEN 0 ELSE 1 END, I."ItemCode"
