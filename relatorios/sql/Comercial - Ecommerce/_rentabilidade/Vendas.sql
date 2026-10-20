-- =====================================================================================
-- Rentabilidade — fonte do painel Comercial - Ecommerce/Rentabilidade (tela React do HL Report).
--
-- Base: HL_RENTABILIDADE (a mesma do e-mail diário "Rentabilidade Consolidada"), com o MESMO critério dele:
-- TIPO_ORIGEM VENDA e VENDA_100_ESPECIAL, por data de emissão.
--   :canal = ''           → Consolidado (todas as empresas e canais)
--   :canal = 'E-commerce' → visão E-commerce
-- Desde a 0.4.0 (20/10/2026) a visão E-commerce também usa esta base (decisão do usuário); a consulta legada direto
-- nas tabelas do SAP (_rentabilidade/Ecommerce.sql, ~30 s por dia) saiu — está no histórico do git.
--
-- Regras da base (confirmadas com o negócio):
--   1) sem regra especial de Amazon (se voltar, é na procedure de carga SP_CARGA_HL_RENTABILIDADE);
--   2) ICMS Presumido é CRÉDITO: fica fora de "Total Impostos" (PIS+COFINS+IPI+DIFAL+Transferência) e já soma na
--      receita da base;
--   3) Vlr Anunciado = ValorTotal (maior entre VLRVEND rateado e o calculado).
--
-- Filtros: :data_ini, :data_fim (YYYY-MM-DD), :marca (texto parcial; vazio = todas), :canal (vazio = todos)
-- Colunas: as que o painel lê (frontend/src/modulos/paineis/rentabilidade/dados.js) — não renomear sem ajustar lá.
-- =====================================================================================
SELECT
    "Filial"                                          AS "Filial",
    "Canal"                                           AS "Canal",
    CASE WHEN "Canal" = 'Atacado' THEN "Setor" ELSE NULL END
                                                      AS "Setor",
    "DocEntry"                                        AS "DocEntry",
    "Vendedor"                                        AS "Loja",
    CAST("Serial" AS VARCHAR)                         AS "NF",
    "UF"                                              AS "UF",
    "DocDate"                                         AS "Data Emissao",
    SUBSTRING(LPAD(TO_VARCHAR("DocTime"),4,'0'),1,2) || ':'
        || SUBSTRING(LPAD(TO_VARCHAR("DocTime"),4,'0'),3,2) AS "Hora Emissao",
    "ItemCode"                                        AS "Item Code",
    "ItemName"                                        AS "Produto",
    "FirmName"                                        AS "Marca",
    "Quantity"                                        AS "Quantidade",
    "ValorTotal"                                      AS "Vlr Anunciado",
    "Comissao"                                        AS "Comissao",
    "FreteProporcional"                               AS "Frete",
    "TotalCustoSTD"                                   AS "Total Custo Mercadorias",
    "CustoComCreditoTotal"                            AS "Total Custo Mercadoria Com Credito",
    "CreditoPirelli"                                  AS "Total Cred. Pirelli",
    "ValorNF"                                         AS "Vlr de NF",
    "IcmsVenda"                                       AS "Vlr. Icms destacado",
    "DifalCalculado"                                  AS "Difal",
    "PisVenda"                                        AS "Vlr. Pis",
    "CofinsVenda"                                     AS "Vlr Cofins",
    "IpiVenda"                                        AS "Vlr IPI",
    "CreditoPresumido"                                AS "ICMS Presumido",
    "CustoTransferencia"                              AS "ICMS Transferencia",
    (IFNULL("PisVenda",0) + IFNULL("CofinsVenda",0) + IFNULL("IpiVenda",0) + IFNULL("DifalCalculado",0)
        + IFNULL("CustoTransferencia",0))             AS "Total Impostos",
    (IFNULL("Comissao",0) + IFNULL("FreteProporcional",0)) AS "Total Desp. Operacional",
    "ReceitaComCreditoPirelli"                        AS "Receita",
    "ReceitaLiquidaCST"                               AS "Receita Liquido Com Cst STD",
    "ReceitaLiquidaComCreditoPirelli"                 AS "Receita Liquido Com Credito",
    "MkpCstSTD"                                       AS "Mkp Receita Com Cst STD",
    "MkpComCreditoPirelli"                            AS "Mkp Receita Com Credito"
FROM "SBO_HLMOTOBIKE_PRD"."HL_RENTABILIDADE"
WHERE "TIPO_ORIGEM" IN ('VENDA','VENDA_100_ESPECIAL')
  AND "DocDate" BETWEEN :data_ini AND :data_fim
  AND (:marca = '' OR "FirmName" LIKE '%' || :marca || '%')
  AND (:canal = '' OR "Canal" = :canal)
