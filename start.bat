@echo off
title HL Report - HLMotobike
cd /d "%~dp0backend"

if not exist "%~dp0frontend\dist\index.html" (
    echo [ERRO] Frontend nao compilado. Veja docs\PUBLICACAO.md.
    pause
    exit /b 1
)

echo.
echo  HL Report - HLMotobike
echo  Acesse: http://localhost:9001
echo  Pressione CTRL+C para encerrar.
echo.

venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 9001
pause
