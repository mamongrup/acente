$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
if (!(Test-Path -LiteralPath $envFile)) { throw 'Önce .env.example dosyasını .env olarak kopyalayıp veritabanı bilgilerini girin.' }
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim(); $index = $line.IndexOf('=')
  if ($index -gt 0) { Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim() }
}
$pg = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
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
  $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  $old = ((& $pg @common -Atc "SELECT checksum FROM system.schema_migrations WHERE version='$version'") | Out-String).Trim()
  if ($old) {
    if ($old -ne $hash) { throw "Uygulanmış migration değişmiş: $version" }
    continue
  }
  $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
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
