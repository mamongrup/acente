<#
.SYNOPSIS
  Gunluk CSP ihlal raporu (report-only -> enforcing gecis izleme betigi).

.DESCRIPTION
  agency.security_events tablosunu okuyarak son N saatteki (varsayilan 24)
  CSP ihlallerini (event_type = 'csp_violation') ve hiz-limiti olaylarini
  (event_type = 'rate_limit') ozetler. Enforcing'e gecis oncesi guvenlik
  kontrol listesindeki (docs/security-deployment-checklist.md, bolum 3 ve 5)
  gunluk izleme adimini tek komutta toplar; sicramalar yapisal CSP hatalarini
  ya da enjeksiyon denemelerini gosterir.

  Baglanti ayarlari .env dosyasindan okunur (PGHOST, PGPORT, PGDATABASE,
  PGUSER, PGPASSWORD); psql bulunamazsa Laragon kurulumu taranir.

  Rapor yalnizca SELECT calistirir; veriyi degistirmez.

.EXAMPLE
  pwsh scripts/daily-csp-report.ps1
  pwsh scripts/daily-csp-report.ps1 -Hours 168 -OutFile raporlar/csp-haftalik.txt
#>
param(
  # Rapor penceresi (saat). 1 ile 720 (30 gun) arasi.
  [int]$Hours = 24,
  # Raporun yazilacagi dosya; verilirse konsolun yanina dosyaya da yazilir.
  [string]$OutFile = "",
  # .env dosyasinin yolu (proje kokune gore cozumlenir).
  [string]$EnvPath = ".env",
  # Yalnizca exit code: ihlal adi verilen esik uzerindeyse 2 doner.
  [int]$AlertThreshold = 0
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Girdi dogrulama
# ---------------------------------------------------------------------------
if ($Hours -lt 1 -or $Hours -gt 720) { throw 'Hours must be between 1 and 720.' }
if ($AlertThreshold -lt 0) { throw 'AlertThreshold cannot be negative.' }

$root = Split-Path $PSScriptRoot -Parent
$resolvedEnv = if ([IO.Path]::IsPathRooted($EnvPath)) { $EnvPath } else { Join-Path $root $EnvPath }
if (!(Test-Path -LiteralPath $resolvedEnv)) { throw "Env file not found: $resolvedEnv" }

# ---------------------------------------------------------------------------
# .env okuma (CRLF/UTF-8 BOM guvenli; mevcut betiklerle ayni desen)
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# psql bulun: once PATH, yoksa Laragon kurulumu
# ---------------------------------------------------------------------------
$psql = Get-Command psql -ErrorAction SilentlyContinue
if (!$psql) {
  $psql = Get-ChildItem 'C:\laragon\bin\postgresql\*\bin\psql.exe' -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
}
if (!$psql) { throw 'psql executable not found.' }

# ---------------------------------------------------------------------------
# Raporda kullanilacak SQL (yalnizca okuma; tek baglanti icinde sirayla kosulur)
# ---------------------------------------------------------------------------
$sqlWindowHeader = @"

=== RAPOR PENCERESI ===
"@

$sqlQueries = [ordered]@{

  'Genel ozet' = @"
select
  'csp_violation' as olay_tipi,
  count(*)::text as adet,
  coalesce(count(distinct client_id), 0)::text as farkli_istemci,
  to_char(min(occurred_at) at time zone 'UTC', 'YYYY-MM-DD HH24:MI') || ' UTC' as ilk,
  to_char(max(occurred_at) at time zone 'UTC', 'YYYY-MM-DD HH24:MI') || ' UTC' as son
from agency.security_events
where event_type = 'csp_violation'
  and occurred_at > now() - make_interval(hours => $($Hours))
union all
select
  'rate_limit',
  count(*)::text,
  coalesce(count(distinct client_id), 0)::text,
  to_char(min(occurred_at) at time zone 'UTC', 'YYYY-MM-DD HH24:MI') || ' UTC',
  to_char(max(occurred_at) at time zone 'UTC', 'YYYY-MM-DD HH24:MI') || ' UTC'
from agency.security_events
where event_type = 'rate_limit'
  and occurred_at > now() - make_interval(hours => $($Hours));
"@

  'Saatlik trend' = @"
select
  to_char(date_trunc('hour', occurred_at) at time zone 'UTC', 'MM-DD HH24:00') || ' UTC' as saat,
  count(*) filter (where event_type = 'csp_violation') as csp_ihlal,
  count(*) filter (where event_type = 'rate_limit') as hiz_limiti_429
from agency.security_events
where event_type in ('csp_violation', 'rate_limit')
  and occurred_at > now() - make_interval(hours => $($Hours))
group by 1
order by 1;
"@

  'Yonerge x engellenen-kaynak kirilimi' = @"
select
  coalesce(metadata->'csp-report'->>'violated-directive',
           metadata->>'violated-directive', '(bilinmiyor)') as yonerge,
  coalesce(metadata->'csp-report'->>'blocked-uri',
           metadata->>'blocked-uri', '(bilinmiyor)') as engellenen_kaynak,
  count(*) as adet
from agency.security_events
where event_type = 'csp_violation'
  and occurred_at > now() - make_interval(hours => $($Hours))
group by 1, 2
order by adet desc, 1, 2
limit 25;
"@

  'En cok ihlal ureten istemciler' = @"
select
  coalesce(client_id, '(anonim)') as istemci,
  count(*) as ihlal_adedi,
  count(distinct coalesce(metadata->'csp-report'->>'document-uri',
                          metadata->>'document-uri', '(bilinmiyor)')) as farkli_sayfa
from agency.security_events
where event_type = 'csp_violation'
  and occurred_at > now() - make_interval(hours => $($Hours))
group by 1
order by ihlal_adedi desc, 1
limit 15;
"@

  'En cok ihlal ureten sayfalar' = @"
select
  coalesce(metadata->'csp-report'->>'document-uri',
           metadata->>'document-uri', '(bilinmiyor)') as sayfa,
  count(*) as ihlal_adedi,
  count(distinct coalesce(metadata->'csp-report'->>'violated-directive',
                          metadata->>'violated-directive', '(bilinmiyor)')) as farkli_yonerge
from agency.security_events
where event_type = 'csp_violation'
  and occurred_at > now() - make_interval(hours => $($Hours))
group by 1
order by ihlal_adedi desc, 1
limit 15;
"@

  'Hiz-limiti olaylari (rate_limit / 429)' = @"
select
  coalesce(client_id, '(anonim)') as istemci,
  route as yol,
  count(*) as adet,
  to_char(min(occurred_at) at time zone 'UTC', 'MM-DD HH24:MI') || ' UTC' as ilk,
  to_char(max(occurred_at) at time zone 'UTC', 'MM-DD HH24:MI') || ' UTC' as son
from agency.security_events
where event_type = 'rate_limit'
  and occurred_at > now() - make_interval(hours => $($Hours))
group by 1, 2
order by adet desc, 1
limit 15;
"@
}

# ---------------------------------------------------------------------------
# Yardimcilar
# ---------------------------------------------------------------------------
$script:reportLines = New-Object System.Collections.Generic.List[string]

function Add-ReportLine {
  param([string]$Text = '')
  $script:reportLines.Add($Text)
  Write-Host $Text
}

function Invoke-PsqlQuery {
  param([string]$Sql)

  $env:PGPASSWORD = [string]$values['PGPASSWORD']
  try {
    & $psql.Source -v ON_ERROR_STOP=1 `
      -h $values['PGHOST'] -p $values['PGPORT'] `
      -U $values['PGUSER'] -d $values['PGDATABASE'] `
      -X -q -A -F '|' -P footer=off `
      -c $Sql 2>&1
  }
  finally {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
  }

  if ($LASTEXITCODE -ne 0) {
    throw "psql query failed with exit code $LASTEXITCODE."
  }
}

function Invoke-PsqlScalar {
  param([string]$Sql)

  $env:PGPASSWORD = [string]$values['PGPASSWORD']
  try {
    $output = & $psql.Source -v ON_ERROR_STOP=1 `
      -h $values['PGHOST'] -p $values['PGPORT'] `
      -U $values['PGUSER'] -d $values['PGDATABASE'] `
      -X -q -A -t `
      -c $Sql 2>&1
  }
  finally {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
  }

  if ($LASTEXITCODE -ne 0) {
    throw "psql query failed with exit code $LASTEXITCODE."
  }
  return (($output | Out-String).Trim())
}

function Format-QueryOutput {
  # psql -A satirlari dondurur; null/ bos satirlari kirp, hata akisina
  # dusebilecek satirlari koru.
  param($Output)
  return @($Output | Where-Object { $null -ne $_ -and "$_".Trim() -ne '' })
}

# ---------------------------------------------------------------------------
# Rapor
# ---------------------------------------------------------------------------
$windowLabel = "Son $Hours saat (bu pencere icin yerel saate gore uretir: $(Get-Date -Format 'yyyy-MM-dd HH:mm'))"

Add-ReportLine ''
Add-ReportLine '==========================================================='
Add-ReportLine '  GUNLUK CSP IHLAL RAPORU (report-only izleme)'
Add-ReportLine $windowLabel
Add-ReportLine "  Veritabani: $($values['PGDATABASE']) @ $($values['PGHOST']):$($values['PGPORT'])"
Add-ReportLine '==========================================================='

# Toplam CSP ihlali (uyari esigi icin)
$totalViolations = Invoke-PsqlScalar @"
select count(*)::text
from agency.security_events
where event_type = 'csp_violation'
  and occurred_at > now() - make_interval(hours => $($Hours));
"@

Add-ReportLine ''
Add-ReportLine $sqlWindowHeader
Add-ReportLine "Toplam CSP ihlali: $totalViolations | Uyari esigi: $AlertThreshold"

foreach ($section in $sqlQueries.Keys) {
  Add-ReportLine ''
  Add-ReportLine "--- $section ---"
  $output = Invoke-PsqlQuery $sqlQueries[$section]
  $rows = Format-QueryOutput $output
  if (!$rows -or $rows.Count -eq 0) {
    Add-ReportLine '(kayit yok)'
    continue
  }
  $rows | ForEach-Object { Add-ReportLine ([string]$_) }
}

Add-ReportLine ''
Add-ReportLine '--- DEGERLENDIRME NOTLARI ---'
Add-ReportLine '1) Yonerge x kaynak kiriliminda uc grup ayristirilir:'
Add-ReportLine '   - Bilinen ucuncu parti (Tawk, Hugeicons, OpenStreetMap): sozlesme karari sonrasi politika guncellemesi.'
Add-ReportLine '   - Kendi inline script/stil bloklarimiz: kod tarafindan duzeltilir (nonce ya da harici dosya); politika gevsetilmez.'
Add-ReportLine '   - blocked-uri icinde javascript: vb. varsa enjeksiyon denemesi olabilir; guvenlik incelemesine alinir.'
Add-ReportLine '2) Ayni istemciden dakikada 20+ rapor uygulama tarafindan 429 ile kesilir; rate_limit satirlari ani sicrama sinyalidir.'
Add-ReportLine '3) CSP olaylari severity=info olarak kaydedilir; warning/critical akisindan ayri degerlendirilir.'
Add-ReportLine '4) Ihlal akisi 7 gun boyunca gercek ihlal vermediginde enforcing''e gecilebilir'
Add-ReportLine '   (docs/security-deployment-checklist.md bolum 3: CSP_REPORT_ONLY unset).'

# ---------------------------------------------------------------------------
# Dosyaya yaz (istendiyse)
# ---------------------------------------------------------------------------
if ($OutFile -ne '') {
  $resolvedOut = if ([IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $root $OutFile }
  $outDir = Split-Path $resolvedOut -Parent
  if ($outDir -and !(Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
  }
  # UTF-8 (BOM'suz); Windows Notepad dahil modern okuyucular sorunsuz acar.
  [IO.File]::WriteAllLines($resolvedOut, $script:reportLines)
  Write-Host ''
  Write-Host "Rapor dosyaya yazildi: $resolvedOut"
}

# ---------------------------------------------------------------------------
# Uyari esigi (opsiyonel; zamanlamalar icin exit code)
# ---------------------------------------------------------------------------
if ([int]$totalViolations -gt $AlertThreshold) {
  Write-Host ''
  Write-Warning ("CSP ihlal sayisi ($totalViolations) esigi asti ($AlertThreshold). " +
    'Yonerge x kaynak kirilimini inceleyin.')
  exit 2
}

exit 0
