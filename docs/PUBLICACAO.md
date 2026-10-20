# HL Report — Publicação na VM

VM `100.64.113.7`, pasta `C:\ProjetosHL\hl-report` (compartilhada como `\\100.64.113.7\ProjetosHL\hl-report`),
tarefa agendada **"HL Report HLMotobike"** (conta SYSTEM). Na mesma VM: HL Logística (8000), HL Backoffice (8002) e o
**Report antigo** (Flask, `C:\ProjetosHL\report`, porta 9000) — nunca use `taskkill python.exe`.

## Regras

- **Código e relatórios**: o GitHub guarda (tag `vX.Y.Z` em cada publicação). Antes de publicar, confira que a VM
  está igual à última tag publicada — se não estiver, alguém mexeu direto na VM: pare e avise.
- **Banco**: `python migrar.py` faz o backup automático (só quando há migração) em `BACKUP_DIR`. O banco guarda só
  login, grupos, configurações e log — os relatórios são arquivos (`relatorios\`).
- **hlcore**: a versão exigida está no comentário do `backend/requirements.txt`.

## Fase 1 — instalar em paralelo (porta 9001)

O Report antigo continua na 9000 (e o agendador de e-mail dele continua rodando da pasta antiga — **não apagar
`C:\ProjetosHL\report`** até a etapa 2 trazer o e-mail).

1. **Antes de copiar**, conferir se o Report antigo mudou depois de 20/10/2026 (SQL/config/template novos ou
   editados pelo Admin dele): comparar `C:\ProjetosHL\report\sql`, `report_config` e `report_template` com
   `relatorios\sql`, `config` e `templates` do repositório. Diferença = trazer para o git primeiro.
2. Criar `C:\ProjetosHL\hl-report` e copiar: `backend\` (sem `venv`, `.env`, `*.db`, `tests\`, `logs\`),
   `relatorios\`, `frontend\dist\` (compilado no desenvolvimento: `cd frontend && npx vite build`) e os `.bat`/`.ps1`.
3. Na VM, `backend\`: `py -3.11 -m venv venv` e `venv\Scripts\python -m pip install -r requirements.txt`.
4. **hlcore**: no desenvolvimento, no `hl-core` na tag exigida, `cd python && <python> -m pip wheel . --no-deps -w dist`;
   copiar o `.whl` para `C:\ProjetosHL\_pacotes\` e `venv\Scripts\python -m pip install C:\ProjetosHL\_pacotes\hlcore-<versão>-py3-none-any.whl`.
5. `backend\.env` a partir do `.env.example`: `DATABASE_URL=sqlite:///./report.db`, **JWT_SECRET próprio**,
   `ALLOW_LOCAL_AUTH=false`, AD, `BACKUP_DIR=C:\ProjetosHL\_backups` e o HANA (os mesmos `HANA_*` do `.env` do
   Report antigo).
6. `venv\Scripts\python migrar.py` (cria o banco).
7. **Permissões**: `venv\Scripts\python scripts\importar_permissoes.py C:\ProjetosHL\report\permissions.json`
   (confere) e de novo com `--executar` (grava).
8. Firewall da VM: liberar a porta **9001** (entrada, TCP) para a rede interna.
9. `instalar-tarefa.ps1` como Administrador (o `start-service.bat` já vem com `PORTA=9001`).
10. Conferir: `http://100.64.113.7:9001/api/health` (cabeçalho `X-App-Versao`), `logs\service.log`, login com
    usuário de rede, abrir uma lista e cada indicador (DRE, Rentabilidade E-commerce/Consolidado, Simulador).
11. Nos outros apps, Configurações → API → Atalhos: `APP_REPORT` = `http://100.64.113.7:9001` durante o teste.

## Fase 2 — troca (porta 9000)

1. Parar o Report antigo (só o processo da porta 9000 — ver como ele é iniciado na VM; o agendador de e-mail é
   outra tarefa e **continua**).
2. `start-service.bat` e `parar-servico.bat`: `PORTA=9000`; parar e iniciar a tarefa "HL Report HLMotobike".
3. Firewall: a 9000 já está liberada (era do Report antigo); a 9001 pode ser fechada.
4. Atalhos nos outros apps de volta para `http://100.64.113.7:9000`.

## Publicações seguintes

1. Conferir a VM = última tag publicada.
2. Parar o serviço (`parar-servico.bat`).
3. Copiar os arquivos alterados do `backend\` e de `relatorios\`, e o `frontend\dist\` inteiro (substituir).
4. Se o `requirements.txt` exigir outra versão do hlcore, instalar o wheel novo (passo 4 da fase 1).
5. `venv\Scripts\python migrar.py` (backup + migrações; sem migração não faz nada).
6. Iniciar a tarefa; conferir `/api/health`. Quem estava com a tela aberta vê "Nova versão disponível — Recarregar".
7. Tag `vX.Y.Z` no commit publicado e entrada no [HISTORICO.md](HISTORICO.md).

Só SQL/config/página de relatório mudou? Basta copiar o arquivo para `relatorios\` — o app lê a cada execução, sem
reiniciar.
