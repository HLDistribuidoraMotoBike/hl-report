@echo off
rem Chamado pela tarefa agendada "HL Report HLMotobike" (conta SYSTEM) — ver instalar-tarefa.ps1
rem PORTA: 9001 enquanto roda em paralelo com o Report antigo (Flask, porta 9000); 9000 depois da troca (docs\PUBLICACAO.md)
set PORTA=9001
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
