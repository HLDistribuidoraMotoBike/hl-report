"""Importa o e-mail agendado do Report antigo (email_reports/config.json) para o HL Report.

    cd backend
    venv\\Scripts\\python scripts\\importar_email.py <config.json> [--executar]

- cada relatório → email_agendamentos (ativo, horário, dias, destinatários, assunto) — só os que existem no
  relatorios/email/emails.json (a definição veio para o git em 20/10/2026);
- smtp → Configurações (SMTP_HOST, SMTP_PORTA, SMTP_USUARIO, SMTP_SENHA criptografada, SMTP_DE).
O agendador continua DESLIGADO (EMAIL_AGENDADOR): ligar só depois de desligar a tarefa do Report antigo.
Sem --executar só mostra o que faria (sem a senha).
"""
import json
import os
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import hlcore  # noqa: E402,F401  (lê o .env)

os.environ.setdefault("DATABASE_URL", "sqlite:///./report.db")

from hlcore import configuracoes  # noqa: E402
from hlcore.configuracoes import encrypt  # noqa: E402
from hlcore.database import SessionLocal  # noqa: E402
from hlcore.modelos import Configuracao  # noqa: E402

from app.modulos.email import mailer  # noqa: E402
from app.modulos.email.models import EmailAgendamento  # noqa: E402
from app.modulos.email.service import DIAS, sincronizar  # noqa: E402

SMTP = {"host": "SMTP_HOST", "port": "SMTP_PORTA", "usuario": "SMTP_USUARIO", "senha": "SMTP_SENHA", "de": "SMTP_DE"}


def importar(arquivo: str, executar: bool) -> list[str]:
    with open(arquivo, encoding="utf-8-sig") as f:
        antigo = json.load(f)
    defs = mailer.definicoes()
    linhas = []
    if executar:
        configuracoes.semear(mailer.CONFIGURACOES)   # instalação nova: o app ainda não subiu para criar as chaves SMTP_*
    db = SessionLocal()
    try:
        sincronizar(db)
        for r in antigo.get("relatorios", []):
            chave = r.get("id")
            if chave not in defs:
                linhas.append(f"PULA     {chave}: não está no emails.json")
                continue
            dados = {"ativo": bool(r.get("ativo", True)), "horario": r.get("horario", "08:00"),
                     "dias_semana": [d for d in DIAS if d in (r.get("dias_semana") or [])],
                     "destinatarios": [e.strip() for e in r.get("destinatarios", []) if e.strip()],
                     "assunto": r.get("assunto") or defs[chave].get("titulo") or chave}
            linhas.append(f"e-mail   {chave}: {'ligado' if dados['ativo'] else 'desligado'} {dados['horario']} "
                          f"{','.join(dados['dias_semana'])} — {len(dados['destinatarios'])} destinatário(s)")
            if executar:
                a = db.query(EmailAgendamento).filter(EmailAgendamento.chave == chave).one()
                for campo, valor in dados.items():
                    setattr(a, campo, valor)
                a.atualizado_em, a.atualizado_por = datetime.now(), "importação do Report antigo"
        for campo, chave in SMTP.items():
            valor = str((antigo.get("smtp") or {}).get(campo) or "")
            if not valor:
                continue
            linhas.append(f"smtp     {chave} = {'(senha)' if campo == 'senha' else valor}")
            if executar:
                cfg = db.query(Configuracao).filter(Configuracao.chave == chave).one()
                cfg.valor = encrypt(valor) if cfg.sensivel else valor
                cfg.atualizado_em, cfg.atualizado_por = datetime.now(), "importação do Report antigo"
        if executar:
            db.commit()
    finally:
        db.close()
    return linhas


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    executar = "--executar" in sys.argv
    for linha in importar(sys.argv[1], executar):
        print(linha)
    print("\nGravado. O agendador segue DESLIGADO (Configurações → API → E-mail)." if executar
          else "\nSimulação — rode com --executar para gravar.")
