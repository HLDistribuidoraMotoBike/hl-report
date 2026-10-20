"""Relatórios (HL Report 0.1.0) com o HANA SIMULADO e uma pasta de relatórios de teste: menu por permissão (pasta =
recurso), execução no formato do Report antigo (filtros :nome → ?, comentários, schema do config, rótulos de mês,
decimal como texto), erros {ok, erro}, caminho fora da pasta recusado, página de indicador com passe e o roteador de
fetch, e a importação do permissions.json."""
import json
import os
import sqlite3
import sys
import tempfile
from datetime import date
from decimal import Decimal
from pathlib import Path

banco = sys.argv[1]
os.environ["DATABASE_URL"] = f"sqlite:///{banco}"
os.environ["ALLOW_LOCAL_AUTH"] = "true"
pasta = Path(tempfile.mkdtemp())
os.environ["RELATORIOS_DIR"] = str(pasta)
sys.path.insert(0, os.getcwd())

# ── Relatórios de teste ──
(pasta / "sql" / "Financeiro" / "_aux").mkdir(parents=True)
(pasta / "sql" / "Compras").mkdir(parents=True)
(pasta / "config" / "Financeiro").mkdir(parents=True)
(pasta / "templates").mkdir()
(pasta / "sql" / "Financeiro" / "Baixas.sql").write_text(
    "-- comentário com :ignorado\nSELECT * FROM X WHERE D >= :data_ini AND D <= :data_fim AND M = :marca", encoding="utf-8")
(pasta / "config" / "Financeiro" / "Baixas.json").write_text(json.dumps(
    {"tipo": "lista", "titulo": "Prazo de Baixas", "schema": "SBO_TESTE", "filtros": [{"id": "data_ini", "tipo": "date"}]}), encoding="utf-8")
(pasta / "sql" / "Financeiro" / "_aux" / "Contas.sql").write_text("SELECT 1 FROM DUMMY", encoding="utf-8")
(pasta / "sql" / "Financeiro" / "Painel.sql").write_text("SELECT 1 FROM DUMMY", encoding="utf-8")
(pasta / "config" / "Financeiro" / "Painel.json").write_text(json.dumps({"tipo": "indicador", "template": "Painel.html", "meta": 5}), encoding="utf-8")
(pasta / "templates" / "Painel.html").write_text(
    "<!DOCTYPE html><html><head><title>P</title></head><body><a href=\"/\">← Voltar</a>"
    "<script>const CFG = {{ config | tojson }}; const REL_ID = {{ rel_id | tojson }};</script></body></html>", encoding="utf-8")
(pasta / "sql" / "Compras" / "Fluxo.sql").write_text("SELECT MES_0_LABEL, MES_1_LABEL FROM X", encoding="utf-8")
(pasta / "sql" / "Solto.sql").write_text("SELECT 1 FROM DUMMY", encoding="utf-8")
(pasta.parent / "segredo.sql").write_text("SELECT 'fora' FROM DUMMY", encoding="utf-8")

from hlcore import auth  # noqa: E402
from app.main import app  # noqa: E402
from app.modulos.relatorios import hana  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

ok = 0


def chk(cond, msg):
    global ok
    if not cond:
        raise SystemExit(f"FALHOU: {msg}")
    ok += 1
    print("  ok -", msg)


# ── HANA simulado: guarda a última chamada; respostas por consulta ──
chamadas = []
respostas = {}


class ConexaoFalsa:
    def __init__(self):
        self.cursor_ = None

    def cursor(self):
        return CursorFalso()

    def close(self):
        pass


class CursorFalso:
    description = None

    def execute(self, sql, params=None):
        chamadas.append((sql, params))
        if sql.startswith("SET SCHEMA"):
            return
        if "FALHA" in sql:
            raise RuntimeError("SQL error: tabela inexistente")
        cols, linhas = respostas.get("atual", ([], []))
        self.description = [(c,) for c in cols]
        self._linhas = linhas

    def fetchall(self):
        return self._linhas

    def fetchmany(self, n):
        return self._linhas[:n]

    def close(self):
        pass


hana.conectar = lambda: ConexaoFalsa()

# ── Logins simulados (AD) ──
usuarios = {"admin": ("Admin", ["Suporte-hl"]), "fin": ("Financeiro", ["Financeiro-hl"]), "sem": ("Sem", ["Outro"])}
auth.autenticar_usuario = lambda u, p, ip=None: usuarios.get(u)

with TestClient(app) as c:
    db = sqlite3.connect(banco)
    db.execute("insert into grupos_permissao(nome, papel, recursos, ativo) values ('Financeiro-hl', 'usuario', '[\"Financeiro\"]', 1)")
    db.commit()

    def login(u):
        r = c.post("/api/auth/login", json={"username": u, "password": "x"})
        return r, ({"Authorization": f"Bearer {r.json()['token']}"} if r.status_code == 200 else {})

    _, ha = login("admin")
    r, hf = login("fin")
    chk(r.status_code == 200 and r.json()["recursos"] == ["Financeiro"], "usuário entra com a pasta Financeiro como recurso")
    chk(login("sem")[0].status_code == 403, "grupo não cadastrado não entra")

    # menu
    menu = c.get("/api/relatorios", headers=ha).json()
    chk([p["pasta"] for p in menu] == ["Compras", "Financeiro", "Geral"], f"admin vê todas as pastas (com 'Geral' p/ SQL solto): {menu}")
    fin = next(p for p in menu if p["pasta"] == "Financeiro")["relatorios"]
    chk([(x["id"], x["titulo"], x["tipo"]) for x in fin] == [("Financeiro/Baixas", "Prazo de Baixas", "lista"),
                                                             ("Financeiro/Painel", "Painel", "indicador")],
        f"relatórios com título/tipo do config; subpasta _aux fora do menu: {fin}")
    chk([p["pasta"] for p in c.get("/api/relatorios", headers=hf).json()] == ["Financeiro"], "usuário só vê as pastas do grupo")
    chk(c.get("/api/relatorios/pastas", headers=ha).json() == ["Compras", "Financeiro", "Geral"], "pastas (recursos) para o admin")
    chk(c.get("/api/relatorios/pastas", headers=hf).status_code == 403, "lista de pastas é só do admin")
    chk(c.get("/api/relatorios").status_code in (401, 403), "sem login não vê nada")

    # config
    chk(c.get("/api/config/Financeiro/Baixas", headers=hf).json()["titulo"] == "Prazo de Baixas", "config do relatório")
    chk(c.get("/api/config/Compras/Fluxo", headers=hf).status_code == 403, "config de outra pasta: 403")
    chk(c.get("/api/config/Compras/Fluxo", headers=ha).json()["filtros"][0]["id"] == "data_ini", "sem config: filtros padrão")

    # execução
    respostas["atual"] = (["DATA", "VALOR", "QTD"], [(date(2026, 10, 1), Decimal("123.4500"), 3), (None, float("nan"), None)])
    r = c.get("/api/executar/Financeiro/Baixas", headers=hf, params={"data_ini": "2026-10-01", "data_fim": "2026-10-15"})
    j = r.json()
    chk(r.status_code == 200 and j["ok"] and j["total"] == 2 and j["colunas"] == ["DATA", "VALOR", "QTD"], f"executa: {j}")
    chk(j["data"][0] == {"DATA": "2026-10-01", "VALOR": "123.4500", "QTD": 3} and j["data"][1]["VALOR"] == 0.0,
        "data ISO, DECIMAL como texto, NaN vira 0 (igual ao Report antigo)")
    sql, params = chamadas[-1]
    chk(sql.count("?") == 3 and ":" not in sql and "comentário" not in sql and params == ["2026-10-01", "2026-10-15", ""],
        f"filtros viram parâmetros na ordem, comentário removido, filtro ausente = '': {sql!r} {params}")
    chk(any(s == 'SET SCHEMA "SBO_TESTE"' for s, _ in chamadas), "schema do config aplicado")
    chk(c.get("/api/executar/Compras/Fluxo", headers=hf).json() == {"ok": False, "erro": "Acesso negado a este relatório."},
        "outra pasta: {ok: false, erro}")
    r = c.get("/api/executar/Financeiro/Baixas", headers=hf, params={"data_ini": "2026-10-20", "data_fim": "2026-10-01"})
    chk(r.status_code == 400 and r.json()["erro"] == "Data inicial maior que data final.", "data inicial > final recusada")
    chk(c.get("/api/executar/Financeiro/Baixas", headers=hf, params={"data_ini": "20/10/2026"}).status_code == 400, "data fora do formato")
    chk(c.get("/api/executar/Financeiro/Nada", headers=hf).status_code == 404, "relatório inexistente: 404")
    chk(c.get("/api/executar/Financeiro/..%2F..%2Fsegredo", headers=ha).json().get("erro") == "Relatório inválido.",
        "caminho para fora da pasta de relatórios recusado")
    chk(c.get("/api/executar/Financeiro/_aux/Contas", headers=hf).json()["ok"], "consulta auxiliar (subpasta) pela pasta do indicador")
    (pasta / "sql" / "Financeiro" / "Erro.sql").write_text("SELECT FALHA", encoding="utf-8")
    r = c.get("/api/executar/Financeiro/Erro", headers=hf)
    chk(r.status_code == 500 and "tabela inexistente" in r.json()["erro"], "erro do HANA volta como {ok: false, erro}")

    # rótulos de mês (pivot)
    respostas["atual"] = (["MES_0_LABEL", "MES_1_LABEL"], [])
    j = c.get("/api/executar/Compras/Fluxo", headers=ha).json()
    hoje = date.today()
    anterior = date(hoje.year - (hoje.month == 1), (hoje.month - 2) % 12 + 1, 1)
    chk(j["mes_labels"] == {"MES_0_LABEL": hoje.strftime("%Y-%m"), "MES_1_LABEL": anterior.strftime("%Y-%m")},
        f"sem linhas: rótulos dos meses: {j.get('mes_labels')}")
    respostas["atual"] = (["MES_0_LABEL", "MES_1_LABEL"], [(None, "2025-01")])
    j = c.get("/api/executar/Compras/Fluxo", headers=ha).json()
    chk(j["data"][0] == {"MES_0_LABEL": hoje.strftime("%Y-%m"), "MES_1_LABEL": "2025-01"} and "mes_labels" not in j,
        "rótulo vazio preenchido; o que veio do banco fica")

    # página de indicador
    r = c.post("/api/relatorios/pagina", headers=hf, json={"rel_id": "Financeiro/Painel"})
    url = r.json()["url"]
    chk(url.startswith("/api/paginas/Financeiro/Painel?t="), f"endereço da página com passe: {url[:40]}")
    p = c.get(url)
    chk(p.status_code == 200 and "hl-embutido" in p.text and p.text.index("__hlFetch") < p.text.index("<title>"),
        "página montada com o roteador de fetch no começo do <head>")
    chk('"meta": 5' in p.text and '"Financeiro/Painel"' in p.text, "Jinja: config e rel_id como JSON")
    chk(c.get(url.split("?")[0] + "?t=errado").status_code == 401, "passe inválido: 401")
    outro = c.post("/api/relatorios/pagina", headers=ha, json={"rel_id": "Compras/Fluxo"}).json()["url"]
    chk(c.get("/api/paginas/Financeiro/Painel?" + outro.split("?")[1]).status_code == 401, "passe de outra página não serve")
    chk(c.post("/api/relatorios/pagina", headers=hf, json={"rel_id": "Compras/Fluxo"}).status_code == 403,
        "passe só para pasta permitida")
    chk(c.get(outro).status_code == 400, "relatório do tipo lista não tem página própria")

# importação do permissions.json do Report antigo
from scripts.importar_permissoes import importar  # noqa: E402

arq = pasta / "permissions.json"
arq.write_text(json.dumps({"acesso_total": ["Domain Admins", "TI-hl"],
                           "grupos": {"Financeiro-hl": ["Financeiro", "Compras"], "Logistica-hl": ["Logistica"]}}), encoding="utf-8")
simulado = importar(str(arq), executar=False)
db = sqlite3.connect(banco)
chk(len(simulado) == 4 and db.execute("select count(*) from grupos_permissao where nome = 'TI-hl'").fetchone()[0] == 0,
    "importação sem --executar não grava")
importar(str(arq), executar=True)
grupos = {n: (p, json.loads(r)) for n, p, r in db.execute("select nome, papel, recursos from grupos_permissao")}
chk(grupos["TI-hl"] == ("admin", []) and grupos["Financeiro-hl"] == ("usuario", ["Compras", "Financeiro"])
    and grupos["Logistica-hl"] == ("usuario", ["Logistica"]) and grupos["Suporte-hl"][0] == "admin",
    f"acesso_total → admin; grupos → usuário com as pastas; os outros ficam: {grupos}")

print(f"\nTODOS OS {ok} TESTES PASSARAM")
