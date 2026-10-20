-- DRE Diretoria — contas penduradas em cada linha do modelo (FRC1 + nome em OACT).
SELECT
    T0."CatId"     AS "CatId",
    T0."AcctCode"  AS "Conta",
    T1."AcctName"  AS "Nome",
    T0."VisOrder"  AS "Ordem"
FROM SBO_HLMOTOBIKE_PRD.FRC1 T0
INNER JOIN SBO_HLMOTOBIKE_PRD.OACT T1 ON T1."AcctCode" = T0."AcctCode"
WHERE T0."TemplateId" = :modelo
