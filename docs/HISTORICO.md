# HL Report — Histórico de versões

Registro de cada entrega (o que mudou e por quê). Regras vigentes: [REGRAS.md](REGRAS.md). A versão fica só em
`backend/app/main.py` (`FastAPI(version=...)`).

### 0.7.2 — 21/10/2026 — Ícone azul

Ícone próprio de cada app (pedido do usuário, 21/10): Logística **verde**, Backoffice **vermelho**, Report **azul**, HL Acesso **preto** — `frontend/public/icone.png` (+ `favicon.png`/`favicon.ico` na aba do navegador). Aparece no topo do menu, no login e no trocador ▾ (cada app com o seu), pelo `LogoApp` do kit (hl-core 0.8.2).

### 0.7.1 — 20/10/2026 — Agendador por caixa/botão

Pedido do usuário: "ficou muito ruim ter que escrever Ligado". O agendador de e-mail (`EMAIL_AGENDADOR`) virou caixa
de marcar em Configurações → API → E-mail (hlcore 0.8.1) e a faixa de Configurações → E-mails agendados ganhou o botão
**Ligar/Desligar agendador** (pede um segundo clique para confirmar; some no desenvolvimento, que é só teste).
Importador de e-mails cria as configurações SMTP_* numa instalação nova (achado na publicação de 20/10).
Publicada na VM em 20/10/2026 com a fase 2 (porta 9000; Report antigo e o agendador dele desligados).

### 0.7.0 — 20/10/2026 — Acesso central (HL Acesso)

Pedido do usuário: gestão de acesso num lugar só. Com `ACESSO_URL` no `.env` o Report usa o **HL Acesso** (hlcore
0.7.0): login único, grupos × apps e sessões centrais. O Report registra papéis e **pastas** no HL Acesso ao subir e
avisa na hora quando uma pasta é criada/excluída. Cenário novo `acesso_central` (HL Acesso simulado). Os grupos do
Report vão para o HL Acesso pelo `importar_grupos.py` de lá. Sem `ACESSO_URL`, tudo como antes.

### 0.6.0 — 20/10/2026 — DRE em React (etapa 3 concluída) + filtro de encerramento

Decisões do usuário: migrar a DRE; trocar "Baixar HTML" por **Exportar Excel + Imprimir/PDF**; visual dos apps na tela
com impressão caprichada; encerramento do exercício como filtro.
- `Diretoria/DRE` virou painel React (`componente: "dre"`); mesmas consultas (a de saldos foi para `_dre/Saldos.sql`)
  e a mesma conta, agora em `paineis/dre/dados.js`. **Conferido contra o DRE.html: 2.880 linhas comparadas (3
  períodos × 5 combinações de empresas), zero diferença.**
- Tudo da tela antiga: período (até 24 meses), meses e empresas combináveis, colunas por mês/total, variação,
  ocultar zeradas, R$ ou % da receita, inteiro/milhares, busca, expandir/recolher, detalhe conta → fornecedores →
  lançamentos. **Excel**: árvore com níveis agrupados (+/− do Excel) e aba de parâmetros. **Imprimir/PDF**: A4
  paisagem, só o relatório.
- **Encerramento do exercício** (lançamentos tipo -3 do SAP, "Para o período de encerramento N" — existem para
  2020–2022): fora por padrão (caixa "Excluir encerramento do exercício"). Ex.: jul/22–fev/23 com o encerramento
  dava receita líquida −R$ 5,5 mi; sem ele, R$ 16,3 mi. Vale também no detalhe.
- Saiu o `DRE.html` (pasta `relatorios/templates` ficou vazia — o tipo "indicador" continua suportado).

### 0.5.0 — 20/10/2026 — Simulador sai para o HL Backoffice; HANA no hlcore

- O **Simulador de Preço** (pasta Comercial) foi para o HL Backoffice 0.4.0 — é formulário e vai guardar orçamentos
  (decisão do usuário). Saíram `sql/Comercial`, `config/Comercial` e `templates/Simulador.html`.
- A conexão com o HANA saiu do app e foi para o **hlcore 0.6.0** (`hlcore.integracoes.hana`), compartilhada com o
  Backoffice — mesmo comportamento.

### 0.4.0 — 20/10/2026 — Rentabilidade E-commerce na base nova

Decisão do usuário: a visão **E-commerce** também passa para a `HL_RENTABILIDADE` (a mesma do Consolidado e do
e-mail). As duas visões usam agora uma consulta só (`_rentabilidade/Vendas.sql`, filtro `:canal`); a consulta legada
(~30 s por dia) saiu. Efeitos nos números do E-commerce: sem a regra especial da Amazon e ICMS Presumido como
**crédito** (card próprio, fora do total de impostos) — como já era no Consolidado. 19/10: E-commerce R$ 501.718,84
(= e-mail).

### 0.3.0 — 20/10/2026 — Rentabilidade em React (etapa 3, 1º indicador) + correções

Decisões do usuário: ordem da etapa 3 = Rentabilidade → Simulador (vai para o HL Backoffice: é formulário e vai
guardar modelos da gestora) → DRE; "Rentabilidade Consolidado" = todas as empresas e canais; juntar as duas.
- Tipo novo de relatório **painel**: tela React do app (`config.componente`), definida só pelo config, que consulta
  as fontes do `config.fontes` (subpasta `_nome`, fora do menu). Admin: painel não tem aba SQL.
- **Comercial - Ecommerce → Rentabilidade** (um item só no menu) substitui as páginas RentabilidadeEcommerce.html e
  RentabilidadeConsolidado.html (3.700 linhas quase iguais): visão **E-commerce** (consulta legada, números iguais aos
  de antes) ou **Consolidado**; abas Visão geral, Gráficos, Produtos, Marcas, Notas; detalhe lateral por produto/marca;
  no consolidado, cards e filtro por canal (Atacado em Moto/Bike, como no e-mail).
- **Erros corrigidos**: (1) a página "Rentabilidade Consolidado" consultava a lógica legada do E-commerce — mostrava os
  mesmos números com outro rótulo; (2) a consulta feita para ela (sobre a HL_RENTABILIDADE) filtrava só o
  E-commerce, usava `CONCAT` com 3 argumentos (o HANA recusa — nunca rodou), parâmetros `:dataIni/:dataFim`, só
  TIPO_ORIGEM VENDA e um nome de coluna de impostos que a página não lia (impostos zerados). Agora: todas as empresas
  e canais, mesmo critério do e-mail diário (VENDA + VENDA_100_ESPECIAL) — conferido: 19/10 bate centavo a centavo
  com o e-mail (E-commerce R$ 501.718,84; Atacado R$ 98.689,00); consulta em 0,6 s (a legada do E-commerce leva ~30 s).
- Removidos os modelos sem uso `IndicadorExemplo.html` e `PivotTemplate.html`.

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

Próximas etapas: (2) Admin do Report em React — feita na 0.2.0; (3) indicadores migrados para React, um a um —
Rentabilidade na 0.3.0, Simulador foi para o HL Backoffice (0.5.0), DRE na 0.6.0 — concluída.
