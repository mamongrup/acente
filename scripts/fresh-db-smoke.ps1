# Fresh-database smoke: runs the whole agency chain end to end on a
# throwaway empty database, outside CI too.
#   1) DROP IF EXISTS + CREATE a scratch database on the .env cluster
#   2) a temporary .env is written and scripts/migrate.ps1 applies the
#      migration chain on the scratch database (guard sim + legacy-role
#      grant patching included)
#   3) scripts/run-db-tests.ps1 runs the db/tests fixture chain + the
#      test/*.sql acceptance layer on it, with agency_app application
#      privileges when the scratch database is owned by agency_app
#   4) DROP the scratch database (kept for inspection with -Keep)
# Guard rails: the name must be a safe identifier and must differ from the
# live .env database and system databases. The control connection is the
# connecting user itself: on CI .env says PGUSER=postgres, on a local
# agency install it is agency_app, which owns the live database but cannot
# CREATE DATABASE - pass an administrator explicitly there:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/fresh-db-smoke.ps1 `
#     -DbHost 127.0.0.1 -Port 5432 -User postgres -Password <postgres-sifresi>
# ASCII only (PowerShell 5.1 ANSI rule for BOM-less UTF-8).
#
# Ornek:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/fresh-db-smoke.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/fresh-db-smoke.ps1 -Keep -ScratchDatabase agency_fresh_smoke_dev
param(
  [string]$DbHost,
  [string]$Port,
  [string]$User,
  [string]$Password,
  [string]$ScratchDatabase = 'agency_fresh_smoke',
  [switch]$Keep
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
if (!(Test-Path -LiteralPath $envFile)) { throw '.env bulunamadi; once .env.example dosyasini .env olarak kopyalayin.' }
# Ortamda zaten tanimli anahtarlari .env ezmez (CI ortami onceliklidir).
Get-Content -LiteralPath $envFile | ForEach-Object {
  $line = $_.Trim(); $i = $line.IndexOf('=')
  if ($i -gt 0) {
    $k = $line.Substring(0, $i).Trim()
    if (![Environment]::GetEnvironmentVariable($k)) {
      Set-Item "Env:$k" $line.Substring($i + 1).Trim()
    }
  }
}
if (!$DbHost) { $DbHost = $env:PGHOST }
if (!$Port) { $Port = $env:PGPORT }
if (!$User) { $User = $env:PGUSER }
if (!$Password) { $Password = $env:PGPASSWORD }
foreach ($pair in @(@('PGHOST', $DbHost), @('PGPORT', $Port), @('PGUSER', $User), @('PGPASSWORD', $Password))) {
  if (!$pair[1]) { throw "Baglanti bilgisi eksik: $($pair[0]) (parametre, ortam degiskeni veya .env ile verilmeli)" }
}
if ($ScratchDatabase -notmatch '^[a-z_][a-z0-9_]{0,62}$') { throw "Gecersiz scratch veritabani adi: '$ScratchDatabase' (beklenen [a-z_][a-z0-9_]*)" }
if ($ScratchDatabase -in @('postgres', 'template0', 'template1')) { throw "Scratch veritabani adi sistem veritabani olamaz: $ScratchDatabase" }
$liveDatabase = $env:PGDATABASE
if (!$liveDatabase) { throw 'PGDATABASE eksik: canli veritabani adi belirlenemedi.' }
if ($ScratchDatabase -eq $liveDatabase) { throw "Scratch veritabani canli veritabanindan farkli olmali: $liveDatabase" }

# Kontrol kumesi (postgres veritabanina) ve scratch hedefi icin ortak baglanti.
$control = @('-X', '-w', '-v', 'ON_ERROR_STOP=1', '-h', $DbHost, '-p', $Port, '-U', $User, '-d', 'postgres')
$target = @('-X', '-w', '-v', 'ON_ERROR_STOP=1', '-h', $DbHost, '-p', $Port, '-U', $User, '-d', $ScratchDatabase)
$psql = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
if (!(Test-Path -LiteralPath $psql)) {
  $cmd = Get-Command psql -ErrorAction SilentlyContinue
  if (!$cmd) { throw 'psql executable not found.' }
  $psql = $cmd.Source
}

# migrate.ps1 .env'i kendi surecine yukler; sonunda eski degerlere geri koy.
$oldEnv = @{}
foreach ($name in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD')) {
  $oldEnv[$name] = [Environment]::GetEnvironmentVariable($name)
}
$tempEnv = Join-Path ([IO.Path]::GetTempPath()) ("fresh-db-smoke-" + [Guid]::NewGuid().ToString('N') + ".env")
try {
  $env:PGPASSWORD = $Password

  Write-Host "[fresh-db-smoke] 1/4 scratch veritabani hazirlaniyor: $ScratchDatabase (canli: $liveDatabase)"
  & $psql @control -c "DROP DATABASE IF EXISTS $ScratchDatabase WITH (FORCE);" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Scratch veritabani dustulemedi (DROP).' }
  & $psql @control -c "CREATE DATABASE $ScratchDatabase OWNER $User;"
  if ($LASTEXITCODE -ne 0) { throw 'Scratch veritabani yaratilamadi (CREATE).' }

  Write-Host '[fresh-db-smoke] 2/4 migration zinciri uygulaniyor (scripts/migrate.ps1)'
  @(
    "PGHOST=$DbHost",
    "PGPORT=$Port",
    "PGDATABASE=$ScratchDatabase",
    "PGUSER=$User",
    "PGPASSWORD=$Password",
    "PSQL_EXECUTABLE=$psql"
  ) | Set-Content -LiteralPath $tempEnv -Encoding ASCII
  & (Join-Path $root 'scripts/migrate.ps1') -EnvPath $tempEnv
  if ($LASTEXITCODE -ne 0) { throw 'Migration zinciri taze veritabaninda basarisiz.' }

  Write-Host '[fresh-db-smoke] 3/4 SQL kabul katmani kosturuluyor (scripts/run-db-tests.ps1)'
  # Baglanti cozumlemesi: parametre > ortam degiskeni > .env. Acente .env'i
  # yerelde agency_app yazar; taze zincir postgres ile uygulandigi icin kabul
  # katmanini ayni baglanti kullanilir (CI'da postgres, yerelde acik admin
  # kimligiyle kosulur; CI db-acceptance ise agency_app perspektifini
  # ayrica dogrular).
  & (Join-Path $root 'scripts/run-db-tests.ps1') -DbHost $DbHost -Port $Port -Database $ScratchDatabase -User $User -Password $Password
  if ($LASTEXITCODE -ne 0) { throw 'SQL kabul katmani taze veritabaninda basarisiz.' }

  Write-Host "[fresh-db-smoke] YESIL: migration zinciri + SQL kabul katmani bos bir veritabaninda gecti."
} finally {
  # Temizlik: scratch'i dus ve migrate.ps1'in yukledigi .env degerlerini
  # eski haline getir. psql cagrilari icin sifreyi yeniden kur.
  $env:PGPASSWORD = $Password
  if (-not $Keep) {
    Write-Host "[fresh-db-smoke] 4/4 scratch veritabani dustuluyor: $ScratchDatabase"
    & $psql @control -c "DROP DATABASE IF EXISTS $ScratchDatabase WITH (FORCE);" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Scratch veritabani dustulemedi (temizlik DROP).' }
  } else {
    Write-Host "[fresh-db-smoke] 4/4 scratch veritabani korundu: $ScratchDatabase (-Keep)"
  }
  Remove-Item -LiteralPath $tempEnv -ErrorAction SilentlyContinue
  foreach ($name in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD')) {
    if ($null -ne $oldEnv[$name]) { [Environment]::SetEnvironmentVariable($name, $oldEnv[$name], 'Process') }
    else { Remove-Item "Env:$name" -ErrorAction SilentlyContinue }
  }
}
