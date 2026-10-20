"""Importa as permissões do Report antigo (permissions.json) para os grupos do HL Report.

    cd backend
    venv\\Scripts\\python scripts\\importar_permissoes.py <permissions.json> [--executar]

- "acesso_total" (Domain Admins, Suporte-hl...) → papel admin;
- "grupos": {"Grupo-AD": ["Pasta", ...]} → papel usuario, recursos = as pastas.
Sem --executar só mostra o que faria. Grupo que já existe é ATUALIZADO (papel e recursos do arquivo); os demais
grupos cadastrados não mudam.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import hlcore  # noqa: E402,F401  (lê o .env)

os.environ.setdefault("DATABASE_URL", "sqlite:///./report.db")

from hlcore.database import SessionLocal  # noqa: E402
from hlcore.modelos import GrupoPermissao  # noqa: E402


def planejar(perms: dict) -> dict:
    """{nome do grupo: (papel, recursos)} — admin vence se o grupo estiver nos dois lugares."""
    plano = {nome: ("usuario", sorted(set(pastas))) for nome, pastas in (perms.get("grupos") or {}).items()}
    for nome in perms.get("acesso_total") or []:
        plano[nome] = ("admin", [])
    return plano


def importar(arquivo: str, executar: bool) -> list:
    with open(arquivo, encoding="utf-8-sig") as f:
        plano = planejar(json.load(f))
    db = SessionLocal()
    linhas = []
    try:
        for nome, (papel, recursos) in sorted(plano.items()):
            g = db.query(GrupoPermissao).filter(GrupoPermissao.nome == nome).first()
            acao = "cria" if g is None else "atualiza"
            linhas.append(f"{acao:8} {nome:25} {papel:8} {', '.join(recursos) or '(todas as pastas)'}")
            if not executar:
                continue
            if g is None:
                db.add(GrupoPermissao(nome=nome, papel=papel, recursos=recursos, ativo=True))
            else:
                g.papel, g.recursos, g.ativo = papel, recursos, True
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
    print("\nGravado." if executar else "\nSimulação — rode com --executar para gravar.")
