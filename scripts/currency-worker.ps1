$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim(); $index = $line.IndexOf('=')
  if ($index -gt 0) { Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim() }
}
$psql = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
$env:PGPASSWORD = $env:PGPASSWORD
function Invoke-AgencySql([string]$sql, [switch]$RowsOnly) {
  $arguments = @('-X','-w','-v','ON_ERROR_STOP=1','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE)
  if ($RowsOnly) { $arguments += @('-At') }
  $arguments += @('-c',$sql)
  $result = & $psql @arguments
  if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed with exit code $LASTEXITCODE" }
  return $result
}
function Update-Rates([string]$tenantId) {
  $xmlContent = & curl.exe --silent --show-error --fail --max-time 20 'https://www.tcmb.gov.tr/kurlar/today.xml'
  if ($LASTEXITCODE -ne 0 -or !$xmlContent) { throw 'TCMB servisine ulaşılamadı' }
  [xml]$xml = ($xmlContent -join "`n")
  $updated = 0
  foreach ($code in @('USD','EUR','GBP','RUB','AED')) {
    $node = $xml.Tarih_Date.Currency | Where-Object { $_.CurrencyCode -eq $code } | Select-Object -First 1
    if ($node -and $node.ForexSelling) {
      $rate = ([string]$node.ForexSelling).Replace(',','.')
      Invoke-AgencySql "update agency.currencies set rate=$rate,updated_at=now() where code='$code'" | Out-Null
      $updated++
    }
  }
  if ($updated -ne 5) { throw "TCMB returned only $updated supported currencies" }
  Invoke-AgencySql "update agency.currency_update_schedules set last_run_at=now(),last_status='success',last_error='' where tenant_id='$tenantId'::uuid" | Out-Null
  $rateRows = Invoke-AgencySql "select code||'|'||rate from agency.currencies where active=true order by code" -RowsOnly
  $rates = @{}
  foreach ($rateRow in $rateRows) {
    $rateParts = $rateRow -split '\|'
    if ($rateParts.Count -eq 2) { $rates[$rateParts[0]] = $rateParts[1] }
  }
  $status = [ordered]@{
    status = 'success'
    updatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    provider = 'TCMB'
    rates = $rates
  } | ConvertTo-Json -Depth 4
  Set-Content -LiteralPath (Join-Path $root 'priv/static/currency-status.json') -Value $status -Encoding UTF8
}
while ($true) {
  try {
    # Recover a claim left behind by a crashed worker before taking new work.
    Invoke-AgencySql "update agency.task_runs set status='queued',locked_until=null,error='Kur güncelleme işçisi yeniden başlatıldığı için kuyruk yeniden açıldı.' where task_name='currency.refresh' and status='running' and coalesce(locked_until,started_at,now()) < now() - interval '15 minutes'" | Out-Null
    $jobs = Invoke-AgencySql "update agency.task_runs set status='running',started_at=now(),locked_until=now()+interval '10 minutes',attempt=attempt+1 where id in (select id from agency.task_runs where task_name='currency.refresh' and status='queued' order by id limit 1 for update skip locked) returning id||'|'||tenant_id" -RowsOnly
    foreach ($job in $jobs) {
      $jobParts = $job -split '\|'; if ($jobParts.Count -lt 2) { continue }
      try { Update-Rates $jobParts[1]; Invoke-AgencySql "update agency.task_runs set status='success',finished_at=now(),locked_until=null,error='' where id='$($jobParts[0])'::uuid" | Out-Null }
      catch { Invoke-AgencySql "update agency.task_runs set status='failed',finished_at=now(),locked_until=null,error='currency refresh failed' where id='$($jobParts[0])'::uuid" | Out-Null }
    }
    $rows = Invoke-AgencySql "select tenant_id||'|'||to_char(first_run_at,'HH24:MI')||'|'||to_char(second_run_at,'HH24:MI')||'|'||coalesce(to_char(last_run_at,'YYYY-MM-DD HH24:MI'),'') from agency.currency_update_schedules where active=true" -RowsOnly
    $now = Get-Date
    foreach ($row in $rows) {
      $parts = $row -split '\|'; if ($parts.Count -lt 4) { continue }
      $stamp = $now.ToString('yyyy-MM-dd HH:mm')
      if (($now.ToString('HH:mm') -eq $parts[1] -or $now.ToString('HH:mm') -eq $parts[2]) -and $parts[3] -ne $stamp) {
        Update-Rates $parts[0]
      }
    }
  } catch {
    Add-Content (Join-Path $root '.local/currency-error.log') "$(Get-Date -Format s) $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 5
}
