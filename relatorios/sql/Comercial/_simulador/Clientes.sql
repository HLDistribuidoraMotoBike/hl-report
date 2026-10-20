-- Simulador de Preço — busca de cliente (código, nome, fantasia ou CNPJ)
-- UF = endereço de entrega padrão (mesma regra da consulta principal).
-- Filtro: :busca
SELECT TOP 30
    C."CardCode", C."CardName", C."CardFName",
    COALESCE(NULLIF(A."State", ''), C."State1") AS "UF",
    A."City" AS "Cidade",
    F."TaxId0" AS "CNPJ"
FROM "SBO_HLMOTOBIKE_PRD".OCRD C
LEFT JOIN "SBO_HLMOTOBIKE_PRD".CRD1 A ON A."CardCode" = C."CardCode" AND A."AdresType" = 'S' AND A."Address" = C."ShipToDef"
LEFT JOIN "SBO_HLMOTOBIKE_PRD".CRD7 F ON F."CardCode" = C."CardCode" AND F."Address" = '' AND F."AddrType" = 'S'
WHERE C."CardType" = 'C'
  AND C."frozenFor" <> 'Y'
  AND ( UPPER(C."CardCode") LIKE '%' || UPPER(:busca) || '%'
     OR UPPER(C."CardName") LIKE '%' || UPPER(:busca) || '%'
     OR UPPER(IFNULL(C."CardFName", '')) LIKE '%' || UPPER(:busca) || '%'
     OR REPLACE_REGEXPR('[^0-9]' IN IFNULL(F."TaxId0", '') WITH '') LIKE '%' || NULLIF(REPLACE_REGEXPR('[^0-9]' IN :busca WITH ''), '') || '%' )
ORDER BY C."CardName"
