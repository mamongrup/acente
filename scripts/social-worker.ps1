$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim(); $index = $line.IndexOf('=')
  if ($index -gt 0) { Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim() }
}
$psql = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
function Invoke-AgencySql([string]$sql, [switch]$RowsOnly) {
  $arguments = @('-X','-w','-v','ON_ERROR_STOP=1','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE)
  if ($RowsOnly) { $arguments += @('-At','-q') }
  $arguments += @('-c',$sql)
  $result = & $psql @arguments
  if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed with exit code $LASTEXITCODE" }
  return @($result)
}
function SqlQuote([string]$value) { return "'" + ($value -replace "'", "''") + "'" }
function Property([object]$object, [string]$name, [string]$fallback = '') {
  if ($null -ne $object -and $object.PSObject.Properties.Name -contains $name) {
    $value = [string]$object.$name
    if ($value) { return $value }
  }
  return $fallback
}
function Get-Config([string]$tenantId) {
  $tenant = SqlQuote $tenantId
  $raw = Invoke-AgencySql "select coalesce((select credentials::text from agency.integrations where tenant_id=$tenant::uuid and provider='social' and kind='social' and active limit 1),'{}')" -RowsOnly | Select-Object -First 1
  if (!$raw) { return [pscustomobject]@{} }
  return ($raw | ConvertFrom-Json)
}
function Publish-Facebook([object]$job, [object]$cfg) {
  $page = Property $cfg 'page_id'; $token = Property $cfg 'access_token'
  if (!$page -or !$token) { throw 'Facebook sayfa ID veya erişim belirteci yapılandırılmamış' }
  $body = @{ message = [string]$job.content; access_token = $token } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "https://graph.facebook.com/v20.0/$page/feed" -ContentType 'application/json' -Body $body -TimeoutSec 20 | Out-Null
}
function Publish-Threads([object]$job, [object]$cfg) {
  $user = Property $cfg 'threads_user_id'; $token = Property $cfg 'access_token'; if (!$token) { $token = Property $cfg 'pinterest_token' }
  if (!$user -or !$token) { throw 'Threads kullanıcı ID veya erişim belirteci yapılandırılmamış' }
  $create = @{ media_type = 'TEXT'; text = [string]$job.content; access_token = $token } | ConvertTo-Json
  $draft = Invoke-RestMethod -Method Post -Uri "https://graph.threads.net/v1.0/$user/threads" -ContentType 'application/json' -Body $create -TimeoutSec 20
  if (!$draft.id) { throw 'Threads taslağı oluşturulamadı' }
  $publish = @{ creation_id = $draft.id; access_token = $token } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "https://graph.threads.net/v1.0/$user/threads_publish" -ContentType 'application/json' -Body $publish -TimeoutSec 20 | Out-Null
}
function Publish-Instagram([object]$job, [object]$cfg) {
  $user = Property $cfg 'instagram_id'; $token = Property $cfg 'access_token'; $media = Property $job.metadata 'media_url'
  if (!$user -or !$token) { throw 'Instagram hesap ID veya erişim belirteci yapılandırılmamış' }
  if (!$media) { throw 'Instagram gönderisi için herkese açık medya URLsi gerekli' }
  $container = Invoke-RestMethod -Method Post -Uri "https://graph.facebook.com/v20.0/$user/media" -Body @{ image_url = $media; caption = [string]$job.content; access_token = $token } -TimeoutSec 20
  if (!$container.id) { throw 'Instagram medya kapsayıcısı oluşturulamadı' }
  Invoke-RestMethod -Method Post -Uri "https://graph.facebook.com/v20.0/$user/media_publish" -Body @{ creation_id = $container.id; access_token = $token } -TimeoutSec 20 | Out-Null
}
function Publish-Pinterest([object]$job, [object]$cfg) {
  $board = Property $cfg 'pinterest_board_id'; $token = Property $cfg 'pinterest_token'; $media = Property $job.metadata 'media_url'
  if (!$board -or !$token) { throw 'Pinterest pano ID veya erişim belirteci yapılandırılmamış' }
  if (!$media) { throw 'Pinterest gönderisi için herkese açık medya URLsi gerekli' }
  $body = @{ board_id = $board; title = ([string]$job.content).Substring(0,[math]::Min(100,([string]$job.content).Length)); description = [string]$job.content; media_source = @{ source_type = 'image_url'; url = $media } } | ConvertTo-Json -Depth 6
  Invoke-RestMethod -Method Post -Uri 'https://api.pinterest.com/v5/pins' -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $body -TimeoutSec 20 | Out-Null
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
function Finish([object]$job, [bool]$success, [string]$errorMessage = '') {
  $id = SqlQuote ([string]$job.id); $tenant = SqlQuote ([string]$job.tenant_id)
  if ($success) {
    Invoke-AgencySql "update agency.social_posts set status='published',started_at=null,published_at=now(),next_attempt_at=null,error='' where id=$id::uuid and tenant_id=$tenant::uuid" | Out-Null
  } else {
    $safe = ($errorMessage -replace "'", "''"); $safe = $safe.Substring(0, [math]::Min(500,$safe.Length)); $attempt = [int]$job.attempts
    $status = if ($attempt -ge 5) { 'failed' } else { 'queued' }
    $delay = [math]::Min(3600, [math]::Pow(2,[math]::Max(0,$attempt-1))*60)
    Invoke-AgencySql "update agency.social_posts set status='$status',started_at=null,error='$safe',next_attempt_at=case when '$status'='queued' then now()+($delay * interval '1 second') else null end where id=$id::uuid and tenant_id=$tenant::uuid" | Out-Null
  }
}
while ($true) {
  try {
    # Requeue claims left by a crashed social worker.
    Invoke-AgencySql "update agency.social_posts set status=case when attempts >= 5 then 'failed' else 'queued' end,started_at=null,next_attempt_at=case when attempts >= 5 then null else now() end,error=case when attempts >= 5 then 'Maksimum deneme sayısına ulaşıldı.' else 'Sosyal medya işçisi yeniden başlatıldığı için kuyruk yeniden açıldı.' end where status='running' and (started_at is null or started_at < now() - interval '10 minutes')" | Out-Null
    $claim = @"
with picked as (
  select id from agency.social_posts
  where status='queued' and coalesce(next_attempt_at,scheduled_at,now()) <= now()
  order by coalesce(scheduled_at,now()),id
  for update skip locked limit 10
)
update agency.social_posts p set status='running',started_at=now(),attempts=p.attempts+1 from picked
where p.id=picked.id
returning json_build_object('id',p.id::text,'tenant_id',p.tenant_id::text,'network',p.network,'content',p.content,'metadata',p.metadata::text,'attempts',p.attempts)::text
"@
    foreach ($line in (Invoke-AgencySql $claim -RowsOnly)) {
      if (!$line) { continue }
      $job = $line | ConvertFrom-Json
      $job.metadata = $job.metadata | ConvertFrom-Json
      try { Publish $job; Finish $job $true } catch { Finish $job $false $_.Exception.Message }
    }
  } catch { Add-Content (Join-Path $root '.local/social-runtime.log') "$(Get-Date -Format s) $($_.Exception.Message)" }
  Start-Sleep -Seconds 15
}

