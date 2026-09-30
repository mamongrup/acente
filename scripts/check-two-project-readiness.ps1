param(
  [string]$NexusRoot = '',
  [switch]$RestoreDrill,
  [string]$AgencyMaintenanceUser = '',
  [string]$AgencyMaintenancePassword = ''
)

$ErrorActionPreference = 'Stop'
$agencyRoot = Split-Path $PSScriptRoot -Parent
if (!$NexusRoot) { $NexusRoot = Join-Path (Split-Path $agencyRoot -Parent) 'Nexustraveltech' }
$NexusRoot = [IO.Path]::GetFullPath($NexusRoot)
if (!(Test-Path -LiteralPath (Join-Path $NexusRoot 'scripts/test.ps1'))) {
  throw "NEXUS checkout missing: $NexusRoot"
}

function Invoke-RequiredScript([string]$Path, [string[]]$Arguments = @()) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Readiness step failed: $Path ($LASTEXITCODE)" }
}

Write-Host '== NEXUS full test suite =='
Invoke-RequiredScript (Join-Path $NexusRoot 'scripts/test.ps1')

Write-Host '== WP2 true concurrent last-inventory test =='
Invoke-RequiredScript (Join-Path $agencyRoot 'scripts/check-wp2-concurrent-booking.ps1') @('-NexusEnvPath', (Join-Path $NexusRoot '.env'))

Write-Host '== Agency WP2 sales-chain lifecycle =='
Invoke-RequiredScript (Join-Path $agencyRoot 'scripts/check-wp2-sales-chain.ps1')

Write-Host '== Agency full release readiness =='
$previousNexusRoot = $env:NEXUS_PROJECT_ROOT
try {
  $env:NEXUS_PROJECT_ROOT = $NexusRoot
  Invoke-RequiredScript (Join-Path $agencyRoot 'scripts/check-release-readiness.ps1')
} finally {
  $env:NEXUS_PROJECT_ROOT = $previousNexusRoot
}

if ($RestoreDrill) {
  Write-Host '== NEXUS backup and restore =='
  Invoke-RequiredScript (Join-Path $NexusRoot 'scripts/backup-restore-drill.ps1') @('-RestoreTest')

  Write-Host '== Agency backup and restore =='
  $restoreArguments = @('-RestoreTest')
  if ($AgencyMaintenanceUser) { $restoreArguments += @('-MaintenanceUser', $AgencyMaintenanceUser) }
  if ($AgencyMaintenancePassword) { $restoreArguments += @('-MaintenancePassword', $AgencyMaintenancePassword) }
  Invoke-RequiredScript (Join-Path $agencyRoot 'scripts/backup-restore-drill.ps1') $restoreArguments
}

Write-Host 'Two-project local readiness passed.'
