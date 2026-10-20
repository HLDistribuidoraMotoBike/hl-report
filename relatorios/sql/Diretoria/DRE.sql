-- =====================================================================================
-- DRE Diretoria — saldos por conta x mês x origem/filial (template report_template/DRE.html)
--
-- Segue o modelo de relatório financeiro do SAP da SBO_HLMOTOBIKE_PRD (OFRC/FRC1). O número do
-- modelo vem de report_config/Diretoria/DRE.json ("modelo"). Valor = Crédito - Débito (JDT1, RefDate).
-- Contas fora do modelo NÃO entram (decisão da diretoria).
--
-- Duas origens:
--   'PRD'    = SBO_HLMOTOBIKE_PRD, sem as filiais de "filiais_ocultas" do JSON (:filiais_ocultas, ex.: ',5,')
--   'MATRIZ' = SBO_MATRIZ inteira (grupo "Especial"). As contas são casadas pelo CÓDIGO com o modelo
--              da PRD; conta do modelo que não existe na MATRIZ simplesmente fica zerada.
-- O agrupamento (HL Distribuição / Especial / Empresas de serviço) é feito no HTML pela origem e
-- pelo BPLId, configurado em "grupos" no mesmo JSON.
--
-- Consultas auxiliares em sql/Diretoria/_dre/ (não aparecem no menu, só o HTML as chama):
--   Modelo.sql, Contas.sql, Parceiros.sql, Lancamentos.sql
-- Os nomes de coluna abaixo são lidos pelo JavaScript do HTML — não renomear sem ajustá-lo.
-- =====================================================================================
SELECT
    'PRD'                                AS "Origem",
    T1."Account"                         AS "Conta",
    TO_VARCHAR(T1."RefDate", 'YYYY-MM')  AS "Mes",
    T1."BPLId"                           AS "Filial",
    SUM(T1."Credit" - T1."Debit")        AS "Valor"
FROM SBO_HLMOTOBIKE_PRD.JDT1 T1
WHERE T1."RefDate" BETWEEN :data_ini AND :data_fim
-- cancelados: o lançamento estornado e o estorno dele não entram (estorno automático entra)
AND T1."TransId" NOT IN (
    SELECT E."TransId" FROM SBO_HLMOTOBIKE_PRD.OJDT E JOIN SBO_HLMOTOBIKE_PRD.OJDT O ON O."TransId" = E."StornoToTr" WHERE O."AutoStorno" = 'N'
    UNION ALL
    SELECT O."TransId" FROM SBO_HLMOTOBIKE_PRD.OJDT E JOIN SBO_HLMOTOBIKE_PRD.OJDT O ON O."TransId" = E."StornoToTr" WHERE O."AutoStorno" = 'N')
  AND T1."Account" IN (SELECT F."AcctCode" FROM SBO_HLMOTOBIKE_PRD.FRC1 F WHERE F."TemplateId" = :modelo)
  AND LOCATE(:filiais_ocultas, ',' || TO_VARCHAR(IFNULL(T1."BPLId", 0)) || ',') = 0
GROUP BY T1."Account", TO_VARCHAR(T1."RefDate", 'YYYY-MM'), T1."BPLId"

UNION ALL

SELECT
    'MATRIZ'                             AS "Origem",
    T1."Account"                         AS "Conta",
    TO_VARCHAR(T1."RefDate", 'YYYY-MM')  AS "Mes",
    CAST(NULL AS INTEGER)                AS "Filial",
    SUM(T1."Credit" - T1."Debit")        AS "Valor"
FROM SBO_MATRIZ.JDT1 T1
WHERE T1."RefDate" BETWEEN :data_ini AND :data_fim
-- cancelados: o lançamento estornado e o estorno dele não entram (estorno automático entra)
AND T1."TransId" NOT IN (
    SELECT E."TransId" FROM SBO_MATRIZ.OJDT E JOIN SBO_MATRIZ.OJDT O ON O."TransId" = E."StornoToTr" WHERE O."AutoStorno" = 'N'
    UNION ALL
    SELECT O."TransId" FROM SBO_MATRIZ.OJDT E JOIN SBO_MATRIZ.OJDT O ON O."TransId" = E."StornoToTr" WHERE O."AutoStorno" = 'N')
  AND T1."Account" IN (SELECT F."AcctCode" FROM SBO_HLMOTOBIKE_PRD.FRC1 F WHERE F."TemplateId" = :modelo)
GROUP BY T1."Account", TO_VARCHAR(T1."RefDate", 'YYYY-MM')
