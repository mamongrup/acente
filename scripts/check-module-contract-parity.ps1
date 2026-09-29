param(
  [string]$AgencyRoot = 'C:\laragon\www\acente',
  [string]$NexusRoot = 'C:\laragon\www\Nexustraveltech'
)

$ErrorActionPreference = 'Stop'
$pg = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'

function Read-EnvFile([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) {
    throw ".env bulunamadı: $Path"
  }
  $values = @{}
  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    $index = $line.IndexOf('=')
    if ($index -gt 0) {
      $values[$line.Substring(0, $index).Trim()] = $line.Substring($index + 1).Trim()
    }
  }
  return $values
}

function Invoke-ProjectSql([hashtable]$Env, [string]$Sql) {
  $previousPassword = [Environment]::GetEnvironmentVariable('PGPASSWORD', 'Process')
  if ($Env.ContainsKey('PGPASSWORD')) {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $Env.PGPASSWORD, 'Process')
  }
  $args = @(
    '-X',
    '-w',
    '-v',
    'ON_ERROR_STOP=1',
    '-h',
    $Env.PGHOST,
    '-p',
    $Env.PGPORT,
    '-U',
    $Env.PGUSER,
    '-d',
    $Env.PGDATABASE,
    '-Atc',
    $Sql
  )
  try {
    $output = & $pg @args
    if ($LASTEXITCODE -ne 0) {
      throw "PostgreSQL sorgusu başarısız: $($Env.PGDATABASE)"
    }
    return @($output)
  } finally {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $previousPassword, 'Process')
  }
}

function Normalize-Rows([string[]]$Rows) {
  return @($Rows | ForEach-Object { "$_".Trim() } | Where-Object { $_ -ne '' } | Sort-Object)
}

$contractPath = Join-Path $AgencyRoot 'contracts/supplier-listing-contract.v1.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$expectedModules = @($contract.supplier_panel_modules | Sort-Object)
$expectedSqlList = ($expectedModules | ForEach-Object { "'$_'" }) -join ','
$moduleDetails = $contract.supplier_panel_module_details
if (-not $moduleDetails) {
  throw 'Tedarikçi panel modül detay sözleşmesi eksik: supplier_panel_module_details'
}

foreach ($moduleCode in $expectedModules) {
  $detail = $moduleDetails.$moduleCode
  if (-not $detail) {
    throw "Tedarikçi panel modül detay sözleşmesi eksik: $moduleCode"
  }
  if (-not $detail.family -or -not $detail.label_tr) {
    throw "Tedarikçi panel modül detayında family/label_tr eksik: $moduleCode"
  }
  if (@($detail.scope).Count -lt 1) {
    throw "Tedarikçi panel modül kapsamı boş olamaz: $moduleCode"
  }
  if (@($detail.permissions).Count -lt 1) {
    throw "Tedarikçi panel modül yetki kodu boş olamaz: $moduleCode"
  }
}

$detailCodes = @($moduleDetails.PSObject.Properties.Name | Sort-Object)
if (($detailCodes -join ',') -ne ($expectedModules -join ',')) {
  throw "Tedarikçi panel modül detay kodları supplier_panel_modules ile uyumsuz: $($detailCodes -join ',')"
}

$agencyEnv = Read-EnvFile (Join-Path $AgencyRoot '.env')
$nexusEnv = Read-EnvFile (Join-Path $NexusRoot '.env')

$agencySql = @"
SELECT DISTINCT code
FROM agency.modules
WHERE active
  AND code IN ($expectedSqlList)
ORDER BY code;
"@

$nexusSql = @"
SELECT code
FROM onboarding.product_modules
WHERE active
  AND code IN ($expectedSqlList)
ORDER BY code;
"@

$agencyDetailsSql = @"
SELECT concat_ws('|', code, family, array_to_string(scope, ','), array_to_string(permissions, ','))
FROM agency.supplier_panel_module_contract_details()
WHERE coalesce(label_tr, '') <> ''
ORDER BY code;
"@

$nexusDetailsSql = @"
SELECT concat_ws('|', code, family, array_to_string(scope, ','), array_to_string(permissions, ','))
FROM onboarding.supplier_panel_module_contract_details()
WHERE coalesce(label_tr, '') <> ''
ORDER BY code;
"@

$agencyRows = Normalize-Rows (Invoke-ProjectSql $agencyEnv $agencySql)
$nexusRows = Normalize-Rows (Invoke-ProjectSql $nexusEnv $nexusSql)
$agencyDetailRows = Normalize-Rows (Invoke-ProjectSql $agencyEnv $agencyDetailsSql)
$nexusDetailRows = Normalize-Rows (Invoke-ProjectSql $nexusEnv $nexusDetailsSql)
$supplierRoles = @('owner','operations_director','content_moderator','general_manager',
  'sales','editor','onboarding_specialist','frontdesk','support_specialist',
  'ai_pricing_specialist','marketing','housekeeping','finance_manager',
  'accounting','purchasing')
$supplierPermissions = @($expectedModules | ForEach-Object {
  @($moduleDetails.$_.permissions)
} | Sort-Object -Unique) + @('supplier.unknown')
$roleSql = ($supplierRoles | ForEach-Object { "('$_')" }) -join ','
$permissionSql = ($supplierPermissions | ForEach-Object { "('$_')" }) -join ','
$decisionSql = @"
WITH roles(role) AS (VALUES $roleSql), permissions(permission) AS (VALUES $permissionSql)
SELECT roles.role || '|' || permissions.permission || '|' ||
  agency.role_allows_supplier_permission(roles.role,permissions.permission)::text
FROM roles CROSS JOIN permissions ORDER BY roles.role,permissions.permission;
"@
$nexusDecisionSql = $decisionSql.Replace('agency.role_allows_supplier_permission',
  'onboarding.role_allows_supplier_permission')
$agencyDecisionRows = Normalize-Rows (Invoke-ProjectSql $agencyEnv $decisionSql)
$nexusDecisionRows = Normalize-Rows (Invoke-ProjectSql $nexusEnv $nexusDecisionSql)
if (($agencyDecisionRows -join "`n") -ne ($nexusDecisionRows -join "`n")) {
  throw 'Acente ve NEXUS tedarikçi rol/yetki kararları farklı.'
}
$expectedDetailRows = Normalize-Rows (@($expectedModules | ForEach-Object {
  $detail = $moduleDetails.$_
  "$_|$($detail.family)|$(@($detail.scope) -join ',')|$(@($detail.permissions) -join ',')"
}))

if (($agencyRows -join ',') -ne ($expectedModules -join ',')) {
  throw "Acente tedarikçi panel modülleri sözleşmeyle uyumsuz: $($agencyRows -join ',')"
}
if (($nexusRows -join ',') -ne ($expectedModules -join ',')) {
  throw "Nexus tedarikçi panel modülleri sözleşmeyle uyumsuz: $($nexusRows -join ',')"
}
if (($agencyDetailRows -join "`n") -ne ($expectedDetailRows -join "`n")) {
  throw "Acente tedarikçi panel modül detayları sözleşmeyle uyumsuz: $($agencyDetailRows -join '; ')"
}
if (($nexusDetailRows -join "`n") -ne ($expectedDetailRows -join "`n")) {
  throw "Nexus tedarikçi panel modül detayları sözleşmeyle uyumsuz: $($nexusDetailRows -join '; ')"
}

$missingInNexus = @($agencyRows | Where-Object { $nexusRows -notcontains $_ })
$missingInAgency = @($nexusRows | Where-Object { $agencyRows -notcontains $_ })
if ($missingInNexus.Count -gt 0 -or $missingInAgency.Count -gt 0) {
  if ($missingInNexus.Count -gt 0) {
    Write-Output 'Nexus tarafında eksik panel modülleri:'
    $missingInNexus | ForEach-Object { Write-Output "  $_" }
  }
  if ($missingInAgency.Count -gt 0) {
    Write-Output 'Acente tarafında eksik panel modülleri:'
    $missingInAgency | ForEach-Object { Write-Output "  $_" }
  }
  throw 'Acente ve Nexus tedarikçi panel modül sözleşmeleri farklı.'
}

Write-Output "Tedarikçi panel modül sözleşmeleri uyumlu: $($agencyRows.Count) aktif modül."
Write-Output "Tedarikçi rol/yetki kararları uyumlu: $($agencyDecisionRows.Count) karar."
