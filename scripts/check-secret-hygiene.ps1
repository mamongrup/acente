param(
  [string]$EnvPath = ".env",
  # SECRET_KEY_BASE icin beklenen rotasyon araligi (gun). Denetim: son kayitli
  # rotasyon yaşı bu aralığın üstündeyse başarısız; hiç kayıt yoksa da
  # başarısız (fail-closed — kayıtsız sır denetlenemez).
  [int]$SecretKeyRotationMaxDays = 180,
  # Rotasyon yaşı beklenen aralığı aştığında denetimi kırıp kırmama.
  # Set edilirse: aralık aşımı yalnız uyarı (exit 0). Set edilmezse (varsayılan):
  # aralık aşımı hygiene hatası (throw).
  [switch]$WarnOnly
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $EnvPath)) {
  throw "Env file not found: $EnvPath"
}

Get-Content $EnvPath | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith("#")) { return }
  $index = $line.IndexOf("=")
  if ($index -gt 0) {
    Set-Item "Env:$($line.Substring(0, $index).Trim())" $line.Substring($index + 1).Trim()
  }
}

$psql = "C:/laragon/bin/postgresql/postgresql/bin/psql.exe"
if (!(Test-Path $psql)) {
  $cmd = Get-Command psql -ErrorAction SilentlyContinue
  if (!$cmd) { throw "psql not found." }
  $psql = $cmd.Source
}

function Invoke-ScalarSql([string]$Sql) {
  $out = & $psql -X -w -v ON_ERROR_STOP=1 -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -At -c $Sql
  if ($LASTEXITCODE -ne 0) {
    throw "PostgreSQL command failed: $LASTEXITCODE"
  }
  if (!$out) { return 0 }
  return [int]($out | Select-Object -First 1)
}

function Test-Table([string]$QualifiedName) {
  $exists = & $psql -X -w -v ON_ERROR_STOP=1 -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -At -c "select case when to_regclass('$QualifiedName') is null then 0 else 1 end"
  if ($LASTEXITCODE -ne 0) {
    throw "PostgreSQL command failed: $LASTEXITCODE"
  }
  return (($exists | Select-Object -First 1) -eq "1")
}

$checks = [ordered]@{}

$checks["settings_plain"] = Invoke-ScalarSql @"
select count(*)::int
from agency.settings
where key in ('parampos_password','parampos_guid','smtp_password','ai_api_key','netgsm_password')
  and coalesce(value::text,'') not in ('','null','""')
"@

$checks["integration_plain"] = Invoke-ScalarSql @"
select count(*)::int
from agency.integrations
where credentials ?| array[
  'password','api_key','token','netgsm_pass','whatsapp_token',
  'access_token','pinterest_token','parampos_password','parampos_guid',
  'username','guid'
]
"@

$checks["ai_pool_plain"] = if (Test-Table "agency.ai_key_pool") {
  Invoke-ScalarSql @"
select count(*)::int
from agency.ai_key_pool
where coalesce(api_key_encrypted,'') <> ''
  and api_key_encrypted not like 'v1:%'
"@
} else { 0 }

$checks["ai_provider_plain"] = if (Test-Table "agency.ai_provider_configs") {
  Invoke-ScalarSql @"
select count(*)::int
from agency.ai_provider_configs
where coalesce(token_encrypted,'') <> ''
  and token_encrypted not like 'v1:%'
"@
} else { 0 }

$checks["payment_card_columns"] = Invoke-ScalarSql @"
select count(*)::int
from information_schema.columns
where table_schema = 'agency'
  and (
    lower(column_name) in ('card_number','cardnumber','pan','cvv','cvc')
    or lower(column_name) like '%card_number%'
    or lower(column_name) like '%cvv%'
    or lower(column_name) like '%cvc%'
  )
"@

$failed = @()
foreach ($name in $checks.Keys) {
  $count = [int]$checks[$name]
  Write-Host "$name=$count"
  if ($count -ne 0) {
    $failed += "$name=$count"
  }
}

# ---------------------------------------------------------------------------
# SECRET_KEY_BASE rotasyon yaşı — kayıt yoksa "bilinmiyor" → fail-closed.
# Kaynak: agency.secret_rotations (db/migrations/238_secret_rotation_baseline.sql,
# kayıt: scripts/record-secret-rotation.ps1).
# ---------------------------------------------------------------------------
$hasRotationTable = Test-Table "agency.secret_rotations"
$rotationStatus = "unknown"
$rotationDays = $null
if ($hasRotationTable) {
  $latest = & $psql -X -w -v ON_ERROR_STOP=1 -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -At -c @"
select coalesce(extract(day from now() - max(rotated_at))::int, -1)
from agency.secret_rotations
where secret_name = 'SECRET_KEY_BASE'
"@
  if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed: $LASTEXITCODE" }
  $days = [int]($latest | Select-Object -First 1)
  if ($days -ge 0) {
    $rotationDays = $days
    if ($days -gt $SecretKeyRotationMaxDays) { $rotationStatus = "overdue" } else { $rotationStatus = "ok" }
  }
}

Write-Host "secret_key_rotation_status=$rotationStatus days=$rotationDays max_days=$SecretKeyRotationMaxDays"
if ($rotationStatus -eq "unknown") {
  $failed += "secret_key_rotation=unknown (kayit yok; scripts/record-secret-rotation.ps1 ile baseline alin)"
} elseif ($rotationStatus -eq "overdue") {
  $msg = "secret_key_rotation overdue: $rotationDays gun (beklenen aralik: en fazla $SecretKeyRotationMaxDays gun) -- rotasyon yapin (docs/secret-rotation-plan.md)"
  if ($WarnOnly) { Write-Warning $msg } else { $failed += $msg }
}

if ($failed.Count -gt 0) {
  throw "Secret hygiene check failed: $($failed -join ', ')"
}

Write-Host "Secret hygiene check passed."
