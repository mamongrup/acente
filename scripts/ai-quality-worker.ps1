$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
Get-Content $envFile | ForEach-Object { $line=$_.Trim(); $i=$line.IndexOf('='); if($i -gt 0){ Set-Item "Env:$($line.Substring(0,$i).Trim())" $line.Substring($i+1).Trim() } }
$psql=(Get-Command psql -ErrorAction Stop).Source
function Invoke-AgencySql([string]$sql){$args=@('-X','-w','-v','ON_ERROR_STOP=1','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE,'-c',$sql);$out=& $psql @args;if($LASTEXITCODE -ne 0){throw "PostgreSQL command failed: $LASTEXITCODE"};return $out}
while($true){
  try {
    # A test is not a pass until its input has been run and its expected result compared.
    # Only a case with a recorded output and supported assertions may complete.
    Invoke-AgencySql @"
with picked as (
  select c.id from agency.ai_test_cases c
  where c.last_result='pending' and c.actual is not null
    and agency.module_execution_allowed(c.tenant_id,'quality')
    and agency.ai_quality_text_rules(c.expected,c.actual) is not null
  order by c.id for update of c skip locked limit 1
), done as (
  update agency.ai_test_cases c
  set last_result=case when agency.ai_quality_text_rules(c.expected,c.actual) then 'passed' else 'failed' end,
      last_run_at=now(),last_error=''
  from picked where c.id=picked.id
  returning c.tenant_id,c.last_result
)
insert into agency.module_run_events(tenant_id,module_key,operation,status,finished_at)
select tenant_id,'quality','quality_test',case when last_result='passed' then 'completed' else 'failed' end,now() from done
"@ | Out-Null
    Invoke-AgencySql "update agency.ai_test_cases c set last_error='Beklenen kurallar veya model çıktısı desteklenmiyor' where c.last_result='pending' and c.actual is not null and c.last_error='' and agency.module_execution_allowed(c.tenant_id,'quality') and agency.ai_quality_text_rules(c.expected,c.actual) is null" | Out-Null
    # Expose pending automatic tests to the super-admin health panel.
    Invoke-AgencySql "insert into agency.ai_worker_health(tenant_id,worker_key,status,last_heartbeat,queue_depth,details,updated_at) select t.id,'ai-quality',case when agency.module_execution_allowed(t.id,'quality') and exists(select 1 from agency.ai_test_cases c where c.tenant_id=t.id and c.last_result='pending' and (c.actual is null or agency.ai_quality_text_rules(c.expected,c.actual) is null)) then 'degraded' else 'healthy' end,now(),(select count(*) from agency.ai_test_cases c where c.tenant_id=t.id and c.last_result='pending'),jsonb_build_object('evaluation','text_rules_active','model_executor','not_configured'),now() from agency.tenants t on conflict(tenant_id,worker_key) do update set status=excluded.status,last_heartbeat=excluded.last_heartbeat,queue_depth=excluded.queue_depth,details=excluded.details,updated_at=excluded.updated_at" | Out-Null
  } catch { Add-Content (Join-Path $root '.local/ai-quality-worker-error.log') "$(Get-Date -Format s) $($_.Exception.Message)" }
  Start-Sleep -Seconds 15
}
