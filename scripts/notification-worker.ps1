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

function SqlQuote([string]$value) {
  return "'" + ($value -replace "'", "''") + "'"
}

function Test-Uuid([string]$value) {
  if (!$value) { return $false }
  return $value -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
}

function Assert-Uuid([string]$value, [string]$name) {
  if (!(Test-Uuid $value)) { throw "Geçersiz UUID: $name" }
}

function Get-Config([string]$tenantId) {
  Assert-Uuid $tenantId 'tenant_id'
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

function XmlEscape([string]$value) {
  if ($null -eq $value) { return '' }
  return [System.Security.SecurityElement]::Escape($value)
}

function CDataSafe([string]$value) {
  if ($null -eq $value) { return '' }
  return ($value -replace '\]\]>', ']]]]><![CDATA[>')
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
  $password = SecretProperty ([string]$job.tenant_id) $smtp 'password' 'password_sealed' 'integration.password'
  if (!$password) { $password = SecretProperty ([string]$job.tenant_id) $settings 'smtp_password' 'smtp_password_sealed' 'settings.smtp_password' }
  if (!$host -or !$username) { throw 'SMTP bağlantısı yapılandırılmamış' }
  $from = Property $smtp 'from_email' $username
  $mail = [System.Net.Mail.MailMessage]::new($from, $to)
  try {
    $mail.Subject = switch ([string]$job.template) {
      'service.overdue' { 'Bekleyen rezervasyon hizmeti' }
      'review.overdue' { 'Geciken inceleme görevi' }
      default { 'Seyahat talebiniz hakkında' }
    }
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
  $password = SecretProperty ([string]$job.tenant_id) $credentials 'netgsm_pass' 'netgsm_pass_sealed' 'integration.netgsm_pass'
  $header = Property $credentials 'netgsm_header' (Property $config.settings 'netgsm_header' 'NEXUS')
  if (!$user -or !$password) { throw 'Netgsm bağlantısı yapılandırılmamış' }
  $xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<mainbody>
  <header>
    <company dil="TR">Netgsm</company>
    <usercode>$(XmlEscape $user)</usercode>
    <password>$(XmlEscape $password)</password>
    <type>1:n</type>
    <msgheader>$(XmlEscape $header)</msgheader>
  </header>
  <body>
    <msg><![CDATA[$(CDataSafe $message)]]></msg>
    <no>$(XmlEscape $phone)</no>
  </body>
</mainbody>
"@
  $response = (Invoke-WebRequest -UseBasicParsing -Uri 'https://api.netgsm.com.tr/sms/send/xml' -Method Post -ContentType 'application/xml; charset=utf-8' -Body $xml -TimeoutSec 20).Content.Trim()
  $success = $response.StartsWith('00') -or $response.StartsWith('20') -or $response.Contains('<code>0</code>')
  if (!$success) { throw "Netgsm hata kodu: $response" }
}

function Send-WhatsApp([object]$job, [object]$config, [string]$message) {
  $payload = $job.payload | ConvertFrom-Json
  $phone = Property $payload 'phone'
  if (!$phone) { throw 'WhatsApp alıcısı boş' }
  $credentials = $config.integrations.sms_whatsapp
  $phoneId = Property $credentials 'whatsapp_phone_id'
  $token = SecretProperty ([string]$job.tenant_id) $credentials 'whatsapp_token' 'whatsapp_token_sealed' 'integration.whatsapp_token'
  if (!$phoneId -or !$token) { throw 'WhatsApp Cloud bağlantısı yapılandırılmamış' }
  if ([string]$job.template -eq 'travel.recommendation') {
    $templateName = Property $credentials 'whatsapp_recommendation_template'
    $templateLanguage = Property $credentials 'whatsapp_recommendation_language' 'tr'
    if (!$templateName -or $templateName -notmatch '^[a-z0-9_]{1,512}$') { throw 'Onaylı WhatsApp öneri şablonu yapılandırılmamış' }
    $body = @{ messaging_product = 'whatsapp'; to = $phone; type = 'template'; template = @{ name = $templateName; language = @{ code = $templateLanguage } } } | ConvertTo-Json -Depth 6
  } else {
    $body = @{ messaging_product = 'whatsapp'; to = $phone; type = 'text'; text = @{ body = $message } } | ConvertTo-Json -Depth 5
  }
  $reply = Invoke-RestMethod -Method Post -Uri "https://graph.facebook.com/v20.0/$phoneId/messages" -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $body -TimeoutSec 20
  return [string]$reply.messages[0].id
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

function Finish([object]$job, [bool]$success, [string]$errorMessage = '', [string]$providerMessageId = '') {
  $rawId = [string]$job.id
  $rawTenant = [string]$job.tenant_id
  Assert-Uuid $rawId 'notification.id'
  Assert-Uuid $rawTenant 'notification.tenant_id'
  $id = SqlQuote $rawId
  $tenant = SqlQuote $rawTenant
  if ($success) {
    $provider = if ($providerMessageId) { SqlQuote $providerMessageId } else { 'NULL' }
    Invoke-AgencySql "update agency.notifications set status='sent',started_at=null,sent_at=now(),last_error='',next_attempt_at=null,provider_message_id=$provider where id=$id::uuid and tenant_id=$tenant::uuid" | Out-Null
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
  select n.id from agency.notifications n
  where n.status='queued' and coalesce(n.next_attempt_at,n.scheduled_at,now()) <= now()
    and agency.module_execution_allowed(n.tenant_id,'notifications')
    and (n.template<>'ai.campaign' or exists (
      select 1 from agency.ai_campaign_notifications link
      join agency.ai_campaign_runs run on run.id=link.run_id and run.tenant_id=link.tenant_id and run.status='running'
      join agency.users u on u.id=link.user_id and u.tenant_id=link.tenant_id and u.active
      join agency.customer_notification_preferences pref on pref.user_id=u.id and pref.tenant_id=u.tenant_id and pref.marketing_email
      where link.notification_id=n.id and link.tenant_id=n.tenant_id and n.user_id=link.user_id
    ))
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
      Assert-Uuid ([string]$job.id) 'notification.id'
      Assert-Uuid ([string]$job.tenant_id) 'notification.tenant_id'
      if ([string]$job.template -eq 'ai.campaign') {
        $id = SqlQuote ([string]$job.id)
        $tenant = SqlQuote ([string]$job.tenant_id)
        $allowed = Invoke-AgencySql "select agency.ai_campaign_delivery_allowed($tenant::uuid,$id::uuid)" -RowsOnly | Select-Object -First 1
        if ($allowed -ne 't') {
          Invoke-AgencySql "update agency.notifications set status='cancelled',started_at=null,next_attempt_at=null,last_error='Pazarlama izni veya kampanya durumu değişti.' where id=$id::uuid and tenant_id=$tenant::uuid and status='running'" | Out-Null
          continue
        }
      }
      try { $providerMessageId = Deliver $job; Finish $job $true '' ([string]$providerMessageId) }
      catch { Finish $job $false $_.Exception.Message }
    }
  } catch {
    Add-Content (Join-Path $root '.local/notification-runtime.log') "$(Get-Date -Format s) $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 10
}
