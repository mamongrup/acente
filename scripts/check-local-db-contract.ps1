$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot '.env'
if (!(Test-Path -LiteralPath $envFile)) {
  throw '.env bulunamadı.'
}

Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  $index = $line.IndexOf('=')
  if ($index -gt 0) {
    Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim()
  }
}

$pg = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
$common = @('-X','-w','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE)
$expectedCategories = @(
  'hotel',
  'holiday_home',
  'yacht',
  'tour',
  'activity',
  'flight',
  'car',
  'cruise',
  'pilgrimage',
  'visa',
  'ferry',
  'transfer',
  'beach',
  'cinema',
  'event',
  'restaurant',
  'bus'
)

$tenantCategoryQuery = @"
SELECT t.id::text || '|' || coalesce(string_agg(c.code, ',' ORDER BY c.sort_order, c.code), '')
FROM agency.tenants t
LEFT JOIN agency.categories c ON c.tenant_id=t.id AND c.active AND c.parent_id IS NULL
GROUP BY t.id
ORDER BY t.id;
"@
$tenantCategories = @(& $pg @common -Atc $tenantCategoryQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB tenant kategori sözlüğü okunamadı.'
}
$expectedCategorySet = ($expectedCategories | Sort-Object) -join ','
foreach ($row in $tenantCategories) {
  $parts = $row -split '\|', 2
  $tenantId = $parts[0]
  $codes = if ($parts.Count -gt 1 -and $parts[1]) { @($parts[1].Split(',')) } else { @() }
  $actualCategorySet = ($codes | Sort-Object) -join ','
  if ($actualCategorySet -ne $expectedCategorySet) {
    throw "Tenant kategori sözlüğü eksik/fazla: $tenantId -> $actualCategorySet"
  }
}

$activeVillaQuery = "SELECT count(*) FROM agency.categories WHERE code='villa' AND active;"
$activeVillaCount = ((& $pg @common -Atc $activeVillaQuery) | Select-Object -First 1)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB villa alias kontrolü çalıştırılamadı.'
}
if ([int]$activeVillaCount -ne 0) {
  throw "villa ana kategori olarak aktif olamaz. Aktif kayıt sayısı: $activeVillaCount"
}
Write-Output 'Acente DB tenant kategori sözlüğü uyumlu.'

$expected = @(
  'property_type',
  'bedroom_count',
  'bathroom_count',
  'guest_capacity',
  'pool_type',
  'kitchen',
  'season_rules'
)

$query = @"
SELECT DISTINCT f.field_key
FROM agency.categories c
JOIN agency.category_fields f ON f.category_id=c.id
WHERE c.code='holiday_home'
ORDER BY f.field_key;
"@

$actual = @(& $pg @common -Atc $query)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB sözleşme kontrolü çalıştırılamadı.'
}

$actualSorted = @($actual | Sort-Object)
$expectedSorted = @($expected | Sort-Object)
if (($actualSorted -join ',') -ne ($expectedSorted -join ',')) {
  throw "Acente DB holiday_home alanları sözleşmeyle uyumsuz: $($actualSorted -join ',')"
}

$propertyTypeQuery = @"
SELECT DISTINCT f.options::text
FROM agency.categories c
JOIN agency.category_fields f ON f.category_id=c.id
WHERE c.code='holiday_home' AND f.field_key='property_type';
"@
$propertyTypeOptions = @(& $pg @common -Atc $propertyTypeQuery)
if ($LASTEXITCODE -ne 0 -or $propertyTypeOptions.Count -eq 0) {
  throw 'Acente DB holiday_home.property_type seçenekleri okunamadı.'
}
if (($propertyTypeOptions | Select-Object -Unique).Count -ne 1 -or $propertyTypeOptions[0] -ne '["Villa", "Apart", "Bungalov", "Daire", "Residence"]') {
  throw "Acente DB holiday_home.property_type seçenekleri uyumsuz: $($propertyTypeOptions -join ' | ')"
}

Write-Output 'Acente DB holiday_home alan sözleşmesi uyumlu.'

$expectedYacht = @(
  'yacht_type',
  'capacity',
  'cabin_count',
  'departure_port',
  'route',
  'captain_included',
  'fuel_policy'
)

$yachtQuery = @"
SELECT DISTINCT f.field_key
FROM agency.categories c
JOIN agency.category_fields f ON f.category_id=c.id
WHERE c.code='yacht'
ORDER BY f.field_key;
"@
$actualYacht = @(& $pg @common -Atc $yachtQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB yacht sözleşme kontrolü çalıştırılamadı.'
}
$actualYachtSorted = @($actualYacht | Sort-Object)
$expectedYachtSorted = @($expectedYacht | Sort-Object)
if (($actualYachtSorted -join ',') -ne ($expectedYachtSorted -join ',')) {
  throw "Acente DB yacht alanları sözleşmeyle uyumsuz: $($actualYachtSorted -join ',')"
}

$yachtTypeQuery = @"
SELECT DISTINCT f.options::text
FROM agency.categories c
JOIN agency.category_fields f ON f.category_id=c.id
WHERE c.code='yacht' AND f.field_key='yacht_type';
"@
$yachtTypeOptions = @(& $pg @common -Atc $yachtTypeQuery)
if ($LASTEXITCODE -ne 0 -or $yachtTypeOptions.Count -eq 0) {
  throw 'Acente DB yacht.yacht_type seçenekleri okunamadı.'
}
if (($yachtTypeOptions | Select-Object -Unique).Count -ne 1 -or $yachtTypeOptions[0] -ne '["Gulet", "Motoryat", "Yelkenli", "Katamaran", "Tekne"]') {
  throw "Acente DB yacht.yacht_type seçenekleri uyumsuz: $($yachtTypeOptions -join ' | ')"
}

Write-Output 'Acente DB yacht alan sözleşmesi uyumlu.'

$contractPath = Join-Path $projectRoot 'contracts/supplier-listing-contract.v1.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$categoryAttributes = $contract.category_attributes
foreach ($categoryName in $categoryAttributes.PSObject.Properties.Name) {
  $expectedFields = @($categoryAttributes.$categoryName | Sort-Object)
  $dbFieldQuery = @"
SELECT DISTINCT f.field_key
FROM agency.categories c
JOIN agency.category_fields f ON f.category_id=c.id
WHERE c.code='$categoryName'
ORDER BY f.field_key;
"@
  $dbFields = @(& $pg @common -Atc $dbFieldQuery)
  if ($LASTEXITCODE -ne 0) {
    throw "Acente DB $categoryName alanları okunamadı."
  }
  $actualFields = @($dbFields | Sort-Object)
  if (($actualFields -join ',') -ne ($expectedFields -join ',')) {
    throw "Acente DB $categoryName alanları sözleşmeyle uyumsuz: $($actualFields -join ',')"
  }
}

Write-Output 'Acente DB tüm kategori alan sözleşmeleri uyumlu.'

function Assert-OnboardingItems($kind, $expectedItems) {
  $query = "SELECT data[2] FROM agency.supplier_onboarding_contract_items() WHERE data[1]='$kind' ORDER BY data[3]::int, data[2];"
  $actualItems = @(& $pg @common -Atc $query)
  if ($LASTEXITCODE -ne 0) {
    throw "Acente DB tedarikçi onboarding sözleşmesi okunamadı: $kind"
  }
  $actualSorted = @($actualItems | Sort-Object)
  $expectedSorted = @($expectedItems | Sort-Object)
  if (($actualSorted -join ',') -ne ($expectedSorted -join ',')) {
    throw "Acente DB tedarikçi onboarding $kind sözleşmesi uyumsuz: $($actualSorted -join ',')"
  }
}

Assert-OnboardingItems 'identity_field' @($contract.supplier_onboarding.required_identity_fields)
Assert-OnboardingItems 'business_field' @($contract.supplier_onboarding.required_business_fields)
Assert-OnboardingItems 'required_document' @($contract.supplier_onboarding.required_documents)
Assert-OnboardingItems 'approval_status' @($contract.supplier_onboarding.approval_statuses)

$expectedApprovalStatuses = @($contract.supplier_onboarding.approval_statuses | Sort-Object)
$applicationStatusQuery = @"
SELECT data[1]
FROM agency.supplier_application_contract_statuses()
ORDER BY data[2]::int;
"@
$actualApplicationStatuses = @(& $pg @common -Atc $applicationStatusQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB tedarikçi başvuru durum sözleşmesi okunamadı.'
}
if (((@($actualApplicationStatuses | Sort-Object)) -join ',') -ne ($expectedApprovalStatuses -join ',')) {
  throw "Acente DB tedarikçi başvuru durumları sözleşmeyle uyumsuz: $($actualApplicationStatuses -join ',')"
}

Write-Output 'Acente DB tedarikçi onboarding sözleşmesi uyumlu.'

$supplierApplicationDecisionQuery = @'
DO $$
DECLARE
  tenant uuid;
  reviewer uuid;
  supplier uuid;
  application uuid;
  answer text;
BEGIN
  SELECT id INTO tenant FROM agency.tenants ORDER BY created_at LIMIT 1;
  SELECT id INTO reviewer FROM agency.users WHERE tenant_id=tenant ORDER BY created_at LIMIT 1;

  INSERT INTO agency.users(tenant_id,email,display_name,membership_type,active)
  VALUES(tenant,'contract-supplier-decision@example.invalid','Contract Supplier','supplier',true)
  ON CONFLICT(tenant_id,email) DO UPDATE SET display_name=excluded.display_name
  RETURNING id INTO supplier;

  INSERT INTO agency.applications(tenant_id,user_id,type,status,identity_status,category_code,note)
  VALUES(tenant,supplier,'supplier','submitted','verified','hotel','contract decision test')
  RETURNING id INTO application;

  answer := agency.decide_supplier_application(tenant, application, reviewer, 'in_review', 'review started');
  IF answer <> 'ok' THEN
    RAISE EXCEPTION 'supplier application in_review decision failed: %', answer;
  END IF;

  answer := agency.decide_supplier_application(tenant, application, reviewer, 'approved', 'approved');
  IF answer <> 'requirements_incomplete' THEN
    RAISE EXCEPTION 'supplier application incomplete approval was not blocked: %', answer;
  END IF;

  answer := agency.decide_supplier_application(tenant, application, reviewer, 'rejected', 'incomplete documents');
  IF answer <> 'ok' THEN
    RAISE EXCEPTION 'supplier application rejection failed: %', answer;
  END IF;

  answer := agency.decide_supplier_application(tenant, application, reviewer, 'approved', 'late approve');
  IF answer <> 'invalid_transition' THEN
    RAISE EXCEPTION 'supplier application invalid transition was not blocked: %', answer;
  END IF;

  UPDATE agency.applications SET status='deleted' WHERE id=application;
END $$;
'@
& $pg @common -v ON_ERROR_STOP=1 -c $supplierApplicationDecisionQuery | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB tedarikçi başvuru karar akışı çalışmadı.'
}

Write-Output 'Acente DB tedarikçi başvuru karar akışı uyumlu.'

$supplierApplicationDocumentDecisionQuery = @'
DO $$
DECLARE
  tenant uuid;
  reviewer uuid;
  supplier uuid;
  application uuid;
  document uuid;
  source_document uuid;
  answer text;
  visible_count int;
BEGIN
  SELECT id INTO tenant FROM agency.tenants ORDER BY created_at LIMIT 1;
  SELECT id INTO reviewer FROM agency.users WHERE tenant_id=tenant ORDER BY created_at LIMIT 1;

  INSERT INTO agency.users(tenant_id,email,display_name,membership_type,active)
  VALUES(tenant,'contract-supplier-document@example.invalid','Contract Supplier Document','supplier',true)
  ON CONFLICT(tenant_id,email) DO UPDATE SET display_name=excluded.display_name
  RETURNING id INTO supplier;

  INSERT INTO agency.applications(tenant_id,user_id,type,status,identity_status,category_code,note)
  VALUES(tenant,supplier,'supplier','submitted','verified','hotel','contract document test')
  RETURNING id INTO application;

  source_document := agency.submit_supplier_document(tenant,supplier,'tax_certificate',
    'https://example.invalid/document/contract-' || application::text,NULL);
  SELECT id INTO document FROM agency.application_documents
  WHERE application_id=application AND supplier_document_id=source_document;

  SELECT count(*) INTO visible_count
  FROM agency.supplier_application_documents(tenant)
  WHERE data[1]=application::text
    AND data[3] IN ('tax_certificate','authorized_signature','trade_registry_or_chamber_record','service_license_if_required','bank_account_verification');

  IF visible_count <> 5 THEN
    RAISE EXCEPTION 'supplier application document contract coverage mismatch: %', visible_count;
  END IF;

  answer := agency.decide_supplier_application_document(tenant, document, reviewer, 'approved', 'ok');
  IF answer <> 'ok' THEN
    RAISE EXCEPTION 'supplier application document approval failed: %', answer;
  END IF;

  IF NOT EXISTS(SELECT 1 FROM agency.application_documents WHERE id=document AND status='approved' AND reviewed_by=reviewer) THEN
    RAISE EXCEPTION 'supplier application document approval was not persisted';
  END IF;

  answer := agency.decide_supplier_application_document(tenant, document, reviewer, 'invalid', '');
  IF answer <> 'invalid_decision' THEN
    RAISE EXCEPTION 'supplier application document invalid decision was not blocked: %', answer;
  END IF;

  UPDATE agency.applications SET status='deleted' WHERE id=application;
END $$;
'@
& $pg @common -v ON_ERROR_STOP=1 -c $supplierApplicationDocumentDecisionQuery | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB tedarikçi başvuru belge karar akışı çalışmadı.'
}

Write-Output 'Acente DB tedarikçi başvuru belge karar akışı uyumlu.'

$expectedSupplierPanelModules = @($contract.supplier_panel_modules | Sort-Object)
$supplierPanelModuleQuery = @"
SELECT DISTINCT code
FROM agency.modules
WHERE active
ORDER BY code;
"@
$actualSupplierPanelModules = @(& $pg @common -Atc $supplierPanelModuleQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB tedarikçi panel modül sözleşmesi okunamadı.'
}
$actualSupplierPanelModules = @($actualSupplierPanelModules | Where-Object { $expectedSupplierPanelModules -contains $_ } | Sort-Object)
if (($actualSupplierPanelModules -join ',') -ne ($expectedSupplierPanelModules -join ',')) {
  throw "Acente DB tedarikçi panel modülleri sözleşmeyle uyumsuz: $($actualSupplierPanelModules -join ',')"
}

Write-Output 'Acente DB tedarikçi panel modül sözleşmesi uyumlu.'

$expectedListingStatuses = @($contract.listing_common.statuses | Sort-Object)
$listingStatusQuery = @"
SELECT data[1]
FROM agency.supplier_listing_lifecycle_statuses()
ORDER BY data[2]::int;
"@
$actualListingStatuses = @(& $pg @common -Atc $listingStatusQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB ilan yaşam döngüsü sözleşmesi okunamadı.'
}
if (((@($actualListingStatuses | Sort-Object)) -join ',') -ne ($expectedListingStatuses -join ',')) {
  throw "Acente DB ilan yaşam döngüsü sözleşmesi uyumsuz: $($actualListingStatuses -join ',')"
}

$legacyReviewCount = ((& $pg @common -Atc "SELECT count(*) FROM agency.listings WHERE status='review';") | Select-Object -First 1)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB eski review statüsü kontrol edilemedi.'
}
if ([int]$legacyReviewCount -ne 0) {
  throw "Acente DB eski review statüsü kaldı: $legacyReviewCount"
}

Write-Output 'Acente DB ilan yaşam döngüsü sözleşmesi uyumlu.'

$listingValidationInvalidQuery = @'
SELECT field_key
FROM agency.validate_listing_contract(
  (SELECT id FROM agency.tenants ORDER BY created_at LIMIT 1),
  'holiday_home',
  jsonb_build_object('contract_fields', jsonb_build_object('property_type', 'Villa'))
)
ORDER BY field_key;
'@
$missingInvalid = @(& $pg @common -Atc $listingValidationInvalidQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB ilan sözleşme doğrulama fonksiyonu çalıştırılamadı.'
}
$expectedMissingHolidayHome = @(
  'bathroom_count',
  'bedroom_count',
  'guest_capacity'
) | Sort-Object
if (((@($missingInvalid | Sort-Object)) -join ',') -ne ($expectedMissingHolidayHome -join ',')) {
  throw "Acente DB eksik ilan alanı doğrulaması uyumsuz: $($missingInvalid -join ',')"
}

$listingValidationValidQuery = @'
SELECT field_key
FROM agency.validate_listing_contract(
  (SELECT id FROM agency.tenants ORDER BY created_at LIMIT 1),
  'holiday_home',
  jsonb_build_object('contract_fields', jsonb_build_object('property_type', 'Villa', 'bedroom_count', '3', 'bathroom_count', '2', 'guest_capacity', '6'))
)
ORDER BY field_key;
'@
$missingValid = @(& $pg @common -Atc $listingValidationValidQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB geçerli ilan sözleşme doğrulaması çalıştırılamadı.'
}
if ($missingValid.Count -ne 0) {
  throw "Acente DB geçerli ilan sözleşme doğrulaması alan eksik döndürdü: $($missingValid -join ',')"
}

Write-Output 'Acente DB ilan sözleşme doğrulaması uyumlu.'

$listingPublishGuardQuery = @'
DO $$
DECLARE
  tenant uuid;
  blocked boolean := false;
  valid_listing uuid;
BEGIN
  SELECT id INTO tenant FROM agency.tenants ORDER BY created_at LIMIT 1;

  DELETE FROM agency.listings
  WHERE tenant_id = tenant
    AND code IN ('CONTRACT-GUARD-TEST', 'CONTRACT-GUARD-VALID-TEST');

  BEGIN
    INSERT INTO agency.listings(
      tenant_id,
      code,
      category,
      title,
      locality,
      description,
      currency,
      price_minor,
      status,
      metadata
    )
    VALUES(
      tenant,
      'CONTRACT-GUARD-TEST',
      'holiday_home',
      'Contract Guard Test',
      'Test',
      'Test',
      'TRY',
      10000,
      'published',
      jsonb_build_object('contract_fields', jsonb_build_object('property_type', 'Villa'))
    );
  EXCEPTION WHEN check_violation THEN
    blocked := true;
  END;

  IF NOT blocked THEN
    RAISE EXCEPTION 'listing contract publish guard did not block invalid listing';
  END IF;

  INSERT INTO agency.listings(
    tenant_id,
    code,
    category,
    title,
    locality,
    description,
    currency,
    price_minor,
    status,
    metadata,
    images,
    owner_info,
    cancellation_policy
  )
  VALUES(
    tenant,
    'CONTRACT-GUARD-VALID-TEST',
    'holiday_home',
    'Contract Guard Valid Test',
    'Test',
    'Test description',
    'TRY',
    10000,
    'published',
    jsonb_build_object('contract_fields', jsonb_build_object('property_type', 'Villa', 'bedroom_count', '3', 'bathroom_count', '2', 'guest_capacity', '6')),
    jsonb_build_array(jsonb_build_object('url','/static/test.jpg')),
    jsonb_build_object('owner_name','Contract Test'),
    jsonb_build_object('policy','Flexible')
  )
  RETURNING id INTO valid_listing;

  UPDATE agency.listings SET status='archived' WHERE id=valid_listing;

  DELETE FROM agency.listings
  WHERE id = valid_listing
    OR (
      tenant_id = tenant
      AND code IN ('CONTRACT-GUARD-TEST', 'CONTRACT-GUARD-VALID-TEST')
    );
END $$;
'@
& $pg @common -v ON_ERROR_STOP=1 -c $listingPublishGuardQuery | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB ilan yayına alma sözleşme koruması çalışmadı.'
}

Write-Output 'Acente DB ilan yayına alma sözleşme koruması uyumlu.'

$canonicalCategorySqlList = (@($categoryAttributes.PSObject.Properties.Name) | ForEach-Object { "'$_'" }) -join ','
$invalidFilterCategoryQuery = @"
SELECT category_code
FROM agency.category_filter_groups
WHERE category_code NOT IN ($canonicalCategorySqlList)
ORDER BY category_code;
"@
$invalidFilterCategories = @(& $pg @common -Atc $invalidFilterCategoryQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB yönetilebilir filtre kategori kapsamı okunamadı.'
}
if ($invalidFilterCategories.Count -gt 0) {
  throw "Acente DB yönetilebilir filtrelerde sözleşme dışı kategori kodu var: $($invalidFilterCategories -join ',')"
}

$managedFilterCoverageQuery = @"
SELECT c
FROM unnest(ARRAY[$canonicalCategorySqlList]) AS expected(c)
WHERE NOT EXISTS (
  SELECT 1
  FROM agency.category_filter_groups g
  JOIN agency.tenants t ON t.id = g.tenant_id
  WHERE g.category_code = expected.c
    AND g.active
)
ORDER BY c;
"@
$missingManagedFilterCategories = @(& $pg @common -Atc $managedFilterCoverageQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB yönetilebilir filtre kategori kapsama kontrolü çalıştırılamadı.'
}
if ($missingManagedFilterCategories.Count -gt 0) {
  throw "Acente DB yönetilebilir filtre grubu eksik kategoriler: $($missingManagedFilterCategories -join ',')"
}

$managedFilterChecks = @(
  @{ Category = 'holiday_home'; Group = 'property_type'; Expected = @('apart','bungalov','daire','residence','villa') },
  @{ Category = 'yacht'; Group = 'yacht_type'; Expected = @('gulet','katamaran','motoryat','tekne','yelkenli') }
)

foreach ($check in $managedFilterChecks) {
  $groupQuery = @"
SELECT data[1]
FROM agency.category_filter_groups_for((SELECT id FROM agency.tenants ORDER BY created_at LIMIT 1), '$($check.Category)', 'tr')
WHERE data[3]='$($check.Group)';
"@
  $groupId = ((& $pg @common -Atc $groupQuery) | Select-Object -First 1)
  if ($LASTEXITCODE -ne 0 -or -not $groupId) {
    throw "Acente DB yönetilebilir filtre grubu eksik: $($check.Category).$($check.Group)"
  }

  $itemsQuery = @"
SELECT data[2]
FROM agency.category_filter_items_for('$groupId'::uuid, 'tr')
ORDER BY data[2];
"@
  $items = @(& $pg @common -Atc $itemsQuery)
  if ($LASTEXITCODE -ne 0) {
    throw "Acente DB yönetilebilir filtre maddeleri okunamadı: $($check.Category).$($check.Group)"
  }
  if (((@($items | Sort-Object)) -join ',') -ne ((@($check.Expected | Sort-Object)) -join ',')) {
    throw "Acente DB yönetilebilir filtre maddeleri uyumsuz: $($check.Category).$($check.Group) -> $($items -join ',')"
  }
}

Write-Output 'Acente DB yönetilebilir kategori filtreleri uyumlu.'

$syncContractStateQuery = @"
SELECT data[1] || '=' || data[2]
FROM agency.sync_contract_state((SELECT id FROM agency.tenants ORDER BY created_at LIMIT 1))
ORDER BY data[1];
"@
$syncContractStateRows = @(& $pg @common -Atc $syncContractStateQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Acente DB senkronizasyon sözleşme durumu okunamadı.'
}
$syncContractState = @{}
foreach ($row in $syncContractStateRows) {
  $parts = $row -split '=', 2
  if ($parts.Count -eq 2) {
    $syncContractState[$parts[0]] = $parts[1]
  }
}
if ($syncContractState['catalog_contract_version'] -ne '1.1.0') {
  throw "Acente DB sync katalog sözleşme sürümü uyumsuz: $($syncContractState['catalog_contract_version'])"
}
if ($syncContractState['supplier_listing_contract_version'] -ne $contract.contract_version) {
  throw "Acente DB sync ilan sözleşme sürümü uyumsuz: $($syncContractState['supplier_listing_contract_version'])"
}
if ([int]$syncContractState['active_category_count'] -ne 17) {
  throw "Acente DB sync kategori sayısı uyumsuz: $($syncContractState['active_category_count'])"
}
if ([int]$syncContractState['active_filter_item_count'] -lt 17) {
  throw "Acente DB sync filtre maddesi sayısı şüpheli: $($syncContractState['active_filter_item_count'])"
}
if ([int]$syncContractState['active_supplier_module_count'] -ne $expectedSupplierPanelModules.Count) {
  throw "Acente DB sync tedarikçi modül sayısı uyumsuz: $($syncContractState['active_supplier_module_count'])"
}
if (-not $syncContractState['supplier_module_detail_signature'] -or $syncContractState['supplier_module_detail_signature'].Length -ne 32) {
  throw "Acente DB sync tedarikçi modül detay imzası geçersiz: $($syncContractState['supplier_module_detail_signature'])"
}

Write-Output 'Acente DB senkronizasyon sözleşme durumu uyumlu.'

$supplierReviewTest = Join-Path $projectRoot 'test/supplier_review_actor_guard.sql'
& $pg @common -v ON_ERROR_STOP=1 -f $supplierReviewTest
if ($LASTEXITCODE -ne 0) {
  throw 'Tedarikçi inceleme tenant ve yetki testi başarısız.'
}
Write-Output 'Tedarikçi inceleme tenant ve yetki testi geçti.'

$supplierCompletionTest = Join-Path $projectRoot 'test/supplier_application_completion.sql'
& $pg @common -v ON_ERROR_STOP=1 -f $supplierCompletionTest
if ($LASTEXITCODE -ne 0) {
  throw 'Tedarikçi başvuru belge ve kimlik onayı testi başarısız.'
}
Write-Output 'Tedarikçi başvuru belge ve kimlik onayı testi geçti.'

$supplierListingGateTest = Join-Path $projectRoot 'test/supplier_listing_approval_gate.sql'
& $pg @common -v ON_ERROR_STOP=1 -f $supplierListingGateTest
if ($LASTEXITCODE -ne 0) {
  throw 'Tedarikçi ilan yayın yetkisi testi başarısız.'
}
Write-Output 'Tedarikçi ilan yayın yetkisi testi geçti.'
