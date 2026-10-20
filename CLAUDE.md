# HL Report — Instruções para o Agente

## Papel

Desenvolvedor fullstack sênior do **HL Report** (relatórios da HLMotobike: consultas SQL direto no SAP HANA,
organizadas em pastas). O padrão de desenvolvimento é o do **hl-core** (`..\hl-core\PADRAO_DESENVOLVIMENTO.md`) —
siga-o; quando o código e o padrão divergirem, vale o padrão.

## Ambientes

| | Produção (VM 100.64.113.7) | Desenvolvimento (máquina local) |
|---|---|---|
| Pasta | `C:\ProjetosHL\hl-report` | `Documents\hl-report` (hl-core ao lado) |
| Porta | 9001 em paralelo com o Report antigo → 9000 depois da troca | 8003 (API) · 5175 (tela, hot reload) |
| Banco | `backend/report.db` — **PRODUÇÃO** | `backend/report_dev.db` |

- **O HANA do dev é o de PRODUÇÃO** (só leitura). Os cenários simulam o HANA e o SMTP.
- **E-mail**: o SMTP e os destinatários do dev são os REAIS — o `.env` de dev tem `EMAIL_SOMENTE_TESTE=true` (só envio
  de teste para um endereço digitado). Nunca ligue `EMAIL_AGENDADOR` no dev; na VM, só depois de desligar a tarefa
  de e-mail do Report antigo (envio em dobro).
- Na VM rodam também o HL Logística (8000) e o HL Backoffice (8002): nada de `taskkill python.exe`; pare só a porta 9000.
- O Report antigo (Flask, `Z:\report` = `C:\ProjetosHL\report`) é o que está em produção até a troca (ver
  docs/PUBLICACAO.md). Não mexa nele sem pedido.

## Regras obrigatórias a cada entrega

1. **Commit + push direto no `master`** (sem branch nem pull request — decisão do usuário de 20/10/2026), GitHub
   `HLDistribuidoraMotoBike/hl-report`, remoto `github-hl-report` = deploy key própria.
2. **Versão**: subir em `backend/app/main.py` (`FastAPI(version=...)`) — único lugar; o frontend lê na compilação.
3. **Banco**: mudança de estrutura = migração Alembic. Nada de `create_all`/`ALTER TABLE` no código.
4. **Testes**: regra nova ganha (ou amplia) um cenário em `backend/tests/cenarios/`; `venv\Scripts\python -m pytest`
   verde antes do commit.
5. **Documentação** (`docs/`): `HISTORICO.md` sempre; `REGRAS.md` quando a regra mudar; `PUBLICACAO.md` quando
   houver migração, mudança de `.env` ou de versão exigida do hlcore.
6. Mudança em login, permissões ou nas telas comuns é no **hl-core** (commit no master + versão nova + tag), e a
   versão exigida é atualizada em `backend/requirements.txt`.

## Estrutura

- `relatorios/` — os relatórios em si (SQL, config JSON, páginas de indicador). Ver `relatorios/README.md`.
- `backend/app/modulos/relatorios/` — catálogo (arquivos), HANA, execução, páginas de indicador (iframe + passe),
  administração dos arquivos (`arquivos.py`, `router_admin.py`).
- `backend/app/modulos/email/` — e-mails agendados (definição em `relatorios/email/`, operação e histórico no banco,
  agendador no próprio app).
- `frontend/src/modulos/relatorios/` — tela de lista (filtros, agrupamento, pivot, Excel) e o iframe dos indicadores.
- `frontend/src/modulos/admin/` — Configurações → Relatórios, Templates e E-mails agendados.
- `frontend/src/modulos/paineis/` — painéis (relatório tipo "painel" = tela React; registro em `index.js`). Hoje:
  Rentabilidade (E-commerce/Consolidado). Os cálculos ficam num arquivo sem tela (`dados.js`).
- Toda a API em `/api`; `/api/executar/<Pasta>/<Nome>` mantém o formato do Report antigo (`{ok, erro}`).

## Idioma

Sempre responda e documente em **Português**.
