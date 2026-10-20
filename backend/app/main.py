"""Aplicação FastAPI do HL Report — relatórios da HLMotobike (consultas SQL no SAP HANA, organizadas em pastas).

Segue o padrão de desenvolvimento dos apps HL (hl-core/PADRAO_DESENVOLVIMENTO.md): monólito modular por domínio
(app/modulos/<dominio>/), peças comuns do hl-core (login AD, grupos, configurações, auditoria, /health), toda a API
em /api, banco versionado com Alembic (migrations/; o app não sobe com o banco atrasado — rodar `python migrar.py`).
Os relatórios em si (SQL, configuração, páginas) ficam em arquivos na pasta relatorios/. Regras: docs/REGRAS.md.
"""
import asyncio
import logging
import os

import hlcore  # noqa: F401  (lê o backend/.env antes de qualquer módulo)

os.environ.setdefault("DATABASE_URL", "sqlite:///./report.db")

from fastapi import FastAPI, HTTPException  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402
from fastapi.responses import FileResponse  # noqa: E402
from fastapi.staticfiles import StaticFiles  # noqa: E402

from hlcore import acesso, auth, configuracoes, erros, logs, migracoes, sistema, tempo_real  # noqa: E402

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ALEMBIC_INI = os.path.join(BACKEND, "alembic.ini")
logger = logs.configurar(os.path.join(BACKEND, "logs"))

from hlcore.database import SessionLocal  # noqa: E402
from hlcore.modelos import GrupoPermissao  # noqa: E402
from app.permissoes import GRUPOS_INICIAIS, PERMISSOES  # noqa: E402
from app.modulos import email, relatorios  # noqa: E402
from app.modulos.email import mailer, service as email_service  # noqa: E402
from hlcore.integracoes import hana  # noqa: E402

# Toda a API fica em /api: o resto do endereço é tela do React
API = "/api"

# Configurações deste app: conexão com o SAP HANA, e-mail (SMTP + agendador) e os atalhos para os outros apps
CONFIGURACOES = hana.CONFIGURACOES + mailer.CONFIGURACOES + [
    configuracoes.atalho("APP_HL_LOGISTICA", "HL Logística", "http://100.64.113.7:8000"),
    configuracoes.atalho("APP_HL_BACKOFFICE", "HL Backoffice", "http://100.64.113.7:8002"),
]

# versão: só aqui — o frontend lê este número na compilação (vite.config.js)
app = FastAPI(title="HL Report", version="0.7.1")
erros.registrar_handlers(app)
app.include_router(acesso.rotas(PERMISSOES), prefix=API)
app.include_router(configuracoes.rotas(), prefix=API)
app.include_router(tempo_real.rotas(), prefix=API)   # WebSocket: logout forçado (Admin → Sessões)
app.include_router(sistema.rotas(), prefix=API)
sistema.registrar_versao(app)
app.include_router(relatorios.router, prefix=API)
app.include_router(relatorios.router_admin, prefix=API)
app.include_router(email.router, prefix=API)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=[sistema.CABECALHO_VERSAO],
)

for _aviso in auth.avisos_de_seguranca():
    logging.getLogger("seguranca").warning(_aviso)


def _semear_grupos() -> None:
    """Só na primeira subida (tabela vazia): os grupos de administrador para alguém conseguir entrar."""
    db = SessionLocal()
    try:
        if db.query(GrupoPermissao).count() == 0:
            db.add_all([GrupoPermissao(nome=nome, papel=papel, recursos=[]) for nome, papel in GRUPOS_INICIAIS])
            db.commit()
    finally:
        db.close()


@app.on_event("startup")
async def startup_event():
    migracoes.exigir_atualizado(ALEMBIC_INI)
    configuracoes.semear(CONFIGURACOES)
    _semear_grupos()
    acesso.registrar_app(PERMISSOES, "HL Report")   # acesso central (HL Acesso): papéis e pastas deste app
    db = SessionLocal()
    try:
        email_service.sincronizar(db)
    finally:
        db.close()
    sistema.iniciar_tarefas_padrao()
    # agendador de e-mails: roda sempre, mas só envia com Configurações → API → E-mail → EMAIL_AGENDADOR = ligado
    asyncio.create_task(email_service.agendador())


@app.on_event("shutdown")
async def shutdown_event():
    await sistema.encerrar()


# ── Frontend compilado ────────────────────────────────────────────────────────
_DIST = os.path.join(BACKEND, "..", "frontend", "dist")

if os.path.isdir(_DIST):
    app.mount("/assets", StaticFiles(directory=os.path.join(_DIST, "assets")), name="assets")
    _DIST_REAL = os.path.realpath(_DIST)

    @app.get("/{full_path:path}", include_in_schema=False)
    def serve_spa(full_path: str):
        # endereço de API que não existe é 404 de API, não a tela
        if full_path == API.strip("/") or full_path.startswith(API.strip("/") + "/"):
            raise HTTPException(status_code=404, detail="Rota de API não encontrada.")
        # arquivos reais do build saem como estão; qualquer outra rota é do React Router (index.html)
        if full_path:
            alvo = os.path.realpath(os.path.join(_DIST_REAL, full_path))
            if alvo.startswith(_DIST_REAL + os.sep) and os.path.isfile(alvo):
                return FileResponse(alvo)
        return FileResponse(os.path.join(_DIST, "index.html"))
