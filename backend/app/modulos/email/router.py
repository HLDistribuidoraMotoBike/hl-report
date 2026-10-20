"""Rotas dos e-mails agendados (/api/email) — só administrador."""
from typing import Optional

from fastapi import APIRouter, Depends, Query
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel
from sqlalchemy.orm import Session

from hlcore.auditoria import registrar
from hlcore.auth import verificar_admin
from hlcore.database import get_db

from app.modulos.email import service

router = APIRouter(prefix="/email", tags=["E-mails agendados"])


class AgendamentoIn(BaseModel):
    ativo: bool
    horario: str
    dias_semana: list[str] = []
    destinatarios: list[str] = []
    assunto: str = ""


class EnvioIn(BaseModel):
    teste: bool = False
    destinatarios: list[str] = []   # só no teste


@router.get("/agendamentos")
def listar(db: Session = Depends(get_db), _=Depends(verificar_admin)):
    return service.listar(db)


@router.put("/agendamentos/{chave}")
def atualizar(chave: str, data: AgendamentoIn, db: Session = Depends(get_db), user=Depends(verificar_admin)):
    r = service.atualizar(db, chave, data.model_dump(), user["display_name"])
    registrar(db, user["display_name"], "email_agendamento_salvo",
              f"{chave}: {'ligado' if data.ativo else 'desligado'} {data.horario} {','.join(data.dias_semana)} "
              f"({len(data.destinatarios)} destinatário(s))")
    return r


@router.post("/agendamentos/{chave}/previa")
async def previa(chave: str, _=Depends(verificar_admin)):
    return await run_in_threadpool(service.previa, chave)


@router.post("/agendamentos/{chave}/enviar")
async def enviar(chave: str, data: EnvioIn, db: Session = Depends(get_db), user=Depends(verificar_admin)):
    tipo = "teste" if data.teste else "manual"
    r = await run_in_threadpool(service.enviar, chave, tipo, user["display_name"], data.destinatarios)
    registrar(db, user["display_name"], f"email_{tipo}", f"{chave} → {', '.join(r['destinatarios'])}: {r['status']}")
    return r


@router.get("/envios")
def historico(chave: Optional[str] = None, limite: int = Query(100, ge=1, le=500),
              db: Session = Depends(get_db), _=Depends(verificar_admin)):
    return service.historico(db, chave, limite)
