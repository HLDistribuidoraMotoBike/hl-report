"""Regras dos relatórios: quem vê o quê e a execução da consulta (mesmo comportamento do Report antigo)."""
import re
from datetime import date, datetime
from typing import Optional

from hlcore.auth import PAPEL_ADMIN
from hlcore.erros import ErroNegocio

from hlcore.integracoes import hana

from app.modulos.relatorios import catalogo


# ── Permissão: a pasta do relatório é o recurso ──────────────────────────────

def pastas_permitidas(user: dict) -> Optional[set]:
    """None = todas (administrador); senão, as pastas que vieram como recurso no login."""
    if user.get("papel") == PAPEL_ADMIN:
        return None
    return set(user.get("recursos") or [])


def pode_ver(user: dict, rel_id: str) -> bool:
    permitidas = pastas_permitidas(user)
    return permitidas is None or catalogo.pasta_do(rel_id) in permitidas


def exigir_acesso(user: dict, rel_id: str) -> None:
    if not pode_ver(user, rel_id):
        raise ErroNegocio("Acesso negado a este relatório.", "SEM_ACESSO", 403)


# ── Execução ────────────────────────────────────────────────────────────────

# Filtros :nome → parâmetros "?" (regra no hlcore; vazio = "")
substituir_filtros = hana.parametros_nomeados


def validar_datas(filtros: dict) -> None:
    for campo in ("data_ini", "data_fim"):
        if filtros.get(campo):
            try:
                datetime.strptime(filtros[campo], "%Y-%m-%d")
            except ValueError:
                raise ErroNegocio(f"'{campo}' deve estar no formato YYYY-MM-DD.", "FILTRO_INVALIDO", 400)
    if filtros.get("data_ini") and filtros.get("data_fim") and filtros["data_ini"] > filtros["data_fim"]:
        raise ErroNegocio("Data inicial maior que data final.", "FILTRO_INVALIDO", 400)


def _mes(offset: int, hoje: Optional[date] = None) -> str:
    d = hoje or date.today()
    mes, ano = d.month - offset, d.year
    while mes <= 0:
        mes += 12
        ano -= 1
    return f"{ano}-{mes:02d}"


def _rotulos_de_mes(colunas: list, linhas: list) -> Optional[dict]:
    """Colunas MES_<n>_LABEL (pivot de meses): vazias recebem "AAAA-MM" de n meses atrás. Devolve os rótulos
    quando não há linha (a tela precisa deles para montar o cabeçalho)."""
    cols = [c for c in colunas if c.startswith("MES_") and c.endswith("_LABEL")]
    if not cols:
        return None
    rotulos = {}
    for c in cols:
        try:
            rotulos[c] = _mes(int(c[4:-6]))
        except ValueError:
            rotulos[c] = c
    for linha in linhas:
        for c in cols:
            if not linha.get(c):
                linha[c] = rotulos[c]
    return rotulos


def executar(rel_id: str, filtros: dict) -> dict:
    """{ok, total, colunas, data[, mes_labels]} — formato que as telas (lista e indicadores) esperam."""
    validar_datas(filtros)
    sql, params = substituir_filtros(catalogo.carregar_sql(rel_id), filtros)
    cfg = catalogo.carregar_config(rel_id)
    colunas, linhas = hana.consultar(sql, params, cfg.get("schema", ""))
    resposta = {"ok": True, "total": len(linhas), "colunas": colunas, "data": linhas}
    rotulos = _rotulos_de_mes(colunas, linhas)
    if rotulos and not linhas:
        resposta["mes_labels"] = rotulos
    return resposta


# ── Teste de SQL (admin) ────────────────────────────────────────────────────

LIMITE_TESTE = 200


def parametros(sql: str) -> list[str]:
    """Nomes dos :filtros usados no SQL (sem repetir, na ordem), ignorando as linhas de comentário."""
    vistos = []
    for linha in sql.splitlines():
        if linha.strip().startswith("--"):
            continue
        for nome in re.findall(r":([a-zA-Z_]+)", linha):
            if nome not in vistos:
                vistos.append(nome)
    return vistos


def testar(sql: str, filtros: dict, schema: str = "") -> dict:
    """Executa um SQL ainda não salvo e devolve só as primeiras linhas."""
    if not (sql or "").strip():
        raise ErroNegocio("O SQL está vazio.", "SQL_VAZIO", 400)
    sql_final, params = substituir_filtros(sql, filtros or {})
    colunas, linhas = hana.consultar(sql_final, params, schema or "", limite=LIMITE_TESTE + 1)
    return {"colunas": colunas, "data": linhas[:LIMITE_TESTE], "cortado": len(linhas) > LIMITE_TESTE}
