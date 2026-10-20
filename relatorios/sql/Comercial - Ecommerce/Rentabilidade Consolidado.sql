-- =====================================================================================
-- Query fonte do dashboard "RentabilidadeEcommerce.html" (categoria REPORT:
-- "Comercial - Ecommerce" / "Rentabilidade Ecommerce"), reestruturada para consumir
-- a HL_RENTABILIDADE em vez da lógica legada (CTEs próprias, UDT @HL_ATCC, etc.).
--
-- IMPORTANTE: os nomes de coluna abaixo são exigidos EXATAMENTE como estão pelo
-- JavaScript do dashboard (função mapRow) — não renomear sem também atualizar o HTML.
--
-- DECISÕES APLICADAS NESTA RECONSTRUÇÃO (confirmadas com o negócio):
--   1) SEM regra especial de Amazon (comissão 12% fixa / frete por tabela de peso).
--      Não é mais aplicada — nem aqui, nem em lugar nenhum da base nova. Se um dia for
--      reativada, a mudança é feita na procedure de carga (SP_CARGA_HL_RENTABILIDADE),
--      não neste relatório — nenhuma manutenção necessária aqui quando isso acontecer.
--   2) ICMS Presumido é CRÉDITO (já validado e implementado assim na base). Por isso
--      SAIU da soma de "Total Impostos" (que agora é só PIS+COFINS+IPI+DIFAL+
--      Transferência) — ele deve aparecer como resultado/crédito, não como despesa.
--      O HTML foi ajustado nesse mesmo sentido (ver 12_Correcao_HTML... abaixo).
--   3) Vlr Anunciado usa a regra JÁ MELHORADA da base (ValorTotal = MAIOR entre
--      VLRVEND rateado e o calculado) — não voltamos para o VLRVEND puro do legado.
--   4) Estoque e Compras REMOVIDOS — não fazem parte do fato de venda; o dashboard
--      nunca os exibia de fato (campos mortos no JS), então a remoção não tem efeito
--      visual.
-- =====================================================================================

SELECT
    "DocEntry"                                      AS "DocEntry",
    "Vendedor"                                       AS "Loja",
    CAST("Serial" AS VARCHAR)                        AS "NF",
    "UF"                                              AS "UF",
    "DocDate"                                         AS "Data Emissao",
    CONCAT(SUBSTRING(LPAD(TO_VARCHAR("DocTime"),4,'0'),1,2), ':',
           SUBSTRING(LPAD(TO_VARCHAR("DocTime"),4,'0'),3,2)) AS "Hora Emissao",
    "ItemCode"                                        AS "Item Code",
    "ItemName"                                        AS "Produto",
    "FirmName"                                        AS "Marca",
    "Quantity"                                        AS "Quantidade",

    -- Vlr Anunciado: usa ValorTotal (já com a regra melhorada VLRVEND vs calculado)
    "ValorTotal"                                      AS "Vlr Anunciado",

    -- Comissão e Frete: sem regra especial de Amazon; já vêm prontos da base
    -- (E-commerce usa U_HL_UDF_NM_COMISSAO/FRETE rateados pelo custo; Atacado usa
    -- a regra própria — mas este relatório só deve ser filtrado para E-commerce)
    "Comissao"                                        AS "Comissao",
    "FreteProporcional"                               AS "Frete",

    "TotalCustoSTD"                                   AS "Total Custo Mercadorias",
    "CustoComCreditoTotal"                            AS "Total Custo Mercadoria Com Credito",
    "CreditoPirelli"                                  AS "Total Cred. Pirelli",
    "ValorNF"                                          AS "Vlr de NF",

    "IcmsVenda"                                        AS "Vlr. Icms destacado",
    "DifalCalculado"                                   AS "Difal",
    "PisVenda"                                          AS "Vlr. Pis",
    "CofinsVenda"                                      AS "Vlr Cofins",
    "IpiVenda"                                          AS "Vlr IPI",
    "CreditoPresumido"                                 AS "ICMS Presumido",
    "CustoTransferencia"                               AS "ICMS Transferencia",

    -- Total Impostos: PIS+COFINS+IPI+DIFAL+Transferência — SEM Presumido (crédito,
    -- não é despesa). Rótulo ajustado para refletir isso.
    ("PisVenda" + "CofinsVenda" + "IpiVenda" + "DifalCalculado" + "CustoTransferencia")
                                                        AS "Total Impostos (Pis + Cofins + IPI + Difal + Transferencia)",

    -- Total Desp. Operacional: Comissão + Frete (sem regra Amazon)
    ("Comissao" + "FreteProporcional")                 AS "Total Desp. Operacional",

    -- Receita, Receita Líquida e Markup: reaproveitados DIRETO da base (já corretos,
    -- já com Presumido somando e Difal/Transferência subtraindo)
    "ReceitaComCreditoPirelli"                         AS "Receita",
    "ReceitaLiquidaCST"                                AS "Receita Liquido Com Cst STD",
    "ReceitaLiquidaComCreditoPirelli"                  AS "Receita Liquido Com Credito",
    "MkpCstSTD"                                        AS "Mkp Receita Com Cst STD",
    "MkpComCreditoPirelli"                             AS "Mkp Receita Com Credito"

FROM "SBO_HLMOTOBIKE_PRD"."HL_RENTABILIDADE"
WHERE "TIPO_ORIGEM" = 'VENDA'
  AND "Canal" = 'E-commerce'
  AND "DocDate" BETWEEN :dataIni AND :dataFim
ORDER BY "DocDate", "Serial";