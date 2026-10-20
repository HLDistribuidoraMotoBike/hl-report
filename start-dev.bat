@echo off
title HL Report - DESENVOLVIMENTO
set ROOT=%~dp0

echo.
echo  ================================================
echo   HL Report - AMBIENTE DE DESENVOLVIMENTO
echo   Backend : http://localhost:8003  (banco dev)
echo   Frontend: http://localhost:5175  (hot reload)
echo   API Docs: http://localhost:8003/docs
echo  ================================================
echo.
echo  ATENCAO: HANA do .env de dev e o de PRODUCAO (so leitura).
echo.

cd /d "%ROOT%backend"
if not exist "venv\Scripts\python.exe" (
    echo [ERRO] venv nao encontrado. Veja "Instalacao" no README.md.
    pause
    exit /b 1
)

rem banco no ultimo nivel (cria na primeira vez)
venv\Scripts\python migrar.py || (pause & exit /b 1)

start "DEV Report :8003" cmd /k "title DEV Report :8003 && cd /d %ROOT%backend && venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8003"
timeout /t 2 /nobreak >nul
start "DEV Report Frontend :5175" cmd /k "title DEV Report Frontend :5175 && cd /d %ROOT%frontend && npm run dev"

echo [DEV] Acesse: http://localhost:5175
pause
