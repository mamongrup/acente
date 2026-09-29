param(
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if (!$line -or $line.StartsWith('#')) { return }
    $index = $line.IndexOf('=')
    if ($index -gt 0) {
      Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim()
    }
  }
}

$psql = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'

function Invoke-AgencySql([string]$sql, [switch]$RowsOnly) {
  $arguments = @(
    '-X', '-w', '-v', 'ON_ERROR_STOP=1',
    '-h', $env:PGHOST,
    '-p', $env:PGPORT,
    '-U', $env:PGUSER,
    '-d', $env:PGDATABASE
  )
  if ($RowsOnly) { $arguments += @('-At', '-q') }
  $arguments += @('-c', $sql)
  $result = & $psql @arguments
  if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed with exit code $LASTEXITCODE" }
  return @($result)
}

function SqlQuote([string]$value) {
  return "'" + ($value -replace "'", "''") + "'"
}

function Get-ConfigSecretKey {
  $key = [string]$env:NEXUS_CONFIG_KEY
  if (!$key -or $key.Trim().Length -lt 64) { $key = [string]$env:SECRET_KEY_BASE }
  if (!$key -or $key.Trim().Length -lt 64) {
    throw 'NEXUS_CONFIG_KEY veya SECRET_KEY_BASE en az 64 karakter olmalı.'
  }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($key.Trim())) }
  finally { $sha.Dispose() }
}

function Seal-Secret([string]$tenantId, [string]$field, [string]$value) {
  if (!$value) { return '' }
  $key = Get-ConfigSecretKey
  $nonce = New-Object byte[] 12
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($nonce) }
  finally { $rng.Dispose() }
  $plain = [System.Text.Encoding]::UTF8.GetBytes($value)
  $cipher = New-Object byte[] $plain.Length
  $tag = New-Object byte[] 16
  $aad = [System.Text.Encoding]::UTF8.GetBytes("${tenantId}:agency.integrations:${field}")
  $aes = [System.Security.Cryptography.AesGcm]::new($key)
  try { $aes.Encrypt($nonce, $plain, $cipher, $tag, $aad) }
  finally { $aes.Dispose() }
  $raw = New-Object byte[] ($nonce.Length + $tag.Length + $cipher.Length)
  [Array]::Copy($nonce, 0, $raw, 0, $nonce.Length)
  [Array]::Copy($tag, 0, $raw, $nonce.Length, $tag.Length)
  [Array]::Copy($cipher, 0, $raw, $nonce.Length + $tag.Length, $cipher.Length)
  return 'v1:' + [Convert]::ToBase64String($raw)
}

function Seal-SettingRows {
  $settingKeys = @(
    'smtp_password',
    'ai_api_key',
    'netgsm_password',
    'parampos_password',
    'parampos_guid'
  )
  $inList = ($settingKeys | ForEach-Object { SqlQuote $_ }) -join ','
  $query = @"
select json_build_object(
  'tenant_id', tenant_id::text,
  'key', key,
  'value', trim(both chr(34) from value::text)
)::text
from agency.settings s
where key in ($inList)
  and coalesce(trim(both chr(34) from value::text),'') <> ''
  and not exists (
    select 1 from agency.settings sealed
    where sealed.tenant_id=s.tenant_id
      and sealed.key=s.key || '_sealed'
      and coalesce(trim(both chr(34) from sealed.value::text),'') <> ''
  )
"@
  $count = 0
  foreach ($line in (Invoke-AgencySql $query -RowsOnly)) {
    if (!$line) { continue }
    $row = $line | ConvertFrom-Json
    $tenantId = [string]$row.tenant_id
    $key = [string]$row.key
    $sealedKey = "${key}_sealed"
    $sealed = Seal-Secret $tenantId "settings.$key" ([string]$row.value)
    $count++
    if ($Apply) {
      $sql = @"
with saved as (
  insert into agency.settings(tenant_id,key,value,updated_at)
  values($(SqlQuote $tenantId)::uuid,$(SqlQuote $sealedKey),to_jsonb($(SqlQuote $sealed)::text),now())
  on conflict(tenant_id,key) do update set value=excluded.value, updated_at=now()
  returning 1
)
delete from agency.settings where tenant_id=$(SqlQuote $tenantId)::uuid and key=$(SqlQuote $key)
"@
      Invoke-AgencySql $sql | Out-Null
    }
  }
  return $count
}

function Seal-IntegrationRows {
  $fieldMap = @(
    @{ plain = 'password'; sealed = 'password_sealed'; context = 'integration.password' },
    @{ plain = 'api_key'; sealed = 'api_key_sealed'; context = 'integration.api_key' },
    @{ plain = 'token'; sealed = 'token_sealed'; context = 'integration.token' },
    @{ plain = 'netgsm_pass'; sealed = 'netgsm_pass_sealed'; context = 'integration.netgsm_pass' },
    @{ plain = 'whatsapp_token'; sealed = 'whatsapp_token_sealed'; context = 'integration.whatsapp_token' },
    @{ plain = 'access_token'; sealed = 'access_token_sealed'; context = 'integration.access_token' },
    @{ plain = 'pinterest_token'; sealed = 'pinterest_token_sealed'; context = 'integration.pinterest_token' }
  )

  $query = @"
select json_build_object(
  'tenant_id', tenant_id::text,
  'provider', provider,
  'kind', kind,
  'credentials', credentials
)::text
from agency.integrations
where credentials ?| array['password','api_key','token','netgsm_pass','whatsapp_token','access_token','pinterest_token']
"@
  $count = 0
  foreach ($line in (Invoke-AgencySql $query -RowsOnly)) {
    if (!$line) { continue }
    $row = $line | ConvertFrom-Json
    $tenantId = [string]$row.tenant_id
    foreach ($field in $fieldMap) {
      $plainName = [string]$field.plain
      $sealedName = [string]$field.sealed
      if ($row.credentials.PSObject.Properties.Name -notcontains $plainName) { continue }
      $plainValue = [string]$row.credentials.$plainName
      if (!$plainValue) { continue }
      if ($row.credentials.PSObject.Properties.Name -contains $sealedName -and [string]$row.credentials.$sealedName) { continue }

      $sealed = Seal-Secret $tenantId ([string]$field.context) $plainValue
      $count++
      if ($Apply) {
        $sql = @"
update agency.integrations
set credentials=(credentials - $(SqlQuote $plainName)) || jsonb_build_object($(SqlQuote $sealedName), $(SqlQuote $sealed))
where tenant_id=$(SqlQuote $tenantId)::uuid
  and provider=$(SqlQuote ([string]$row.provider))
  and kind=$(SqlQuote ([string]$row.kind))
"@
        Invoke-AgencySql $sql | Out-Null
      }
    }
  }
  return $count
}

function Seal-AiPoolRows {
  $query = @"
select json_build_object(
  'tenant_id', tenant_id::text,
  'id', id::text,
  'value', api_key_encrypted
)::text
from agency.ai_key_pool
where coalesce(api_key_encrypted,'') <> ''
  and api_key_encrypted not like 'v1:%'
"@
  $count = 0
  foreach ($line in (Invoke-AgencySql $query -RowsOnly)) {
    if (!$line) { continue }
    $row = $line | ConvertFrom-Json
    $tenantId = [string]$row.tenant_id
    $sealed = Seal-Secret $tenantId 'ai_pool.api_key' ([string]$row.value)
    $count++
    if ($Apply) {
      $sql = @"
update agency.ai_key_pool
set api_key_encrypted=$(SqlQuote $sealed), updated_at=now()
where tenant_id=$(SqlQuote $tenantId)::uuid
  and id=$(SqlQuote ([string]$row.id))::uuid
  and api_key_encrypted=$(SqlQuote ([string]$row.value))
"@
      Invoke-AgencySql $sql | Out-Null
    }
  }
  return $count
}

function Seal-AiProviderRows {
  $query = @"
select json_build_object(
  'tenant_id', tenant_id::text,
  'provider', provider,
  'model', model,
  'value', token_encrypted
)::text
from agency.ai_providers
where coalesce(token_encrypted,'') <> ''
  and token_encrypted not like 'v1:%'
"@
  $count = 0
  foreach ($line in (Invoke-AgencySql $query -RowsOnly)) {
    if (!$line) { continue }
    $row = $line | ConvertFrom-Json
    $tenantId = [string]$row.tenant_id
    $sealed = Seal-Secret $tenantId 'ai_provider.api_key' ([string]$row.value)
    $count++
    if ($Apply) {
      $sql = @"
update agency.ai_providers
set token_encrypted=$(SqlQuote $sealed)
where tenant_id=$(SqlQuote $tenantId)::uuid
  and provider=$(SqlQuote ([string]$row.provider))
  and model=$(SqlQuote ([string]$row.model))
  and token_encrypted=$(SqlQuote ([string]$row.value))
"@
      Invoke-AgencySql $sql | Out-Null
    }
  }
  return $count
}

try {
  $settings = Seal-SettingRows
  $integrations = Seal-IntegrationRows
  $aiPool = Seal-AiPoolRows
  $aiProviders = Seal-AiProviderRows
  $mode = if ($Apply) { 'APPLIED' } else { 'DRY-RUN' }
  Write-Host "[$mode] Settings secrets found: $settings"
  Write-Host "[$mode] Integration secrets found: $integrations"
  Write-Host "[$mode] AI pool keys found: $aiPool"
  Write-Host "[$mode] AI provider tokens found: $aiProviders"
  if (!$Apply) {
    Write-Host 'Gerçek dönüşüm için: powershell -ExecutionPolicy Bypass -File scripts/seal-legacy-secrets.ps1 -Apply'
  }
} catch {
  Write-Error "Legacy secret sealing tamamlanamadı: $($_.Exception.Message)"
  Write-Error "PostgreSQL erişimini ve .env içindeki PGHOST/PGPORT/PGDATABASE/PGUSER değerlerini kontrol edin."
  exit 1
}
