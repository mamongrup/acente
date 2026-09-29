$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Get-Content -LiteralPath (Join-Path $root '.env') | ForEach-Object {
  $line = $_.Trim()
  $index = $line.IndexOf('=')
  if ($index -gt 0 -and !$line.StartsWith('#')) {
    Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim()
  }
}
$pg = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
foreach ($test in @('tenant_catalog_bootstrap.sql','connected_standalone_checkout.sql','public_inquiry_listing_scope.sql')) {
  & $pg -X -w -v ON_ERROR_STOP=1 -h $env:PGHOST -p $env:PGPORT `
    -U $env:PGUSER -d $env:PGDATABASE -f (Join-Path $root "test/$test")
  if ($LASTEXITCODE -ne 0) { throw "Agency mode check failed: $test" }
}
