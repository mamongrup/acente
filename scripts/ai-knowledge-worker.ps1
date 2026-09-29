$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
Get-Content $envFile | ForEach-Object { $line=$_.Trim(); $i=$line.IndexOf('='); if($i -gt 0){ Set-Item "Env:$($line.Substring(0,$i).Trim())" $line.Substring($i+1).Trim() } }
$psql=(Get-Command psql -ErrorAction Stop).Source
function Invoke-AgencySql([string]$sql){$args=@('-X','-w','-v','ON_ERROR_STOP=1','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE,'-c',$sql);$out=& $psql @args;if($LASTEXITCODE -ne 0){throw "PostgreSQL command failed: $LASTEXITCODE"};return $out}
while($true){
  try {
    # Store actual text chunks before reporting a document as indexed. Embedding
    # generation can subsequently enrich these rows without changing their source.
    Invoke-AgencySql @"
with eligible as (
  select d.id,d.tenant_id,d.content
  from agency.ai_knowledge_documents d
  where d.status='pending' and length(btrim(d.content)) > 0
    and agency.module_execution_allowed(d.tenant_id,'knowledge')
  order by d.id limit 20 for update of d skip locked
), chunks as (
  insert into agency.ai_knowledge_chunks(document_id,tenant_id,chunk_index,content,metadata)
  select e.id,e.tenant_id,n.i,substr(e.content,n.i * 800 + 1,800),jsonb_build_object('index_type','text','chunk_size',800)
  from eligible e cross join lateral generate_series(0,(length(e.content)-1)/800) n(i)
  on conflict(document_id,chunk_index) do update
    set content=excluded.content,tenant_id=excluded.tenant_id,metadata=excluded.metadata
  returning document_id,tenant_id
), done as (
  update agency.ai_knowledge_documents d set status='indexed',updated_at=now()
  where (d.id,d.tenant_id) in (select distinct document_id,tenant_id from chunks)
  returning d.tenant_id
)
insert into agency.module_run_events(tenant_id,module_key,operation,status,finished_at)
select tenant_id,'knowledge','document_index','completed',now() from done
"@ | Out-Null
    Invoke-AgencySql "insert into agency.ai_worker_health(tenant_id,worker_key,status,last_heartbeat,queue_depth,details,updated_at) select t.id,'ai-knowledge','healthy',now(),(select count(*) from agency.ai_knowledge_documents d where d.tenant_id=t.id and d.status='pending'),jsonb_build_object('index_type','text','embedding_executor','not_configured'),now() from agency.tenants t on conflict(tenant_id,worker_key) do update set status=excluded.status,last_heartbeat=excluded.last_heartbeat,queue_depth=excluded.queue_depth,details=excluded.details,updated_at=excluded.updated_at" | Out-Null
    Invoke-AgencySql "with failed as (update agency.ai_knowledge_documents set status='failed',updated_at=now() where tenant_id is not null and status='pending' and content='' and agency.module_execution_allowed(tenant_id,'knowledge') returning tenant_id) insert into agency.module_run_events(tenant_id,module_key,operation,status,finished_at) select tenant_id,'knowledge','document_index','failed',now() from failed" | Out-Null
  } catch { Add-Content (Join-Path $root '.local/ai-knowledge-worker-error.log') "$(Get-Date -Format s) $($_.Exception.Message)" }
  Start-Sleep -Seconds 30
}
