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
$routerSource = Join-Path $root 'src/nexus_agency/erl/nexus_agency@router_impl.erl'
$routerOutput = Join-Path $root 'build/dev/erlang/nexus_agency/ebin'
& 'C:/laragon/bin/erlang/bin/erlc.exe' -o $routerOutput $routerSource
if ($LASTEXITCODE -ne 0) { throw 'Router Erlang derlemesi başarısız.' }
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
$operationPath = Join-Path $root 'scripts/ai-operation-worker.ps1'
$feedPath = Join-Path $root 'scripts/commerce-feed-worker.ps1'
$knowledgePath = Join-Path $root 'scripts/ai-knowledge-worker.ps1'
$campaignPath = Join-Path $root 'scripts/ai-campaign-worker.ps1'
$qualityPath = Join-Path $root 'scripts/ai-quality-worker.ps1'
$followupPath = Join-Path $root 'scripts/followup-worker.ps1'
$notificationPath = Join-Path $root 'scripts/notification-worker.ps1'
$panelOperationsPath = Join-Path $root 'scripts/panel-operations-worker.ps1'
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
$existingOperation = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($operationPath) } |
  Select-Object -First 1
if (-not $existingOperation) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$operationPath) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.local/ai-operation.log') -RedirectStandardError (Join-Path $root '.local/ai-operation-error.log')
}
$existingFeed = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($feedPath) } |
  Select-Object -First 1
if (-not $existingFeed) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$feedPath) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.local/commerce-feed.log') -RedirectStandardError (Join-Path $root '.local/commerce-feed-error.log')
}
$existingKnowledge = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($knowledgePath) } |
  Select-Object -First 1
if (-not $existingKnowledge) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$knowledgePath) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.local/ai-knowledge.log') -RedirectStandardError (Join-Path $root '.local/ai-knowledge-error.log')
}
foreach ($workerSpec in @(@($campaignPath,'.local/ai-campaign.log','.local/ai-campaign-error.log'), @($qualityPath,'.local/ai-quality.log','.local/ai-quality-error.log'))) {
  $path=$workerSpec[0]
  $exists=Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($path) } | Select-Object -First 1
  if (-not $exists) { Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$path) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root $workerSpec[1]) -RedirectStandardError (Join-Path $root $workerSpec[2]) }
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
$existingPanelOperations = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($panelOperationsPath) } |
  Select-Object -First 1
if (-not $existingPanelOperations) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$panelOperationsPath) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.local/panel-operations.log') -RedirectStandardError (Join-Path $root '.local/panel-operations-error.log')
}
$existingSocial = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($socialPath) } |
  Select-Object -First 1
if (-not $existingSocial) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$socialPath) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.local/social.log') -RedirectStandardError (Join-Path $root '.local/social-error.log')
}
Write-Output "NEXUS Agency başlatılıyor: $env:APP_ORIGIN"
