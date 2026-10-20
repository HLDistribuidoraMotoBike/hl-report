SELECT  "DocEntry", "CardCode", "CardName", "DocDueDate"
from SBO_HLMOTOBIKE_PRD.ORDR Where "DocStatus"='O' AND "BPLId"='3'  AND "UserSign"='113'
order by "DocDueDate"