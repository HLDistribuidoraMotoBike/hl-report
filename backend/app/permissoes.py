"""Regras de acesso do HL Report (login, grupos e sessões são do hlcore.acesso).

- Papéis, em ordem de prioridade: admin (todos os relatórios, Admin e Configurações) > usuario (os relatórios das
  pastas marcadas no grupo).
- Recursos: um por PASTA de relatórios ("Financeiro", "Comercial - Ecommerce"...). A lista vem do servidor
  (GET /api/relatorios/pastas) — criar uma pasta nova cria um recurso novo.
- Sessão: admin e usuário podem estar em vários lugares (relatório é consulta; no Report antigo não havia limite).
"""
from hlcore.acesso import Permissoes

PAPEIS = ("admin", "usuario")
# Grupos que já nascem cadastrados: os de "acesso total" do Report antigo (permissions.json) + Administradores (padrão
# dos apps HL; é o grupo do login local de desenvolvimento). O resto vem do script scripts/importar_permissoes.py ou o
# admin cadastra em Admin → Grupos.
GRUPOS_INICIAIS = (("Suporte-hl", "admin"), ("Domain Admins", "admin"), ("Administradores", "admin"))

ROTULOS = [
    {"value": "admin", "label": "Administrador", "cor": "#6c5ce7", "bg": "#f0eeff",
     "ajuda": "Todos os relatórios, Admin e Configurações (SQL, templates, e-mails agendados)"},
    {"value": "usuario", "label": "Usuário", "cor": "#00b894", "bg": "#e8faf5", "ajuda": "Os relatórios das pastas marcadas"},
]


def recursos() -> list[dict]:
    """Cada pasta de relatórios é um recurso (lista viva: pasta nova = recurso novo)."""
    from app.modulos.relatorios import catalogo
    return [{"key": p, "label": p, "desc": f"Relatórios da pasta {p}"} for p in catalogo.pastas()]


# rótulos e pastas também vão para o HL Acesso (acesso central) — no startup e ao criar/excluir pasta
PERMISSOES = Permissoes(papeis=PAPEIS, sessao={"usuario": "multipla"}, rotulos=ROTULOS, catalogo=recursos)
