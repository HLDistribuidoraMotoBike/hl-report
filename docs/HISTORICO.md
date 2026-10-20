# HL Report — Histórico de versões

Registro de cada entrega (o que mudou e por quê). Regras vigentes: [REGRAS.md](REGRAS.md). A versão fica só em
`backend/app/main.py` (`FastAPI(version=...)`).

### 0.1.0 — 20/10/2026 — Report no padrão dos apps HL

Decisão do usuário: padronizar o Report (Flask + Jinja, `C:\ProjetosHL\report`) no padrão FastAPI + React sobre o
hl-core, como HL Logística e HL Backoffice. Etapa 1 de 3:
- Login AD, grupos, sessões, Admin e Configurações do hl-core; **cada pasta de relatórios é um recurso**; script
  `importar_permissoes.py` traz o `permissions.json` (acesso total → administrador).
- Relatórios continuam em arquivos — agora **no git** (`relatorios/`: 24 SQL, 13 configs, 6 páginas copiados do
  Report antigo em 20/10; ficaram fora 2 arquivos de dados soltos `asdf`/`asf` da pasta Comercial - Ecommerce).
- `/api/executar` com a mesma resposta do Flask (as páginas de indicador não mudaram).
- Tela de **lista** reescrita em React (tudo do ListTemplate: filtros, busca, ordenação, congeladas, pivot,
  agrupamento, Excel/CSV), no visual do kit.
- **Indicadores** (DRE, Rentabilidade E-commerce/Consolidado, Simulador) abertos com a página própria num iframe
  dentro do menu, com passe e o login da tela nas chamadas.
- Conexão HANA em Configurações → API → SAP HANA. hlcore 0.5.1. Cenários `app` e `relatorios`.

Próximas etapas: (2) Admin do Report em React — pastas, editor de SQL com teste, config, templates e o e-mail
agendado (`scheduler.py`/`mailer.py`) para o repositório; (3) indicadores migrados para React, um a um.
