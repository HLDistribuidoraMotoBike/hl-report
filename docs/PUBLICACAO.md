# HL Report — Publicação na VM

VM `100.64.113.7`, pasta `C:\ProjetosHL\hl-report` (compartilhada como `\\100.64.113.7\ProjetosHL\hl-report`),
tarefa agendada **"HL Report HLMotobike"** (conta SYSTEM). Na mesma VM: HL Logística (8000), HL Backoffice (8002) e o
**Report antigo** (Flask, `C:\ProjetosHL\report`, porta 9000) — nunca use `taskkill python.exe`.

## Regras

- **Código e relatórios**: o GitHub guarda (tag `vX.Y.Z` em cada publicação). Antes de publicar, confira que a VM
  está igual à última tag publicada — se não estiver, alguém mexeu direto na VM (ou editou pela tela
  Configurações → Relatórios/Templates): traga para o git antes de copiar por cima.
- **Banco**: `python migrar.py` faz o backup automático (só quando há migração) em `BACKUP_DIR`. O banco guarda
  login, grupos, configurações, os agendamentos/histórico de e-mail e o log — os relatórios são arquivos.
- **hlcore**: a versão exigida está no comentário do `backend/requirements.txt`.
- **E-mail**: só UM agendador pode estar ligado (o do Report antigo OU o do app novo) — senão o e-mail sai em dobro.

## Fase 1 — instalar em paralelo (porta 9001)

O Report antigo continua na 9000 e o **agendador de e-mail dele continua enviando** (tarefa "HLMotobike - Agendador
de Relatorios Email", da pasta antiga) — **não apagar `C:\ProjetosHL\report`**. No app novo o agendador fica
DESLIGADO até a fase 2.

1. **Antes de copiar**, conferir se o Report antigo mudou depois de 20/10/2026 (SQL/config/template novos ou
   editados pelo Admin dele): comparar `C:\ProjetosHL\report\sql`, `report_config`, `report_template` e
   `email_reports\templates`, `processors`, `assets` com `relatorios\sql`, `config`, `templates` e `email\` do
   repositório. Diferença = trazer para o git primeiro.
2. Criar `C:\ProjetosHL\hl-report` e copiar: `backend\` (sem `venv`, `.env`, `*.db`, `tests\`, `logs\`),
   `relatorios\`, `frontend\dist\` (compilado no desenvolvimento: `cd frontend && npx vite build`) e os `.bat`/`.ps1`.
3. Na VM, `backend\`: `py -3.11 -m venv venv` e `venv\Scripts\python -m pip install -r requirements.txt`.
4. **hlcore**: no desenvolvimento, no `hl-core` na tag exigida, `cd python && <python> -m pip wheel . --no-deps -w dist`;
   copiar o `.whl` para `C:\ProjetosHL\_pacotes\` e `venv\Scripts\python -m pip install C:\ProjetosHL\_pacotes\hlcore-<versão>-py3-none-any.whl`.
5. `backend\.env` a partir do `.env.example`: `DATABASE_URL=sqlite:///./report.db`, **JWT_SECRET próprio**,
   `ALLOW_LOCAL_AUTH=false`, AD, `BACKUP_DIR=C:\ProjetosHL\_backups`, o HANA (os mesmos `HANA_*` do `.env` do
   Report antigo) e `EMAIL_SOMENTE_TESTE=false`.
6. `venv\Scripts\python migrar.py` (cria o banco).
7. **Permissões**: `venv\Scripts\python scripts\importar_permissoes.py C:\ProjetosHL\report\permissions.json`
   (confere) e de novo com `--executar` (grava).
8. **E-mail**: `venv\Scripts\python scripts\importar_email.py C:\ProjetosHL\report\email_reports\config.json`
   (confere) e com `--executar` (grava agendamentos e SMTP; o agendador continua desligado).
9. Firewall da VM: liberar a porta **9001** (entrada, TCP) para a rede interna.
10. `instalar-tarefa.ps1` como Administrador (o `start-service.bat` já vem com `PORTA=9001`).
11. Conferir: `http://100.64.113.7:9001/api/health` (cabeçalho `X-App-Versao`), `logs\service.log`, login com
    usuário de rede, abrir uma lista, a Rentabilidade (E-commerce/Consolidado) e a DRE,
    Configurações → E-mails agendados: **Prévia** e **Enviar teste** para você (faixa amarela = agendador desligado).
12. Nos outros apps, Configurações → API → Atalhos: `APP_REPORT` = `http://100.64.113.7:9001` durante o teste.

## Fase 2 — troca (porta 9000)

1. Parar o Report antigo (só o processo da porta 9000 — ver como ele é iniciado na VM).
2. **E-mail** (fora dos horários de envio — hoje 7h e 8h):
   - desligar a tarefa antiga: `Disable-ScheduledTask -TaskName "HLMotobike - Agendador de Relatorios Email"` e
     encerrar o processo dela (pythonw do `scheduler.py`);
   - se o `email_reports\config.json` antigo mudou depois da importação, importar de novo (`--executar`);
   - no app novo: Configurações → E-mails agendados → botão **Ligar agendador** (ou a caixa em Configurações → API → E-mail); conferir a faixa verde em
     Configurações → E-mails agendados e, no dia seguinte, o histórico de envios.
3. `start-service.bat` e `parar-servico.bat`: `PORTA=9000`; parar e iniciar a tarefa "HL Report HLMotobike".
4. Firewall: a 9000 já está liberada (era do Report antigo); a 9001 pode ser fechada.
5. Atalhos nos outros apps de volta para `http://100.64.113.7:9000`.
6. Depois de alguns dias sem problema, arquivar `C:\ProjetosHL\report` (fica como backup; não apagar).

## Por versão

- **0.7.1**: exige **hlcore 0.8.1** (wheel novo: caixa Ligado/Desligado); sem migração.
- **0.7.0**: exige **hlcore 0.7.0**; sem migração. Para ligar ao HL Acesso (publicado antes — `hl-core/acesso/PUBLICACAO.md`):
  `ACESSO_URL`, `ACESSO_URL_INTERNA`, `ACESSO_APP`, `ACESSO_SEGREDO`, `APP_URL` no `.env`. Sem elas, login local.
- **0.6.0**: sem migração; `relatorios\` inteira (DRE.sql foi para `_dre\Saldos.sql`, saiu `templates\DRE.html`).
  A pasta Diretoria continua liberada só para quem já tinha (Admin → Grupos).
- **0.5.0**: exige **hlcore 0.6.0** (wheel novo); `relatorios\` inteira (saiu a pasta Comercial — Simulador foi
  para o HL Backoffice 0.4.0: publicar os dois juntos).
- **0.4.0**: sem migração; `relatorios\` inteira de novo (`_rentabilidade\Ecommerce.sql` e `Consolidado.sql` viraram
  `Vendas.sql`).
- **0.3.0**: sem migração. Em `relatorios\` saíram arquivos (páginas e configs antigos da Rentabilidade, 2 modelos sem
  uso, `Rentabilidade Ecommerce.sql`/`Rentabilidade Consolidado.sql` foram para `_rentabilidade\`) — copiar a pasta
  `relatorios\` inteira (substituir), não só os alterados.
- **0.2.0**: migração 0002 (e-mails agendados); dependência nova `openpyxl`; `.env` `EMAIL_SOMENTE_TESTE=false`;
  pasta nova `relatorios\email\`. Na primeira instalação já entra tudo pela fase 1.

## Publicações seguintes

1. Conferir a VM = última tag publicada.
2. Parar o serviço (`parar-servico.bat`).
3. Copiar os arquivos alterados do `backend\` e de `relatorios\`, e o `frontend\dist\` inteiro (substituir).
4. Se o `requirements.txt` mudou: `venv\Scripts\python -m pip install -r requirements.txt`; se exigir outra versão
   do hlcore, instalar o wheel novo (passo 4 da fase 1).
5. `venv\Scripts\python migrar.py` (backup + migrações; sem migração não faz nada).
6. Iniciar a tarefa; conferir `/api/health`. Quem estava com a tela aberta vê "Nova versão disponível — Recarregar".
7. Tag `vX.Y.Z` no commit publicado e entrada no [HISTORICO.md](HISTORICO.md).

Só SQL/config/página de relatório mudou? Basta copiar o arquivo para `relatorios\` — o app lê a cada execução, sem
reiniciar.
