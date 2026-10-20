"""Rotas dos relatórios — só HTTP: login, permissão (pasta = recurso) e chamada ao service.

/api/executar e /api/config mantêm o endereço e o formato do Report antigo ({ok, erro}): as páginas de indicador
(relatorios/templates/) chamam esses endereços direto.
"""
import logging
import time
from urllib.parse import quote

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel

from hlcore.auth import verificar_admin, verificar_token
from hlcore.erros import ErroNegocio

from app.modulos.relatorios import catalogo, paginas, service

logger = logging.getLogger("relatorios")

router = APIRouter(tags=["Relatórios"])


class PaginaIn(BaseModel):
    rel_id: str


@router.get("/relatorios")
def listar(user=Depends(verificar_token)):
    """Menu: pastas que o usuário pode ver, com os relatórios de cada uma."""
    return catalogo.listar(service.pastas_permitidas(user))


@router.get("/relatorios/pastas")
def pastas(_=Depends(verificar_admin)):
    """Todas as pastas — são os recursos da tela Admin → Grupos."""
    return catalogo.pastas()


@router.get("/config/{rel_id:path}")
def config(rel_id: str, user=Depends(verificar_token)):
    service.exigir_acesso(user, rel_id)
    if not catalogo.existe(rel_id):
        raise ErroNegocio(f"Relatório '{rel_id}' não encontrado.", "RELATORIO_NAO_ENCONTRADO", 404)
    return catalogo.carregar_config(rel_id)


@router.get("/executar/{rel_id:path}")
def executar(rel_id: str, request: Request, user=Depends(verificar_token)):
    inicio = time.monotonic()
    try:
        service.exigir_acesso(user, rel_id)
        resposta = service.executar(rel_id, dict(request.query_params))
    except ErroNegocio as e:
        return JSONResponse(status_code=e.status, content={"ok": False, "erro": e.erro})
    except Exception as e:
        logger.exception(f"Erro ao executar {rel_id} ({user.get('sub')})")
        return JSONResponse(status_code=500, content={"ok": False, "erro": str(e)})
    logger.info(f"{user.get('sub')} executou {rel_id}: {resposta['total']} linhas em {time.monotonic() - inicio:.1f}s")
    return resposta


@router.post("/relatorios/pagina")
def abrir_pagina(data: PaginaIn, user=Depends(verificar_token)):
    """Endereço (com passe) da página própria de um indicador, para o iframe da tela."""
    service.exigir_acesso(user, data.rel_id)
    if not catalogo.existe(data.rel_id):
        raise ErroNegocio(f"Relatório '{data.rel_id}' não encontrado.", "RELATORIO_NAO_ENCONTRADO", 404)
    passe = paginas.criar_passe(user["sub"], data.rel_id)
    caminho = "/".join(quote(p, safe="") for p in data.rel_id.split("/"))
    return {"url": f"/api/paginas/{caminho}?t={passe}"}


@router.get("/paginas/{rel_id:path}", response_class=HTMLResponse, include_in_schema=False)
def pagina(rel_id: str, t: str = ""):
    paginas.conferir_passe(t, rel_id)
    return HTMLResponse(paginas.montar(rel_id))
