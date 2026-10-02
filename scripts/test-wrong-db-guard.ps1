# Wrong-database guard rejection test (agency side, cross-platform pwsh).
#
# Kanit: hedef veritabaninda NEXUS platform kok semasi ('catalog') varsa
# scripts/migrate.ps1 TUM psql adimlarindan ONCE reddetmeli ve hicbir DDL
# uygulamamali. Bu betik bunu gercek bir migrate.ps1 cagrisiyle simule eder:
#   1) kontrol kumesinde scratch veritabani yarat (DROP IF EXISTS + CREATE,
#      ayri -c cagrilarlari; tek -c "transaction block" hatasi verir)
#   2) scratch icinde yabanci platform semasini yarat (CREATE SCHEMA catalog)
#   3) migrate.ps1'i gecici .env ile scratch veritabanina yonlendir
#   4) red bekle: migrate'in throw mesaji yabanci semayi adlandirmali
#      (baska bir hata reddetme kaniti degildir)
#   5) DDL-yok iddiasi: 'system' semasi (migrate'in ilk adimi) hic
#      yaratilmamis olmali; 'catalog' semasi dokunulmamis kalmali
#   6) finally: scratch veritabanini dus (kume temiz kalir, kosum idempotent)
#
# Baglanti cozumlemesi: parametre > ortam degiskeni > .env (run-db-tests
# kalibi). Scratch yaratma yonetici yetkisi ister: CI'da release-readiness
# .env'i PGUSER=postgres yazar. Yerelde acente .env'i agency_app yazar
# (CREATE DATABASE yetkisi yok); superkullaniciyi acik verin:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-wrong-db-guard.ps1 `
#     -DbHost 127.0.0.1 -Port 5432 -User postgres -Password <postgres-sifresi>
#
# Not: Bu dosya bilerek yalnizca ASCII yazar. Windows PowerShell 5.1,
# BOM'suz UTF-8 betigi ANSI okur; ASCII disi karakterler betigi bozabilir.
param(
  [string]$DbHost,
  [string]$Port,
  [string]$User,
  [string]$Password,
  [string]$ControlDatabase = 'postgres',
  [string]$ScratchDatabase = 'wrong_db_guard_sim',
  [string]$Psql
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
if (!$Psql) {
  $Psql = if ($env:PSQL_EXECUTABLE) { $env:PSQL_EXECUTABLE }
  elseif (Test-Path -LiteralPath 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe') { 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe' }
  else { (Get-Command psql -ErrorAction Stop).Source }
}
if ($ScratchDatabase -notmatch '^[a-z_][a-z0-9_]{0,62}$') { throw "Gecersiz scratch veritabani adi: '$ScratchDatabase' (beklenen [a-z_][a-z0-9_]*)" }
if ($ScratchDatabase -in @('postgres', 'template0', 'template1')) { throw "Scratch veritabani adi sistem veritabani olamaz: $ScratchDatabase" }
if ($ScratchDatabase -eq $ControlDatabase) { throw "Scratch veritabani adi kontrol veritabanindan farkli olmali: $ControlDatabase" }

$control = @('-X', '-w', '-v', 'ON_ERROR_STOP=1', '-h', $DbHost, '-p', $Port, '-U', $User, '-d', $ControlDatabase)
$target = @('-X', '-w', '-v', 'ON_ERROR_STOP=1', '-h', $DbHost, '-p', $Port, '-U', $User, '-d', $ScratchDatabase)

# migrate.ps1 .env'i kendi surecine yukler; sonunda eski degerlere geri koy.
$oldEnv = @{}
foreach ($name in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD')) {
  $oldEnv[$name] = [Environment]::GetEnvironmentVariable($name)
}
$tempEnv = Join-Path ([IO.Path]::GetTempPath()) ("wrong-db-guard-" + [Guid]::NewGuid().ToString('N') + ".env")
try {
  $env:PGPASSWORD = $Password

  Write-Host "[wrong-db-guard] 1/5 scratch veritabani hazirlaniyor: $ScratchDatabase"
  & $Psql @control -c "DROP DATABASE IF EXISTS $ScratchDatabase WITH (FORCE);" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Scratch veritabani dustulemedi (DROP).' }
  & $Psql @control -c "CREATE DATABASE $ScratchDatabase OWNER $User;"
  if ($LASTEXITCODE -ne 0) { throw 'Scratch veritabani yaratilamadi (CREATE).' }

  Write-Host "[wrong-db-guard] 2/5 yabanci platform semasi yaratiliyor ('catalog')"
  & $Psql @target -c 'CREATE SCHEMA catalog;'
  if ($LASTEXITCODE -ne 0) { throw 'Yabanci sema yaratilamadi.' }

  Write-Host "[wrong-db-guard] 3/5 migrate.ps1 scratch'e yonlendiriliyor (red bekleniyor)"
  @(
    "PGHOST=$DbHost",
    "PGPORT=$Port",
    "PGDATABASE=$ScratchDatabase",
    "PGUSER=$User",
    "PGPASSWORD=$Password",
    "PSQL_EXECUTABLE=$Psql"
  ) | Set-Content -LiteralPath $tempEnv -Encoding ASCII

  $rejected = $true
  $reason = ''
  try {
    & (Join-Path $root 'scripts/migrate.ps1') -EnvPath $tempEnv
    $rejected = $false
  } catch {
    $reason = "$_"
  }
  if (!$rejected) { throw 'Guard beklenmedik sekilde gecti: migrate.ps1 platform bicimli veritabanina DDL uygulamaya kalkti.' }
  if ($reason -notmatch 'catalog') {
    throw "Migrate yabanci bir nedenle dustu (bu bir guard reddi degil): $reason"
  }
  Write-Host "[wrong-db-guard] 4/5 red dogrulandi: $($reason.Trim())"

  Write-Host "[wrong-db-guard] 5/5 DDL-yok iddiasi ('system' semasi yaratilmamali)"
  $systemSchemas = ((& $Psql @target -Atc "SELECT count(*) FROM pg_namespace WHERE nspname='system'") | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'DDL-yok sorgusu calistirilamadi.' }
  if ($systemSchemas -ne '0') { throw "Migration DDL sizdi: 'system' semasi mevcut (count=$systemSchemas)." }
  $catalogSchemas = ((& $Psql @target -Atc "SELECT count(*) FROM pg_namespace WHERE nspname='catalog'") | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'Sema dogrulama sorgusu calistirilamadi.' }
  if ($catalogSchemas -ne '1') { throw "Yabanci sema beklenmedik sekilde degisti (count=$catalogSchemas)." }

  Write-Host "[wrong-db-guard] YESIL: migrate.ps1 platform bicimli hedefi reddetti ve hicbir DDL uygulamadi."
} finally {
  # Temizlik: scratch'i dus ve migrate.ps1'in yukledigi .env degerlerini
  # eski haline getir. psql cagrilari icin sifreyi yeniden kur (migrate.ps1
  # PGPASSWORD'u kendi girisindeki degerle birakabilir).
  $env:PGPASSWORD = $Password
  & $Psql @control -c "DROP DATABASE IF EXISTS $ScratchDatabase WITH (FORCE);" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Scratch veritabani dustulemedi (temizlik DROP).' }
  Remove-Item -LiteralPath $tempEnv -ErrorAction SilentlyContinue
  foreach ($name in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD')) {
    if ($null -ne $oldEnv[$name]) { [Environment]::SetEnvironmentVariable($name, $oldEnv[$name], 'Process') }
    else { Remove-Item "Env:$name" -ErrorAction SilentlyContinue }
  }
}
