"""E-mails agendados: a parte de OPERAÇÃO de cada e-mail (liga/desliga, horário, dias, destinatários, assunto) e o
histórico de envios. A DEFINIÇÃO (consulta, template, processador, anexo) é código: relatorios/email/emails.json."""
from datetime import datetime

from sqlalchemy import JSON, Boolean, Column, DateTime, Integer, String, Text

from hlcore.database import Base


class EmailAgendamento(Base):
    __tablename__ = "email_agendamentos"
    id = Column(Integer, primary_key=True)
    chave = Column(String(80), nullable=False, unique=True)        # = chave no emails.json (id do Report antigo)
    ativo = Column(Boolean, nullable=False, default=False)
    horario = Column(String(5), nullable=False, default="07:00")    # HH:MM
    dias_semana = Column(JSON, nullable=False, default=list)        # ["seg", "ter", ...]
    destinatarios = Column(JSON, nullable=False, default=list)
    assunto = Column(String(300), nullable=False, default="")
    atualizado_em = Column(DateTime, nullable=True)
    atualizado_por = Column(String(200), nullable=True)


class EmailEnvio(Base):
    """`tipo`: agendado (agendador) | manual (Disparar agora) | teste (para um endereço digitado).
    `status`: enviando | ok | erro."""
    __tablename__ = "email_envios"
    id = Column(Integer, primary_key=True)
    chave = Column(String(80), nullable=False, index=True)
    tipo = Column(String(20), nullable=False)
    usuario = Column(String(200), nullable=True)
    inicio = Column(DateTime, nullable=False, default=datetime.now, index=True)
    fim = Column(DateTime, nullable=True)
    status = Column(String(20), nullable=False, default="enviando")
    destinatarios = Column(JSON, nullable=True)
    linhas = Column(Integer, nullable=True)                         # linhas da consulta do corpo
    anexo = Column(String(300), nullable=True)                      # nome do .xlsx anexado
    erro = Column(Text, nullable=True)
