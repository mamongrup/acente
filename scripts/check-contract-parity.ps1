param(
  [string]$PeerContract
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$localContract = Join-Path $projectRoot 'contracts/catalog-categories.v1.json'
$localSupplierListingContract = Join-Path $projectRoot 'contracts/supplier-listing-contract.v1.json'
if (-not $PeerContract) {
  $peerRoot = if ($projectRoot -like '*\Nexustraveltech') {
    'C:\laragon\www\acente'
  } else {
    'C:\laragon\www\Nexustraveltech'
  }
  $PeerContract = Join-Path $peerRoot 'contracts/catalog-categories.v1.json'
}
$peerSupplierListingContract = Join-Path (Split-Path -Parent $PeerContract) 'supplier-listing-contract.v1.json'

$local = Get-Content -LiteralPath $localContract -Raw | ConvertFrom-Json
$peer = Get-Content -LiteralPath $PeerContract -Raw | ConvertFrom-Json
$expectedCodes = @(
  'hotel','holiday_home','yacht','tour','activity','flight','car','cruise',
  'pilgrimage','visa','ferry','transfer','beach','cinema','event',
  'restaurant','bus'
)

if ($local.contract_version -ne '1.1.0') {
  throw "Beklenmeyen yerel sözleşme sürümü: $($local.contract_version)"
}
if ($local.contract_version -ne $peer.contract_version) {
  throw "Sözleşme sürümleri farklı: $($local.contract_version) / $($peer.contract_version)"
}
$localCodes = @($local.categories | ForEach-Object code)
$peerCodes = @($peer.categories | ForEach-Object code)
if (($localCodes -join ',') -ne ($expectedCodes -join ',')) {
  throw 'Yerel kanonik kategori sırası veya kodları geçersiz.'
}
if (($localCodes -join ',') -ne ($peerCodes -join ',')) {
  throw 'İki projenin kategori kodları farklı.'
}
$localCanonical = $local.categories | ConvertTo-Json -Depth 8 -Compress
$peerCanonical = $peer.categories | ConvertTo-Json -Depth 8 -Compress
if ($localCanonical -ne $peerCanonical) {
  throw 'İki projenin kategori adları, slug değerleri veya eşlemeleri farklı.'
}
Write-Output "Kategori sözleşmeleri uyumlu: $($local.contract_version), $($localCodes.Count) kategori."

$localSupplierListing = Get-Content -LiteralPath $localSupplierListingContract -Raw | ConvertFrom-Json
$peerSupplierListing = Get-Content -LiteralPath $peerSupplierListingContract -Raw | ConvertFrom-Json
if ($localSupplierListing.contract_version -ne '1.1.0') {
  throw "Beklenmeyen tedarikçi/ilan sözleşme sürümü: $($localSupplierListing.contract_version)"
}
if ($localSupplierListing.contract_version -ne $peerSupplierListing.contract_version) {
  throw "Tedarikçi/ilan sözleşme sürümleri farklı: $($localSupplierListing.contract_version) / $($peerSupplierListing.contract_version)"
}
$localSupplierListingCanonical = $localSupplierListing | ConvertTo-Json -Depth 20 -Compress
$peerSupplierListingCanonical = $peerSupplierListing | ConvertTo-Json -Depth 20 -Compress
if ($localSupplierListingCanonical -ne $peerSupplierListingCanonical) {
  throw 'İki projenin tedarikçi/ilan sözleşmesi farklı.'
}
$expectedHolidayHomeFields = @(
  'property_type',
  'bedroom_count',
  'bathroom_count',
  'guest_capacity',
  'pool_type',
  'kitchen',
  'season_rules'
)
$categoryAttributes = $localSupplierListing.category_attributes
if ($categoryAttributes.PSObject.Properties.Name -contains 'villa') {
  throw 'villa ana kategori özniteliği olarak geri eklenemez; holiday_home.property_type alt türü olmalıdır.'
}
$holidayHomeFields = @($categoryAttributes.holiday_home)
if (($holidayHomeFields -join ',') -ne ($expectedHolidayHomeFields -join ',')) {
  throw "holiday_home alan sözleşmesi geçersiz: $($holidayHomeFields -join ',')"
}
$propertyType = $localSupplierListing.field_definitions.'holiday_home.property_type'
if (-not $propertyType) {
  throw 'holiday_home.property_type field_definitions içinde tanımlı değil.'
}
$expectedHolidayHomeTypes = @('Villa','Apart','Bungalov','Daire','Residence')
$actualHolidayHomeTypes = @($propertyType.options)
if (($actualHolidayHomeTypes -join ',') -ne ($expectedHolidayHomeTypes -join ',')) {
  throw "holiday_home.property_type seçenekleri geçersiz: $($actualHolidayHomeTypes -join ',')"
}
$expectedYachtFields = @(
  'yacht_type',
  'capacity',
  'cabin_count',
  'departure_port',
  'route',
  'captain_included',
  'fuel_policy'
)
$yachtFields = @($categoryAttributes.yacht)
if (($yachtFields -join ',') -ne ($expectedYachtFields -join ',')) {
  throw "yacht alan sözleşmesi geçersiz: $($yachtFields -join ',')"
}
$yachtType = $localSupplierListing.field_definitions.'yacht.yacht_type'
if (-not $yachtType) {
  throw 'yacht.yacht_type field_definitions içinde tanımlı değil.'
}
$expectedYachtTypes = @('Gulet','Motoryat','Yelkenli','Katamaran','Tekne')
$actualYachtTypes = @($yachtType.options)
if (($actualYachtTypes -join ',') -ne ($expectedYachtTypes -join ',')) {
  throw "yacht.yacht_type seçenekleri geçersiz: $($actualYachtTypes -join ',')"
}
Write-Output "Tedarikçi/ilan sözleşmeleri uyumlu: $($localSupplierListing.contract_version)."

$filterParityScript = Join-Path $PSScriptRoot 'check-filter-contract-parity.ps1'
if (Test-Path -LiteralPath $filterParityScript) {
  & powershell -ExecutionPolicy Bypass -File $filterParityScript
  if ($LASTEXITCODE -ne 0) {
    throw 'Yönetilebilir filtre sözleşmesi parity kontrolü başarısız.'
  }
}

$moduleParityScript = Join-Path $PSScriptRoot 'check-module-contract-parity.ps1'
if (Test-Path -LiteralPath $moduleParityScript) {
  & powershell -ExecutionPolicy Bypass -File $moduleParityScript
  if ($LASTEXITCODE -ne 0) {
    throw 'Tedarikçi panel modül sözleşmesi parity kontrolü başarısız.'
  }
}
