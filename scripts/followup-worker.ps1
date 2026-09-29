$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
Get-Content (Join-Path $root '.env') | ForEach-Object { $line=$_.Trim();$i=$line.IndexOf('=');if($i -gt 0){Set-Item "Env:$($line.Substring(0,$i).Trim())" $line.Substring($i+1).Trim()} }
$psql=(Get-Command psql -ErrorAction Stop).Source
function Sql([string]$q){$a=@('-X','-w','-v','ON_ERROR_STOP=1','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE,'-c',$q);$o=& $psql @a;if($LASTEXITCODE -ne 0){throw "PostgreSQL command failed: $LASTEXITCODE"};$o}
while($true){
 try {
  Sql "with requests as (select 'public_inquiry' as source,id::text as request_id,tenant_id,full_name as name,email,phone,created_at from agency.public_inquiries where status in ('new','contacted') union all select 'contact_request' as source,id::text as request_id,tenant_id,name,email,phone,created_at from agency.contact_requests where status in ('new','in_progress')), steps as (select * from (values (1,interval '5 hours'),(2,interval '10 hours'),(3,interval '2 days'),(4,interval '5 days')) v(step,delay)) insert into agency.notifications(tenant_id,channel,template,payload,scheduled_at) select r.tenant_id,case when r.email <> '' then 'email' else 'sms' end,'inquiry.followup',jsonb_build_object('source',r.source,'request_id',r.source||':'||r.request_id,'name',r.name,'email',r.email,'phone',r.phone,'step',s.step),r.created_at+s.delay from requests r cross join steps s where r.created_at+s.delay <= now() and r.created_at+s.delay > now() - interval '30 days' and not exists (select 1 from agency.notifications n where n.template='inquiry.followup' and n.payload->>'request_id'=(r.source||':'||r.request_id) and (n.payload->>'step')=s.step::text)" | Out-Null
 } catch { Add-Content (Join-Path $root '.local/followup-error.log') "$(Get-Date -Format s) $($_.Exception.Message)" }
 Start-Sleep -Seconds 60
}
