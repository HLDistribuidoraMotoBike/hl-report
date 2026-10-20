# HL Report

Relatórios da HLMotobike: consultas SQL direto no **SAP HANA**, organizadas em pastas, com login pelo Active
Directory e acesso por grupo (cada pasta é um recurso). Substitui o Report antigo em Flask (`C:\ProjetosHL\report`).

- **Backend**: FastAPI + `hlcore` (login AD, grupos, sessões, configurações, auditoria) — `backend/`
- **Frontend**: React + kit `@hl/ui` do hl-core (menu com trocador de apps) — `frontend/`
- **Relatórios**: arquivos em `relatorios/` (SQL + config + páginas de indicador) — ver `relatorios/README.md`

## Executar (desenvolvimento)

Requisitos: Python 3.11, Node 18+, o repositório `hl-core` clonado ao lado deste.

```cmd
cd backend
py -3.11 -m venv venv
venv\Scripts\python -m pip install -e ..\..\hl-core\python -r requirements-dev.txt
copy .env.example .env      (preencher: DATABASE_URL=sqlite:///./report_dev.db, JWT_SECRET, AD, HANA)
cd ..\frontend && npm install
cd .. && start-dev.bat      (API :8003, tela :5175)
```

Testes: `cd backend && venv\Scripts\python -m pytest`.

## Documentação

- [docs/REGRAS.md](docs/REGRAS.md) — como funciona hoje
- [docs/HISTORICO.md](docs/HISTORICO.md) — versões
- [docs/PUBLICACAO.md](docs/PUBLICACAO.md) — instalação e publicação na VM
