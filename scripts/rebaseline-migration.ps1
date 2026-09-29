param(
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$EnvPath = ".env",
  [switch]$ConfirmIntentional
)

$ErrorActionPreference = "Stop"
if (!$ConfirmIntentional) {
  throw "Rebaseline is destructive to migration history. Re-run with -ConfirmIntentional after reviewing the migration diff."
}

$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root $EnvPath
if (!(Test-Path -LiteralPath $envFile)) { throw "Env file not found: $envFile" }
Get-Content -LiteralPath $envFile | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith("#")) { return }
  $index = $line.IndexOf("=")
  if ($index -gt 0) {
    Set-Item "Env:$($line.Substring(0, $index).Trim())" $line.Substring($index + 1).Trim()
  }
}

$file = Join-Path $root "db/migrations/$Version.sql"
if (!(Test-Path -LiteralPath $file)) { throw "Migration not found: $file" }
$hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
$psql = "C:/laragon/bin/postgresql/postgresql/bin/psql.exe"
if (!(Test-Path -LiteralPath $psql)) { $psql = "psql" }
$escapedVersion = $Version.Replace("'", "''")
& $psql -X -w -v ON_ERROR_STOP=1 -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -c "UPDATE system.schema_migrations SET checksum='$hash', applied_at=now() WHERE version='$escapedVersion';"
if ($LASTEXITCODE -ne 0) { throw "Migration checksum update failed: $Version" }
Write-Host "Rebaselined migration checksum: $Version"

