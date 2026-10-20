# HL Report — Regras vigentes

Como o sistema funciona **hoje**. O caminho até aqui está no [HISTORICO.md](HISTORICO.md).

## 1. Acesso

- Login pelo Active Directory (hl-core). O usuário entra se algum grupo AD dele estiver cadastrado e ativo em
  **Admin → Grupos**.
- Papéis: **Administrador** (todos os relatórios, Admin e Configurações) e **Usuário** (os relatórios das pastas
  marcadas no grupo). Mais de um grupo: vale o papel mais alto e a soma das pastas.
- **Recurso = pasta de relatórios** (Comercial, Financeiro, Logistica...). A lista de pastas vem dos arquivos —
  pasta nova aparece sozinha em Admin → Grupos.
- Na primeira subida nascem como administradores: **Suporte-hl**, **Domain Admins** (os "acesso total" do Report
  antigo) e **Administradores**. Os grupos do Report antigo vêm do `permissions.json` pelo script
  `scripts/importar_permissoes.py`.
- Sessão: administrador e usuário podem estar logados em vários lugares (o Report antigo não limitava).
- Menu: uma seção por pasta, com os relatórios dela; **trocador de apps** no topo (HL Logística, HL Backoffice).

## 2. Relatórios (`app/modulos/relatorios`, arquivos em `relatorios/`)

- Formato dos arquivos e da configuração: [relatorios/README.md](../relatorios/README.md).
- O servidor confere a pasta em toda chamada (lista, configuração, execução e página): sem a pasta, "Acesso negado".
  Consultas auxiliares (`Pasta/_sub/Nome`) seguem a permissão da pasta.
- Execução: conexão direta com o HANA (Configurações → API → SAP HANA; a senha fica criptografada), uma conexão por
  execução. Resposta igual à do Report antigo: data em ISO, **DECIMAL como texto** ("123.45"), NaN → 0; erro como
  `{ok: false, erro}` (inclusive o texto do erro do HANA). Data inicial maior que a final é recusada.
- **Lista** (tela React): filtros do config, busca em todos os campos, filtro por coluna, ordenação, 100 linhas por
  página, colunas congeladas, modo pivot (meses em colunas, com total) e agrupamento (totais por nível, expandir/
  recolher, total geral), exportação Excel/CSV.
- **Painel** (tela React do app, `config.componente`): definido só pelo config; consulta as fontes do
  `config.fontes` (subpasta `_nome` da mesma pasta, então a permissão é a da pasta). Hoje: Rentabilidade (seção 5).
- **Indicador** (DRE): a página própria em `relatorios/templates/`, aberta num iframe
  dentro do menu. O endereço leva um passe de 12 h válido só para aquela página (só o HTML, sem dados); as chamadas
  da página a `/api` usam o login da tela.

## 3. Administração (`Configurações`, só administrador)

- **Relatórios**: cria/exclui pasta (nome com `_` no começo ou "Geral" é reservado; só exclui pasta vazia) e
  relatório (SQL + configuração; sem configuração vale o padrão). Consulta auxiliar = subpasta `_nome` (fora do
  menu). **Testar** roda o SQL do editor, mesmo sem salvar, e mostra até 200 linhas.
- **Templates**: páginas de indicador (`relatorios/templates`) e modelos de e-mail (`relatorios/email/templates`).
- Tudo grava direto na pasta de relatórios do servidor e vai para o log de ações. Em produção, o que for editado
  pela tela precisa voltar para o git (a publicação confere a diferença antes de copiar).

## 4. E-mails agendados (`app/modulos/email`)

- Definição (código): `relatorios/email/emails.json` — consulta, filtros (datas dinâmicas HOJE, HOJE-n, MES_INICIO...),
  modelo, processador, anexo Excel (`sql_anexo`), imagens. Formato em [relatorios/README.md](../relatorios/README.md).
- Operação (tela Configurações → E-mails agendados): ligado/desligado, horário, dias, destinatários e assunto. Para
  ligar precisa de dias, destinatários e assunto.
- **Agendador**: só envia com `EMAIL_AGENDADOR = ligado` (Configurações → API → E-mail). Um envio agendado por dia
  por e-mail, a partir do horário e até 30 min depois (se o servidor estava parado); envio com erro não repete
  sozinho no mesmo dia (use Disparar agora).
- **Prévia** monta com os dados de agora e não envia. **Envio de teste** vai só para o endereço digitado, com
  "[TESTE]" no assunto. **Disparar agora** vai para os destinatários cadastrados.
- `EMAIL_SOMENTE_TESTE=true` (desenvolvimento): só o envio de teste funciona — o SMTP e os destinatários são os reais.
- Todo envio fica no histórico (quem, quando, tipo, status, linhas, anexo, erro). SMTP: STARTTLS na porta
  configurada; se falhar, SSL na 465.

## 5. Rentabilidade (`Comercial - Ecommerce/Rentabilidade`, painel)

- Fonte única `_rentabilidade/Vendas.sql` sobre a `HL_RENTABILIDADE`, mesmo critério do e-mail diário "Rentabilidade
  Consolidada" (TIPO_ORIGEM VENDA e VENDA_100_ESPECIAL, data de emissão). Visão **E-commerce** = canal E-commerce;
  **Consolidado** = todas as empresas e canais (desde a 0.4.0 as duas na mesma base).
- ICMS Presumido é **crédito** (card próprio, fora dos impostos). Sem regra especial de Amazon. Filtro de marca por
  texto parcial. No Consolidado, o Atacado abre em Moto/Bike pelo setor do vendedor; filtro por canal na tela.
- Margem = receita líquida com crédito ÷ valor anunciado. "Mkp médio" = média simples do markup das linhas.
- Gráficos: 5 maiores por valor anunciado + "Outros". Produtos e Marcas: 50 primeiros (botão "Mostrar todos").

## 6. DRE Diretoria (`Diretoria/DRE`, painel)

- Modelo financeiro do SAP nº 12 (OFRC/FRC1 da PRD): linhas viram árvore, contas penduradas nas linhas; contas fora
  do modelo não entram. Valor = Crédito − Débito (JDT1, data do lançamento). Linhas somam as filhas; fórmulas
  (+/−) na ordem do modelo.
- Empresas (combináveis, ao menos uma): **HL Distribuição** (filiais 1–4 da PRD), **Especial** (base SBO_MATRIZ
  inteira, contas casadas pelo código), **Empresas de serviço** (filiais 6 e 7). Filial 5 da PRD fica fora sempre.
  Configuração em `relatorios/config/Diretoria/DRE.json`.
- Fora: lançamento estornado e o estorno dele (estorno automático entra); **encerramento do exercício** (tipo -3) —
  salvo se a caixa "Excluir encerramento do exercício" for desmarcada.
- Detalhe (clique no valor de uma conta): fornecedores/clientes (só parceiro cadastrado; o resto em "Sem fornecedor";
  sem conta de contrapartida), até 500 na tela (a busca procura em todos); lançamentos com documento, filial,
  histórico da linha e observação (até 2.000).
- Exportar Excel (o que está na tela: meses, empresas, zeradas) e Imprimir/PDF.
