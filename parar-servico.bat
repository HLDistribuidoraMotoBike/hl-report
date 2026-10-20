@echo off
rem Para SO o HL Report — nunca "taskkill python.exe": HL Logistica e HL Backoffice rodam na mesma VM.
rem PORTA: a mesma do start-service.bat (9001 na fase em paralelo; 9000 depois da troca)
set PORTA=9001
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

echo Parando HL Report (porta %PORTA%)...
schtasks /end /TN "HLMotobike\HL Report HLMotobike"
for /f "tokens=5" %%p in ('netstat -ano ^| findstr /R /C:":%PORTA% .*LISTENING"') do taskkill /F /PID %%p /T >nul 2>&1
echo Servico parado.
pause
