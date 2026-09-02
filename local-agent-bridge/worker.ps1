$ErrorActionPreference = 'Stop'
$Repo = 'david6428/line-gpt-bot'
$ApiBase = "https://api.github.com/repos/$Repo"
$Root = 'C:\LOCAL_AGENT\ollama_bridge'
$Outbox = Join-Path $Root 'outbox'
$Logs = Join-Path $Root 'logs'
$StateFile = Join-Path $Root 'processed.json'
$LogFile = Join-Path $Logs 'worker.log'
$PollSeconds = 30

New-Item -ItemType Directory -Force -Path $Root,$Outbox,$Logs | Out-Null

$mutex = New-Object System.Threading.Mutex($false, 'OllamaAgentBridgeMutex')
if (-not $mutex.WaitOne(0, $false)) { exit 0 }

function Write-Log([string]$Message) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    [System.IO.File]::AppendAllText($LogFile, $line + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

function Load-Processed {
    if (-not (Test-Path $StateFile)) { return @{} }
    try {
        $items = Get-Content $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $h = @{}
        foreach ($x in @($items)) { $h[[string]$x] = $true }
        return $h
    } catch {
        Write-Log "STATE_READ_ERROR $($_.Exception.Message)"
        return @{}
    }
}

function Save-Processed($Map) {
    @($Map.Keys) | ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8
}

function Get-Field([string]$Body, [string]$Name, [string]$Default='') {
    $m = [regex]::Match($Body, "(?im)^" + [regex]::Escape($Name) + ":\s*(.+?)\s*$")
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return $Default
}

function Get-Prompt([string]$Body) {
    $m = [regex]::Match($Body, '(?is)PROMPT:\s*(.*?)(?:\r?\n\s*DONE_CRITERIA:|\z)')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return $Body.Trim()
}

function Test-Ollama {
    try {
        $null = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -Method Get -TimeoutSec 8
        return $true
    } catch {
        Write-Log "OLLAMA_UNAVAILABLE $($_.Exception.Message)"
        return $false
    }
}

function Invoke-OllamaTask([string]$Model, [string]$Prompt) {
    $payload = @{
        model = $Model
        stream = $false
        messages = @(
            @{ role='system'; content='You are a local execution agent. Follow the task exactly. Return concise deterministic output.' },
            @{ role='user'; content=$Prompt }
        )
    } | ConvertTo-Json -Depth 8
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/chat' -Method Post -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 300
    return [string]$resp.message.content
}

function Get-DriveOutbox {
    $candidates = @(
        "$env:USERPROFILE\My Drive",
        "$env:USERPROFILE\Google Drive",
        'G:\我的雲端硬碟', 'G:\My Drive', 'G:\Google Drive',
        'H:\我的雲端硬碟', 'H:\My Drive', 'H:\Google Drive',
        'I:\我的雲端硬碟', 'I:\My Drive', 'I:\Google Drive'
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $p = Join-Path $c 'AI_AGENT_QUEUE\outbox'
            New-Item -ItemType Directory -Force -Path $p | Out-Null
            return $p
        }
    }
    return $null
}

function Try-GitHubWriteback([int]$IssueNumber, [string]$ResultFile) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) { return $false }
    & gh auth status 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    & gh issue comment $IssueNumber --repo $Repo --body-file $ResultFile 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    & gh issue close $IssueNumber --repo $Repo --reason completed 1>$null 2>$null
    return ($LASTEXITCODE -eq 0)
}

$Processed = Load-Processed
Write-Log 'WORKER_START'

try {
    while ($true) {
        try {
            if (-not (Test-Ollama)) { Start-Sleep -Seconds $PollSeconds; continue }

            $headers = @{ 'User-Agent'='OllamaAgentBridge'; 'Accept'='application/vnd.github+json' }
            $issues = Invoke-RestMethod -Uri "$ApiBase/issues?state=open&per_page=50" -Headers $headers -Method Get -TimeoutSec 20
            $tasks = @($issues | Where-Object { $_.title -like '[[]OLLAMA_TASK[]]*' -and -not $_.pull_request })

            foreach ($issue in $tasks) {
                $key = [string]$issue.number
                if ($Processed.ContainsKey($key)) { continue }

                $taskId = Get-Field $issue.body 'TASK_ID' "ISSUE-$($issue.number)"
                $model = Get-Field $issue.body 'MODEL' 'qwen2.5:7b'
                $prompt = Get-Prompt $issue.body
                Write-Log "TASK_START issue=$($issue.number) task=$taskId model=$model"

                try {
                    $answer = Invoke-OllamaTask $model $prompt
                    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                    $safeTask = ($taskId -replace '[^a-zA-Z0-9._-]','_')
                    $resultFile = Join-Path $Outbox "$safeTask`_$stamp.md"
                    $content = @"
TASK_ID: $taskId
ISSUE: $($issue.number)
MODEL: $model
STATUS: DONE
UPDATED_AT: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## RESULT
$answer
"@
                    [System.IO.File]::WriteAllText($resultFile, $content, (New-Object System.Text.UTF8Encoding($false)))

                    $driveOut = Get-DriveOutbox
                    if ($driveOut) {
                        Copy-Item $resultFile (Join-Path $driveOut ([IO.Path]::GetFileName($resultFile))) -Force
                        Write-Log "DRIVE_WRITEBACK_OK $driveOut"
                    }

                    $ghOk = Try-GitHubWriteback ([int]$issue.number) $resultFile
                    if ($ghOk) { Write-Log "GITHUB_WRITEBACK_OK issue=$($issue.number)" }
                    else { Write-Log "GITHUB_WRITEBACK_SKIPPED issue=$($issue.number)" }

                    $Processed[$key] = $true
                    Save-Processed $Processed
                    Write-Log "TASK_DONE issue=$($issue.number) task=$taskId file=$resultFile"
                } catch {
                    $errCode = 'E' + (Get-Date -Format 'yyyyMMdd') + '-LOCAL'
                    $errFile = Join-Path $Outbox "ERROR_ISSUE-$($issue.number)_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
                    $err = @"
ERROR_CODE: $errCode
SOURCE: OllamaAgentBridge
TASK_ID: $taskId
ISSUE: $($issue.number)
ROOT_CAUSE: $($_.Exception.Message)
WHAT_ALREADY_TRIED: GitHub Queue -> Ollama localhost -> result writeback
FIX: Auto-retry on next polling cycle; do not mark processed.
TEST_RESULT: FAILED
FALLBACK: Keep task open and retry automatically.
NEXT_BEST_ACTION: Retry automatically after $PollSeconds seconds.
UPDATED_AT: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
                    [System.IO.File]::WriteAllText($errFile, $err, (New-Object System.Text.UTF8Encoding($false)))
                    Write-Log "TASK_ERROR issue=$($issue.number) $($_.Exception.Message)"
                }
            }
        } catch {
            Write-Log "LOOP_ERROR $($_.Exception.Message)"
        }
        Start-Sleep -Seconds $PollSeconds
    }
} finally {
    try { $mutex.ReleaseMutex() | Out-Null } catch {}
    $mutex.Dispose()
}
