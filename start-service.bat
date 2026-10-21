@echo off
rem Chamado pela tarefa agendada "HL Report HLMotobike" (conta SYSTEM) — ver instalar-tarefa.ps1
rem PORTA: 9000 (desde a troca de 20/10/2026; foi 9001 na fase em paralelo com o Report antigo)
set PORTA=9000
cd /d "C:\ProjetosHL\hl-report\backend"

set LOG_DIR=C:\ProjetosHL\hl-report\logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set LOG_FILE=%LOG_DIR%\service.log
echo [%DATE% %TIME%] Iniciando HL Report na porta %PORTA%... >> "%LOG_FILE%"

if not exist "C:\ProjetosHL\hl-report\frontend\dist\index.html" (
    echo [%DATE% %TIME%] ERRO: Frontend nao compilado. >> "%LOG_FILE%"
    exit /b 1
)

"C:\ProjetosHL\hl-report\backend\venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port %PORTA% >> "%LOG_FILE%" 2>&1
