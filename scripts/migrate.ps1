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
& $pg @common -v ON_ERROR_STOP=1 -c 'CREATE SCHEMA IF NOT EXISTS system; CREATE TABLE IF NOT EXISTS system.schema_migrations (version text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now());'
if ($LASTEXITCODE -ne 0) { throw 'Migration takip tablosu oluşturulamadı' }
$files = Get-ChildItem (Join-Path $root 'db/migrations') -Filter '*.sql' | Sort-Object Name
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
    # This legacy migration grants access to the separate NEXUS database.
    # A standalone agency has no such database. Preserve the source checksum
    # while omitting only that irrelevant grant during a fresh installation.
    $nexusDatabase = ((& $pg @common -Atc "SELECT 1 FROM pg_database WHERE datname='nexustraveltech'") | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not check optional NEXUS database.' }
    if (!$nexusDatabase) {
      $legacyGrant = 'GRANT CONNECT ON DATABASE nexustraveltech TO agency_app;'
      if (!$content.Contains($legacyGrant)) { throw 'Legacy migration 024 changed unexpectedly.' }
      $content = $content.Replace($legacyGrant, '-- Optional NEXUS database is absent on this standalone agency.')
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
