"""App (HL Report 0.1.0) num banco NOVO migrado: grupos de administrador semeados (os de acesso
total do Report antigo), configurações do HANA e atalhos, toda a API em /api com a versão no cabeçalho, 404 de API, login local e o app recusando subir com o
banco atrasado (migração pendente)."""
import os
import sqlite3
import sys

banco = sys.argv[1]
os.environ["DATABASE_URL"] = f"sqlite:///{banco}"
os.environ["ALLOW_LOCAL_AUTH"] = "true"
sys.path.insert(0, os.getcwd())

from app.main import ALEMBIC_INI, app  # noqa: E402
from hlcore import migracoes  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

ok = 0


def chk(cond, msg):
    global ok
    if not cond:
        raise SystemExit(f"FALHOU: {msg}")
    ok += 1
    print("  ok -", msg)


atual, head = migracoes.situacao(ALEMBIC_INI)
chk(atual == head and head, f"banco migrado até a última versão ({head})")

with TestClient(app) as raiz:
    c = sqlite3.connect(banco)
    grupos = dict(c.execute("select nome, papel from grupos_permissao").fetchall())
    chk(grupos == {"Suporte-hl": "admin", "Domain Admins": "admin", "Administradores": "admin"}, f"grupos de administrador semeados: {grupos}")
    chaves = {k for (k,) in c.execute("select chave from configuracoes")}
    chk({"HANA_HOST", "HANA_PORT", "HANA_USER", "HANA_PASSWORD", "HANA_DATABASE", "HANA_SCHEMA",
         "APP_HL_LOGISTICA", "APP_HL_BACKOFFICE"} <= chaves, f"configurações do HANA e atalhos semeadas: {sorted(chaves)}")
    sensivel = dict(c.execute("select chave, sensivel from configuracoes where grupo = 'hana'").fetchall())
    chk(sensivel["HANA_PASSWORD"] and not sensivel["HANA_HOST"], "senha do HANA guardada como sensível (criptografada)")
    c.close()

    r = raiz.get("/api/health")
    chk(r.status_code == 200 and r.headers.get("x-app-versao") == app.version, f"/api/health com X-App-Versao {app.version}")
    chk(raiz.get("/api/nao-existe").status_code == 404, "/api/<inexistente> é 404")
    api_fora = [r.path for r in app.routes if hasattr(r, "endpoint") and getattr(r, "include_in_schema", True)
                and not r.path.startswith("/api") and r.path not in ("/openapi.json", "/docs", "/docs/oauth2-redirect", "/redoc")]
    chk(not api_fora, f"toda rota de API está em /api (fora: {api_fora})")

    r = raiz.post("/api/auth/login", json={"username": "admin", "password": os.getenv("LOCAL_ADMIN_PASS", "admin123")})
    chk(r.status_code == 200 and r.json()["papel"] == "admin", f"login local de administrador ({r.status_code})")
    h = {"Authorization": f"Bearer {r.json()['token']}"}
    r = raiz.post("/api/grupos-permissao", headers=h, json={"nome": "Fiscal-teste", "papel": "usuario",
                                                             "recursos": ["Financeiro"], "ativo": True})
    chk(r.status_code == 200 and r.json()["recursos"] == ["Financeiro"], "admin cadastra grupo de usuário com uma pasta como recurso")
    chk(raiz.post("/api/grupos-permissao", headers=h, json={"nome": "X", "papel": "logistica", "recursos": [],
                                                             "ativo": True}).status_code == 400, "papel de outro app recusado")

# banco atrasado: o app não sobe
c = sqlite3.connect(banco)
c.execute("update alembic_version set version_num = 'antiga'")
c.commit()
c.close()
try:
    with TestClient(app):
        pass
    chk(False, "app subiu com o banco atrasado")
except RuntimeError as e:
    chk("migrar.py" in str(e), f"app recusa subir com o banco atrasado: {e}")

print(f"\nTODOS OS {ok} TESTES PASSARAM")
