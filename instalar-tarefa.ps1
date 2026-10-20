# HL Report — Registrar tarefa no Agendador do Windows (porta do start-service.bat: 9000; 9001 na fase em paralelo com o Report antigo)
# Execute como Administrador

$taskName = "HL Report HLMotobike"
$taskPath = "\HLMotobike\"

Write-Host "=== HL Report — Instalador de Tarefa Agendada ===" -ForegroundColor Cyan
Write-Host ""

$existente = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
if ($existente) {
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
    Write-Host "Tarefa anterior removida." -ForegroundColor Yellow
}

$logDir = "C:\ProjetosHL\hl-report\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$action = New-ScheduledTaskAction `
    -Execute "C:\Windows\System32\cmd.exe" `
    -Argument '/c "C:\ProjetosHL\hl-report\start-service.bat"' `
    -WorkingDirectory "C:\ProjetosHL\hl-report\backend"

# Ao iniciar o sistema, 45 s depois (o HL Logistica sobe aos 30 s)
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = "PT45S"

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 2) `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -Priority 7

$principal = New-ScheduledTaskPrincipal `
    -UserId "NT AUTHORITY\SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -TaskPath $taskPath `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Inicia o HL Report (relatórios HLMotobike) no boot do servidor. Roda como SYSTEM, porta definida no start-service.bat." `
    -Force | Out-Null

Write-Host "Tarefa registrada!" -ForegroundColor Green
Write-Host "  Nome  : $taskPath$taskName"
Write-Host "  Inicio: na inicializacao do sistema (delay 45s)"
Write-Host "  Log   : $logDir\service.log"
Write-Host ""

$resposta = Read-Host "Deseja iniciar o servico agora para testar? (S/N)"
if ($resposta -match "^[Ss]") {
    Start-ScheduledTask -TaskName $taskName -TaskPath $taskPath
    Start-Sleep -Seconds 3
    $estado = (Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath).State
    Write-Host "Estado: $estado" -ForegroundColor Cyan
    Write-Host "Acesse: http://localhost:<porta do start-service.bat>" -ForegroundColor Green
}

Write-Host ""
Write-Host "Pressione ENTER para fechar..."
Read-Host
