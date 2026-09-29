$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
if (!(Test-Path -LiteralPath $envFile)) { throw '.env bulunamadı.' }
Get-Content -LiteralPath $envFile | ForEach-Object {
  if ($_ -match '^\s*([^#=]+)\s*=\s*(.*)\s*$') {
    [Environment]::SetEnvironmentVariable($matches[1].Trim(),$matches[2].Trim())
  }
}
$pg = (Get-Command psql -ErrorAction Stop).Source
$common = @('-X','-w','-v','ON_ERROR_STOP=1','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE)

function Invoke-PanelSql([string]$sql) {
  $result = & $pg @common -Atc $sql 2>&1
  if ($LASTEXITCODE -ne 0) { throw ($result | Out-String) }
  return $result
}

while ($true) {
  try {
    # The database function claims reservations with row locks and skips rows
    # that another worker is already processing.
    $sql = @'
with enabled as (
  select p.tenant_id,u.id as actor_id
  from agency.supplier_settlement_policies p
  join lateral (
    select id from agency.users
    where tenant_id=p.tenant_id and membership_type='admin' and active
    order by created_at,id limit 1
  ) u on true
  where p.enabled
), due as (
  select e.tenant_id,e.actor_id from enabled e
  where exists(select 1 from agency.reservations r
    where r.tenant_id=e.tenant_id and r.status='completed'
      and r.payment_status='paid' and r.check_out<=current_date
      and not exists(select 1 from agency.supplier_settlements s where s.reservation_id=r.id))
  order by e.tenant_id limit 100
)
select tenant_id::text || '|' || actor_id::text from due
'@
    foreach ($line in (Invoke-PanelSql $sql)) {
      if ($line -notmatch '^([0-9a-f-]{36})\|([0-9a-f-]{36})$') { continue }
      $tenantId = $matches[1]; $actorId = $matches[2]
      Invoke-PanelSql "select agency.generate_scheduled_supplier_settlements('$tenantId'::uuid,'$actorId'::uuid)" | Out-Null
    }
    $reviewSql = @'
select u.tenant_id::text || '|' || u.id::text
from agency.users u
where u.membership_type='admin' and u.active
  and u.id=(select id from agency.users a where a.tenant_id=u.tenant_id
    and a.membership_type='admin' and a.active order by a.created_at,a.id limit 1)
  and exists(select 1 from agency.review_assignments r
    where r.tenant_id=u.tenant_id and r.status='open' and r.due_at<now()
      and (r.last_overdue_notified_at is null or r.last_overdue_notified_at<now()-interval '24 hours'))
order by u.tenant_id limit 100
'@
    foreach ($line in (Invoke-PanelSql $reviewSql)) {
      if ($line -notmatch '^([0-9a-f-]{36})\|([0-9a-f-]{36})$') { continue }
      $tenantId = $matches[1]; $actorId = $matches[2]
      Invoke-PanelSql "select agency.queue_overdue_review_notifications('$tenantId'::uuid,'$actorId'::uuid)" | Out-Null
    }
    $serviceSql = @'
select u.tenant_id::text || '|' || u.id::text
from agency.users u
where u.membership_type='admin' and u.active
  and u.id=(select id from agency.users a where a.tenant_id=u.tenant_id
    and a.membership_type='admin' and a.active order by a.created_at,a.id limit 1)
  and exists(select 1 from agency.reservation_service_tasks t
    join agency.reservations r on r.id=t.reservation_id and r.tenant_id=t.tenant_id
    join agency.listings l on l.id=t.listing_id and l.tenant_id=t.tenant_id
    join agency.users supplier on supplier.id=l.owner_user_id and supplier.tenant_id=t.tenant_id
    where t.tenant_id=u.tenant_id and t.status='open' and t.owner_role='supplier'
      and r.status in ('confirmed','completed') and supplier.active
      and nullif(trim(supplier.email),'') is not null
      and (case when t.stage='after' then coalesce(r.check_out,r.check_in) else r.check_in end)<current_date
      and (t.last_overdue_notified_at is null or t.last_overdue_notified_at<now()-interval '24 hours'))
order by u.tenant_id limit 100
'@
    foreach ($line in (Invoke-PanelSql $serviceSql)) {
      if ($line -notmatch '^([0-9a-f-]{36})\|([0-9a-f-]{36})$') { continue }
      $tenantId = $matches[1]; $actorId = $matches[2]
      Invoke-PanelSql "select agency.queue_overdue_service_notifications('$tenantId'::uuid,'$actorId'::uuid)" | Out-Null
    }
    $expirySql = @'
select u.tenant_id::text || '|' || u.id::text
from agency.users u
where u.membership_type='admin' and u.active
  and u.id=(select id from agency.users a where a.tenant_id=u.tenant_id
    and a.membership_type='admin' and a.active order by a.created_at,a.id limit 1)
  and exists(select 1 from agency.applications a
    where a.tenant_id=u.tenant_id and a.type='supplier' and a.status='approved')
order by u.tenant_id
'@
    foreach ($line in (Invoke-PanelSql $expirySql)) {
      if ($line -notmatch '^([0-9a-f-]{36})\|([0-9a-f-]{36})$') { continue }
      $tenantId = $matches[1]; $actorId = $matches[2]
      Invoke-PanelSql "select agency.suspend_expired_supplier_applications('$tenantId'::uuid,'$actorId'::uuid)" | Out-Null
    }
  } catch {
    Add-Content (Join-Path $root '.local/panel-operations-runtime.log') "$(Get-Date -Format s) $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 3600
}
