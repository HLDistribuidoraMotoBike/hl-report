"""Rotas de administração dos relatórios (/api/admin/...) — só administrador. Toda gravação vai para o log de ações."""
from typing import Any, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from hlcore.auditoria import registrar
from hlcore.auth import verificar_admin
from hlcore.database import get_db

from app.modulos.relatorios import arquivos, service

router_admin = APIRouter(prefix="/admin", tags=["Relatórios — administração"])


class PastaIn(BaseModel):
    nome: str


class SqlIn(BaseModel):
    id: str
    sql: str
    config: Optional[dict[str, Any]] = None
    novo: bool = False


class TesteIn(BaseModel):
    sql: str
    filtros: dict[str, str] = {}
    schema_: str = Field("", alias="schema")   # "schema" é nome reservado no pydantic


class TemplateIn(BaseModel):
    nome: str
    html: str = ""
    novo: bool = False


@router_admin.get("/arvore")
def arvore(_=Depends(verificar_admin)):
    return arquivos.arvore()


@router_admin.post("/pastas")
def criar_pasta(data: PastaIn, db: Session = Depends(get_db), user=Depends(verificar_admin)):
    nome = arquivos.criar_pasta(data.nome)
    registrar(db, user["display_name"], "relatorio_pasta_criada", nome)
    return {"nome": nome}


@router_admin.delete("/pastas/{nome}")
def excluir_pasta(nome: str, db: Session = Depends(get_db), user=Depends(verificar_admin)):
    arquivos.excluir_pasta(nome)
    registrar(db, user["display_name"], "relatorio_pasta_excluida", nome)
    return {"ok": True}


@router_admin.get("/sql/{rel_id:path}")
def ler_sql(rel_id: str, _=Depends(verificar_admin)):
    dados = arquivos.ler(rel_id)
    dados["parametros"] = service.parametros(dados["sql"])
    return dados


@router_admin.put("/sql")
def salvar_sql(data: SqlIn, db: Session = Depends(get_db), user=Depends(verificar_admin)):
    rel_id = arquivos.salvar(data.id, data.sql, data.config, data.novo)
    registrar(db, user["display_name"], "relatorio_criado" if data.novo else "relatorio_salvo", rel_id)
    return {"id": rel_id}


@router_admin.delete("/sql/{rel_id:path}")
def excluir_sql(rel_id: str, db: Session = Depends(get_db), user=Depends(verificar_admin)):
    rel_id = arquivos.excluir(rel_id)
    registrar(db, user["display_name"], "relatorio_excluido", rel_id)
    return {"ok": True}


@router_admin.post("/testar-sql")
def testar_sql(data: TesteIn, _=Depends(verificar_admin)):
    return service.testar(data.sql, data.filtros, data.schema_)


@router_admin.get("/templates/{tipo}")
def listar_templates(tipo: str, _=Depends(verificar_admin)):
    return arquivos.listar_templates(tipo)


@router_admin.get("/templates/{tipo}/{nome}")
def ler_template(tipo: str, nome: str, _=Depends(verificar_admin)):
    return arquivos.ler_template(tipo, nome)


@router_admin.put("/templates/{tipo}")
def salvar_template(tipo: str, data: TemplateIn, db: Session = Depends(get_db), user=Depends(verificar_admin)):
    nome = arquivos.salvar_template(tipo, data.nome, data.html, data.novo)
    registrar(db, user["display_name"], "template_criado" if data.novo else "template_salvo", f"{tipo}/{nome}")
    return {"nome": nome}


@router_admin.delete("/templates/{tipo}/{nome}")
def excluir_template(tipo: str, nome: str, db: Session = Depends(get_db), user=Depends(verificar_admin)):
    nome = arquivos.excluir_template(tipo, nome)
    registrar(db, user["display_name"], "template_excluido", f"{tipo}/{nome}")
    return {"ok": True}
