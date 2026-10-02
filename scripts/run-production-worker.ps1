param([Parameter(Mandatory = $true)][string]$Name)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$allowed = @(
  'currency','ai-supervisor','ai-operation','commerce-feed','ai-knowledge',
  'ai-campaign','ai-quality','followup','notification','panel-operations','social','translation','calendar'
)
if ($Name -notin $allowed) { throw "Unknown agency worker: $Name" }
& "$PSScriptRoot/check-production-gates.ps1" -EnvPath (Join-Path $root '.env')
if ($LASTEXITCODE -ne 0) { throw 'Production configuration failed.' }
$appEnv = (Get-Content -LiteralPath (Join-Path $root '.env') | Where-Object { $_ -match '^APP_ENV=' } | Select-Object -Last 1)
if ($appEnv -ne 'APP_ENV=production') { throw 'APP_ENV=production is required.' }
$script = Join-Path $PSScriptRoot "$Name-worker.ps1"
if (!(Test-Path -LiteralPath $script)) { throw "Worker script missing: $script" }
New-Item -ItemType Directory -Path (Join-Path $root '.local') -Force | Out-Null
& $script
if ($LASTEXITCODE -ne 0) { throw "Agency worker exited: $Name" }
