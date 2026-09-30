param([string]$EnvPath = '.env')

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$settings = @{}
Get-Content -LiteralPath (Join-Path $root $EnvPath) | ForEach-Object {
  if ($_ -match '^([^#=]+)=(.*)$') { $settings[$Matches[1].Trim()] = $Matches[2].Trim() }
}
$previousPassword = $env:PGPASSWORD
try {
  $env:PGPASSWORD = $settings.PGPASSWORD
  & psql -X -w -v ON_ERROR_STOP=1 -h $settings.PGHOST -p $settings.PGPORT `
    -U $settings.PGUSER -d $settings.PGDATABASE `
    -f (Join-Path $root 'test/wp2_sales_chain_lifecycle_and_race_guards.sql')
  if ($LASTEXITCODE -ne 0) { throw 'Acente WP2 satış zinciri testi başarısız.' }
  & psql -X -w -v ON_ERROR_STOP=1 -h $settings.PGHOST -p $settings.PGPORT `
    -U $settings.PGUSER -d $settings.PGDATABASE `
    -f (Join-Path $root 'test/wp2_parampos_refund_unknown.sql')
  if ($LASTEXITCODE -ne 0) { throw 'ParamPOS belirsiz iade koruma testi başarısız.' }
  Write-Output 'Acente WP2 satış zinciri testi geçti.'
} finally {
  $env:PGPASSWORD = $previousPassword
}
