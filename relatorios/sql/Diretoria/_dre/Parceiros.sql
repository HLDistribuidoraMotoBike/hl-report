-- DRE Diretoria — detalhamento de UMA conta por fornecedor/cliente.
-- Só vira item próprio o parceiro cadastrado (ContraAct encontrado na OCRD da própria base); o resto
-- (lançamento manual, contrapartida em outra conta etc.) fica num único item "Sem fornecedor" (Parceiro = '').
-- Decisão da diretoria: não mostrar a conta de contrapartida.
--   :meses             = lista de meses entre vírgulas, ex.: ',2026-01,2026-03,'
--   Empresas marcadas no HTML (grupos do DRE.json):
--   :incluir_base      = 'S' quando "HL Distribuição" (filiais da PRD fora de qualquer grupo) está marcada
--   :filiais_grupos    = BPLIds da PRD que pertencem a algum grupo, ex.: ',6,7,'
--   :filiais_incluidas = BPLIds da PRD dos grupos marcados, ex.: ',6,7,' (ou ',')
--   :filiais_ocultas   = BPLIds da PRD que nunca entram, ex.: ',5,'
--   :incluir_matriz    = 'S' quando "Especial" (base SBO_MATRIZ) está marcada
SELECT "Origem", "Parceiro", "NomeParceiro", "N", "Valor" FROM (
    SELECT
        'PRD'                          AS "Origem",
        IFNULL(T2."CardCode", '')      AS "Parceiro",
        MAX(T2."CardName")             AS "NomeParceiro",
        COUNT(*)                       AS "N",
        SUM(T1."Credit" - T1."Debit")  AS "Valor"
    FROM SBO_HLMOTOBIKE_PRD.JDT1 T1
    LEFT JOIN SBO_HLMOTOBIKE_PRD.OCRD T2 ON T2."CardCode" = T1."ContraAct"
    WHERE T1."Account" = :conta
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
    GROUP BY IFNULL(T2."CardCode", '')

    UNION ALL

    SELECT
        'MATRIZ'                       AS "Origem",
        IFNULL(T2."CardCode", '')      AS "Parceiro",
        MAX(T2."CardName")             AS "NomeParceiro",
        COUNT(*)                       AS "N",
        SUM(T1."Credit" - T1."Debit")  AS "Valor"
    FROM SBO_MATRIZ.JDT1 T1
    LEFT JOIN SBO_MATRIZ.OCRD T2 ON T2."CardCode" = T1."ContraAct"
    WHERE :incluir_matriz = 'S'
      AND T1."Account" = :conta
      AND T1."RefDate" BETWEEN :data_ini AND :data_fim
  -- encerramento do exercício (OJDT.TransType -3, "Para o período de encerramento N"): fora, salvo :incluir_encerramento = 'S'
  AND (:incluir_encerramento = 'S' OR T1."TransType" <> '-3')
      -- cancelados: o lançamento estornado e o estorno dele não entram (estorno automático entra)
      AND T1."TransId" NOT IN (
          SELECT E."TransId" FROM SBO_MATRIZ.OJDT E JOIN SBO_MATRIZ.OJDT O ON O."TransId" = E."StornoToTr" WHERE O."AutoStorno" = 'N'
          UNION ALL
          SELECT O."TransId" FROM SBO_MATRIZ.OJDT E JOIN SBO_MATRIZ.OJDT O ON O."TransId" = E."StornoToTr" WHERE O."AutoStorno" = 'N')
      AND LOCATE(:meses, ',' || TO_VARCHAR(T1."RefDate", 'YYYY-MM') || ',') > 0
    GROUP BY IFNULL(T2."CardCode", '')
) X
ORDER BY ABS("Valor") DESC
