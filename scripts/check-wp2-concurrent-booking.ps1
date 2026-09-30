param([string]$NexusEnvPath = (Join-Path $PSScriptRoot '..\..\Nexustraveltech\.env'))

$ErrorActionPreference = 'Stop'
$nexusSettings = @{}
Get-Content -LiteralPath $NexusEnvPath | ForEach-Object {
  if ($_ -match '^([^#=]+)=(.*)$') { $nexusSettings[$Matches[1].Trim()] = $Matches[2].Trim() }
}
$sourceDatabase = $nexusSettings.PGDATABASE
$dbUser = $nexusSettings.PGOWNER
$previousPassword = $env:PGPASSWORD
$env:PGPASSWORD = $nexusSettings.PGOWNER_PASSWORD
$database = 'wp2_race_' + [guid]::NewGuid().ToString('N').Substring(0, 12)
$pgHostName = $nexusSettings.PGHOST
$pgPortNumber = $nexusSettings.PGPORT
if (!$sourceDatabase -or !$dbUser -or !$pgHostName -or !$pgPortNumber -or !$env:PGPASSWORD) {
  throw 'NEXUS bakım veritabanı ayarları eksik.'
}
$connection = @('-X', '-w', '-v', 'ON_ERROR_STOP=1', '-At', '-h', $pgHostName, '-p', $pgPortNumber, '-U', $dbUser, '-d', $database)
$created = $false
$dumpPath = Join-Path ([IO.Path]::GetTempPath()) ($database + '.dump')

try {
  & pg_dump -w -h $pgHostName -p $pgPortNumber -U $dbUser -d $sourceDatabase -Fc -f $dumpPath
  if ($LASTEXITCODE -ne 0) { throw 'NEXUS test kopyası alınamadı.' }
  & createdb -w -h $pgHostName -p $pgPortNumber -U $dbUser $database
  if ($LASTEXITCODE -ne 0) { throw 'WP2 yarış testi için yalıtılmış veritabanı oluşturulamadı.' }
  $created = $true
  & pg_restore -w -h $pgHostName -p $pgPortNumber -U $dbUser -d $database --no-owner --no-privileges $dumpPath
  if ($LASTEXITCODE -ne 0) { throw 'NEXUS test kopyası geri yüklenemedi.' }

  $fixtureSql = @'
SELECT concat_ws('|',p.id,r.id,c.agency_id,p.tenant_id,d.service_date,d.nightly_minor,p.currency)
FROM catalog.properties p
JOIN partners.connections c ON c.supplier_id=p.tenant_id AND c.status='active'
JOIN partners.connection_policies cp ON cp.agency_id=c.agency_id AND cp.active
JOIN inventory.resources r ON r.property_id=p.id AND r.tenant_id=p.tenant_id
JOIN inventory.days d ON d.resource_id=r.id AND d.tenant_id=r.tenant_id
WHERE p.status='published' AND p.category_code IN ('hotel','holiday_home','yacht')
  AND d.service_date>(clock_timestamp() AT TIME ZONE 'Europe/Istanbul')::date
  AND d.capacity-d.blocked-d.held-d.sold>=1
  AND d.nightly_minor IS NOT NULL AND d.currency=p.currency
  AND (jsonb_array_length(cp.allowed_categories)=0 OR p.category_code IN
    (SELECT value FROM jsonb_array_elements_text(cp.allowed_categories)))
ORDER BY d.service_date LIMIT 1
'@
  $fixture = & psql @connection -c $fixtureSql
  if ($LASTEXITCODE -ne 0 -or !$fixture) { throw 'Bağlı ve satılabilir NEXUS fikstürü bulunamadı.' }
  $fields = $fixture.Trim().Split('|')
  if ($fields.Count -ne 7) { throw 'Fikstür yanıtı okunamadı.' }
  $property, $resource, $agency, $supplier, $serviceDate, $amount, $currency = $fields
  $checkOut = ([datetime]::ParseExact($serviceDate, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)).AddDays(1).ToString('yyyy-MM-dd')

  $setCapacity = "UPDATE inventory.days SET capacity=sold+held+blocked+1 WHERE tenant_id='$supplier'::uuid AND resource_id='$resource'::uuid AND service_date='$serviceDate'::date"
  & psql @connection -c $setCapacity | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Son stok fikstürü hazırlanamadı.' }

  $jobs = @()
  foreach ($number in 1..2) {
    $reservation = [guid]::NewGuid().ToString()
    $key = 'wp2-real-race-' + [guid]::NewGuid().ToString('N')
    $sql = @"
SELECT pg_sleep(2);
SELECT partners.process_reservation_webhook('$key','$agency','$property','WP2 Race Guest $number','wp2-race-$number@example.invalid','','','$serviceDate','$checkOut',1,
  jsonb_build_object('reservation_id','$reservation','check_in','$serviceDate','check_out','$checkOut','guests',1,'amount_minor','$amount','currency','$currency'));
"@
    $jobs += Start-Job -ArgumentList $connection, $sql -ScriptBlock {
      param($psqlArgs, $query)
      $output = & psql @psqlArgs -c $query 2>&1
      if ($LASTEXITCODE -ne 0) { throw "psql failed: $output" }
      $output
    }
  }
  $jobs | Wait-Job | Out-Null
  $results = @($jobs | Receive-Job)
  $jobs | Remove-Job
  $replies = @($results | Where-Object { $_ -match '^\{' } | ForEach-Object { $_ | ConvertFrom-Json })
  if ($replies.Count -ne 2) { throw "İki yarış yanıtı alınamadı: $($results -join ' | ')" }
  $success = @($replies | Where-Object { $_.status -eq 'processed' })
  $rejected = @($replies | Where-Object { $_.error -in @('capacity_unavailable','inventory_unavailable') })
  if ($success.Count -ne 1 -or $rejected.Count -ne 1) {
    throw "Son stok yarışı beklenen sonucu vermedi: $($results -join ' | ')"
  }
  $sold = & psql @connection -c "SELECT sold+held+blocked-capacity FROM inventory.days WHERE tenant_id='$supplier'::uuid AND resource_id='$resource'::uuid AND service_date='$serviceDate'::date"
  if ($LASTEXITCODE -ne 0 -or [int]$sold -gt 0) { throw 'Stok kapasitesi aşıldı.' }
  Write-Output 'WP2 gerçek eşzamanlı son stok yarışı geçti: 1 rezervasyon, 1 kapasite reddi.'
} finally {
  if ($created -and $database -match '^wp2_race_[0-9a-f]{12}$') {
    & dropdb -w -h $pgHostName -p $pgPortNumber -U $dbUser --if-exists $database
    if ($LASTEXITCODE -ne 0) { Write-Warning "Geçici veritabanı temizlenemedi: $database" }
  }
  Remove-Item -LiteralPath $dumpPath -ErrorAction SilentlyContinue
  $env:PGPASSWORD = $previousPassword
}
