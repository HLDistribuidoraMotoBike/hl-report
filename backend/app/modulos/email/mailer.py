"""Montagem e envio de um e-mail de relatório (veio do email_reports/mailer.py do Report antigo, mesmo resultado).

Definição de cada e-mail: relatorios/email/emails.json — {chave: {titulo, sql, filtros, template, processador?,
anexo_excel?, sql_anexo?, imagens_inline?, subtitulo_tabela?, kpis?, colunas?}}.
- filtros aceitam datas dinâmicas: HOJE, HOJE-7, HOJE+1, MES_INICIO, MES_FIM, MES_ANT_INI, MES_ANT_FIM;
- processador "arquivo.funcao" (relatorios/email/processadores/arquivo.py) monta o contexto do template a partir das
  linhas; sem processador vai o contexto padrão (titulo, periodo, kpis, colunas, dados);
- anexo_excel: .xlsx com as linhas de sql_anexo (ou as do corpo);
- imagens_inline {cid: "assets/arquivo.png"} viram imagens do corpo (src="cid:...").
SMTP em Configurações → API → E-mail (SMTP).
"""
import base64
import importlib.util
import json
import logging
import math
import mimetypes
import smtplib
import ssl
from datetime import date, datetime, timedelta
from email.header import Header
from email.mime.application import MIMEApplication
from email.mime.image import MIMEImage
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formataddr
from io import BytesIO
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from hlcore.configuracoes import get_config
from hlcore.erros import ErroNegocio

from app.modulos.relatorios import catalogo, hana, service as relatorios

log = logging.getLogger("email")

# (grupo, chave, variável do .env, sensível, descrição[, padrão]) — semeadas no startup (app/main.py)
CONFIGURACOES = [
    ("smtp", "SMTP_HOST", "SMTP_HOST", False, "Servidor SMTP", "mail.hlmotobike.com.br"),
    ("smtp", "SMTP_PORTA", "SMTP_PORTA", False, "Porta (STARTTLS; se falhar tenta SSL na 465)", "587"),
    ("smtp", "SMTP_USUARIO", "SMTP_USUARIO", False, "Usuário do SMTP"),
    ("smtp", "SMTP_SENHA", "SMTP_SENHA", True, "Senha do SMTP"),
    ("smtp", "SMTP_DE", "SMTP_DE", False, "Remetente (Nome <email@empresa.com>)"),
    ("smtp", "EMAIL_AGENDADOR", "EMAIL_AGENDADOR", False,
     "Agendador de e-mails: ligado | desligado. Só ligue depois de desligar o agendador do Report antigo (envio em dobro)",
     "desligado"),
]


def pasta() -> Path:
    return catalogo.raiz() / "email"


def definicoes() -> dict:
    arq = pasta() / "emails.json"
    if not arq.is_file():
        return {}
    with open(arq, encoding="utf-8-sig") as f:
        return json.load(f)


def definicao(chave: str) -> dict:
    d = definicoes().get(chave)
    if d is None:
        raise ErroNegocio(f"E-mail '{chave}' não existe em relatorios/email/emails.json.", "EMAIL_NAO_ENCONTRADO", 404)
    return d


# ── Datas dinâmicas ─────────────────────────────────────────────────────────

def resolver_data(valor: str, hoje: date = None) -> str:
    hoje = hoje or date.today()
    if not isinstance(valor, str):
        return valor
    if valor == "HOJE":
        return hoje.isoformat()
    if valor.startswith("HOJE") and valor[4:5] in ("-", "+") and valor[5:].isdigit():
        dias = int(valor[5:])
        return (hoje - timedelta(days=dias) if valor[4] == "-" else hoje + timedelta(days=dias)).isoformat()
    if valor == "MES_INICIO":
        return hoje.replace(day=1).isoformat()
    if valor == "MES_FIM":
        prox = hoje.replace(day=28) + timedelta(days=4)
        return (prox - timedelta(days=prox.day)).isoformat()
    if valor == "MES_ANT_INI":
        return (hoje.replace(day=1) - timedelta(days=1)).replace(day=1).isoformat()
    if valor == "MES_ANT_FIM":
        return (hoje.replace(day=1) - timedelta(days=1)).isoformat()
    return valor


# ── Dados ───────────────────────────────────────────────────────────────────

def _celula(v):
    """Mesma conversão do mailer antigo (os processadores contam com ela): data dd/mm/aaaa, vazio = "",
    DECIMAL continua Decimal."""
    if v is None:
        return ""
    if isinstance(v, (date, datetime)):
        return v.strftime("%d/%m/%Y")
    if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
        return "0"
    return v


def consultar(rel_id: str, filtros: dict) -> list[dict]:
    """Linhas do SQL do relatório (o e-mail usa o schema padrão, como no Report antigo)."""
    sql, params = relatorios.substituir_filtros(catalogo.carregar_sql(rel_id), filtros)
    return hana.consultar(sql, params, converter=_celula)[1]


def gerar_excel(linhas: list[dict]) -> bytes:
    from openpyxl import Workbook  # import pesado só quando há anexo

    wb = Workbook(write_only=True)
    ws = wb.create_sheet("Dados")
    if linhas:
        colunas = list(linhas[0].keys())
        ws.append(colunas)
        for linha in linhas:
            ws.append([None if linha.get(c) == "" else linha.get(c) for c in colunas])
    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _processar(nome: str, linhas: list, definicao_: dict, filtros: dict) -> dict:
    modulo, funcao = nome.rsplit(".", 1)
    caminho = catalogo._dentro(pasta() / "processadores", pasta() / "processadores" / f"{modulo}.py")
    spec = importlib.util.spec_from_file_location(f"processador_{modulo}", caminho)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return getattr(mod, funcao)(linhas, definicao_, filtros)


def renderizar(template: str, contexto: dict) -> str:
    # sem autoescape, como no Report antigo (os templates de e-mail montam HTML a partir do contexto)
    env = Environment(loader=FileSystemLoader(str(pasta() / "templates")))
    return env.get_template(template).render(**contexto)


def montar(chave: str) -> dict:
    """{html, linhas, anexos: [(nome, bytes)], imagens: {cid: caminho}} de um e-mail, com os dados de agora."""
    d = definicao(chave)
    filtros = {k: resolver_data(v) for k, v in (d.get("filtros") or {}).items()}
    linhas = consultar(d["sql"], filtros)
    titulo = d.get("titulo") or chave
    if d.get("processador"):
        contexto = _processar(d["processador"], linhas, {**d, "id": chave}, filtros)
    else:
        ini, fim = filtros.get("data_ini", ""), filtros.get("data_fim", "")
        contexto = {
            "titulo": titulo,
            "periodo": f"{ini} a {fim}" if ini and fim else "",
            "data_geracao": datetime.now().strftime("%d/%m/%Y %H:%M"),
            "subtitulo_tabela": d.get("subtitulo_tabela", ""),
            "kpis": d.get("kpis", []),
            "colunas": d.get("colunas", []),
            "dados": linhas,
        }
    html = renderizar(d["template"], contexto)

    anexos = []
    if d.get("anexo_excel"):
        linhas_anexo = consultar(d["sql_anexo"], filtros) if d.get("sql_anexo") else linhas
        if linhas_anexo:
            data_ref = filtros.get("data_ini") or datetime.now().strftime("%Y-%m-%d")
            anexos.append((f"{titulo} - {data_ref}.xlsx", gerar_excel(linhas_anexo)))
        else:
            log.warning(f"'{chave}': anexo_excel ligado mas a consulta do anexo não trouxe linhas — vai sem anexo.")
    imagens = {cid: str(catalogo._dentro(pasta(), pasta() / caminho)) for cid, caminho in (d.get("imagens_inline") or {}).items()}
    return {"html": html, "linhas": len(linhas), "anexos": anexos, "imagens": imagens}


def previa_html(montado: dict) -> str:
    """HTML para ver na tela: as imagens cid: viram data URI (no e-mail elas vão como anexo inline)."""
    html = montado["html"]
    for cid, caminho in montado["imagens"].items():
        tipo = mimetypes.guess_type(caminho)[0] or "image/png"
        dados = base64.b64encode(Path(caminho).read_bytes()).decode()
        html = html.replace(f"cid:{cid}", f"data:{tipo};base64,{dados}")
    return html


# ── Envio ───────────────────────────────────────────────────────────────────

def smtp() -> dict:
    cfg = {"host": get_config("SMTP_HOST"), "porta": int(get_config("SMTP_PORTA", "587") or 587),
           "usuario": get_config("SMTP_USUARIO"), "senha": get_config("SMTP_SENHA"), "de": get_config("SMTP_DE")}
    if not (cfg["host"] and cfg["usuario"] and cfg["senha"] and cfg["de"]):
        raise ErroNegocio("SMTP não configurado (Configurações → API → E-mail).", "SMTP_NAO_CONFIGURADO", 400)
    return cfg


def enviar(montado: dict, assunto: str, destinatarios: list[str], cfg: dict) -> None:
    de = cfg["de"]
    if "<" in de:
        nome, endereco = de[:de.rfind("<")].strip(), de[de.rfind("<") + 1:].rstrip(">").strip()
        de_formatado = formataddr((str(Header(nome, "utf-8")), endereco))
    else:
        endereco = de_formatado = de

    msg = MIMEMultipart("mixed")
    msg["Subject"] = assunto
    msg["From"] = de_formatado
    msg["To"] = ", ".join(destinatarios)
    corpo = MIMEMultipart("related")
    alternativo = MIMEMultipart("alternative")
    alternativo.attach(MIMEText(montado["html"], "html", "utf-8"))
    corpo.attach(alternativo)
    for cid, caminho in montado["imagens"].items():
        img = MIMEImage(Path(caminho).read_bytes())
        img.add_header("Content-ID", f"<{cid}>")
        img.add_header("Content-Disposition", "inline", filename=Path(caminho).name)
        corpo.attach(img)
    msg.attach(corpo)
    for nome_arquivo, conteudo in montado["anexos"]:
        parte = MIMEApplication(conteudo, _subtype="vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        parte.add_header("Content-Disposition", "attachment", filename=nome_arquivo)
        msg.attach(parte)
    bruto = msg.as_string()

    # STARTTLS na porta configurada; se falhar (sem ser senha errada), SSL na 465 — igual ao Report antigo
    falhas = []
    for porta, metodo in ((cfg["porta"], "STARTTLS"), (465, "SSL")):
        try:
            if metodo == "SSL":
                with smtplib.SMTP_SSL(cfg["host"], porta, context=ssl.create_default_context(), timeout=30) as s:
                    s.login(cfg["usuario"], cfg["senha"])
                    s.sendmail(endereco, destinatarios, bruto)
            else:
                with smtplib.SMTP(cfg["host"], porta, timeout=30) as s:
                    s.ehlo()
                    s.starttls()
                    s.ehlo()
                    s.login(cfg["usuario"], cfg["senha"])
                    s.sendmail(endereco, destinatarios, bruto)
            log.info(f"E-mail enviado para {destinatarios} pela porta {porta}")
            return
        except smtplib.SMTPAuthenticationError:
            raise ErroNegocio("SMTP recusou usuário/senha.", "SMTP_SENHA", 400)
        except Exception as e:
            falhas.append(f":{porta} {e}")
            log.warning(f"SMTP falhou na porta {porta}: {e}")
    raise ErroNegocio("Não foi possível enviar o e-mail: " + "; ".join(falhas), "SMTP_FALHOU", 502)
