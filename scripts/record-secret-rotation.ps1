param(
  # Rotasyonu kaydedilen sır (varsayılan SECRET_KEY_BASE).
  [ValidateSet("SECRET_KEY_BASE", "NEXUS_CONFIG_KEY")]
  [string]$Name = "SECRET_KEY_BASE",
  # Rotasyon kaydına eklenen kaynak etiketi (ör. "planned", "emergency").
  [string]$Source = "manual",
  [string]$EnvPath = ".env"
)

# Rotasyon tarihini agency.secret_rotations tablosuna yazar.
#
# check-secret-hygiene.ps1'in rotasyon yaşı kontrolü bu tabloyu okur: kayıt
# yoksa kontrol "bilinmiyor" der ve başarısız olur (fail-closed). Bu yüzden
# SECRET_KEY_BASE ilk kez değiştirilmeden önce mevcut sırrın devreye alınma
# tarihi baseline olarak kaydedilmelidir.
#
# Tablo kalıcı DDL ile db/migrations/238_secret_rotation_baseline.sql içinde
# taşınır; bu betik yalnızca tablo henüz yoksa idempotent oluşturur ve aynı
# sırrı 5 dakika içinde tekrar kaydetmez (idempotent kayıt).

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$resolvedEnv = if ([IO.Path]::IsPathRooted($EnvPath)) { $EnvPath } else { Join-Path $root $EnvPath }
if (!(Test-Path -LiteralPath $resolvedEnv)) { throw "Env file not found: $resolvedEnv" }

$values = @{}
Get-Content -LiteralPath $resolvedEnv | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith('#')) { return }
  $index = $line.IndexOf('=')
  if ($index -gt 0) { $values[$line.Substring(0, $index).Trim()] = $line.Substring($index + 1).Trim() }
}

foreach ($key in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD')) {
  if (!$values.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$values[$key])) {
    throw "$key is required."
  }
}

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (!$psql) {
  $psql = Get-ChildItem 'C:\laragon\bin\postgresql\*\bin\psql.exe' -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
}
if (!$psql) { throw 'psql executable not found.' }

$nameEscaped = $Name -replace "'", "''"
$sourceEscaped = $Source -replace "'", "''"

$sql = @"
CREATE TABLE IF NOT EXISTS agency.secret_rotations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  secret_name varchar(64) NOT NULL,
  rotated_at timestamptz NOT NULL DEFAULT now(),
  source varchar(64) NOT NULL DEFAULT 'manual'
);
CREATE INDEX IF NOT EXISTS agency_secret_rotations_name_time_idx
  ON agency.secret_rotations(secret_name, rotated_at DESC);
INSERT INTO agency.secret_rotations(secret_name, source)
SELECT '$nameEscaped', left('$sourceEscaped', 64)
WHERE NOT EXISTS (
  SELECT 1 FROM agency.secret_rotations
   WHERE secret_name = '$nameEscaped'
     AND rotated_at > now() - interval '5 minutes'
);
"@

$env:PGPASSWORD = [string]$values['PGPASSWORD']
try {
  & $psql.Source -v ON_ERROR_STOP=1 -h $values['PGHOST'] -p $values['PGPORT'] `
    -U $values['PGUSER'] -d $values['PGDATABASE'] `
    -c $sql
  if ($LASTEXITCODE -ne 0) { throw "Rotation record failed with exit code $LASTEXITCODE" }
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

Write-Host "Rotasyon kaydedildi: $Name (source=$Source)."
Write-Host "Not: gercek rotasyon tarihinden farkli bir baseline kaydediyorsaniz, rotasyon denetiminin dogru calismasi icin tarihi DB'den duzeltin."
