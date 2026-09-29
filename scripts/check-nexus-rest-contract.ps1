param([switch]$RequireListing)
$ErrorActionPreference = "Stop"

function Load-DotEnv([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  Get-Content -LiteralPath $Path | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)\s*=\s*(.*)\s*$') {
      [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
  }
}

Load-DotEnv (Join-Path $PSScriptRoot "..\.env")

$origin = [Environment]::GetEnvironmentVariable("NEXUS_API_ORIGIN")
$apiKey = [Environment]::GetEnvironmentVariable("NEXUS_API_KEY")
$agencyId = [Environment]::GetEnvironmentVariable("NEXUS_TENANT_ID")
$agencyOrigin = [Environment]::GetEnvironmentVariable("APP_ORIGIN")

if ([string]::IsNullOrWhiteSpace($origin) -or
    [string]::IsNullOrWhiteSpace($apiKey) -or
    [string]::IsNullOrWhiteSpace($agencyId)) {
  throw "NEXUS_API_ORIGIN, NEXUS_API_KEY ve NEXUS_TENANT_ID .env içinde tanımlı olmalı."
}

$origin = $origin.TrimEnd("/")
$headers = @{ Authorization = "Bearer $apiKey"; Accept = "application/json" }

function Get-StatusCode([scriptblock]$Request) {
  try {
    & $Request | Out-Null
    return 200
  } catch {
    if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
    throw
  }
}

function Test-AgencyCallbackUnauthorized([string]$AgencyOrigin, [string]$AgencyId) {
  if ([string]::IsNullOrWhiteSpace($AgencyOrigin)) {
    Write-Host "[6/6] Acente callback 401 kontrolü atlandı: APP_ORIGIN boş." -ForegroundColor Yellow
    return
  }
  $AgencyOrigin = $AgencyOrigin.TrimEnd("/")
  Write-Host "[6/6] Acente callback yanlış anahtar 401 kontrolü"
  $payload = @{
    agency_id = $AgencyId
    api_key = "nx_smoke_should_not_be_saved"
  } | ConvertTo-Json -Compress
  $callbackStatus = Get-StatusCode {
    Invoke-WebRequest `
      -Uri "$AgencyOrigin/v1/nexus/connection-approved" `
      -Headers @{ Authorization = "Bearer invalid-test-key"; "Content-Type" = "application/json" } `
      -Method Post `
      -Body $payload `
      -UseBasicParsing
  }
  if ($callbackStatus -ne 401) {
    throw "Acente callback yanlış anahtar 401 döndürmedi: $callbackStatus"
  }
}

Write-Host "[1/6] NEXUS health"
$health = Invoke-RestMethod -Uri "$origin/v1/health" -Method Get
if ($health.service -ne "nexustraveltech" -or $health.database -ne "ready") {
  throw "Health yanıtı beklenen sözleşmeye uymuyor."
}

Write-Host "[2/6] Yanlış anahtar 401 kontrolü"
$wrongStatus = Get-StatusCode {
  Invoke-WebRequest -Uri "$origin/api/v1/feed/listings?agency_id=$agencyId" -Headers @{ Authorization = "Bearer invalid-test-key" } -UseBasicParsing
}
if ($wrongStatus -ne 401) { throw "Yanlış anahtar 401 döndürmedi: $wrongStatus" }

Write-Host "[3/6] Agency-scoped feed"
$feed = Invoke-RestMethod -Uri "$origin/api/v1/feed/listings?agency_id=$agencyId" -Headers $headers -Method Get
if ($feed.ok -ne $true -or $null -eq $feed.listings) {
  throw "Feed yanıtı beklenen sözleşmeye uymuyor."
}

$listing = @($feed.listings) | Select-Object -First 1
if ($null -eq $listing -or [string]::IsNullOrWhiteSpace([string]$listing.id)) {
  Write-Host "Feed boş; inventory ve status webhook kontrolleri atlandı." -ForegroundColor Yellow
  Test-AgencyCallbackUnauthorized -AgencyOrigin $agencyOrigin -AgencyId $agencyId
  if ($RequireListing) { throw "Tam REST sözleşme kontrolü için acenteye bağlı en az bir ilan gerekli." }
  Write-Host "[KISMİ] Temel REST kontrolleri geçti; tam feed sözleşmesi doğrulanmadı." -ForegroundColor Yellow
  exit 0
}

Write-Host "[4/6] Agency-scoped inventory"
$inventory = Invoke-RestMethod -Uri "$origin/api/v1/feed/inventory?agency_id=$agencyId&listing_id=$($listing.id)" -Headers $headers -Method Get
if ($inventory.ok -ne $true -or $null -eq $inventory.inventory) {
  throw "Inventory yanıtı beklenen sözleşmeye uymuyor."
}

Write-Host "[5/6] Var olmayan rezervasyon durum olayı reddi"
$statusPayload = @{
  idempotency_key = "rest-contract-$([guid]::NewGuid().ToString('N'))"
  event_type = "reservation.status_changed"
  agency_id = $agencyId
  listing_id = [string]$listing.id
  reservation_id = [guid]::NewGuid().ToString()
  reservation_status = "cancelled"
} | ConvertTo-Json -Compress
$statusReply = Invoke-RestMethod -Uri "$origin/api/v1/webhooks/reservations" -Headers ($headers + @{ "Content-Type" = "application/json" }) -Method Post -Body $statusPayload
if ($statusReply.ok -ne $false -or $statusReply.error -ne "reservation_not_found") {
  throw "Status webhook yanıtı beklenmeyen sonuç verdi: $($statusReply | ConvertTo-Json -Compress)"
}

Test-AgencyCallbackUnauthorized -AgencyOrigin $agencyOrigin -AgencyId $agencyId

Write-Host "[BAŞARILI] NEXUS REST sözleşme smoke testi tamamlandı." -ForegroundColor Green
