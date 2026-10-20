-- Rentabilidade Completa (Anexo Excel do email "Rentabilidade Consolidada")
-- Fonte: HL_RENTABILIDADE — detalhe por item de NF (sem agrupamento)
--
-- Filtros: :data_ini (YYYY-MM-DD), :data_fim (YYYY-MM-DD)

SELECT
    "Filial"                            AS "Filial",
    "Canal"                             AS "Canal",
    "DocEntry"                          AS "Id. Documento",
    "Vendedor"                          AS "Vendedor",
    "Setor"                             AS "Setor Vend.",
    "Cliente"                           As "Cod. Cliente",
    "NumAtCard"                         AS "Referencia Pedido",
    "Serial"                            AS "NF",
    "UF"                                AS "UF",
    "DocDate"                           AS "Data",
    "ItemCode"                          AS "Cod. Produto",
    "ItemName"                          AS "Descricao",
    "FirmName"                          AS "Marca",
    "Quantity"                          AS "Qtd",
    "PrecoUnitario"                     AS "Vlr. Unitario",

    "DescontoEspecial"                  AS "(I) Desc. Especial",
    "DiscPrcnt"                         AS "(I) Desconto",
    "FreteCobrado"                      AS "(I) Frete Cobrado",
    "ValorNF"                           AS "(I) Vlr. de NF",
    "CustoStdComST"                     AS "(I) Cst Std C/Imp Unit.",
    "TotalCustoSTD"                     AS "(I) Cst Std C/Imp Total",
    "CustoComCredito"                   AS "(I) Cst C/Credito Unit.",
    "CustoComCreditoTotal"              AS "(I) Cst C/Credito Total",
    "CustoStdSemST"                     AS "(I) Cst Std S/Imp Unit.",

    "ValorTotal"                        AS "(R) Vlr. de Total",
    "CreditoPirelli"                    AS "(R) Credito Pirelli",
    "CreditoPresumido"                  AS "(R) Credito Presumido",

    "Comissao"                          AS "(D) Comissao",
    "FreteProporcional"                 AS "(D) Frete Proporcional",
    "IcmsVenda"                         AS "(D) Icms Venda",
    "StVenda"                           AS "(D) St Venda",
    "PisVenda"                          AS "(D) Pis Venda",
    "CofinsVenda"                       AS "(D) Cofins Venda",
    "IpiVenda"                          AS "(D) IPI Venda",
    "DifalCalculado"                    AS "(D) Difal Calculado",
    "CustoTransferencia"                AS "(D) Custo Transferencia",

    "ReceitaComCreditoPirelli"          AS "(RE) Receita Bruta",
    "MkpComCreditoPirelli"              AS "(RE) Mkp S/ Receita Bruta",
    "ReceitaLiquidaComCreditoPirelli"   AS "(RE) Receita Liquida.",
    ("ReceitaLiquidaComCreditoPirelli" / NULLIF("ValorTotal", 0)) * 100 AS "(RE) Margem S/ Receita Liquida"

FROM "SBO_HLMOTOBIKE_PRD"."HL_RENTABILIDADE"
WHERE "TIPO_ORIGEM" IN ('VENDA','VENDA_100_ESPECIAL')
  AND "DocDate" BETWEEN :data_ini AND :data_fim
ORDER BY "Data", "NF";
