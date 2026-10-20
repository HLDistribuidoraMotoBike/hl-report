"""E-mails agendados (HL Report 0.2.0), com HANA e SMTP SIMULADOS: datas dinâmicas; definição no emails.json +
operação no banco (nasce desligado); validações ao salvar; prévia (cid → data URI, nada enviado); envio de teste,
manual e do agendador (assunto, destinatários, anexo .xlsx, imagem inline, processador, histórico); agendador
desligado não envia; janela de horário; um envio por dia; EMAIL_SOMENTE_TESTE; erro de SMTP no histórico;
importação do config.json antigo (SMTP com senha criptografada)."""
import email
import json
import os
import sqlite3
import sys
import tempfile
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

banco = sys.argv[1]
os.environ["DATABASE_URL"] = f"sqlite:///{banco}"
os.environ["ALLOW_LOCAL_AUTH"] = "true"
os.environ["EMAIL_SOMENTE_TESTE"] = "false"
pasta = Path(tempfile.mkdtemp())
os.environ["RELATORIOS_DIR"] = str(pasta)
sys.path.insert(0, os.getcwd())

# ── Relatórios e e-mails de teste ──
(pasta / "sql" / "Logistica").mkdir(parents=True)
(pasta / "sql" / "Logistica" / "Resumo.sql").write_text("SELECT * FROM R WHERE D = :data_ini", encoding="utf-8")
(pasta / "sql" / "Logistica" / "Detalhe.sql").write_text("SELECT * FROM D", encoding="utf-8")
e = pasta / "email"
(e / "templates").mkdir(parents=True)
(e / "processadores").mkdir()
(e / "assets").mkdir()
(e / "assets" / "logo.png").write_bytes(b"\x89PNG\r\n\x1a\nFALSO")
(e / "templates" / "base.html").write_text(
    "<h1>{{ titulo }}</h1><p>{{ periodo }}</p><img src=\"cid:logo\">{% for d in dados %}<i>{{ d.QTD }}</i>{% endfor %}", encoding="utf-8")
(e / "processadores" / "conta.py").write_text(
    "def preparar(dados, rel, filtros):\n    return {'titulo': rel['titulo'] + ' (proc)', 'periodo': filtros['data_ini'], 'dados': dados}\n",
    encoding="utf-8")
(e / "emails.json").write_text(json.dumps({
    "resumo": {"titulo": "Resumo", "sql": "Logistica/Resumo", "filtros": {"data_ini": "HOJE-1"}, "template": "base.html",
               "processador": "conta.preparar", "anexo_excel": True, "sql_anexo": "Logistica/Detalhe",
               "imagens_inline": {"logo": "assets/logo.png"}},
    "simples": {"titulo": "Simples", "sql": "Logistica/Detalhe", "filtros": {"data_ini": "MES_INICIO", "data_fim": "HOJE"},
                "template": "base.html"},
}), encoding="utf-8")

from hlcore import auth  # noqa: E402
from hlcore.configuracoes import decrypt  # noqa: E402
from app.main import app  # noqa: E402
from app.modulos.email import mailer, service  # noqa: E402
from hlcore.integracoes import hana  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

ok = 0


def chk(cond, msg):
    global ok
    if not cond:
        raise SystemExit(f"FALHOU: {msg}")
    ok += 1
    print("  ok -", msg)


# ── Datas dinâmicas ──
d = date(2026, 3, 15)
chk([mailer.resolver_data(v, d) for v in ("HOJE", "HOJE-1", "HOJE+2", "MES_INICIO", "MES_FIM", "MES_ANT_INI", "MES_ANT_FIM", "2025-01-01")]
    == ["2026-03-15", "2026-03-14", "2026-03-17", "2026-03-01", "2026-03-31", "2026-02-01", "2026-02-28", "2025-01-01"],
    "datas dinâmicas (HOJE±n, mês atual e anterior, literal)")

# ── HANA e SMTP simulados ──
consultas = []


def consultar_falso(sql, params, schema="", limite=0, converter=hana.valor):
    consultas.append((sql, params))
    if "FROM R" in sql:
        linhas = [{"DATA": date(2026, 10, 19), "QTD": Decimal("3"), "VAZIO": None}]
    else:
        linhas = [{"NF": 1, "VALOR": Decimal("10.50")}, {"NF": 2, "VALOR": Decimal("7")}]
    return list(linhas[0]), [{k: converter(v) for k, v in linha.items()} for linha in linhas]


hana.consultar = consultar_falso
enviados = []
falhar_smtp = {"sim": False}


class SmtpFalso:
    def __init__(self, host, porta, timeout=None, context=None):
        self.porta = porta

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def ehlo(self):
        pass

    def starttls(self):
        pass

    def login(self, u, s):
        if falhar_smtp["sim"]:
            raise OSError("conexão recusada")

    def sendmail(self, de, para, bruto):
        enviados.append({"de": de, "para": para, "msg": email.message_from_string(bruto), "porta": self.porta})


mailer.smtplib.SMTP = SmtpFalso
mailer.smtplib.SMTP_SSL = SmtpFalso
usuarios = {"admin": ("Admin", ["Suporte-hl"])}
auth.autenticar_usuario = lambda u, p, ip=None: usuarios.get(u)

with TestClient(app) as c:
    h = {"Authorization": f"Bearer {c.post('/api/auth/login', json={'username': 'admin', 'password': 'x'}).json()['token']}"}
    lst = c.get("/api/email/agendamentos", headers=h).json()
    ag = {a["chave"]: a for a in lst["agendamentos"]}
    chk(set(ag) == {"resumo", "simples"} and not any(a["ativo"] for a in ag.values()) and lst["agendador_ligado"] is False,
        "cada e-mail do emails.json nasce desligado; agendador desligado")
    chk(ag["resumo"]["definicao"]["sql"] == "Logistica/Resumo", "definição vem do emails.json")

    # validações
    base = {"ativo": True, "horario": "07:00", "dias_semana": ["seg"], "destinatarios": ["a@hl.com.br"], "assunto": "Resumo do dia"}
    chk(c.put("/api/email/agendamentos/resumo", headers=h, json={**base, "horario": "7h"}).status_code == 400, "horário inválido")
    chk(c.put("/api/email/agendamentos/resumo", headers=h, json={**base, "destinatarios": ["sem-arroba"]}).status_code == 400, "e-mail inválido")
    chk(c.put("/api/email/agendamentos/resumo", headers=h, json={**base, "destinatarios": []}).status_code == 400, "ligar exige destinatários")
    chk(c.put("/api/email/agendamentos/nada", headers=h, json=base).status_code == 404, "e-mail inexistente: 404")
    r = c.put("/api/email/agendamentos/resumo", headers=h,
              json={**base, "dias_semana": ["sex", "seg", "xx"], "destinatarios": ["a@hl.com.br", " b@hl.com.br ", "A@HL.com.br", ""]})
    a = c.get("/api/email/agendamentos", headers=h).json()["agendamentos"][0]
    chk(r.status_code == 200 and a["dias_semana"] == ["seg", "sex"] and a["destinatarios"] == ["a@hl.com.br", "b@hl.com.br"]
        and a["atualizado_por"] == "Admin", "salva: dias na ordem, destinatários limpos e sem repetir")

    # prévia: nada enviado
    p = c.post("/api/email/agendamentos/resumo/previa", headers=h).json()
    chk("data:image/png;base64," in p["html"] and "cid:" not in p["html"] and p["anexos"] and not enviados,
        "prévia com a imagem embutida, lista o anexo e não envia")
    chk(consultas[0][1] == [mailer.resolver_data("HOJE-1")], "filtro HOJE-1 resolvido na consulta")

    # sem SMTP configurado
    r = c.post("/api/email/agendamentos/resumo/enviar", headers=h, json={"teste": True, "destinatarios": ["eu@hl.com.br"]}).json()
    chk(r["status"] == "erro" and "SMTP não configurado" in r["erro"] and not enviados, "sem SMTP: erro no histórico, nada enviado")
    db = sqlite3.connect(banco)
    from hlcore.configuracoes import encrypt  # noqa: E402
    for k, v in (("SMTP_HOST", "smtp.teste"), ("SMTP_USUARIO", "u"), ("SMTP_SENHA", encrypt("s")), ("SMTP_DE", "Relatórios HL <rel@hl.com.br>")):
        db.execute("update configuracoes set valor = ? where chave = ?", (v, k))
    db.commit()

    # envio de teste
    r = c.post("/api/email/agendamentos/resumo/enviar", headers=h, json={"teste": True, "destinatarios": ["eu@hl.com.br"]}).json()
    m = enviados[-1]
    partes = {p.get_content_type(): p for p in m["msg"].walk()}
    html = partes["text/html"].get_payload(decode=True).decode()
    anexo = partes["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]
    chk(r["status"] == "ok" and m["para"] == ["eu@hl.com.br"] and m["de"] == "rel@hl.com.br"
        and str(email.header.make_header(email.header.decode_header(m["msg"]["Subject"]))) == "[TESTE] Resumo do dia",
        "teste vai só para o endereço digitado, assunto com [TESTE]")
    chk("Resumo (proc)" in html and "<i>3</i>" in html, "processador monta o contexto (Decimal chega como Decimal)")
    chk("image/png" in partes and partes["image/png"]["Content-ID"] == "<logo>", "imagem inline com Content-ID")
    nome_anexo = anexo.get_filename()
    from io import BytesIO  # noqa: E402
    from openpyxl import load_workbook  # noqa: E402
    ws = load_workbook(BytesIO(anexo.get_payload(decode=True))).active
    chk(nome_anexo == f"Resumo - {mailer.resolver_data('HOJE-1')}.xlsx" and [list(x) for x in ws.values] ==
        [["NF", "VALOR"], [1, 10.5], [2, 7]], f"anexo .xlsx com as linhas do sql_anexo: {nome_anexo}")

    # disparo manual
    r = c.post("/api/email/agendamentos/resumo/enviar", headers=h, json={"teste": False}).json()
    chk(r["status"] == "ok" and enviados[-1]["para"] == ["a@hl.com.br", "b@hl.com.br"] and r["tipo"] == "manual",
        "Disparar agora vai para os destinatários cadastrados")

    # EMAIL_SOMENTE_TESTE
    os.environ["EMAIL_SOMENTE_TESTE"] = "true"
    n = len(enviados)
    chk(c.post("/api/email/agendamentos/resumo/enviar", headers=h, json={"teste": False}).status_code == 400 and len(enviados) == n,
        "EMAIL_SOMENTE_TESTE: disparo manual recusado")
    chk(c.get("/api/email/agendamentos", headers=h).json()["somente_teste"] is True, "tela sabe que é só teste")
    os.environ["EMAIL_SOMENTE_TESTE"] = "false"

# ── Agendador ──
segunda = datetime(2026, 10, 19, 7, 5)   # segunda-feira
n = len(enviados)
chk(service.rodar_agendados(segunda) == 0 and len(enviados) == n, "agendador DESLIGADO não envia")
db = sqlite3.connect(banco)
db.execute("update configuracoes set valor = 'ligado' where chave = 'EMAIL_AGENDADOR'")
db.commit()
chk(service.rodar_agendados(datetime(2026, 10, 19, 6, 59)) == 0, "antes do horário não envia")
chk(service.rodar_agendados(datetime(2026, 10, 20, 7, 5)) == 0, "dia fora da agenda (terça) não envia")
chk(service.rodar_agendados(datetime(2026, 10, 19, 7, 31)) == 0, "mais de 30 min depois do horário não envia")
chk(service.rodar_agendados(segunda) == 1 and enviados[-1]["para"] == ["a@hl.com.br", "b@hl.com.br"], "no horário: envia")
chk(service.rodar_agendados(datetime(2026, 10, 19, 7, 20)) == 0 and len(enviados) == n + 1, "não envia de novo no mesmo dia")
os.environ["EMAIL_SOMENTE_TESTE"] = "true"
chk(service.rodar_agendados(datetime(2026, 10, 23, 7, 5)) == 0, "EMAIL_SOMENTE_TESTE: agendador não envia")
os.environ["EMAIL_SOMENTE_TESTE"] = "false"
falhar_smtp["sim"] = True
chk(service.rodar_agendados(datetime(2026, 10, 23, 7, 5)) == 1, "sexta: tenta enviar")
ult = db.execute("select tipo, status, erro from email_envios order by id desc limit 1").fetchone()
chk(ult[0] == "agendado" and ult[1] == "erro" and "conexão recusada" in ult[2], f"falha do SMTP fica no histórico: {ult}")
chk(service.rodar_agendados(datetime(2026, 10, 23, 7, 10)) == 0, "envio com erro não repete sozinho no mesmo dia")
tipos = [t for (t,) in db.execute("select tipo from email_envios order by id")]
chk(tipos == ["teste", "teste", "manual", "agendado", "agendado"], f"histórico de envios: {tipos}")

# ── Importação do config.json antigo ──
from scripts.importar_email import importar  # noqa: E402

antigo = pasta / "config.json"
antigo.write_text(json.dumps({"smtp": {"host": "mail.hl", "port": 587, "usuario": "c@hl", "senha": "segredo", "de": "R <c@hl>"},
                              "relatorios": [{"id": "simples", "ativo": True, "horario": "08:00", "dias_semana": ["dom", "seg"],
                                              "destinatarios": ["x@hl.com.br"], "assunto": "📦 Simples"},
                                             {"id": "sumiu", "ativo": True}]}), encoding="utf-8")
linhas = importar(str(antigo), executar=False)
chk(any("PULA" in x and "sumiu" in x for x in linhas) and not any("segredo" in x for x in linhas), "simulação: pula o que não existe, não mostra a senha")
importar(str(antigo), executar=True)
a = db.execute("select ativo, horario, dias_semana, destinatarios, assunto from email_agendamentos where chave = 'simples'").fetchone()
chk(a == (1, "08:00", '["seg", "dom"]', '["x@hl.com.br"]', "📦 Simples"), f"agendamento importado: {a}")
cfg = dict(db.execute("select chave, valor from configuracoes where grupo = 'smtp'").fetchall())
chk(cfg["SMTP_HOST"] == "mail.hl" and cfg["SMTP_PORTA"] == "587" and cfg["SMTP_SENHA"] != "segredo" and decrypt(cfg["SMTP_SENHA"]) == "segredo",
    "SMTP importado com a senha criptografada")

print(f"\nTODOS OS {ok} TESTES PASSARAM")
