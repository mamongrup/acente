param(
  [string]$EnvPath = ".env",
  [switch]$Production,
  [switch]$SkipParampos,
  [switch]$SkipNexusRest,
  [switch]$SkipLocalNexusHarness,
  [switch]$SkipTwoProjectContracts,
  [switch]$SkipBrowser
)

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$optionalNexusRoot = if ($env:NEXUS_PROJECT_ROOT) {
  $env:NEXUS_PROJECT_ROOT
} else {
  Join-Path (Split-Path $root -Parent) 'Nexustraveltech'
}
$readinessEnv = @{}
$readinessEnvPath = Join-Path $root $EnvPath
if (!(Test-Path -LiteralPath $readinessEnvPath)) { throw "Env file not found: $readinessEnvPath" }
Get-Content -LiteralPath $readinessEnvPath | ForEach-Object {
  if ($_ -match '^\s*([^#=]+)\s*=\s*(.*)\s*$') {
    $readinessEnv[$matches[1].Trim()] = $matches[2].Trim()
  }
}
$nexusKeyConfigured = -not [string]::IsNullOrWhiteSpace($readinessEnv['NEXUS_API_KEY'])
$nexusOriginConfigured = -not [string]::IsNullOrWhiteSpace($readinessEnv['NEXUS_API_ORIGIN'])
if ($nexusKeyConfigured -xor $nexusOriginConfigured) {
  throw 'NEXUS connection is partially configured: API origin and key must both be set or both be empty.'
}

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Body
  )

  Write-Host ""
  Write-Host "== $Name ==" -ForegroundColor Cyan
  & $Body
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

function Invoke-ProjectScript {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptName,
    [string[]]$Arguments = @()
  )

  $scriptPath = Join-Path $root "scripts\$ScriptName"
  if (!(Test-Path -LiteralPath $scriptPath)) {
    throw "Script not found: $scriptPath"
  }
  & powershell -ExecutionPolicy Bypass -File $scriptPath @Arguments
}

if ($Production) {
  Invoke-Step "Production gates" {
    Invoke-ProjectScript "check-production-gates.ps1" @("-EnvPath", $EnvPath)
  }
} else {
  Write-Host "Production gates skipped. Use -Production to enforce production env checks." -ForegroundColor Yellow
}

Invoke-Step "Gleam build" {
  Push-Location $root
  try { & gleam build } finally { Pop-Location }
}

Invoke-Step "Local category and supplier contract" {
  Invoke-ProjectScript "check-local-db-contract.ps1"
  Push-Location $root
  try { & node scripts/check-shared-contracts.mjs } finally { Pop-Location }
}

Invoke-Step "Runtime health" {
  Invoke-ProjectScript "check-runtime-health.ps1"
}

Invoke-Step "Standalone and connected agency flows" {
  Invoke-ProjectScript "check-agency-mode-flows.ps1"
}

Invoke-Step "Secret hygiene" {
  Invoke-ProjectScript "check-secret-hygiene.ps1" @("-EnvPath", $EnvPath)
}

Invoke-Step "Legacy cleanup guards" {
  Invoke-ProjectScript "check-legacy-cleanup.ps1" @("-EnvPath", $EnvPath)
}

Invoke-Step "Worker hygiene" {
  Invoke-ProjectScript "check-worker-hygiene.ps1"
}

Invoke-Step "Audit retention smoke" {
  Invoke-ProjectScript "run-audit-retention.ps1"
}

Invoke-Step "Security retention smoke" {
  Invoke-ProjectScript "run-security-retention.ps1"
}

Invoke-Step "NEXUS reservation queue smoke" {
  Invoke-ProjectScript "check-nexus-reservation-queue.ps1" @("-EnvPath", $EnvPath)
}

if ($nexusKeyConfigured) {
  Invoke-Step "NEXUS connection callback flow" {
    Invoke-ProjectScript "check-nexus-callback-flow.ps1"
  }
} else {
  Write-Host "NEXUS callback check skipped: standalone mode has no central connection." -ForegroundColor Yellow
}

if ($SkipLocalNexusHarness) {
  Write-Host "Local NEXUS connection harness skipped." -ForegroundColor Yellow
} else {
  Invoke-Step "Local NEXUS connection approval/feed harness" {
    Invoke-ProjectScript "run-local-nexus-connection-harness.ps1"
  }
}

if ($SkipBrowser) {
  Write-Host "Critical browser page checks skipped." -ForegroundColor Yellow
} else {
  Invoke-Step "Critical browser page contract" {
    Push-Location $root
    try { & npm run test:e2e -- --grep "critical page contract" } finally { Pop-Location }
  }
}

if ($SkipParampos) {
  Write-Host "ParamPOS tests skipped." -ForegroundColor Yellow
} else {
  Invoke-Step "ParamPOS lifecycle/protocol tests" {
    Invoke-ProjectScript "test-parampos.ps1"
  }
}

if ($SkipTwoProjectContracts -or -not (Test-Path -LiteralPath (Join-Path $optionalNexusRoot 'contracts\supplier-listing-contract.v1.json'))) {
  Write-Host "Two-project checks skipped: optional NEXUS checkout is unavailable or explicitly skipped." -ForegroundColor Yellow
} else {
  Invoke-Step "Two-project contract parity" {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/check-two-project-contracts.ps1') -NexusRoot $optionalNexusRoot
  }
  Invoke-Step "Runtime listing validation parity for every tenant" {
    Push-Location $root
    try { & node scripts/check-runtime-listing-contracts.mjs } finally { Pop-Location }
  }
}

if ($SkipNexusRest -or -not $nexusKeyConfigured) {
  Write-Host "NEXUS REST contract test skipped: optional connection is unavailable or explicitly skipped." -ForegroundColor Yellow
} else {
  Invoke-Step "NEXUS REST contract smoke" {
    if ($Production) {
      Invoke-ProjectScript "check-nexus-rest-contract.ps1" -Arguments @('-RequireListing')
    } else {
      Invoke-ProjectScript "check-nexus-rest-contract.ps1"
    }
  }
}

Write-Host ""
Write-Host "Release readiness check passed." -ForegroundColor Green
