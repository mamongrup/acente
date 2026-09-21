# NEXUS Agency — File watcher that runs `gleam test` on .gleam changes.
# Usage:  powershell -File scripts\watch-tests.ps1
# Stops with Ctrl-C.  Requires PowerShell 5+ (ships with Windows).

$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $root
$watcher.IncludeSubdirectories = $true
$watcher.Filter = '*.gleam'
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName

$last_run = [datetime]::MinValue
$debounce_ms = 800

function Run-Tests {
    Write-Host ''
    $ts = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$ts] Changes detected - running gleam test..." -ForegroundColor Cyan
    Set-Location $root
    $output = gleam test 2>&1 | Out-String
    $exit = $LASTEXITCODE
    Write-Host $output.Trim()
    $ts2 = Get-Date -Format 'HH:mm:ss'
    if ($exit -eq 0) {
        Write-Host "[$ts2] All tests passed." -ForegroundColor Green
    } else {
        Write-Host "[$ts2] Tests failed (exit $exit)." -ForegroundColor Red
    }
}

# Initial run
Run-Tests

$action = {
    $now = [datetime]::UtcNow
    $elapsed = ($now - $last_run).TotalMilliseconds
    if ($elapsed -lt $debounce_ms) { return }
    $script:last_run = $now
    Run-Tests
}

Register-ObjectEvent $watcher 'Changed' -Action $action | Out-Null
Register-ObjectEvent $watcher 'Created' -Action $action | Out-Null
Register-ObjectEvent $watcher 'Renamed' -Action $action | Out-Null

$watcher.EnableRaisingEvents = $true

$ts = Get-Date -Format 'HH:mm:ss'
Write-Host "[$ts] Watching for .gleam changes in $root  (Ctrl-C to stop)" -ForegroundColor Yellow

try {
    while ($true) { Start-Sleep -Milliseconds 500 }
} finally {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    Unregister-Event -SourceIdentifier * -ErrorAction SilentlyContinue
    Write-Host "Watcher stopped." -ForegroundColor Yellow
}
