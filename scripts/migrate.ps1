param(
  [string]$EnvPath = '.env'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$envFile = if ([IO.Path]::IsPathRooted($EnvPath)) { $EnvPath } else { Join-Path $root $EnvPath }
if (!(Test-Path -LiteralPath $envFile)) { throw 'Önce .env.example dosyasını .env olarak kopyalayıp veritabanı bilgilerini girin.' }
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim(); $index = $line.IndexOf('=')
  if ($index -gt 0) { Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim() }
}
$pg = if ($env:PSQL_EXECUTABLE) {
  $env:PSQL_EXECUTABLE
} else {
  (Get-Command psql -ErrorAction Stop).Source
}
$common = @('-X','-w','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE)
# Wrong-database guard: the NEXUS platform's root schema is 'catalog'. If it
# exists in the target database, .env points at a platform database and the
# agency migration chain must never touch it.
$foreignSchema = ((& $pg @common -Atc "SELECT count(*) FROM pg_namespace WHERE nspname='catalog'") | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Yanlış veritabanı kontrolü çalıştırılamadı' }
if ($foreignSchema -ne '0') { throw "Hedef veritabanı bir NEXUS platform veritabanı gibi görünüyor: 'catalog' şeması mevcut ($($env:PGDATABASE)). Acente migration'ları uygulanmadı; .env içindeki PGDATABASE/PGPORT değerlerini kontrol edin." }
& $pg @common -v ON_ERROR_STOP=1 -c 'CREATE SCHEMA IF NOT EXISTS system; CREATE TABLE IF NOT EXISTS system.schema_migrations (version text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now());'
if ($LASTEXITCODE -ne 0) { throw 'Migration takip tablosu oluşturulamadı' }
$files = Get-ChildItem (Join-Path $root 'db/migrations') -Filter '*.sql' | Sort-Object Name
# Legacy migrations grant to the NEXUS operator roles (nexus_owner/nexus_app).
# Neither role exists on a standalone agency installation; detect their
# absence once and omit only those grant lines at apply time (source files
# and their recorded checksums stay untouched).
$missingLegacyRoles = @()
foreach ($legacyRole in @('nexus_owner', 'nexus_app')) {
  $roleExists = ((& $pg @common -Atc "SELECT 1 FROM pg_roles WHERE rolname='$legacyRole'") | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) { throw "Could not check optional $legacyRole role." }
  if (!$roleExists) { $missingLegacyRoles += $legacyRole }
}
# Preflight: aynı sayısal öneki paylaşan dosyalar varsa uyar (version tam dosya adı olduğu
# için güvenlidir ama karışıklığa yol açar; yenileri için benzersiz numara kullanılmalı).
$files | ForEach-Object { if ($_.BaseName -match '^(\d{3})_') { [pscustomobject]@{ Num = $Matches[1]; Name = $_.Name } } } |
  Group-Object Num | Where-Object { $_.Count -gt 1 } | ForEach-Object {
    Write-Warning ("Duplicate migration number {0}: {1}" -f $_.Name, (($_.Group | ForEach-Object Name) -join ', '))
  }
foreach ($file in $files) {
  $version = $file.BaseName
  $rawHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  # Git can check out the same SQL as CRLF on Windows and LF on Linux. Keep
  # accepting hashes already recorded from raw bytes while recording a stable
  # checksum for new migrations on either platform.
  $normalized = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8).Replace("`r`n", "`n").Replace("`r", "`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($normalized))).Replace('-', '')
  } finally {
    $sha.Dispose()
  }
  $old = ((& $pg @common -Atc "SELECT checksum FROM system.schema_migrations WHERE version='$version'") | Out-String).Trim()
  if ($old) {
    if ($old -ne $hash -and $old -ne $rawHash) { throw "Uygulanmış migration değişmiş: $version" }
    continue
  }
  $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
  if ($version -eq '024_runtime_compatibility') {
    # Leftover marker: line 6 of this migration grants CONNECT on the
    # pre-split platform database 'nexustraveltech', which the 5432 cluster
    # cleanup dropped (docs/db-cluster-cleanup-plan.md). Applied-migration
    # checksums are immutable, so the source line stays untouched and is
    # retired at apply time: when the platform database is absent from this
    # cluster the grant is omitted with an explicit leftover marker, and
    # migration 258_retire_platform_db_grant revokes it on clusters that
    # still host the platform database.
    $nexusDatabase = ((& $pg @common -Atc "SELECT 1 FROM pg_database WHERE datname='nexustraveltech'") | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not check optional NEXUS database.' }
    if (!$nexusDatabase) {
      $legacyGrant = 'GRANT CONNECT ON DATABASE nexustraveltech TO agency_app;'
      if (!$content.Contains($legacyGrant)) { throw 'Legacy migration 024 changed unexpectedly.' }
      $content = $content.Replace($legacyGrant, "-- Leftover grant to the pre-split platform database 'nexustraveltech' (dropped by the 5432 cluster cleanup); omitted on this standalone agency.")
    }
  }
  foreach ($legacyRole in $missingLegacyRoles) {
    if ($content.Contains("$legacyRole;") -or $content.Contains("$legacyRole, ")) {
      $patched = $content `
        -replace "(?m)^GRANT [^\r\n]*?TO $legacyRole;\s*$", "-- $legacyRole role is absent on this standalone agency; grant omitted." `
        -replace "(?m)^TO $legacyRole;\s*$", "-- $legacyRole role is absent on this standalone agency; grant omitted." `
        -replace ", $legacyRole;", ";" `
        -replace "$legacyRole, ", ""
      if ($patched -eq $content) { throw "Legacy grant to $legacyRole could not be omitted." }
      $content = $patched
    }
  }
  if ($version -eq '072_user_wizard_prefs') {
    # PostgreSQL cannot replace a RETURNS TABLE function with a new column.
    # This historical migration omitted the drops used by migrations 071/074.
    # Keep its recorded checksum intact and repair only the execution text.
    if (!$content.Contains('CREATE OR REPLACE FUNCTION auth.session(p_token text)') -or
        !$content.Contains('CREATE OR REPLACE FUNCTION agency_auth.session(p_token text)')) {
      throw 'Legacy migration 072 changed unexpectedly.'
    }
    $content = "DROP FUNCTION IF EXISTS auth.session(text);`nDROP FUNCTION IF EXISTS agency_auth.session(text);`n$content"
  }
  if ($version -eq '192_seed_new_tenant_catalog') {
    # The initial tenant may be the only canonical source on a fresh install.
    # Let an already complete tenant seed itself; a new tenant still selects
    # another complete tenant because it has no categories yet.
    $legacySource = 'WHERE c.tenant_id<>p_tenant AND c.parent_id IS NULL AND c.active'
    if (!$content.Contains($legacySource)) { throw 'Legacy migration 192 changed unexpectedly.' }
    $content = $content.Replace($legacySource, 'WHERE c.parent_id IS NULL AND c.active')
  }
  $temp = Join-Path $root '.local/migration.sql'
  New-Item -ItemType Directory -Force -Path (Split-Path $temp) | Out-Null
  try {
    "BEGIN;`n$content`nINSERT INTO system.schema_migrations(version, checksum) VALUES ('$version', '$hash');`nCOMMIT;" | Set-Content -LiteralPath $temp -Encoding utf8
    & $pg @common -v ON_ERROR_STOP=1 -f $temp
    if ($LASTEXITCODE -ne 0) { throw "Migration başarısız: $version" }
  } finally {
    Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue
  }
}
