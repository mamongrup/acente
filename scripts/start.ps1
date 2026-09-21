$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
if (!(Test-Path -LiteralPath $envFile)) { throw 'Önce .env.example dosyasını .env olarak kopyalayın.' }
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim(); $index = $line.IndexOf('=')
  if ($index -gt 0) { Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim() }
}
Set-Location $root
gleam build
if ($LASTEXITCODE -ne 0) { throw 'Derleme başarısız.' }
New-Item -ItemType Directory -Force -Path (Join-Path $root '.local') | Out-Null
# Tek bir yerel API süreci çalıştır. Eski gleam/erl süreçleri portu kilitleyip
# yeni derlenmiş kodun yerine eski binary'nin cevap vermesine neden olabiliyordu.
$buildMarker = (Join-Path $root 'build').ToLowerInvariant()
$oldApiProcesses = Get-CimInstance -ClassName Win32_Process |
  Where-Object { $_.CommandLine -and $_.CommandLine.ToLowerInvariant().Contains($buildMarker) }
$oldApiIds = @($oldApiProcesses | ForEach-Object { $_.ProcessId })
$oldApiParentIds = @($oldApiProcesses | ForEach-Object { $_.ParentProcessId })
$oldApiIds += $oldApiParentIds
foreach ($oldApiId in ($oldApiIds | Sort-Object -Unique)) {
  Stop-Process -Id $oldApiId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Milliseconds 500
Start-Process -FilePath 'C:/laragon/bin/gleam/gleam.exe' -ArgumentList @('run') -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.local/agency.log') -RedirectStandardError (Join-Path $root '.local/agency-error.log')
$workerPath = Join-Path $root 'scripts/currency-worker.ps1'
$supervisorPath = Join-Path $root 'scripts/ai-supervisor-worker.ps1'
$followupPath = Join-Path $root 'scripts/followup-worker.ps1'
$notificationPath = Join-Path $root 'scripts/notification-worker.ps1'
$socialPath = Join-Path $root 'scripts/social-worker.ps1'
$existingWorker = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($workerPath) } |
  Select-Object -First 1
if (-not $existingWorker) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$workerPath) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.local/currency.log') -RedirectStandardError (Join-Path $root '.local/currency-error.log')
}
$existingSupervisor = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($supervisorPath) } |
  Select-Object -First 1
if (-not $existingSupervisor) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$supervisorPath) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.local/ai-supervisor.log') -RedirectStandardError (Join-Path $root '.local/ai-supervisor-error.log')
}
$existingFollowup = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($followupPath) } |
  Select-Object -First 1
if (-not $existingFollowup) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$followupPath) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.local/followup.log') -RedirectStandardError (Join-Path $root '.local/followup-error.log')
}
$existingNotification = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($notificationPath) } |
  Select-Object -First 1
if (-not $existingNotification) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$notificationPath) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.local/notification.log') -RedirectStandardError (Join-Path $root '.local/notification-error.log')
}
$existingSocial = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($socialPath) } |
  Select-Object -First 1
if (-not $existingSocial) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$socialPath) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.local/social.log') -RedirectStandardError (Join-Path $root '.local/social-error.log')
}
Write-Output "NEXUS Agency başlatılıyor: $env:APP_ORIGIN"
