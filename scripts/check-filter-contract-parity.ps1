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
  return @($Rows | Where-Object { $_ -and $_.Trim() -ne '' } | Sort-Object)
}

$agencyEnv = Read-EnvFile (Join-Path $AgencyRoot '.env')
$nexusEnv = Read-EnvFile (Join-Path $NexusRoot '.env')

$agencySql = @"
WITH selected_tenant AS (
  SELECT id
  FROM agency.tenants
  ORDER BY created_at
  LIMIT 1
)
SELECT concat_ws('|', g.category_code, g.group_key, i.item_key, coalesce(i.contract_field_key,''), coalesce(i.contract_value,''))
FROM agency.category_filter_groups g
JOIN selected_tenant t ON t.id = g.tenant_id
JOIN agency.category_filter_items i ON i.group_id = g.id
WHERE g.active AND i.active
ORDER BY 1;
"@

$nexusSql = @"
SELECT concat_ws('|', g.category_code, g.group_key, i.item_key, coalesce(i.contract_field_code,''), coalesce(i.contract_value,''))
FROM onboarding.category_filter_groups g
JOIN onboarding.category_filter_items i ON i.group_id = g.id
WHERE g.active AND i.active
ORDER BY 1;
"@

$agencyRows = Normalize-Rows (Invoke-ProjectSql $agencyEnv $agencySql)
$nexusRows = Normalize-Rows (Invoke-ProjectSql $nexusEnv $nexusSql)

$missingInNexus = @($agencyRows | Where-Object { $nexusRows -notcontains $_ })
$missingInAgency = @($nexusRows | Where-Object { $agencyRows -notcontains $_ })

if ($missingInNexus.Count -gt 0 -or $missingInAgency.Count -gt 0) {
  if ($missingInNexus.Count -gt 0) {
    Write-Output 'Nexus tarafında eksik filtre sözleşmeleri:'
    $missingInNexus | ForEach-Object { Write-Output "  $_" }
  }
  if ($missingInAgency.Count -gt 0) {
    Write-Output 'Acente tarafında eksik filtre sözleşmeleri:'
    $missingInAgency | ForEach-Object { Write-Output "  $_" }
  }
  throw 'Acente ve Nexus yönetilebilir filtre sözleşmeleri farklı.'
}

Write-Output "Yönetilebilir filtre sözleşmeleri uyumlu: $($agencyRows.Count) aktif filtre maddesi."
