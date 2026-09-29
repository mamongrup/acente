param(
  [string]$EnvPath = ".env",
  [int]$KeepDays = 365,
  [int]$BatchSize = 5000
)

$ErrorActionPreference = 'Stop'
if ($KeepDays -lt 30) { throw 'KeepDays must be at least 30.' }
if ($BatchSize -lt 1 -or $BatchSize -gt 50000) { throw 'BatchSize must be between 1 and 50000.' }
if (!(Test-Path -LiteralPath $EnvPath)) { throw "Env file not found: $EnvPath" }

Get-Content -LiteralPath $EnvPath | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith('#')) { return }
  $idx = $line.IndexOf('=')
  if ($idx -gt 0) {
    Set-Item "Env:$($line.Substring(0, $idx).Trim())" $line.Substring($idx + 1).Trim()
  }
}

$psql = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
if (!(Test-Path -LiteralPath $psql)) { $psql = 'psql' }

$arguments = @(
  '-X',
  '-w',
  '-v', 'ON_ERROR_STOP=1',
  '-h', $env:PGHOST,
  '-p', $env:PGPORT,
  '-U', $env:PGUSER,
  '-d', $env:PGDATABASE,
  '-At',
  '-c', "select agency.archive_audit_logs($KeepDays,$BatchSize);"
)

$result = & $psql @arguments
if ($LASTEXITCODE -ne 0) { throw "Audit retention failed with exit code $LASTEXITCODE" }

$moved = ($result | Select-Object -First 1)
Write-Host "Audit retention completed. Archived rows: $moved"
