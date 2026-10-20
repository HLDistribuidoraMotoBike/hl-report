"""Administração dos relatórios (HL Report 0.2.0), com o HANA SIMULADO e uma pasta de relatórios de teste: só admin;
árvore (com consultas auxiliares e pasta vazia); criar/excluir pasta (nome reservado, não vazia); criar/salvar/
excluir SQL + config (sem config = padrão; JSON gravado legível); nomes com caminho recusados; teste de SQL sem
salvar (limite de linhas, filtros, schema); templates de indicador e de e-mail; log de ações."""
import json
import os
import sqlite3
import sys
import tempfile
from pathlib import Path

banco = sys.argv[1]
os.environ["DATABASE_URL"] = f"sqlite:///{banco}"
os.environ["ALLOW_LOCAL_AUTH"] = "true"
pasta = Path(tempfile.mkdtemp())
os.environ["RELATORIOS_DIR"] = str(pasta)
sys.path.insert(0, os.getcwd())

(pasta / "sql" / "Financeiro" / "_aux").mkdir(parents=True)
(pasta / "sql" / "Financeiro" / "Baixas.sql").write_text("SELECT 1 FROM DUMMY", encoding="utf-8")
(pasta / "sql" / "Financeiro" / "_aux" / "Contas.sql").write_text("SELECT 2 FROM DUMMY", encoding="utf-8")
(pasta / "templates").mkdir()
(pasta / "templates" / "Painel.html").write_text("<html></html>", encoding="utf-8")
(pasta / "email" / "templates").mkdir(parents=True)

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


chamadas = []


def consultar_falso(sql, params, schema="", limite=0, converter=hana.valor):
    chamadas.append((sql, params, schema, limite))
    linhas = [{"N": i} for i in range(250)]
    return ["N"], linhas[:limite] if limite else linhas


hana.consultar = consultar_falso
usuarios = {"admin": ("Admin", ["Suporte-hl"]), "fin": ("Fin", ["Financeiro-hl"])}
auth.autenticar_usuario = lambda u, p, ip=None: usuarios.get(u)

with TestClient(app) as c:
    db = sqlite3.connect(banco)
    db.execute("insert into grupos_permissao(nome, papel, recursos, ativo) values ('Financeiro-hl', 'usuario', '[\"Financeiro\"]', 1)")
    db.commit()
    ha = {"Authorization": f"Bearer {c.post('/api/auth/login', json={'username': 'admin', 'password': 'x'}).json()['token']}"}
    hf = {"Authorization": f"Bearer {c.post('/api/auth/login', json={'username': 'fin', 'password': 'x'}).json()['token']}"}

    chk(all(c.get(u, headers=hf).status_code == 403 for u in ("/api/admin/arvore", "/api/admin/sql/Financeiro/Baixas",
                                                              "/api/admin/templates/relatorio")), "usuário comum não administra")
    arv = c.get("/api/admin/arvore", headers=ha).json()
    itens = arv[0]["itens"]
    chk(arv[0]["pasta"] == "Financeiro" and [(i["id"], i["auxiliar"]) for i in itens] ==
        [("Financeiro/Baixas", False), ("Financeiro/_aux/Contas", True)], f"árvore com consulta auxiliar: {arv}")

    # pastas
    chk(c.post("/api/admin/pastas", headers=ha, json={"nome": "Vendas"}).json() == {"nome": "Vendas"}, "cria pasta")
    chk(any(p["pasta"] == "Vendas" and p["itens"] == [] for p in c.get("/api/admin/arvore", headers=ha).json()),
        "pasta vazia aparece na árvore")
    chk(c.post("/api/admin/pastas", headers=ha, json={"nome": "Vendas"}).status_code == 409, "pasta repetida: 409")
    chk(c.post("/api/admin/pastas", headers=ha, json={"nome": "_interna"}).status_code == 400, "nome com _ é reservado")
    chk(c.post("/api/admin/pastas", headers=ha, json={"nome": "../fora"}).status_code == 400, "nome com caminho recusado")
    chk(c.delete("/api/admin/pastas/Financeiro", headers=ha).status_code == 409, "pasta com relatório não é excluída")

    # SQL + config
    r = c.put("/api/admin/sql", headers=ha, json={"id": "Vendas/Diario", "sql": "SELECT :data_ini FROM DUMMY", "config": None, "novo": True})
    chk(r.status_code == 200 and (pasta / "sql" / "Vendas" / "Diario.sql").read_text(encoding="utf-8") == "SELECT :data_ini FROM DUMMY",
        "cria relatório (SQL)")
    chk(c.put("/api/admin/sql", headers=ha, json={"id": "Vendas/Diario", "sql": "x", "novo": True}).status_code == 409, "relatório repetido: 409")
    chk(c.put("/api/admin/sql", headers=ha, json={"id": "Nada/X", "sql": "x", "novo": True}).status_code == 404, "pasta inexistente: 404")
    chk(c.put("/api/admin/sql", headers=ha, json={"id": "Vendas/..\\x", "sql": "x", "novo": True}).status_code == 400, "nome com caminho recusado")
    chk(c.put("/api/admin/sql", headers=ha, json={"id": "Vendas/Diario", "sql": "  ", "novo": False}).status_code == 400, "SQL vazio recusado")
    dados = c.get("/api/admin/sql/Vendas/Diario", headers=ha).json()
    chk(dados["config"] is None and dados["parametros"] == ["data_ini"], f"lê SQL sem config, com os filtros usados: {dados}")
    cfg = {"titulo": "Vendas do dia", "tipo": "lista", "filtros": [{"id": "data_ini", "label": "Início", "tipo": "date"}]}
    c.put("/api/admin/sql", headers=ha, json={"id": "Vendas/Diario", "sql": "SELECT :data_ini FROM DUMMY\r\n", "config": cfg, "novo": False})
    texto = (pasta / "config" / "Vendas" / "Diario.json").read_text(encoding="utf-8")
    chk(json.loads(texto) == cfg and "\n  " in texto and "Início" in texto, "config gravado (JSON legível, acentos)")
    chk(b"\r\n" not in (pasta / "sql" / "Vendas" / "Diario.sql").read_bytes(), "SQL gravado com fim de linha LF")
    chk(c.put("/api/admin/sql", headers=ha, json={"id": "Vendas/Diario", "sql": "x", "config": {"tipo": "outro"}}).status_code == 400,
        "tipo inválido recusado")
    menu = c.get("/api/relatorios", headers=ha).json()
    chk(any(r["titulo"] == "Vendas do dia" for p in menu for r in p["relatorios"]), "relatório novo no menu com o título do config")
    c.put("/api/admin/sql", headers=ha, json={"id": "Vendas/Diario", "sql": "SELECT 1 FROM DUMMY", "config": None, "novo": False})
    chk(not (pasta / "config" / "Vendas" / "Diario.json").exists(), "config None apaga o arquivo (vale o padrão)")
    r = c.put("/api/admin/sql", headers=ha, json={"id": "Financeiro/_aux/Novo", "sql": "SELECT 3 FROM DUMMY", "novo": True})
    chk(r.status_code == 200 and (pasta / "sql" / "Financeiro" / "_aux" / "Novo.sql").exists(), "cria consulta auxiliar em subpasta")
    chk(c.delete("/api/admin/sql/Vendas/Diario", headers=ha).status_code == 200 and not (pasta / "sql" / "Vendas" / "Diario.sql").exists(),
        "exclui relatório")
    chk(c.delete("/api/admin/pastas/Vendas", headers=ha).status_code == 200 and not (pasta / "sql" / "Vendas").exists(), "exclui pasta vazia")

    # painel: só config, sem SQL
    r = c.put("/api/admin/sql", headers=ha, json={"id": "Financeiro/Painel", "sql": None, "novo": True,
                                                  "config": {"titulo": "Painel X", "tipo": "painel", "componente": "x"}})
    chk(r.status_code == 200 and not (pasta / "sql" / "Financeiro" / "Painel.sql").exists(), "cria painel sem SQL")
    chk(any(i["id"] == "Financeiro/Painel" and i["tipo"] == "painel" for i in c.get("/api/admin/arvore", headers=ha).json()[0]["itens"]),
        "painel aparece na árvore")
    d = c.get("/api/admin/sql/Financeiro/Painel", headers=ha).json()
    chk(d["sql"] is None and d["config"]["componente"] == "x" and d["parametros"] == [], "lê painel (sql None)")
    chk(c.put("/api/admin/sql", headers=ha, json={"id": "Financeiro/Painel", "novo": False,
                                                  "config": {"titulo": "P", "tipo": "painel"}}).status_code == 400, "painel exige componente")
    chk(c.put("/api/admin/sql", headers=ha, json={"id": "Financeiro/Painel", "sql": None, "novo": True,
                                                  "config": {"tipo": "painel", "componente": "x"}}).status_code == 409, "painel repetido: 409")
    chk(c.delete("/api/admin/sql/Financeiro/Painel", headers=ha).status_code == 200
        and not (pasta / "config" / "Financeiro" / "Painel.json").exists(), "exclui painel")

    # teste de SQL
    r = c.post("/api/admin/testar-sql", headers=ha, json={"sql": "-- x\nSELECT :a, :b FROM T", "filtros": {"a": "1"}, "schema": "SBO_X"})
    j = r.json()
    chk(r.status_code == 200 and len(j["data"]) == 200 and j["cortado"] is True, "teste devolve até 200 linhas e avisa o corte")
    chk(chamadas[-1] == ("SELECT ?, ? FROM T", ["1", ""], "SBO_X", 201), f"teste com filtros e schema: {chamadas[-1]}")

    # templates
    chk(c.get("/api/admin/templates/relatorio", headers=ha).json() == ["Painel.html"], "lista templates de indicador")
    chk(c.put("/api/admin/templates/email", headers=ha, json={"nome": "aviso", "html": "<p>{{ titulo }}</p>", "novo": True}).json()
        == {"nome": "aviso.html"}, "cria template de e-mail (.html acrescentado)")
    chk(c.get("/api/admin/templates/email/aviso.html", headers=ha).json()["html"] == "<p>{{ titulo }}</p>", "lê template")
    chk(c.put("/api/admin/templates/email", headers=ha, json={"nome": "aviso.html", "html": "x", "novo": True}).status_code == 409,
        "template repetido: 409")
    chk(c.get("/api/admin/templates/outro", headers=ha).status_code == 400, "tipo de template inválido")
    chk(c.delete("/api/admin/templates/email/aviso.html", headers=ha).status_code == 200
        and not (pasta / "email" / "templates" / "aviso.html").exists(), "exclui template")

acoes = [a for (a,) in sqlite3.connect(banco).execute("select acao from logs_acoes")]
chk({"relatorio_pasta_criada", "relatorio_criado", "relatorio_salvo", "relatorio_excluido", "template_criado",
     "template_excluido"} <= set(acoes), f"gravações no log de ações: {sorted(set(acoes))}")

print(f"\nTODOS OS {ok} TESTES PASSARAM")
