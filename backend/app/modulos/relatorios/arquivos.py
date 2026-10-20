"""Administração dos arquivos de relatório (só admin): pastas, SQL, configuração e templates.

Grava direto na pasta de relatórios (RELATORIOS_DIR). Em produção, o que for editado pela tela fica DIFERENTE do
git até alguém trazer de volta — por isso toda gravação vai para o log de ações (Admin) e a publicação confere a
diferença antes de copiar (docs/PUBLICACAO.md).
"""
import json
import re
from pathlib import Path

from hlcore.erros import ErroNegocio

from app.modulos.relatorios import catalogo

PROIBIDOS = re.compile(r'[<>:"/\\|?*\x00-\x1f]')
TIPOS_TEMPLATE = ("relatorio", "email")
TIPOS_RELATORIO = ("lista", "indicador", "painel")


def validar_nome(nome: str, oque: str = "Nome") -> str:
    nome = (nome or "").strip()
    if not nome or nome in (".", "..") or PROIBIDOS.search(nome) or nome.endswith("."):
        raise ErroNegocio(f"{oque} inválido: não use / \\ : * ? \" < > | nem deixe em branco.", "NOME_INVALIDO", 400)
    return nome


def _gravar(caminho: Path, texto: str) -> None:
    caminho.parent.mkdir(parents=True, exist_ok=True)
    with open(caminho, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto.replace("\r\n", "\n"))


# ── Árvore ──────────────────────────────────────────────────────────────────

def arvore() -> list[dict]:
    """[{pasta, itens: [{id, nome, auxiliar, tipo, titulo}]}] — inclusive pastas vazias e consultas auxiliares."""
    base = catalogo.pasta_sql()
    if not base.is_dir():
        return []
    pastas = sorted([p.name for p in base.iterdir() if p.is_dir() and not p.name.startswith("_")], key=str.lower)
    if any(base.glob("*.sql")):
        pastas.append(catalogo.GERAL)
    resultado = []
    for pasta in pastas:
        dir_ = base if pasta == catalogo.GERAL else base / pasta
        itens = []
        for nome in sorted([a.stem for a in dir_.glob("*.sql")] + catalogo.paineis(pasta), key=str.lower):
            rel_id = f"{pasta}/{nome}"
            cfg = catalogo.carregar_config(rel_id)
            itens.append({"id": rel_id, "nome": nome, "auxiliar": False, "tipo": cfg.get("tipo", "lista"),
                          "titulo": cfg.get("titulo") or nome})
        if pasta != catalogo.GERAL:
            for sub in sorted(p for p in dir_.iterdir() if p.is_dir() and p.name.startswith("_")):
                for arq in sorted(sub.glob("*.sql"), key=lambda p: p.stem.lower()):
                    itens.append({"id": f"{pasta}/{sub.name}/{arq.stem}", "nome": f"{sub.name}/{arq.stem}",
                                  "auxiliar": True, "tipo": "auxiliar", "titulo": arq.stem})
        resultado.append({"pasta": pasta, "itens": itens})
    return resultado


# ── Pastas ──────────────────────────────────────────────────────────────────

def criar_pasta(nome: str) -> str:
    nome = validar_nome(nome, "Nome da pasta")
    if nome.startswith("_") or nome.lower() == catalogo.GERAL.lower():
        raise ErroNegocio("Nome de pasta reservado (começa com _ ou é 'Geral').", "NOME_INVALIDO", 400)
    destino = catalogo.pasta_sql() / nome
    if destino.exists():
        raise ErroNegocio("Pasta já existe.", "PASTA_EXISTE", 409)
    destino.mkdir(parents=True)
    return nome


def excluir_pasta(nome: str) -> None:
    nome = validar_nome(nome, "Nome da pasta")
    pasta = catalogo.pasta_sql() / nome
    if not pasta.is_dir():
        raise ErroNegocio("Pasta não encontrada.", "PASTA_NAO_ENCONTRADA", 404)
    if any(pasta.iterdir()):
        raise ErroNegocio("A pasta não está vazia: exclua os relatórios antes.", "PASTA_COM_RELATORIOS", 409)
    pasta.rmdir()
    cfg = catalogo.pasta_config() / nome
    if cfg.is_dir() and not any(cfg.iterdir()):
        cfg.rmdir()


# ── SQL + configuração ──────────────────────────────────────────────────────

def _caminhos(rel_id: str) -> tuple[str, Path, Path]:
    pasta, nome = catalogo.separar(rel_id)
    for parte in [pasta, *nome.split("/")]:
        validar_nome(parte)
    rel_id = f"{pasta}/{nome}"
    return rel_id, catalogo._arquivo(catalogo.pasta_sql(), rel_id, ".sql"), \
        catalogo._arquivo(catalogo.pasta_config(), rel_id, ".json")


def ler(rel_id: str) -> dict:
    rel_id, sql, cfg = _caminhos(rel_id)
    if not sql.is_file() and not catalogo.e_painel(rel_id):
        raise ErroNegocio(f"SQL '{rel_id}' não encontrado.", "RELATORIO_NAO_ENCONTRADO", 404)
    config = None
    if cfg.is_file():
        with open(cfg, encoding="utf-8-sig") as f:
            config = json.load(f)
    return {"id": rel_id, "sql": sql.read_text(encoding="utf-8-sig") if sql.is_file() else None, "config": config}


def salvar(rel_id: str, sql: str, config, novo: bool) -> str:
    """Grava o SQL e a configuração (config None = sem arquivo de config: vale o padrão)."""
    rel_id, caminho_sql, caminho_cfg = _caminhos(rel_id)
    pasta = catalogo.pasta_do(rel_id)
    if pasta != catalogo.GERAL and not (catalogo.pasta_sql() / pasta).is_dir():
        raise ErroNegocio(f"Pasta '{pasta}' não existe.", "PASTA_NAO_ENCONTRADA", 404)
    if config is not None and not isinstance(config, dict):
        raise ErroNegocio("A configuração precisa ser um objeto JSON.", "CONFIG_INVALIDA", 400)
    if config and config.get("tipo", "lista") not in TIPOS_RELATORIO:
        raise ErroNegocio("Tipo deve ser 'lista', 'indicador' ou 'painel'.", "CONFIG_INVALIDA", 400)
    painel = bool(config) and config.get("tipo") == "painel"
    existe = caminho_sql.exists() or catalogo.e_painel(rel_id)
    if novo and existe:
        raise ErroNegocio("Já existe um relatório com esse nome.", "RELATORIO_EXISTE", 409)
    if not novo and not existe:
        raise ErroNegocio(f"SQL '{rel_id}' não encontrado.", "RELATORIO_NAO_ENCONTRADO", 404)
    if painel:
        if not config.get("componente"):
            raise ErroNegocio("Painel precisa de 'componente' (a tela React).", "CONFIG_INVALIDA", 400)
    elif not (sql or "").strip():
        raise ErroNegocio("O SQL está vazio.", "SQL_VAZIO", 400)
    if (sql or "").strip():
        _gravar(caminho_sql, sql)
    if config is None:
        if caminho_cfg.exists():
            caminho_cfg.unlink()
    else:
        _gravar(caminho_cfg, json.dumps(config, ensure_ascii=False, indent=2) + "\n")
    return rel_id


def excluir(rel_id: str) -> str:
    rel_id, sql, cfg = _caminhos(rel_id)
    if not sql.is_file() and not catalogo.e_painel(rel_id):
        raise ErroNegocio(f"SQL '{rel_id}' não encontrado.", "RELATORIO_NAO_ENCONTRADO", 404)
    if sql.is_file():
        sql.unlink()
    if cfg.is_file():
        cfg.unlink()
    return rel_id


# ── Templates (páginas de indicador e e-mail) ───────────────────────────────

def pasta_templates(tipo: str) -> Path:
    if tipo not in TIPOS_TEMPLATE:
        raise ErroNegocio("Tipo de template inválido.", "TIPO_INVALIDO", 400)
    return catalogo.pasta_templates() if tipo == "relatorio" else catalogo.raiz() / "email" / "templates"


def _template(tipo: str, nome: str) -> Path:
    nome = validar_nome(nome, "Nome do template")
    if not nome.lower().endswith(".html"):
        nome += ".html"
    base = pasta_templates(tipo)
    return catalogo._dentro(base, base / nome)


def listar_templates(tipo: str) -> list[str]:
    base = pasta_templates(tipo)
    return sorted((p.name for p in base.glob("*.html")), key=str.lower) if base.is_dir() else []


def ler_template(tipo: str, nome: str) -> dict:
    caminho = _template(tipo, nome)
    if not caminho.is_file():
        raise ErroNegocio("Template não encontrado.", "TEMPLATE_NAO_ENCONTRADO", 404)
    return {"nome": caminho.name, "html": caminho.read_text(encoding="utf-8-sig")}


def salvar_template(tipo: str, nome: str, html: str, novo: bool) -> str:
    caminho = _template(tipo, nome)
    if novo and caminho.exists():
        raise ErroNegocio("Já existe um template com esse nome.", "TEMPLATE_EXISTE", 409)
    if not novo and not caminho.exists():
        raise ErroNegocio("Template não encontrado.", "TEMPLATE_NAO_ENCONTRADO", 404)
    _gravar(caminho, html or "")
    return caminho.name


def excluir_template(tipo: str, nome: str) -> str:
    caminho = _template(tipo, nome)
    if not caminho.is_file():
        raise ErroNegocio("Template não encontrado.", "TEMPLATE_NAO_ENCONTRADO", 404)
    caminho.unlink()
    return caminho.name
