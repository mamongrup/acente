param([string]$EnvPath = '.env')

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$resolvedEnv = Join-Path $root $EnvPath
if (!(Test-Path -LiteralPath $resolvedEnv)) { throw "Env file not found: $resolvedEnv" }

Get-Content -LiteralPath $resolvedEnv | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith('#')) { return }
  $index = $line.IndexOf('=')
  if ($index -gt 0) {
    Set-Item "Env:$($line.Substring(0, $index).Trim())" $line.Substring($index + 1).Trim()
  }
}

$psql = 'psql'
$laragonPsql = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
if (Test-Path -LiteralPath $laragonPsql) { $psql = $laragonPsql }

# Release checks never claim queued jobs or print guest information.
# The worker owns status changes; this check only verifies its database contract.
$sql = @'
SELECT CASE WHEN
  to_regclass('agency.nexus_reservation_deliveries') IS NOT NULL
  AND to_regprocedure('agency.nexus_reservation_ready(uuid,uuid)') IS NOT NULL
  AND to_regprocedure('agency.retry_nexus_reservation_delivery(uuid,uuid,uuid)') IS NOT NULL
  AND EXISTS (SELECT 1 FROM pg_indexes
    WHERE schemaname='agency' AND tablename='nexus_reservation_deliveries')
THEN 'ready' ELSE 'missing' END;
'@
$result = @(& $psql -X -w -v ON_ERROR_STOP=1 -At -h $env:PGHOST -p $env:PGPORT `
  -U $env:PGUSER -d $env:PGDATABASE -c $sql)
if ($LASTEXITCODE -ne 0 -or $result.Count -ne 1 -or $result[0] -ne 'ready') {
  throw 'NEXUS reservation queue schema is incomplete.'
}
Write-Output 'NEXUS reservation queue schema ready (read-only check).'
