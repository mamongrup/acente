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

Write-Output ""
Write-Output "İki proje sözleşme kontrolleri tamamlandı."
