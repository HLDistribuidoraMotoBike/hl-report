-- DRE Diretoria — linhas do modelo financeiro (OFRC). Linha de fórmula = Param_1 preenchido.
SELECT
    "CatId"     AS "CatId",
    "Name"      AS "Nome",
    "Levels"    AS "Nivel",
    "FatherNum" AS "Pai",
    "VisOrder"  AS "Ordem",
    "CatClass"  AS "Classe",
    "Param_1" AS "Param_1", "Param_2" AS "Param_2", "Param_3" AS "Param_3",
    "Param_4" AS "Param_4", "Param_5" AS "Param_5",
    "OP_1" AS "Op_1", "OP_2" AS "Op_2", "OP_3" AS "Op_3", "OP_4" AS "Op_4"
FROM SBO_HLMOTOBIKE_PRD.OFRC
WHERE "TemplateId" = :modelo
ORDER BY "VisOrder"
