$ErrorActionPreference = 'Stop'
$Root = 'C:\LOCAL_AGENT\ollama_bridge'
$WorkerUrl = 'https://raw.githubusercontent.com/david6428/line-gpt-bot/main/local-agent-bridge/worker.ps1'
$Worker = Join-Path $Root 'worker.ps1'
$TaskName = 'OllamaAgentBridge'

New-Item -ItemType Directory -Force -Path $Root | Out-Null

try {
    $tags = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -Method Get -TimeoutSec 8
    if (-not $tags.models) { throw 'Ollama API responded but no models were returned.' }
} catch {
    Write-Host "E20260902-OLLAMA Ollama localhost:11434 unavailable: $($_.Exception.Message)"
    exit 2
}

Invoke-WebRequest -Uri $WorkerUrl -OutFile $Worker -UseBasicParsing
if (-not (Test-Path $Worker)) { throw 'worker.ps1 download failed.' }

$cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Worker`""
$created = $false
try {
    schtasks.exe /Create /TN $TaskName /TR $cmd /SC ONLOGON /F | Out-Null
    if ($LASTEXITCODE -eq 0) { $created = $true }
} catch {}

if (-not $created) {
    $startup = [Environment]::GetFolderPath('Startup')
    $bat = Join-Path $startup 'OllamaAgentBridge.cmd'
    "@echo off`r`nstart `"`" /min $cmd`r`n" | Set-Content -Path $bat -Encoding ASCII
}

Start-Process powershell.exe -ArgumentList @('-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',$Worker)
Start-Sleep -Seconds 2

Write-Host 'OLLAMA_BRIDGE_INSTALL_OK'
Write-Host "ROOT=$Root"
Write-Host "WORKER=$Worker"
Write-Host "LOG=$Root\logs\worker.log"
Write-Host "OUTBOX=$Root\outbox"
Write-Host 'TEST_QUEUE=https://github.com/david6428/line-gpt-bot/issues/1'
