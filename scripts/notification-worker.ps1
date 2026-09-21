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

function SqlQuote([string]$value) {
  return "'" + ($value -replace "'", "''") + "'"
}

function Get-Config([string]$tenantId) {
  $tenant = SqlQuote $tenantId
  $query = @"
select json_build_object(
  'settings', coalesce((select json_object_agg(key, trim(both '"' from value::text)) from agency.settings where tenant_id=$tenant::uuid), '{}'::json),
  'integrations', coalesce((select json_object_agg(provider, credentials) from agency.integrations where tenant_id=$tenant::uuid and active), '{}'::json)
)::text
"@
  $raw = (Invoke-AgencySql $query -RowsOnly | Select-Object -First 1)
  if (!$raw) { return [pscustomobject]@{ settings = [pscustomobject]@{}; integrations = [pscustomobject]@{} } }
  return ($raw | ConvertFrom-Json)
}

function Property([object]$object, [string]$name, [string]$fallback = '') {
  if ($null -ne $object -and $object.PSObject.Properties.Name -contains $name) {
    $value = [string]$object.$name
    if ($value) { return $value }
  }
  return $fallback
}

function Message-Text([object]$job) {
  $payload = $job.payload | ConvertFrom-Json
  $custom = Property $payload 'message'
  if ($custom) { return $custom }
  $name = Property $payload 'name' 'misafir'
  switch ([string]$job.template) {
    'inquiry.followup' { return "Merhaba $name, seyahat talebiniz için size uygun seçenekleri hazırladık. Yardımcı olmamızı ister misiniz?" }
    'booking.confirmed' { return "Merhaba $name, rezervasyonunuz onaylandı. Detaylar için acentenizle iletişime geçebilirsiniz." }
    'abandoned_cart' { return "Merhaba $name, seçtiğiniz seyahat ürünleri hâlâ sepetinizde. İsterseniz rezervasyonunuzu tamamlamanız için size yardımcı olabiliriz." }
    default { return "Merhaba $name, talebinizle ilgili yeni bir bilgilendirme var." }
  }
}

function Send-Email([object]$job, [object]$config, [string]$message) {
  $payload = $job.payload | ConvertFrom-Json
  $to = Property $payload 'email'
  if (!$to) { throw 'E-posta alıcısı boş' }
  $smtp = $config.integrations.smtp
  $settings = $config.settings
  $host = Property $smtp 'host' (Property $settings 'smtp_host')
  $username = Property $smtp 'username' (Property $settings 'smtp_username')
  $password = Property $smtp 'password' (Property $settings 'smtp_password')
  if (!$host -or !$username) { throw 'SMTP bağlantısı yapılandırılmamış' }
  $from = Property $smtp 'from_email' $username
  $mail = [System.Net.Mail.MailMessage]::new($from, $to)
  try {
    $mail.Subject = 'Seyahat talebiniz hakkında'
    $mail.Body = $message
    $mail.IsBodyHtml = $false
    $client = [System.Net.Mail.SmtpClient]::new($host, [int](Property $smtp 'port' '587'))
    $client.EnableSsl = $true
    if ($username) { $client.Credentials = [System.Net.NetworkCredential]::new($username, $password) }
    $client.Send($mail)
  } finally {
    $mail.Dispose()
  }
}

function Send-Sms([object]$job, [object]$config, [string]$message) {
  $payload = $job.payload | ConvertFrom-Json
  $phone = Property $payload 'phone'
  if (!$phone) { throw 'SMS alıcısı boş' }
  $credentials = $config.integrations.sms_whatsapp
  $user = Property $credentials 'netgsm_user'
  $password = Property $credentials 'netgsm_pass'
  $header = Property $credentials 'netgsm_header' (Property $config.settings 'netgsm_header' 'NEXUS')
  if (!$user -or !$password) { throw 'Netgsm bağlantısı yapılandırılmamış' }
  $uri = 'https://api.netgsm.com.tr/sms/send/get/?usercode=' + [uri]::EscapeDataString($user) + '&password=' + [uri]::EscapeDataString($password) + '&gsmno=' + [uri]::EscapeDataString($phone) + '&message=' + [uri]::EscapeDataString($message) + '&msgheader=' + [uri]::EscapeDataString($header)
  $response = (Invoke-WebRequest -UseBasicParsing -Uri $uri -Method Get -TimeoutSec 20).Content.Trim()
  if (!$response.StartsWith('00') -and !$response.StartsWith('20')) { throw "Netgsm hata kodu: $response" }
}

function Send-WhatsApp([object]$job, [object]$config, [string]$message) {
  $payload = $job.payload | ConvertFrom-Json
  $phone = Property $payload 'phone'
  if (!$phone) { throw 'WhatsApp alıcısı boş' }
  $credentials = $config.integrations.sms_whatsapp
  $phoneId = Property $credentials 'whatsapp_phone_id'
  $token = Property $credentials 'whatsapp_token'
  if (!$phoneId -or !$token) { throw 'WhatsApp Cloud bağlantısı yapılandırılmamış' }
  $body = @{ messaging_product = 'whatsapp'; to = $phone; type = 'text'; text = @{ body = $message } } | ConvertTo-Json -Depth 5
  Invoke-RestMethod -Method Post -Uri "https://graph.facebook.com/v20.0/$phoneId/messages" -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $body -TimeoutSec 20 | Out-Null
}

function Deliver([object]$job) {
  $config = Get-Config ([string]$job.tenant_id)
  $message = Message-Text $job
  switch ([string]$job.channel) {
    'email' { Send-Email $job $config $message }
    'sms' { Send-Sms $job $config $message }
    'whatsapp' { Send-WhatsApp $job $config $message }
    default { throw "Desteklenmeyen bildirim kanalı: $($job.channel)" }
  }
}

function Finish([object]$job, [bool]$success, [string]$errorMessage = '') {
  $id = SqlQuote ([string]$job.id)
  $tenant = SqlQuote ([string]$job.tenant_id)
  if ($success) {
    Invoke-AgencySql "update agency.notifications set status='sent',started_at=null,sent_at=now(),last_error='',next_attempt_at=null where id=$id::uuid and tenant_id=$tenant::uuid" | Out-Null
  } else {
    $safeError = ($errorMessage -replace "'", "''").Substring(0, [math]::Min(500, $errorMessage.Length))
    $attempts = [int]$job.attempts
    $terminal = $attempts -ge 5
    $status = if ($terminal) { 'failed' } else { 'queued' }
    $delay = [math]::Min(3600, [math]::Pow(2, [math]::Max(0, $attempts - 1)) * 60)
    Invoke-AgencySql "update agency.notifications set status='$status',started_at=null,last_error='${safeError}',next_attempt_at=case when '$status'='queued' then now()+($delay * interval '1 second') else null end where id=$id::uuid and tenant_id=$tenant::uuid" | Out-Null
  }
}

while ($true) {
  try {
    # A process can terminate after claiming a row but before delivery. Requeue
    # stale claims so a restart never leaves notifications running forever.
    Invoke-AgencySql "update agency.notifications set status=case when attempts >= 5 then 'failed' else 'queued' end,started_at=null,next_attempt_at=case when attempts >= 5 then null else now() end,last_error=case when attempts >= 5 then 'Maksimum deneme sayısına ulaşıldı.' else 'Bildirim işçisi yeniden başlatıldığı için kuyruk yeniden açıldı.' end where status='running' and (started_at is null or started_at < now() - interval '10 minutes')" | Out-Null
    $claim = @"
with picked as (
  select id from agency.notifications
  where status='queued' and coalesce(next_attempt_at,scheduled_at,now()) <= now()
  order by coalesce(scheduled_at,created_at),created_at
  for update skip locked limit 10
)
update agency.notifications n
set status='running',started_at=now(),attempts=n.attempts+1
from picked
where n.id=picked.id
returning json_build_object('id',n.id::text,'tenant_id',n.tenant_id::text,'channel',n.channel,'template',n.template,'payload',n.payload::text,'attempts',n.attempts)::text
"@
    foreach ($line in (Invoke-AgencySql $claim -RowsOnly)) {
      if (!$line) { continue }
      $job = $line | ConvertFrom-Json
      try { Deliver $job; Finish $job $true }
      catch { Finish $job $false $_.Exception.Message }
    }
  } catch {
    Add-Content (Join-Path $root '.local/notification-runtime.log') "$(Get-Date -Format s) $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 10
}
