"""Catálogo dos relatórios: arquivos na pasta RELATORIOS_DIR (padrão ..\\relatorios, a do repositório).

    sql/<Pasta>/<Nome>.sql          a consulta (filtros como :nome_do_filtro); sql/<Nome>.sql = pasta "Geral"
    sql/<Pasta>/_<sub>/<Nome>.sql   consultas auxiliares de um indicador (não aparecem no menu; id "Pasta/_sub/Nome")
    config/<Pasta>/<Nome>.json      tipo (lista | indicador), título, filtros, modo pivot, agrupamento, schema...
    templates/<Arquivo>.html        página própria de um relatório do tipo "indicador" (Jinja)

O id de um relatório é "Pasta/Nome" (o mesmo do Report antigo). A pasta é a unidade de permissão: o grupo do
usuário precisa ter a pasta como recurso (admin vê todas).
"""
import json
import os
from pathlib import Path
from typing import Optional

from hlcore.erros import ErroNegocio

BACKEND = Path(__file__).resolve().parents[3]
GERAL = "Geral"

CONFIG_PADRAO = {
    "tipo": "lista", "titulo": "", "filtros": [
        {"id": "data_ini", "label": "Data Inicial", "tipo": "date"},
        {"id": "data_fim", "label": "Data Final", "tipo": "date"},
        {"id": "marca", "label": "Marca", "tipo": "text"},
        {"id": "loja", "label": "Loja", "tipo": "text"},
    ],
}


def raiz() -> Path:
    return Path(os.getenv("RELATORIOS_DIR") or BACKEND.parent / "relatorios").resolve()


def pasta_sql() -> Path:
    return raiz() / "sql"


def pasta_config() -> Path:
    return raiz() / "config"


def pasta_templates() -> Path:
    return raiz() / "templates"


def _dentro(base: Path, caminho: Path) -> Path:
    """Impede sair da pasta dos relatórios com ".." no id."""
    real = caminho.resolve()
    if base.resolve() not in real.parents:
        raise ErroNegocio("Relatório inválido.", "RELATORIO_INVALIDO", 400)
    return real


def separar(rel_id: str) -> tuple[str, str]:
    """("Pasta", "Nome") — sem pasta, "Geral"."""
    partes = (rel_id or "").strip("/").split("/", 1)
    if len(partes) == 2 and partes[0] and partes[1]:
        return partes[0], partes[1]
    return GERAL, partes[0]


def pasta_do(rel_id: str) -> str:
    return separar(rel_id)[0]


def _arquivo(base: Path, rel_id: str, ext: str) -> Path:
    pasta, nome = separar(rel_id)
    if not nome:
        raise ErroNegocio("Relatório inválido.", "RELATORIO_INVALIDO", 400)
    destino = base / f"{nome}{ext}" if pasta == GERAL else base / pasta / f"{nome}{ext}"
    return _dentro(base, destino)


def carregar_sql(rel_id: str) -> str:
    caminho = _arquivo(pasta_sql(), rel_id, ".sql")
    if not caminho.is_file():
        raise ErroNegocio(f"Relatório '{rel_id}' não encontrado.", "RELATORIO_NAO_ENCONTRADO", 404)
    return caminho.read_text(encoding="utf-8-sig")


def existe(rel_id: str) -> bool:
    try:
        return _arquivo(pasta_sql(), rel_id, ".sql").is_file()
    except ErroNegocio:
        return False


def carregar_config(rel_id: str) -> dict:
    caminho = _arquivo(pasta_config(), rel_id, ".json")
    if caminho.is_file():
        with open(caminho, encoding="utf-8-sig") as f:
            cfg = json.load(f)
    else:
        cfg = json.loads(json.dumps(CONFIG_PADRAO))
    if not cfg.get("titulo"):
        cfg["titulo"] = separar(rel_id)[1]
    return cfg


def caminho_template(nome: str) -> Path:
    return _dentro(pasta_templates(), pasta_templates() / Path(nome).name)


def pastas() -> list[str]:
    """Todas as pastas que têm relatório (inclusive "Geral", se houver SQL solto)."""
    base = pasta_sql()
    if not base.is_dir():
        return []
    nomes = [p.name for p in base.iterdir() if p.is_dir() and not p.name.startswith("_")]
    if any(base.glob("*.sql")):
        nomes.append(GERAL)
    return sorted(nomes, key=str.lower)


def listar(permitidas: Optional[set] = None) -> list[dict]:
    """[{pasta, relatorios: [{id, nome, titulo, tipo}]}] — só as pastas permitidas (None = todas)."""
    base = pasta_sql()
    resultado = []
    for pasta in pastas():
        if permitidas is not None and pasta not in permitidas:
            continue
        dir_ = base if pasta == GERAL else base / pasta
        itens = []
        for arq in sorted(dir_.glob("*.sql"), key=lambda p: p.stem.lower()):
            rel_id = f"{pasta}/{arq.stem}"
            cfg = carregar_config(rel_id)
            itens.append({"id": rel_id, "nome": arq.stem, "titulo": cfg.get("titulo") or arq.stem,
                          "tipo": cfg.get("tipo", "lista")})
        if itens:
            resultado.append({"pasta": pasta, "relatorios": itens})
    return resultado
