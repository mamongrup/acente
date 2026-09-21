$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
Get-Content $envFile | ForEach-Object { $line=$_.Trim(); $i=$line.IndexOf('='); if($i -gt 0){ Set-Item "Env:$($line.Substring(0,$i).Trim())" $line.Substring($i+1).Trim() } }
$psql='C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
function Invoke-AgencySql([string]$sql,[switch]$RowsOnly){$args=@('-X','-w','-v','ON_ERROR_STOP=1','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE);if($RowsOnly){$args+=@('-At')};$args+=@('-c',$sql);$out=& $psql @args;if($LASTEXITCODE -ne 0){throw "PostgreSQL command failed: $LASTEXITCODE"};return $out}
while($true){
 try {
   # Recover AI tasks claimed by a worker that crashed before finishing them.
   # The attempt cap prevents an endlessly failing task from re-entering the queue.
   Invoke-AgencySql "update agency.task_runs set status=case when attempt >= 3 then 'failed' else 'queued' end,finished_at=case when attempt >= 3 then now() else null end,locked_until=null,error=case when attempt >= 3 then 'AI görevi maksimum deneme sayısına ulaştı.' else 'AI işçisi yeniden başlatıldığı için kuyruk yeniden açıldı.' end where status='running' and coalesce(locked_until,started_at,now()) < now() - interval '15 minutes' and task_name like 'ai.%'" | Out-Null
   $jobs=Invoke-AgencySql "update agency.task_runs set status='running',started_at=now(),locked_until=now()+interval '10 minutes',attempt=attempt+1 where id in (select id from agency.task_runs where task_name='ai.supervisor' and status='queued' order by id limit 1 for update skip locked) returning id||'|'||tenant_id" -RowsOnly
  foreach($job in $jobs){$parts=$job -split '\|';if($parts.Count -lt 2){continue};$tenant=$parts[1];
   $failed=Invoke-AgencySql "select count(*) from agency.task_runs where tenant_id='$tenant'::uuid and task_name like 'ai.%' and status='failed'" -RowsOnly
   $queued=Invoke-AgencySql "select count(*) from agency.task_runs where tenant_id='$tenant'::uuid and task_name like 'ai.%' and status='queued'" -RowsOnly
   $retried=Invoke-AgencySql "with retry as (select id from agency.task_runs where tenant_id='$tenant'::uuid and task_name like 'ai.%' and status='failed' and attempt < 3 order by finished_at nulls first limit 25) update agency.task_runs set status='queued',locked_until=null,error='AI Müdür yeniden deniyor' where id in (select id from retry) returning id" -RowsOnly
   $retryCount=@($retried).Count
   Invoke-AgencySql "insert into agency.health_checks(tenant_id,component,status,details) values('$tenant'::uuid,'ai.supervisor',case when '$failed'::int > 10 then 'degraded' else 'ok' end,jsonb_build_object('failedTasks','$failed'::int,'queuedTasks','$queued'::int,'retriedTasks',$retryCount,'checkedAt',now()))" | Out-Null
    Invoke-AgencySql "update agency.task_runs set status='success',finished_at=now(),locked_until=null,error='' where id='$($parts[0])'::uuid" | Out-Null
  }
 } catch { Add-Content (Join-Path $root '.local/ai-supervisor-error.log') "$(Get-Date -Format s) $($_.Exception.Message)" }
 Start-Sleep -Seconds 15
}
