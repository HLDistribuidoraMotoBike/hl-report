"""Report no modo ACESSO CENTRAL (HL Acesso SIMULADO por um transporte httpx falso): registro de papéis e pastas no
startup; sem login local nem cadastro de grupos aqui; troca do código pelo token RS256; permissão por pasta vinda do
token; token de outra chave ou de outro app recusado; renovação; sessão encerrada no central derruba o acesso; sair
encerra no central; pasta nova avisa o HL Acesso."""
import json
import os
import sys
import tempfile
import uuid
from datetime import datetime, timedelta
from pathlib import Path

banco = sys.argv[1]
os.environ["DATABASE_URL"] = f"sqlite:///{banco}"
os.environ.update({"ACESSO_URL": "http://acesso.teste", "ACESSO_APP": "report", "ACESSO_SEGREDO": "s3gr3d0",
                   "APP_URL": "http://localhost:5175"})
pasta = Path(tempfile.mkdtemp())
os.environ["RELATORIOS_DIR"] = str(pasta)
for p in ("Financeiro", "Compras"):
    (pasta / "sql" / p).mkdir(parents=True)
    (pasta / "sql" / p / "Rel.sql").write_text("SELECT 1 FROM DUMMY", encoding="utf-8")
sys.path.insert(0, os.getcwd())

import httpx  # noqa: E402
from cryptography.hazmat.primitives import serialization  # noqa: E402
from cryptography.hazmat.primitives.asymmetric import rsa  # noqa: E402
from jose import jwt  # noqa: E402

ok = 0


def chk(cond, msg):
    global ok
    if not cond:
        raise SystemExit(f"FALHOU: {msg}")
    ok += 1
    print("  ok -", msg)


def chave_rsa():
    k = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    priv = k.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode()
    pub = k.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo).decode()
    return priv, pub


PRIV, PUB = chave_rsa()
OUTRA_PRIV, _ = chave_rsa()
central = {"registros": [], "ativa": {"S1": True, "S2": True}, "encerradas": [], "headers": None}


def token(sid="S1", papel="usuario", recursos=("Financeiro",), aud="report", priv=PRIV, minutos=30):
    return jwt.encode({"sub": "ana", "display_name": "Ana", "grupos": ["Financeiro-hl"], "papel": papel, "recursos": list(recursos),
                       "sid": sid, "aud": aud, "jti": str(uuid.uuid4()), "exp": datetime.utcnow() + timedelta(minutes=minutos)},
                      priv, algorithm="RS256")


def resposta(tok, papel="usuario", recursos=("Financeiro",)):
    return {"token": tok, "username": "ana", "display_name": "Ana", "grupos": ["Financeiro-hl"], "papel": papel, "recursos": list(recursos)}


def handler(req: httpx.Request) -> httpx.Response:
    central["headers"] = dict(req.headers)
    caminho = req.url.path
    corpo = json.loads(req.content or b"{}")
    if caminho == "/api/publica/chave":
        return httpx.Response(200, json={"chave": PUB})
    if caminho == "/api/publica/apps/registrar":
        central["registros"].append(corpo)
        return httpx.Response(200, json={"ok": True})
    if caminho == "/api/publica/codigos/trocar":
        if corpo["codigo"] == "bom":
            return httpx.Response(200, json=resposta(token()))
        if corpo["codigo"] == "admin":
            return httpx.Response(200, json=resposta(token(sid="S2", papel="admin", recursos=()), "admin", ()))
        return httpx.Response(401, json={"erro": "Código de login inválido ou vencido — entre de novo."})
    if caminho == "/api/publica/sessoes/renovar":
        sid = jwt.get_unverified_claims(corpo["token"])["sid"]
        if not central["ativa"].get(sid):
            return httpx.Response(401, json={"erro": "Sessão expirada. Faça login novamente."})
        return httpx.Response(200, json=resposta(token(sid=sid, recursos=("Financeiro", "Compras")), recursos=("Financeiro", "Compras")))
    if caminho.startswith("/api/publica/sessoes/") and req.method == "GET":
        return httpx.Response(200, json={"ativa": central["ativa"].get(caminho.rsplit("/", 1)[1], False)})
    if caminho == "/api/publica/sessoes/encerrar":
        sid = jwt.get_unverified_claims(corpo["token"])["sid"]
        central["ativa"][sid] = False
        central["encerradas"].append(sid)
        return httpx.Response(200, json={"ok": True})
    return httpx.Response(404, json={"erro": "?"})


from hlcore import sso  # noqa: E402

sso._cliente = httpx.Client(base_url="http://acesso.teste", transport=httpx.MockTransport(handler),
                            headers={"X-App": sso.ACESSO_APP, "X-App-Segredo": sso.ACESSO_SEGREDO})

from app.main import app  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

with TestClient(app) as c:
    reg = central["registros"][0]
    chk(central["headers"]["x-app"] == "report" and central["headers"]["x-app-segredo"] == "s3gr3d0", "app se identifica com chave e segredo")
    chk(reg["nome"] == "HL Report" and reg["url"] == "http://localhost:5175" and [r["key"] for r in reg["recursos"]] == ["Compras", "Financeiro"]
        and [p["value"] for p in reg["papeis"]] == ["admin", "usuario"] and reg["regras"]["papeis"] == ["admin", "usuario"],
        f"startup registra papéis e PASTAS no HL Acesso: {[r['key'] for r in reg['recursos']]}")
    chk(c.get("/api/auth/config").json() == {"central": "http://acesso.teste", "app": "report"}, "tela sabe que o login é central")
    chk(c.post("/api/auth/login", json={"username": "admin", "password": "x"}).status_code in (404, 405), "sem login local")
    chk(c.get("/api/grupos-permissao").status_code in (401, 403, 404, 405), "sem cadastro de grupos no app")

    chk(c.post("/api/auth/sso", json={"codigo": "ruim"}).status_code == 401, "código inválido: 401")
    r = c.post("/api/auth/sso", json={"codigo": "bom"})
    j = r.json()
    chk(r.status_code == 200 and j["username"] == "ana" and j["recursos"] == ["Financeiro"], "troca o código pelo token do Report")
    h = {"Authorization": f"Bearer {j['token']}"}
    chk([p["pasta"] for p in c.get("/api/relatorios", headers=h).json()] == ["Financeiro"], "menu com as pastas do token")
    chk(c.get("/api/config/Compras/Rel", headers=h).status_code == 403, "pasta fora do token: 403")
    chk(c.get("/api/relatorios/pastas", headers=h).status_code == 403, "usuário não administra")
    chk(c.get("/api/relatorios", headers={"Authorization": f"Bearer {token(priv=OUTRA_PRIV)}"}).status_code == 401, "token de outra chave: 401")
    chk(c.get("/api/relatorios", headers={"Authorization": f"Bearer {token(aud='backoffice')}"}).status_code == 401, "token de outro app: 401")
    chk(c.get("/api/relatorios", headers={"Authorization": f"Bearer {token(minutos=-1)}"}).status_code == 401, "token vencido: 401")

    r = c.post("/api/auth/refresh", headers=h)
    h2 = {"Authorization": f"Bearer {r.json()['access_token']}"}
    chk(r.status_code == 200 and [p["pasta"] for p in c.get("/api/relatorios", headers=h2).json()] == ["Compras", "Financeiro"],
        "renovação traz o acesso de agora (pasta nova liberada no central)")

    # pasta nova pelo admin → avisa o HL Acesso
    ha = {"Authorization": f"Bearer {c.post('/api/auth/sso', json={'codigo': 'admin'}).json()['token']}"}
    antes = len(central["registros"])
    chk(c.post("/api/admin/pastas", headers=ha, json={"nome": "Vendas"}).status_code == 200
        and len(central["registros"]) == antes + 1 and "Vendas" in [r["key"] for r in central["registros"][-1]["recursos"]],
        "pasta nova vai para o HL Acesso na hora")

    # sessão encerrada no central
    central["ativa"]["S1"] = False
    sso.esquecer_sessao("S1")
    chk(c.get("/api/relatorios", headers=h2).status_code == 401, "sessão encerrada no HL Acesso: o app recusa")
    chk(c.post("/api/auth/refresh", headers=h2).status_code == 401, "e não renova")
    chk(c.post("/api/auth/logout", headers=ha).json()["central"] == "http://acesso.teste" and "S2" in central["encerradas"],
        "sair encerra a sessão no HL Acesso (todos os apps)")

print(f"\nTODOS OS {ok} TESTES PASSARAM")
