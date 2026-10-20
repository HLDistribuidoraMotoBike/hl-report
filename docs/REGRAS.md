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
- **Indicador** (DRE, Rentabilidade, Simulador...): a página própria em `relatorios/templates/`, aberta num iframe
  dentro do menu. O endereço leva um passe de 12 h válido só para aquela página (só o HTML, sem dados); as chamadas
  da página a `/api` usam o login da tela.
