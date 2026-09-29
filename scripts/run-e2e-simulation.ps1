# run-e2e-simulation.ps1
# NEXUS TravelTech & Acente Platformu Uctan Uca (E2E) Simulasyon Betigi

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PGCLIENTENCODING = "UTF8"

$root = Split-Path $PSScriptRoot -Parent
function Load-DotEnv([string]$Path) {
    if (!(Test-Path -LiteralPath $Path)) { return }
    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if (!$line -or $line.StartsWith("#")) { return }
        $index = $line.IndexOf("=")
        if ($index -gt 0) {
            $key = $line.Substring(0, $index).Trim()
            $value = $line.Substring($index + 1).Trim()
            if (![Environment]::GetEnvironmentVariable($key)) {
                [Environment]::SetEnvironmentVariable($key, $value)
            }
        }
    }
}

function Require-Env([string]$Name) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$Name environment variable is required for E2E simulation."
    }
    return $value
}

Load-DotEnv (Join-Path $root ".env")
Load-DotEnv "C:\laragon\www\Nexustraveltech\.env"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  NEXUS - Acente Uctan Uca (E2E) Entegrasyon Simulasyonu" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$NexusPort = if ($env:NEXUS_PGPORT) { [int]$env:NEXUS_PGPORT } else { 5433 }
$NexusDb = if ($env:NEXUS_PGDATABASE) { $env:NEXUS_PGDATABASE } else { "nexustraveltech" }
$NexusUser = if ($env:NEXUS_PGUSER) { $env:NEXUS_PGUSER } else { "nexus_app" }
$NexusPass = Require-Env "NEXUS_PGPASSWORD"

$AgencyPort = if ($env:PGPORT) { [int]$env:PGPORT } else { 5432 }
$AgencyDb = if ($env:PGDATABASE) { $env:PGDATABASE } else { "nexus_agency" }
$AgencyUser = if ($env:PGUSER) { $env:PGUSER } else { "agency_app" }
$AgencyPass = Require-Env "PGPASSWORD"
$TenantId = Require-Env "NEXUS_TENANT_ID"

# 1. Veritabani Baglanti Testleri
Write-Host "`n[1/5] Veritabani baglantilari test ediliyor..." -ForegroundColor Yellow

$env:PGPASSWORD = $NexusPass
$nexusCheck = psql -h 127.0.0.1 -p $NexusPort -U $NexusUser -d $NexusDb -t -A -c "SELECT 'NEXUS_OK';" 2>&1
if ($nexusCheck -match "NEXUS_OK") {
    Write-Host "  [OK] NEXUS DB (Port $NexusPort) erisilebilir." -ForegroundColor Green
} else {
    Write-Host "  [ERR] NEXUS DB erisilemedi: $nexusCheck" -ForegroundColor Red
    exit 1
}

$env:PGPASSWORD = $AgencyPass
$agencyCheck = psql -h 127.0.0.1 -p $AgencyPort -U $AgencyUser -d $AgencyDb -t -A -c "SELECT 'AGENCY_OK';" 2>&1
if ($agencyCheck -match "AGENCY_OK") {
    Write-Host "  [OK] Acente DB (Port $AgencyPort) erisilebilir." -ForegroundColor Green
} else {
    Write-Host "  [ERR] Acente DB erisilemedi: $agencyCheck" -ForegroundColor Red
    exit 1
}

# 2. NEXUS Ilan Feed Kaynak Kontrolu
Write-Host "`n[2/5] NEXUS ilan feed'i ve sozlesme durumu denetleniyor..." -ForegroundColor Yellow
$env:PGPASSWORD = $NexusPass
$listingCount = psql -h 127.0.0.1 -p $NexusPort -U $NexusUser -d $NexusDb -t -A -c "SELECT count(*) FROM catalog.marketplace_listings_v2('', '', '');"
Write-Host "  [OK] NEXUS pazar yerinde onayli ve yayinda $listingCount adet ilan mevcut." -ForegroundColor Green

# 3. Acente Senkronizasyon Simulasyonu (NEXUS -> Acente Upsert)
Write-Host "`n[3/5] Acente senkronizasyonu simule ediliyor (NEXUS Feed -> agency.listings)..." -ForegroundColor Yellow

$env:PGPASSWORD = $NexusPass
$listingsJson = psql -h 127.0.0.1 -p $NexusPort -U $NexusUser -d $NexusDb -t -A -c "
  SELECT json_agg(t) FROM (
    SELECT id::text, title, locality, category, capacity::text, price::text, currency, description, images::text 
    FROM catalog.marketplace_listings_v2('', '', '')
  ) t;
"
$listings = $listingsJson | ConvertFrom-Json

$env:PGPASSWORD = $AgencyPass
$allSql = New-Object System.Text.StringBuilder
foreach ($item in $listings) {
    $code = "NEXUS-" + $item.id
    $priceMinor = [int64]$item.price
    $titleEscaped = $item.title.Replace("'", "''")
    $locEscaped = $item.locality.Replace("'", "''")
    $descEscaped = $item.description.Replace("'", "''")
    $cap = if ([string]::IsNullOrWhiteSpace($item.capacity)) { "4" } else { $item.capacity }
    $loc = if ([string]::IsNullOrWhiteSpace($item.locality)) { "Merkez" } else { $item.locality }
    $imagesJson = if ([string]::IsNullOrWhiteSpace($item.images) -or $item.images -eq "[]") { "[{`"url`":`"/static/placeholder.jpg`"}]" } else { $item.images.Replace("'", "''") }
    
    $contractFields = switch ($item.category) {
        "holiday_home" { "{`"property_type`":`"Villa`",`"bedroom_count`":`"3`",`"bathroom_count`":`"2`",`"guest_capacity`":`"$cap`"}" }
        "hotel"        { "{`"property_type`":`"Otel`",`"board_type`":`"Oda Kahvalti`",`"check_in_time`":`"14:00`",`"check_out_time`":`"12:00`",`"room_types`":`"Standart`"}" }
        "yacht"        { "{`"yacht_type`":`"Gulet`",`"capacity`":`"$cap`",`"captain_included`":`"Evet`",`"departure_port`":`"$loc`",`"route`":`"Standart Seyir`"}" }
        "tour"         { "{`"tour_type`":`"Kultur Tipi`",`"duration`":`"Gunubirlik`",`"start_point`":`"$loc`"}" }
        "activity"     { "{`"activity_type`":`"Acik Hava`",`"duration`":`"2 Saat`",`"meeting_point`":`"$loc`"}" }
        "car"          { "{`"vehicle_type`":`"Sedan`",`"transmission`":`"Otomatik`",`"seat_count`":`"$cap`",`"deposit_policy`":`"Kredi Karti`",`"pickup_locations`":`"$loc`"}" }
        "transfer"     { "{`"transfer_type`":`"VIP`",`"vehicle_type`":`"Minivan`",`"capacity`":`"$cap`",`"pickup_location`":`"Havalimani`",`"dropoff_location`":`"$loc`"}" }
        default        { "{`"property_type`":`"Standart`",`"capacity`":`"$cap`"}" }
    }
    $metaJson = "{`"nexus_listing_id`":`"$($item.id)`",`"guests`":`"$cap`",`"contract_fields`":$contractFields}"

    $null = $allSql.AppendLine(@"
INSERT INTO agency.listings(
  tenant_id, code, category, title, locality, description, currency, price_minor,
  status, source, metadata, images, amenities, owner_info, cancellation_policy
) VALUES (
  '$TenantId'::uuid,
  upper('$code'),
  '$($item.category)',
  '$titleEscaped',
  '$locEscaped',
  '$descEscaped',
  upper('$($item.currency)'),
  $priceMinor,
  'published',
  'nexus',
  '$metaJson'::jsonb,
  '$imagesJson'::jsonb,
  '[]'::jsonb,
  jsonb_build_object('provider', 'NEXUS TravelTech'),
  jsonb_build_object('policy', 'Standart')
)
ON CONFLICT (tenant_id, code) DO UPDATE SET
  category = EXCLUDED.category,
  title = EXCLUDED.title,
  locality = EXCLUDED.locality,
  description = EXCLUDED.description,
  currency = EXCLUDED.currency,
  price_minor = EXCLUDED.price_minor,
  status = 'published',
  source = 'nexus',
  metadata = agency.listings.metadata || EXCLUDED.metadata,
  images = CASE WHEN EXCLUDED.images <> '[]'::jsonb THEN EXCLUDED.images ELSE agency.listings.images END,
  owner_info = CASE WHEN agency.listings.owner_info = '{}'::jsonb THEN EXCLUDED.owner_info ELSE agency.listings.owner_info END,
  cancellation_policy = CASE WHEN agency.listings.cancellation_policy = '{}'::jsonb THEN EXCLUDED.cancellation_policy ELSE agency.listings.cancellation_policy END,
  updated_at = now();
"@)
}

$tmpSqlFile = [System.IO.Path]::GetTempFileName() + ".sql"
[System.IO.File]::WriteAllText($tmpSqlFile, $allSql.ToString(), [System.Text.UTF8Encoding]::new($false))

try {
    $res = psql -h 127.0.0.1 -p $AgencyPort -U $AgencyUser -d $AgencyDb -f $tmpSqlFile 2>&1
    $syncedCount = ($res | Select-String "INSERT 0 1").Count
    Write-Host "  [OK] Acente DB'ye $syncedCount adet NEXUS ilani basariyla aktarildi/guncellendi." -ForegroundColor Green
} finally {
    if (Test-Path $tmpSqlFile) { Remove-Item $tmpSqlFile -Force }
}

# 4. Acente Vitrin & Kategori Filtreleme Dogrulamasi
Write-Host "`n[4/5] Acente vitrin filtreleri ve kategori sorgulari test ediliyor..." -ForegroundColor Yellow
$yachtCount = psql -h 127.0.0.1 -p $AgencyPort -U $AgencyUser -d $AgencyDb -t -A -c "
  SELECT count(*) FROM agency.listings 
  WHERE tenant_id = '$TenantId'::uuid AND source = 'nexus' AND category = 'yacht' AND status = 'published';
"
$hotelCount = psql -h 127.0.0.1 -p $AgencyPort -U $AgencyUser -d $AgencyDb -t -A -c "
  SELECT count(*) FROM agency.listings 
  WHERE tenant_id = '$TenantId'::uuid AND source = 'nexus' AND category = 'hotel' AND status = 'published';
"
$homeCount = psql -h 127.0.0.1 -p $AgencyPort -U $AgencyUser -d $AgencyDb -t -A -c "
  SELECT count(*) FROM agency.listings 
  WHERE tenant_id = '$TenantId'::uuid AND source = 'nexus' AND category = 'holiday_home' AND status = 'published';
"
Write-Host "  [OK] Acente vitrininde yayindaki senkronize ilanlar:" -ForegroundColor Green
Write-Host "    - Yat kategorisi: $yachtCount ilan" -ForegroundColor Gray
Write-Host "    - Otel kategorisi: $hotelCount ilan" -ForegroundColor Gray
Write-Host "    - Tatil Evi kategorisi: $homeCount ilan" -ForegroundColor Gray

# 5. Rezervasyon Webhook & Idempotency Testi (Acente -> NEXUS Webhook)
Write-Host "`n[5/5] Rezervasyon Webhook ve Idempotency testi yurutuluyor..." -ForegroundColor Yellow
$testKey = "e2e-sim-" + [guid]::NewGuid().ToString("N")
$webhookJson = @"
{
  `"idempotency_key`": `"$testKey`",
  `"agency_id`": `"$TenantId`",
  `"listing_id`": `"33333333-cccc-4333-8333-333333333333`",
  `"guest_name`": `"E2E Test Misafir`",
  `"guest_email`": `"test.guest@example.com`",
  `"guest_phone`": `"+905559876543`",
  `"tc`": `"10000000146`",
  `"check_in`": `"2026-10-01`",
  `"check_out`": `"2026-10-08`",
  `"guests`": 4
}
"@

$env:PGPASSWORD = $NexusPass
$webhookQuery = "SELECT partners.receive_reservation_webhook_json(`$payload`$" + $webhookJson + "`$payload`$::jsonb);"

$tmpWhFile = [System.IO.Path]::GetTempFileName() + ".sql"
[System.IO.File]::WriteAllText($tmpWhFile, $webhookQuery, [System.Text.UTF8Encoding]::new($false))

try {
    $webhookResRaw = psql -h 127.0.0.1 -p $NexusPort -U $NexusUser -d $NexusDb -t -A -f $tmpWhFile 2>&1
    $webhookRes = $webhookResRaw | ConvertFrom-Json

    if ($webhookRes.ok -eq $true -and $webhookRes.status -eq "processed") {
        Write-Host "  [OK] Ilk rezervasyon webhook'u NEXUS tarafindan kabul edildi (Status: processed, Inbox ID: $($webhookRes.inbox_id))." -ForegroundColor Green
    } else {
        Write-Host "  [ERR] Webhook basarisiz oldu: $webhookResRaw" -ForegroundColor Red
        exit 1
    }

    # 5b. Ayni Idempotency Key ile Mukerrer Gonderim (Idempotency Denetimi)
    Write-Host "  Idempotency kilidi denetleniyor (ayni anahtar ile ikinci gonderim)..." -ForegroundColor Yellow
    $duplicateResRaw = psql -h 127.0.0.1 -p $NexusPort -U $NexusUser -d $NexusDb -t -A -f $tmpWhFile 2>&1
    $duplicateRes = $duplicateResRaw | ConvertFrom-Json

    if ($duplicateRes.ok -eq $true -and $duplicateRes.status -eq "duplicate_ignored") {
        Write-Host "  [OK] Idempotency korumasi dogrulandi: Mukerrer istek guvenle yok sayildi (Status: duplicate_ignored)." -ForegroundColor Green
    } else {
        Write-Host "  [ERR] Idempotency korumasi basarisiz: $duplicateResRaw" -ForegroundColor Red
        exit 1
    }
} finally {
    if (Test-Path $tmpWhFile) { Remove-Item $tmpWhFile -Force }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  [BASARILI] E2E Entegrasyon Simulasyonu TAMAMLANDI!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
