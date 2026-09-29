param(
  [string]$EnvPath = ".env"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$resolvedEnv = Join-Path $root $EnvPath
if (!(Test-Path -LiteralPath $resolvedEnv)) { throw "Env file not found: $resolvedEnv" }

Get-Content -LiteralPath $resolvedEnv | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith("#")) { return }
  $index = $line.IndexOf("=")
  if ($index -gt 0) {
    Set-Item "Env:$($line.Substring(0, $index).Trim())" $line.Substring($index + 1).Trim()
  }
}

$psql = "psql"
$laragonPsql = "C:/laragon/bin/postgresql/postgresql/bin/psql.exe"
if (Test-Path -LiteralPath $laragonPsql) { $psql = $laragonPsql }

function Invoke-ScalarSql([string]$Sql) {
  $result = & $psql -X -w -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -At -c $Sql
  if ($LASTEXITCODE -ne 0) { throw "SQL failed: $Sql" }
  return ($result | Select-Object -First 1)
}

$checks = [ordered]@{}
$checks["legacy_categories"] = Invoke-ScalarSql @"
select count(*) from agency.categories
where code in (
  'villa','VILLA','OTEL','YAT','TUR','AKTIVITE','UCUS','ARAC',
  'KRUVAZIYER','HAC_UMRE','VIZE','FERIBOT','TRANSFER','SEZLONG',
  'SINEMA','ETKINLIK','RESTORAN','OTOBUS'
);
"@

$checks["legacy_listing_categories"] = Invoke-ScalarSql @"
select count(*) from agency.listings
where category in (
  'villa','VILLA','OTEL','YAT','TUR','AKTIVITE','UCUS','ARAC',
  'KRUVAZIYER','HAC_UMRE','VIZE','FERIBOT','TRANSFER','SEZLONG',
  'SINEMA','ETKINLIK','RESTORAN','OTOBUS'
);
"@

$checks["plain_setting_secrets"] = Invoke-ScalarSql @"
select count(*) from agency.settings
where key in ('parampos_password','parampos_guid','smtp_password','ai_api_key','netgsm_password');
"@

$checks["plain_integration_secrets"] = Invoke-ScalarSql @"
select count(*) from agency.integrations
where credentials ?| array[
  'password','api_key','token','netgsm_pass','whatsapp_token',
  'access_token','pinterest_token','parampos_password','parampos_guid','guid'
];
"@

$checks["unvalidated_cleanup_constraints"] = Invoke-ScalarSql @"
select count(*) from pg_constraint
where conname in (
  'agency_settings_no_plain_secret_keys',
  'agency_integrations_no_plain_secret_credentials',
  'agency_categories_no_legacy_main_codes',
  'agency_listings_no_legacy_main_categories'
)
and not convalidated;
"@

$checks.GetEnumerator() | ForEach-Object {
  Write-Host "$($_.Key)=$($_.Value)"
  if ([int]$_.Value -ne 0) {
    throw "Legacy cleanup check failed: $($_.Key)=$($_.Value)"
  }
}

Write-Host "Legacy cleanup check passed."

