# HL Report — Histórico de versões

Registro de cada entrega (o que mudou e por quê). Regras vigentes: [REGRAS.md](REGRAS.md). A versão fica só em
`backend/app/main.py` (`FastAPI(version=...)`).

### 0.2.0 — 20/10/2026 — Administração e e-mails agendados (etapa 2)

Usuário testou e aprovou a 0.1.0; etapa 2 do plano:
- **Configurações → Relatórios**: árvore de pastas (com as consultas auxiliares dos indicadores), criar/excluir
  pasta e relatório, editor de SQL, configuração em formulário (título, tipo, página, schema, filtros) + JSON
  avançado para o resto (pivot, agrupamento, chaves dos indicadores) — salvar mantém o arquivo igual quando nada
  mudou (conferido nos 13 configs) —, e **Testar** o SQL do editor antes de salvar (até 200 linhas).
- **Configurações → Templates**: páginas de indicador e modelos de e-mail.
- **E-mails agendados** (vieram do `email_reports` do Report antigo): a DEFINIÇÃO de cada e-mail (consulta,
  modelo, processador, anexo) virou código em `relatorios/email/` (emails.json + templates + processadores + logo);
  a OPERAÇÃO (liga/desliga, horário, dias, destinatários, assunto) fica no banco e se edita na tela, com **prévia**
  (nada é enviado), **envio de teste** para um endereço e **Disparar agora**; histórico de todos os envios.
  HTML idêntico ao do mailer antigo (conferido com o e-mail das 8h de 20/10).
- Agendador dentro do app (1 envio por dia por e-mail, até 30 min depois do horário se o servidor estava parado),
  que **nasce desligado** (`EMAIL_AGENDADOR`, Configurações → API → E-mail): ligar só depois de desligar a tarefa do
  Report antigo — senão o e-mail sai em dobro. `EMAIL_SOMENTE_TESTE=true` no `.env` de desenvolvimento.
- SMTP em Configurações (senha criptografada). Script `importar_email.py` traz o `config.json` antigo.
- Gravações pela tela vão para o log de ações. Migração 0002 (`email_agendamentos`, `email_envios`); dependência
  nova `openpyxl`. Cenários `admin` e `email`.

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

Próximas etapas: (2) Admin do Report em React — feita na 0.2.0; (3) indicadores migrados para React, um a um.
