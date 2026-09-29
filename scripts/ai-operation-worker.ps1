$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
Get-Content $envFile | ForEach-Object { $line=$_.Trim(); $i=$line.IndexOf('='); if($i -gt 0){ Set-Item "Env:$($line.Substring(0,$i).Trim())" $line.Substring($i+1).Trim() } }
$psql=(Get-Command psql -ErrorAction Stop).Source
function Invoke-AgencySql([string]$sql,[switch]$RowsOnly){$args=@('-X','-w','-v','ON_ERROR_STOP=1','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE);if($RowsOnly){$args+=@('-At')};$args+=@('-c',$sql);$out=& $psql @args;if($LASTEXITCODE -ne 0){throw "PostgreSQL command failed: $LASTEXITCODE"};return $out}
while($true){
  try {
    # Her tenant için worker heartbeat ve kuyruk derinliğini güncelle.
    Invoke-AgencySql "insert into agency.ai_worker_health(tenant_id,worker_key,status,last_heartbeat,queue_depth,updated_at) select t.id,'ai-operation',case when exists(select 1 from agency.ai_operation_tasks q where q.tenant_id=t.id and q.status in ('queued','running')) then 'degraded' else 'healthy' end,now(),coalesce((select count(*) from agency.ai_operation_tasks q where q.tenant_id=t.id and q.status in ('queued','running','awaiting_approval')),0),now() from agency.tenants t on conflict(tenant_id,worker_key) do update set status=excluded.status,last_heartbeat=now(),queue_depth=excluded.queue_depth,updated_at=now()" | Out-Null
    # Financial, destructive and customer-facing actions always stop at approval.
    Invoke-AgencySql "update agency.ai_operation_tasks set status='awaiting_approval',updated_at=now() where status='queued' and risk_level in ('high','financial') and agency.module_execution_allowed(tenant_id,'operations')" | Out-Null
    Invoke-AgencySql "insert into agency.ai_action_approvals(tenant_id,task_id,action,payload) select tenant_id,id,operation,input from agency.ai_operation_tasks t where t.status='awaiting_approval' and not exists(select 1 from agency.ai_action_approvals a where a.task_id=t.id and a.status='pending')" | Out-Null
    # There is no operation executor here. Preserve queued work instead of claiming it
    # and subsequently reporting a timeout for an operation that was never attempted.
    Invoke-AgencySql "update agency.ai_operation_tasks set status='queued',error='Yürütücü yapılandırılmamış',updated_at=now() where status='running' and updated_at < now() - interval '15 minutes'" | Out-Null
  } catch {
    Add-Content (Join-Path $root '.local/ai-operation-worker-error.log') "$(Get-Date -Format s) $($_.Exception.Message)"
    Invoke-AgencySql "update agency.ai_worker_health set status='degraded',error_count=error_count+1,updated_at=now() where worker_key='ai-operation'" | Out-Null
  }
  Start-Sleep -Seconds 15
}
