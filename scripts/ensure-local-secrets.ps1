param(
  [string]$EnvPath = ".env"
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path $EnvPath
$lines = [System.Collections.Generic.List[string]]::new()
Get-Content $resolved | ForEach-Object { [void]$lines.Add($_) }

function New-Secret([int]$bytes = 48) {
  $raw = New-Object byte[] $bytes
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($raw) }
  finally { $rng.Dispose() }
  return [Convert]::ToBase64String($raw)
}

function Get-EnvValue([string]$key) {
  foreach ($line in $lines) {
    if ($line -match "^$([regex]::Escape($key))=(.*)$") { return $Matches[1].Trim() }
  }
  return ''
}

function Set-EnvValue([string]$key, [string]$value) {
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^$([regex]::Escape($key))=") {
      $lines[$i] = "$key=$value"
      return
    }
  }
  [void]$lines.Add("$key=$value")
}

$changed = $false
$configKey = Get-EnvValue 'NEXUS_CONFIG_KEY'
if (!$configKey -or $configKey.Length -lt 64) {
  Set-EnvValue 'NEXUS_CONFIG_KEY' (New-Secret 48)
  $changed = $true
}

$secretKeyBase = Get-EnvValue 'SECRET_KEY_BASE'
if (!$secretKeyBase -or $secretKeyBase -eq 'generated-by-setup' -or $secretKeyBase.Length -lt 64) {
  Set-EnvValue 'SECRET_KEY_BASE' (New-Secret 48)
  $changed = $true
}

if ($changed) {
  Set-Content -LiteralPath $resolved -Value $lines -Encoding UTF8
  Write-Host "Local secret values updated in $resolved"
} else {
  Write-Host "Local secret values already satisfy minimum length requirements."
}
