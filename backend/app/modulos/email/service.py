"""Regras dos e-mails agendados: cadastro de operação, envio (agendado, manual, teste), prévia e o agendador."""
import asyncio
import logging
import os
import re
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from hlcore.configuracoes import get_config
from hlcore.database import SessionLocal
from hlcore.erros import ErroNegocio

from app.modulos.email import mailer
from app.modulos.email.models import EmailAgendamento, EmailEnvio

log = logging.getLogger("email")

DIAS = ("seg", "ter", "qua", "qui", "sex", "sab", "dom")   # índice = datetime.weekday()
JANELA_MINUTOS = 30          # depois do horário, o agendador ainda envia (servidor reiniciado, por exemplo)
INTERVALO_SEGUNDOS = 30
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def somente_teste() -> bool:
    """EMAIL_SOMENTE_TESTE=true no .env (desenvolvimento): nada vai para os destinatários cadastrados — só o envio de
    teste, para um endereço digitado. O SMTP e os destinatários do dev são os REAIS."""
    return os.getenv("EMAIL_SOMENTE_TESTE", "false").strip().lower() == "true"


# ── Cadastro ────────────────────────────────────────────────────────────────

def sincronizar(db: Session) -> None:
    """Cada e-mail do emails.json ganha sua linha de operação (nasce DESLIGADO)."""
    existentes = {a.chave for a in db.query(EmailAgendamento).all()}
    for chave, d in mailer.definicoes().items():
        if chave not in existentes:
            db.add(EmailAgendamento(chave=chave, ativo=False, horario="07:00", dias_semana=list(DIAS[:5]),
                                    destinatarios=[], assunto=d.get("titulo") or chave))
    db.commit()


def _ultimo_envio(db: Session, chave: str) -> Optional[dict]:
    e = db.query(EmailEnvio).filter(EmailEnvio.chave == chave).order_by(EmailEnvio.id.desc()).first()
    return _envio(e) if e else None


def _envio(e: EmailEnvio) -> dict:
    return {"id": e.id, "chave": e.chave, "tipo": e.tipo, "usuario": e.usuario, "inicio": e.inicio, "fim": e.fim,
            "status": e.status, "destinatarios": e.destinatarios or [], "linhas": e.linhas, "anexo": e.anexo,
            "erro": e.erro}


def listar(db: Session) -> dict:
    sincronizar(db)
    defs = mailer.definicoes()
    itens = []
    for a in db.query(EmailAgendamento).order_by(EmailAgendamento.chave).all():
        d = defs.get(a.chave)
        itens.append({
            "chave": a.chave, "titulo": (d or {}).get("titulo") or a.chave, "definido": d is not None,
            "ativo": a.ativo, "horario": a.horario, "dias_semana": a.dias_semana or [],
            "destinatarios": a.destinatarios or [], "assunto": a.assunto,
            "atualizado_em": a.atualizado_em, "atualizado_por": a.atualizado_por,
            "definicao": d, "ultimo_envio": _ultimo_envio(db, a.chave),
        })
    return {"agendador_ligado": agendador_ligado(), "somente_teste": somente_teste(), "agendamentos": itens}


def _validar_destinatarios(lista: list[str]) -> list[str]:
    limpos = []
    for e in lista or []:
        e = (e or "").strip()
        if not e:
            continue
        if not EMAIL_RE.match(e):
            raise ErroNegocio(f"E-mail inválido: {e}", "EMAIL_INVALIDO", 400)
        if e.lower() not in (x.lower() for x in limpos):
            limpos.append(e)
    return limpos


def atualizar(db: Session, chave: str, dados: dict, usuario: str) -> dict:
    a = db.query(EmailAgendamento).filter(EmailAgendamento.chave == chave).first()
    if not a:
        raise ErroNegocio("E-mail não encontrado.", "EMAIL_NAO_ENCONTRADO", 404)
    horario = (dados.get("horario") or "").strip()
    if not re.match(r"^([01]\d|2[0-3]):[0-5]\d$", horario):
        raise ErroNegocio("Horário inválido (HH:MM).", "HORARIO_INVALIDO", 400)
    dias = [d for d in DIAS if d in (dados.get("dias_semana") or [])]
    destinatarios = _validar_destinatarios(dados.get("destinatarios"))
    assunto = (dados.get("assunto") or "").strip()
    ativo = bool(dados.get("ativo"))
    if ativo and not (dias and destinatarios and assunto):
        raise ErroNegocio("Para ligar, informe dias, destinatários e assunto.", "AGENDAMENTO_INCOMPLETO", 400)
    if ativo and chave not in mailer.definicoes():
        raise ErroNegocio("Este e-mail não está mais no emails.json — não dá para ligar.", "EMAIL_NAO_ENCONTRADO", 400)
    a.ativo, a.horario, a.dias_semana, a.destinatarios, a.assunto = ativo, horario, dias, destinatarios, assunto
    a.atualizado_em, a.atualizado_por = datetime.now(), usuario
    db.commit()
    return {"chave": chave}


def historico(db: Session, chave: Optional[str], limite: int) -> list[dict]:
    q = db.query(EmailEnvio)
    if chave:
        q = q.filter(EmailEnvio.chave == chave)
    return [_envio(e) for e in q.order_by(EmailEnvio.id.desc()).limit(limite).all()]


# ── Prévia e envio ──────────────────────────────────────────────────────────

def previa(chave: str) -> dict:
    montado = mailer.montar(chave)
    return {"html": mailer.previa_html(montado), "linhas": montado["linhas"],
            "anexos": [nome for nome, _ in montado["anexos"]]}


def enviar(chave: str, tipo: str, usuario: str, destinatarios: Optional[list[str]] = None) -> dict:
    """Monta e envia agora, registrando no histórico. tipo manual = destinatários cadastrados; teste = os informados."""
    db = SessionLocal()
    try:
        a = db.query(EmailAgendamento).filter(EmailAgendamento.chave == chave).first()
        if not a:
            raise ErroNegocio("E-mail não encontrado.", "EMAIL_NAO_ENCONTRADO", 404)
        if tipo != "teste" and somente_teste():
            raise ErroNegocio("Este ambiente só faz envio de teste (EMAIL_SOMENTE_TESTE no .env).", "SOMENTE_TESTE", 400)
        para = _validar_destinatarios(destinatarios) if tipo == "teste" else (a.destinatarios or [])
        if not para:
            raise ErroNegocio("Sem destinatários.", "SEM_DESTINATARIOS", 400)
        assunto = a.assunto or chave
        if tipo == "teste":
            assunto = f"[TESTE] {assunto}"
        envio = EmailEnvio(chave=chave, tipo=tipo, usuario=usuario, destinatarios=para, status="enviando")
        db.add(envio)
        db.commit()
        return _executar(db, envio, assunto, para)
    finally:
        db.close()


def _executar(db: Session, envio: EmailEnvio, assunto: str, para: list[str]) -> dict:
    try:
        cfg = mailer.smtp()
        montado = mailer.montar(envio.chave)
        envio.linhas = montado["linhas"]
        envio.anexo = ", ".join(nome for nome, _ in montado["anexos"]) or None
        mailer.enviar(montado, assunto, para, cfg)
        envio.status = "ok"
    except ErroNegocio as e:
        envio.status, envio.erro = "erro", e.erro
    except Exception as e:
        log.exception(f"Falha no e-mail '{envio.chave}'")
        envio.status, envio.erro = "erro", str(e)[:2000]
    envio.fim = datetime.now()
    db.commit()
    return _envio(envio)


# ── Agendador ───────────────────────────────────────────────────────────────

def agendador_ligado() -> bool:
    return (get_config("EMAIL_AGENDADOR", "desligado") or "").strip().lower() == "ligado"


def pendentes(db: Session, agora: datetime) -> list[EmailAgendamento]:
    """Agendamentos ligados cujo horário de hoje já chegou (até JANELA_MINUTOS depois) e que ainda não têm envio
    agendado hoje — um envio por dia por e-mail, mesmo que o servidor reinicie."""
    hoje = DIAS[agora.weekday()]
    inicio_dia = agora.replace(hour=0, minute=0, second=0, microsecond=0)
    devidos = []
    for a in db.query(EmailAgendamento).filter(EmailAgendamento.ativo == True).all():  # noqa: E712
        if hoje not in (a.dias_semana or []):
            continue
        h, m = map(int, a.horario.split(":"))
        hora = inicio_dia.replace(hour=h, minute=m)
        if not (hora <= agora < hora + timedelta(minutes=JANELA_MINUTOS)):
            continue
        ja = db.query(EmailEnvio).filter(EmailEnvio.chave == a.chave, EmailEnvio.tipo == "agendado",
                                         EmailEnvio.inicio >= inicio_dia).first()
        if not ja:
            devidos.append(a)
    return devidos


def rodar_agendados(agora: Optional[datetime] = None) -> int:
    """Uma rodada do agendador (síncrona). Devolve quantos e-mails tentou enviar."""
    if not agendador_ligado() or somente_teste():
        return 0
    agora = agora or datetime.now()
    db = SessionLocal()
    try:
        enviados = 0
        for a in pendentes(db, agora):
            envio = EmailEnvio(chave=a.chave, tipo="agendado", usuario="agendador", inicio=agora,
                               destinatarios=a.destinatarios, status="enviando")
            db.add(envio)
            db.commit()   # grava ANTES de enviar: outra rodada não envia de novo
            log.info(f"Agendador: enviando '{a.chave}'")
            _executar(db, envio, a.assunto or a.chave, a.destinatarios or [])
            enviados += 1
        return enviados
    finally:
        db.close()


async def agendador() -> None:
    """Laço do agendador (uma tarefa no processo do app; 1 worker na VM = um agendador só)."""
    while True:
        try:
            await asyncio.to_thread(rodar_agendados)
        except Exception:
            log.exception("Agendador de e-mail: falha na rodada")
        await asyncio.sleep(INTERVALO_SEGUNDOS)
