-- DRE Diretoria — lançamentos de UMA conta x UM parceiro de UMA origem
-- (:origem = 'PRD' ou 'MATRIZ' e :parceiro = CardCode, ou '' para "Sem fornecedor", vêm da linha
-- clicada em Parceiros.sql; demais filtros iguais aos dela).
-- "Historico" = JDT1.LineMemo (linha); "Memo" = OJDT.Memo (observação do lançamento contábil).
-- Limitado a 2001 linhas: o HTML mostra 2000 e avisa quando há mais.
SELECT "Data", "Lancamento", "TipoDoc", "Documento", "Filial", "NomeFilial", "Valor", "Historico", "Memo" FROM (
    SELECT
        T1."RefDate"                             AS "Dt",
        T1."Line_ID"                             AS "Linha",
        TO_VARCHAR(T1."RefDate", 'DD/MM/YYYY')   AS "Data",
        T1."TransId"                             AS "Lancamento",
        T0."TransType"                           AS "TipoDoc",
        T0."BaseRef"                             AS "Documento",
        T1."BPLId"                               AS "Filial",
        T4."BPLName"                             AS "NomeFilial",
        T1."Credit" - T1."Debit"                 AS "Valor",
        T1."LineMemo"                            AS "Historico",
        T0."Memo"                                AS "Memo"
    FROM SBO_HLMOTOBIKE_PRD.JDT1 T1
    INNER JOIN SBO_HLMOTOBIKE_PRD.OJDT T0 ON T0."TransId" = T1."TransId"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OBPL T4 ON T4."BPLId" = T1."BPLId"
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OCRD T2 ON T2."CardCode" = T1."ContraAct"
    WHERE :origem = 'PRD'
      AND T1."Account" = :conta
      AND IFNULL(T2."CardCode", '') = :parceiro
      AND T1."RefDate" BETWEEN :data_ini AND :data_fim
  -- encerramento do exercício (OJDT.TransType -3, "Para o período de encerramento N"): fora, salvo :incluir_encerramento = 'S'
  AND (:incluir_encerramento = 'S' OR T1."TransType" <> '-3')
      -- cancelados: o lançamento estornado e o estorno dele não entram (estorno automático entra)
      AND T1."TransId" NOT IN (
          SELECT E."TransId" FROM SBO_HLMOTOBIKE_PRD.OJDT E JOIN SBO_HLMOTOBIKE_PRD.OJDT O ON O."TransId" = E."StornoToTr" WHERE O."AutoStorno" = 'N'
          UNION ALL
          SELECT O."TransId" FROM SBO_HLMOTOBIKE_PRD.OJDT E JOIN SBO_HLMOTOBIKE_PRD.OJDT O ON O."TransId" = E."StornoToTr" WHERE O."AutoStorno" = 'N')
      AND LOCATE(:meses, ',' || TO_VARCHAR(T1."RefDate", 'YYYY-MM') || ',') > 0
      AND LOCATE(:filiais_ocultas, ',' || TO_VARCHAR(IFNULL(T1."BPLId", 0)) || ',') = 0
      AND (   (:incluir_base = 'S' AND LOCATE(:filiais_grupos, ',' || TO_VARCHAR(IFNULL(T1."BPLId", 0)) || ',') = 0)
           OR LOCATE(:filiais_incluidas, ',' || TO_VARCHAR(IFNULL(T1."BPLId", 0)) || ',') > 0)

    UNION ALL

    SELECT
        T1."RefDate", T1."Line_ID",
        TO_VARCHAR(T1."RefDate", 'DD/MM/YYYY'),
        T1."TransId", T0."TransType", T0."BaseRef",
        CAST(NULL AS INTEGER), 'MATRIZ',
        T1."Credit" - T1."Debit", T1."LineMemo", T0."Memo"
    FROM SBO_MATRIZ.JDT1 T1
    INNER JOIN SBO_MATRIZ.OJDT T0 ON T0."TransId" = T1."TransId"
    LEFT JOIN SBO_MATRIZ.OCRD T2 ON T2."CardCode" = T1."ContraAct"
    WHERE :origem = 'MATRIZ' AND :incluir_matriz = 'S'
      AND T1."Account" = :conta
      AND IFNULL(T2."CardCode", '') = :parceiro
      AND T1."RefDate" BETWEEN :data_ini AND :data_fim
  -- encerramento do exercício (OJDT.TransType -3, "Para o período de encerramento N"): fora, salvo :incluir_encerramento = 'S'
  AND (:incluir_encerramento = 'S' OR T1."TransType" <> '-3')
      -- cancelados: o lançamento estornado e o estorno dele não entram (estorno automático entra)
      AND T1."TransId" NOT IN (
          SELECT E."TransId" FROM SBO_MATRIZ.OJDT E JOIN SBO_MATRIZ.OJDT O ON O."TransId" = E."StornoToTr" WHERE O."AutoStorno" = 'N'
          UNION ALL
          SELECT O."TransId" FROM SBO_MATRIZ.OJDT E JOIN SBO_MATRIZ.OJDT O ON O."TransId" = E."StornoToTr" WHERE O."AutoStorno" = 'N')
      AND LOCATE(:meses, ',' || TO_VARCHAR(T1."RefDate", 'YYYY-MM') || ',') > 0
) X
ORDER BY "Dt", "Lancamento", "Linha"
LIMIT 2001
