"""Conexão direta com o SAP HANA (hdbcli) — os relatórios leem o banco do SAP, só leitura.

Dados da conexão em Configurações → API → SAP HANA (na primeira subida vêm do .env). Uma conexão por execução,
fechada no fim (o Report antigo fazia igual; a VM tem pouca memória, nada de pool parado).
"""
import math
from datetime import date, datetime
from decimal import Decimal

from hlcore.configuracoes import get_config

# (grupo, chave, variável do .env, sensível, descrição[, padrão]) — semeadas no startup (app/main.py)
CONFIGURACOES = [
    ("hana", "HANA_HOST", "HANA_HOST", False, "Servidor do SAP HANA (IP ou nome)"),
    ("hana", "HANA_PORT", "HANA_PORT", False, "Porta SQL do HANA", "30015"),
    ("hana", "HANA_USER", "HANA_USER", False, "Usuário do HANA (só leitura)"),
    ("hana", "HANA_PASSWORD", "HANA_PASSWORD", True, "Senha do usuário do HANA"),
    ("hana", "HANA_DATABASE", "HANA_DATABASE", False, "Banco (tenant) do HANA"),
    ("hana", "HANA_SCHEMA", "HANA_SCHEMA", False, "Schema padrão (empresa do SAP) — o relatório pode trocar no config"),
]


def conectar():
    from hdbcli import dbapi  # import pesado só quando executa

    conn = dbapi.connect(
        address=get_config("HANA_HOST"), port=int(get_config("HANA_PORT", "30015") or 30015),
        user=get_config("HANA_USER"), password=get_config("HANA_PASSWORD"),
        databaseName=get_config("HANA_DATABASE") or None,
    )
    schema = get_config("HANA_SCHEMA")
    if schema:
        usar_schema(conn.cursor(), schema, fechar=True)
    return conn


def usar_schema(cursor, schema: str, fechar: bool = False) -> None:
    cursor.execute(f'SET SCHEMA "{schema.replace(chr(34), "")}"')
    if fechar:
        cursor.close()


def valor(v):
    """Valor de uma célula pronto para JSON — a MESMA saída do Report antigo (Flask), da qual as telas dependem:
    DECIMAL do HANA sai como texto ("123.4500"), data em ISO, NaN/infinito viram 0."""
    if v is None:
        return None
    if isinstance(v, (date, datetime)):
        return v.isoformat()
    if isinstance(v, Decimal):
        return str(v)
    if isinstance(v, float):
        if math.isnan(v) or math.isinf(v):
            return 0.0
        return round(v, 10)
    return v


def consultar(sql: str, params: list, schema: str = "", limite: int = 0, converter=valor) -> tuple[list[str], list[dict]]:
    """(colunas, linhas) da consulta. limite > 0 corta as linhas (teste de SQL do admin); converter = conversão de
    cada célula (padrão: a da tela; o e-mail usa a dele)."""
    conn = cursor = None
    try:
        conn = conectar()
        cursor = conn.cursor()
        if schema:
            usar_schema(cursor, schema)
        cursor.execute(sql, params)
        colunas = [d[0] for d in cursor.description] if cursor.description else []
        linhas = cursor.fetchmany(limite) if limite else cursor.fetchall()
        return colunas, [{c: converter(v) for c, v in zip(colunas, linha)} for linha in linhas]
    finally:
        for recurso in (cursor, conn):
            if recurso is not None:
                try:
                    recurso.close()
                except Exception:
                    pass
