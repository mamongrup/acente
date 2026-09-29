$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim(); $index = $line.IndexOf('=')
  if ($index -gt 0) { Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim() }
}
$psql = (Get-Command psql -ErrorAction Stop).Source
function Invoke-AgencySql([string]$sql, [switch]$RowsOnly) {
  $arguments = @('-X','-w','-v','ON_ERROR_STOP=1','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE)
  if ($RowsOnly) { $arguments += @('-At','-q') }
  $arguments += @('-c',$sql)
  $result = & $psql @arguments
  if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed with exit code $LASTEXITCODE" }
  return @($result)
}
function SqlQuote([string]$value) { return "'" + ($value -replace "'", "''") + "'" }
function Test-Uuid([string]$value) {
  if (!$value) { return $false }
  return $value -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
}
function Assert-Uuid([string]$value, [string]$name) {
  if (!(Test-Uuid $value)) { throw "Geçersiz UUID: $name" }
}
function Property([object]$object, [string]$name, [string]$fallback = '') {
  if ($null -ne $object -and $object.PSObject.Properties.Name -contains $name) {
    $value = [string]$object.$name
    if ($value) { return $value }
  }
  return $fallback
}
function Get-ConfigSecretKey {
  $key = [string]$env:NEXUS_CONFIG_KEY
  if (!$key -or $key.Trim().Length -lt 64) { $key = [string]$env:SECRET_KEY_BASE }
  if (!$key -or $key.Trim().Length -lt 64) { return $null }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($key.Trim())) }
  finally { $sha.Dispose() }
}
function Open-SealedSecret([string]$tenantId, [string]$field, [string]$sealed) {
  if (!$sealed -or !$sealed.StartsWith('v1:')) { return '' }
  $key = Get-ConfigSecretKey
  if ($null -eq $key) { return '' }
  try {
    $raw = [Convert]::FromBase64String($sealed.Substring(3))
    if ($raw.Length -lt 29) { return '' }
    $nonce = New-Object byte[] 12
    $tag = New-Object byte[] 16
    $cipher = New-Object byte[] ($raw.Length - 28)
    [Array]::Copy($raw, 0, $nonce, 0, 12)
    [Array]::Copy($raw, 12, $tag, 0, 16)
    [Array]::Copy($raw, 28, $cipher, 0, $cipher.Length)
    $plain = New-Object byte[] $cipher.Length
    $aad = [System.Text.Encoding]::UTF8.GetBytes("${tenantId}:agency.integrations:${field}")
    $aes = [System.Security.Cryptography.AesGcm]::new($key)
    try { $aes.Decrypt($nonce, $cipher, $tag, $plain, $aad) }
    finally { $aes.Dispose() }
    return [System.Text.Encoding]::UTF8.GetString($plain)
  } catch {
    return ''
  }
}
function SecretProperty([string]$tenantId, [object]$object, [string]$plainName, [string]$sealedName, [string]$field, [string]$fallback = '') {
  $sealed = Property $object $sealedName
  if ($sealed) {
    $opened = Open-SealedSecret $tenantId $field $sealed
    if ($opened) { return $opened }
  }
  return (Property $object $plainName $fallback)
}
function Get-Config([string]$tenantId) {
  Assert-Uuid $tenantId 'tenant_id'
  $tenant = SqlQuote $tenantId
  $raw = Invoke-AgencySql "select coalesce((select credentials::text from agency.integrations where tenant_id=$tenant::uuid and provider='social' and kind='social' and active limit 1),'{}')" -RowsOnly | Select-Object -First 1
  if (!$raw) { return [pscustomobject]@{} }
  return ($raw | ConvertFrom-Json)
}
function Publish-Facebook([object]$job, [object]$cfg) {
  $page = Property $cfg 'page_id'; $token = SecretProperty ([string]$job.tenant_id) $cfg 'access_token' 'access_token_sealed' 'integration.access_token'
  if (!$page -or !$token) { throw 'Facebook sayfa ID veya erişim belirteci yapılandırılmamış' }
  $body = @{ message = [string]$job.content; access_token = $token } | ConvertTo-Json
  $result = Invoke-RestMethod -Method Post -Uri "https://graph.facebook.com/v20.0/$page/feed" -ContentType 'application/json' -Body $body -TimeoutSec 20
  if (!$result.id) { throw 'Facebook gönderi kimliği dönmedi' }
  return [string]$result.id
}
function Publish-Threads([object]$job, [object]$cfg) {
  $user = Property $cfg 'threads_user_id'; $token = SecretProperty ([string]$job.tenant_id) $cfg 'access_token' 'access_token_sealed' 'integration.access_token'; if (!$token) { $token = SecretProperty ([string]$job.tenant_id) $cfg 'pinterest_token' 'pinterest_token_sealed' 'integration.pinterest_token' }
  if (!$user -or !$token) { throw 'Threads kullanıcı ID veya erişim belirteci yapılandırılmamış' }
  $create = @{ media_type = 'TEXT'; text = [string]$job.content; access_token = $token } | ConvertTo-Json
  $draft = Invoke-RestMethod -Method Post -Uri "https://graph.threads.net/v1.0/$user/threads" -ContentType 'application/json' -Body $create -TimeoutSec 20
  if (!$draft.id) { throw 'Threads taslağı oluşturulamadı' }
  $publish = @{ creation_id = $draft.id; access_token = $token } | ConvertTo-Json
  $result = Invoke-RestMethod -Method Post -Uri "https://graph.threads.net/v1.0/$user/threads_publish" -ContentType 'application/json' -Body $publish -TimeoutSec 20
  if (!$result.id) { throw 'Threads gönderi kimliği dönmedi' }
  return [string]$result.id
}
function Publish-Instagram([object]$job, [object]$cfg) {
  $user = Property $cfg 'instagram_id'; $token = SecretProperty ([string]$job.tenant_id) $cfg 'access_token' 'access_token_sealed' 'integration.access_token'; $media = Property $job.metadata 'media_url'
  if (!$user -or !$token) { throw 'Instagram hesap ID veya erişim belirteci yapılandırılmamış' }
  if (!$media) { throw 'Instagram gönderisi için herkese açık medya URLsi gerekli' }
  $container = Invoke-RestMethod -Method Post -Uri "https://graph.facebook.com/v20.0/$user/media" -Body @{ image_url = $media; caption = [string]$job.content; access_token = $token } -TimeoutSec 20
  if (!$container.id) { throw 'Instagram medya kapsayıcısı oluşturulamadı' }
  $result = Invoke-RestMethod -Method Post -Uri "https://graph.facebook.com/v20.0/$user/media_publish" -Body @{ creation_id = $container.id; access_token = $token } -TimeoutSec 20
  if (!$result.id) { throw 'Instagram gönderi kimliği dönmedi' }
  return [string]$result.id
}
function Publish-Pinterest([object]$job, [object]$cfg) {
  $board = Property $cfg 'pinterest_board_id'; $token = SecretProperty ([string]$job.tenant_id) $cfg 'pinterest_token' 'pinterest_token_sealed' 'integration.pinterest_token'; $media = Property $job.metadata 'media_url'
  if (!$board -or !$token) { throw 'Pinterest pano ID veya erişim belirteci yapılandırılmamış' }
  if (!$media) { throw 'Pinterest gönderisi için herkese açık medya URLsi gerekli' }
  $body = @{ board_id = $board; title = ([string]$job.content).Substring(0,[math]::Min(100,([string]$job.content).Length)); description = [string]$job.content; media_source = @{ source_type = 'image_url'; url = $media } } | ConvertTo-Json -Depth 6
  $result = Invoke-RestMethod -Method Post -Uri 'https://api.pinterest.com/v5/pins' -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $body -TimeoutSec 20
  if (!$result.id) { throw 'Pinterest gönderi kimliği dönmedi' }
  return [string]$result.id
}
function Publish([object]$job) {
  $cfg = Get-Config ([string]$job.tenant_id)
  switch ([string]$job.network) {
    'facebook' { Publish-Facebook $job $cfg }
    'threads' { Publish-Threads $job $cfg }
    'instagram' { Publish-Instagram $job $cfg }
    'pinterest' { Publish-Pinterest $job $cfg }
    default { throw "Desteklenmeyen sosyal ağ: $($job.network)" }
  }
}
function Finish([object]$job, [bool]$success, [string]$externalPostId = '') {
  $rawId = [string]$job.id
  $rawTenant = [string]$job.tenant_id
  Assert-Uuid $rawId 'social_posts.id'
  Assert-Uuid $rawTenant 'social_posts.tenant_id'
  $id = SqlQuote $rawId; $tenant = SqlQuote $rawTenant
  if ($success) {
    if ([string]::IsNullOrWhiteSpace($externalPostId)) { throw 'Sağlayıcı gönderi kimliği eksik' }
    $external = SqlQuote $externalPostId
    Invoke-AgencySql "with done as (update agency.social_posts set status='published',external_post_id=$external,started_at=null,published_at=now(),next_attempt_at=null,error='',failure_code=null where id=$id::uuid and tenant_id=$tenant::uuid and status='running' returning tenant_id,id,external_post_id) insert into agency.social_post_events(tenant_id,social_post_id,event_type,payload) select tenant_id,id,'published',jsonb_build_object('external_post_id',external_post_id) from done" | Out-Null
  } else {
    # Provider exception bodies can contain tokens or private request data.
    # A timeout after submission may mean the provider published successfully.
    # Require review before retrying to avoid creating a duplicate public post.
    $safe = 'Gönderim sonucu doğrulanamadı; yeniden denemeden önce sosyal ağı kontrol edin.'; $attempt = [int]$job.attempts
    $eventPayload = (@{ failure_code = 'delivery_unknown'; attempts = $attempt } | ConvertTo-Json -Compress).Replace("'", "''")
    Invoke-AgencySql "with done as (update agency.social_posts set status='failed',started_at=null,error='$safe',failure_code='delivery_unknown',next_attempt_at=null where id=$id::uuid and tenant_id=$tenant::uuid and status='running' returning tenant_id,id) insert into agency.social_post_events(tenant_id,social_post_id,event_type,payload) select tenant_id,id,'delivery_failed','$eventPayload'::jsonb from done" | Out-Null
  }
}
while ($true) {
  try {
    # A crashed worker may have sent the post before its acknowledgement was stored.
    Invoke-AgencySql "with stale as (update agency.social_posts set status='failed',started_at=null,next_attempt_at=null,failure_code='delivery_unknown',error='Gönderim sonucu doğrulanamadı; sosyal ağı kontrol edin.' where status='running' and (started_at is null or started_at < now() - interval '10 minutes') returning tenant_id,id) insert into agency.social_post_events(tenant_id,social_post_id,event_type,payload) select tenant_id,id,'delivery_failed',jsonb_build_object('failure_code','delivery_unknown') from stale" | Out-Null
    $claim = @"
with picked as (
  select p.id from agency.social_posts p
  where p.status='queued' and coalesce(p.next_attempt_at,p.scheduled_at,now()) <= now()
    and (coalesce(p.metadata->>'approval_required', 'false') <> 'true' or p.approved_at is not null)
    and p.moderation_status <> 'rejected'
    and not exists (
      select 1 from agency.social_automation_policies approval_policy
      where approval_policy.tenant_id=p.tenant_id and approval_policy.active=true
        and approval_policy.approval_required=true and p.approved_at is null
        and (approval_policy.network='*' or approval_policy.network=p.network)
        and (approval_policy.language_code='*' or approval_policy.language_code=p.language_code)
        and (approval_policy.market_code='*' or approval_policy.market_code=p.market_code)
    )
    and not exists (
      select 1 from agency.social_automation_policies ap
      where ap.tenant_id=p.tenant_id and ap.active=true
        and (ap.network='*' or ap.network=p.network)
        and (ap.language_code='*' or ap.language_code=p.language_code)
        and (ap.market_code='*' or ap.market_code=p.market_code)
        and (not ((ap.window_start <= ap.window_end and localtime between ap.window_start and ap.window_end)
             or (ap.window_start > ap.window_end and (localtime >= ap.window_start or localtime <= ap.window_end)))
        or (select count(*) from agency.social_posts d
             where d.tenant_id=p.tenant_id
               and (ap.network='*' or d.network=ap.network)
               and (ap.language_code='*' or d.language_code=ap.language_code)
               and (ap.market_code='*' or d.market_code=ap.market_code)
               and coalesce(d.published_at,d.started_at,d.scheduled_at) >= date_trunc('day', now())
               and d.status in ('running','published')) >= ap.daily_limit)
    )
  order by coalesce(p.scheduled_at,now()),p.id
  for update of p skip locked limit 1
)
update agency.social_posts p set status='running',started_at=now(),attempts=p.attempts+1 from picked
where p.id=picked.id
returning json_build_object('id',p.id::text,'tenant_id',p.tenant_id::text,'network',p.network,'language_code',p.language_code,'content',p.content,'metadata',p.metadata::text,'attempts',p.attempts)::text
"@
    foreach ($line in (Invoke-AgencySql $claim -RowsOnly)) {
      if (!$line) { continue }
      $job = $line | ConvertFrom-Json
      Assert-Uuid ([string]$job.id) 'social_posts.id'
      Assert-Uuid ([string]$job.tenant_id) 'social_posts.tenant_id'
      $job.metadata = $job.metadata | ConvertFrom-Json
      try { $externalPostId = Publish $job; Finish $job $true $externalPostId } catch { Finish $job $false }
    }
  } catch { Add-Content (Join-Path $root '.local/social-runtime.log') "$(Get-Date -Format s) $($_.Exception.Message)" }
  Start-Sleep -Seconds 15
}

