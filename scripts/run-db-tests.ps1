# SQL kabul katmani kosucusu (acente) - tek kaynak, capraz platform (pwsh).
#
# Acente'de platformdaki gibi siraya duyarli bir db/tests fixture zinciri
# yoktur; bu betik test/*.sql kabul katmanini ada gore sirali kosturur.
# Ileride db/tests eklenirse once asagidaki $ChainOrder doldurulmalidir:
# tanimli siraya girmeyen bir db/tests dosyasi betigi gurultulu durdurur
# (sessiz atlama yasak). Platform aynasi icin bkz.
# Nexustraveltech/scripts/run-db-tests.ps1.
#
# Baglanti cozumlemesi: parametre > ortam degiskeni > .env (CI .env'i
# PGUSER/PGPASSWORD yazar; yerel .env acente rollerini yazar).
#
# Onemli fixture notu: acente kabul testlerinin bir bolumu KENDI verisini
# kendisi kurar (orn. ai_campaign_*), bir bolumu ise canli veri fixture'i
# ister (orn. category_service_operations mevcut admin + ilan arar).
# Bu yuzden katman, tasarlandigi gibi, veri tasiyan yerel/canli veritabanina
# karsi kosturulmalidir; migration-only bos bir DB'de 'fixture_missing'
# ile gurultulu kirilir (bu bir hata degil, tasarimdir - sessiz atlama yok).
# CI'da canli fixture verisi olmadigi icin bu katman CI'ya baglanmadi;
# bagimsizligi koruyan gleam testleri CI kapsamini olusturur.
#
# Not: Bu dosya bilerek yalnizca ASCII yazar. Windows PowerShell 5.1, BOM'suz
# UTF-8 betigi ANSI okur; em-dash gibi karakterlerin son bayti tirnak bytesi
# olarak cozulup betigi bozar. Turkce mesajlar ANSI terminalde bozuk
# gorunebilir, islev etkilenmez.
param(
  [string]$EnvFile,
  [string]$DbHost,
  [string]$Port,
  [string]$Database,
  [string]$User,
  [string]$Password,
  [string]$Psql
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$EnvFile) { $EnvFile = Join-Path $root '.env' }
if (Test-Path -LiteralPath $EnvFile) {
  # Ortamda zaten tanimli anahtarlari .env ezmez (CI ortami onceliklidir).
  Get-Content -LiteralPath $EnvFile | ForEach-Object {
    $line = $_.Trim(); $i = $line.IndexOf('=')
    if ($i -gt 0) {
      $k = $line.Substring(0, $i).Trim()
      if (![Environment]::GetEnvironmentVariable($k)) {
        Set-Item "Env:$k" $line.Substring($i + 1).Trim()
      }
    }
  }
}
if (!$DbHost) { $DbHost = $env:PGHOST }
if (!$Port) { $Port = $env:PGPORT }
if (!$Database) { $Database = $env:PGDATABASE }
if (!$User) { $User = $env:PGUSER }
if (!$Password) { $Password = $env:PGPASSWORD }
foreach ($pair in @(@('PGHOST', $DbHost), @('PGPORT', $Port), @('PGDATABASE', $Database), @('PGUSER', $User), @('PGPASSWORD', $Password))) {
  if (!$pair[1]) { throw "Baglanti bilgisi eksik: $($pair[0]) (parametre, ortam degiskeni veya .env ile verilmeli)" }
}
if (!$Psql) {
  $Psql = if ($env:PSQL_EXECUTABLE) { $env:PSQL_EXECUTABLE }
  elseif (Test-Path -LiteralPath 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe') { 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe' }
  else { (Get-Command psql -ErrorAction Stop).Source }
}

# Siraya duyarli fixture zinciri: acente'de su an bos. db/tests altina dosya
# eklenirse Once buraya sirayla eklenmelidir; aksi halde tripwire durdurur.
$ChainOrder = @()

$oldPassword = $env:PGPASSWORD
$script:ran = 0
function Invoke-SqlFile([string]$Path, [string]$Label) {
  Write-Host "::group::$Label"
  & $Psql -X -w -h $DbHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -f $Path
  $ok = ($LASTEXITCODE -eq 0)
  Write-Host "::endgroup::"
  if (!$ok) { throw "SQL testi basarisiz: $Label" }
  $script:ran++
}
try {
  $env:PGPASSWORD = $Password
  $testsDir = Join-Path $root 'db/tests'
  if (Test-Path -LiteralPath $testsDir) {
    $unlisted = Get-ChildItem -LiteralPath $testsDir -Filter '*.sql' |
      Where-Object { $ChainOrder -notcontains $_.Name }
    if ($unlisted) {
      throw ("ChainOrder listesine eklenmemis db/tests dosyalari (Once sirayi tanimlayin): " + (($unlisted | ForEach-Object Name) -join ', '))
    }
    foreach ($name in $ChainOrder) {
      Invoke-SqlFile -Path (Join-Path $testsDir $name) -Label "db/tests/$name"
    }
  }
  $acceptance = Get-ChildItem -LiteralPath (Join-Path $root 'test') -Filter '*.sql' | Sort-Object Name
  if (!$acceptance) { throw 'Kabul testi bulunamadi: test/*.sql bos' }
  foreach ($file in $acceptance) {
    Invoke-SqlFile -Path $file.FullName -Label "test/$($file.Name)"
  }
  Write-Host "run-db-tests: YESIL - $script:ran SQL dosyasi gecti."
} finally {
  $env:PGPASSWORD = $oldPassword
}
