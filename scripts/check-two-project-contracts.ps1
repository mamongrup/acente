param(
  [string]$AgencyRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$NexusRoot = 'C:\laragon\www\Nexustraveltech'
)

$ErrorActionPreference = 'Stop'

function Invoke-ContractCheck {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$ScriptName,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $scriptPath = Join-Path $Root "scripts\$ScriptName"
  if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "$Label kontrol scripti bulunamadı: $scriptPath"
  }

  Write-Output ""
  Write-Output "== $Label =="
  & powershell -ExecutionPolicy Bypass -File $scriptPath
  if ($LASTEXITCODE -ne 0) {
    throw "$Label başarısız oldu."
  }
}

if (-not (Test-Path -LiteralPath $AgencyRoot)) {
  throw "Acente proje yolu bulunamadı: $AgencyRoot"
}

if (-not (Test-Path -LiteralPath $NexusRoot)) {
  throw "NEXUS proje yolu bulunamadı: $NexusRoot"
}

Invoke-ContractCheck -Root $AgencyRoot -ScriptName 'check-local-db-contract.ps1' -Label 'Acente lokal DB sözleşme kontrolü'
Invoke-ContractCheck -Root $NexusRoot -ScriptName 'check-local-db-contract.ps1' -Label 'NEXUS lokal DB sözleşme kontrolü'
Invoke-ContractCheck -Root $AgencyRoot -ScriptName 'check-contract-parity.ps1' -Label 'Acente ↔ NEXUS sözleşme eşitliği'
Invoke-ContractCheck -Root $NexusRoot -ScriptName 'check-contract-parity.ps1' -Label 'NEXUS ↔ Acente sözleşme eşitliği'
Invoke-ContractCheck -Root $NexusRoot -ScriptName 'check-reservation-status-flow.ps1' -Label 'NEXUS rezervasyon durum kapsamı'

Write-Output ""
Write-Output '== Tedarikçi rol/izin karar eşitliği =='
$previousNexusRoot = $env:NEXUS_PROJECT_ROOT
try {
  $env:NEXUS_PROJECT_ROOT = $NexusRoot
  & node (Join-Path $AgencyRoot 'scripts/check-supplier-permission-parity.mjs')
  if ($LASTEXITCODE -ne 0) { throw 'Tedarikçi rol/izin kararları iki projede farklı.' }
} finally {
  $env:NEXUS_PROJECT_ROOT = $previousNexusRoot
}

Write-Output ""
Write-Output "İki proje sözleşme kontrolleri tamamlandı."
& node (Join-Path $AgencyRoot 'scripts/check-channel-operations-parity.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Ortak kanal operasyonları sözleşmesi farklı.' }
