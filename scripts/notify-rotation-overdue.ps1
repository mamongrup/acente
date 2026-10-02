<#
.SYNOPSIS
  Haftalik rotasyon penceresi denetimi; overdue durumunda webhook/e-posta uyarisi.

.DESCRIPTION
  agency.rotation_window_state('SECRET_KEY_BASE') durumunu okur (migration 247
  sozlesmesi; platform 187'nin acente aynalari; check-secret-hygiene.ps1 ile
  ayni kaynak):
    - open    -> bilgilendirme, cikis 0.
    - expired -> SECRET_KEY_BASE_PREVIOUS hala env'deyse uyarilir (cikis 1);
                 kaldirilmissa saglikli durumdur, cikis 0. Ayrica rotasyon
                 yasi -SecretKeyRotationMaxDays (varsayilan 180 gun; acente
                 238 sozlesmesi) ustundeyse rotasyon overdue uyarisi,
                 cikis 1. Yas kapisi pencere durumundan bagimsizdir ve
                 durum anahtarindan ONCE degerlendirilir.
    - unknown -> rotasyon kaydi yok (fail-closed); uyarilir, cikis 1.
  DB'ye ulasilamazsa uyarilamaz; konsol + log, cikis 2.

  Baglanti: .env'den PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD okunur
  (acente .env sozlesmesi; platform PGOWNER/PGOWNER_PASSWORD kullanir,
  burada uygulama rolunun salt-okur fonksiyon erisimi yeterlidir).

  Uyari kanallari opsiyoneldir ve birbirinden bagimsizdir:
    -WebhookUrl : Slack uyumlu {"text": ...} govdesiyle POST (Teams/Slack/Discord
                  benzeri webhook'lar kabul eder).
    -MailTo     : Send-MailMessage ile e-posta. Acente .env'sinde MAIL_*
                  sozlesmesi yoktur; SMTP ayarlari YALNIZCA parametreyle
                  verilir (-MailHost/-MailPort/-MailFrom/-MailUser/
                  -MailPassword). -MailTo verilip -MailHost verilmezse
                  e-posta atlanir ve log'a [WARN] yazilir.

  Cikis dosyasi: .local/rotation-check.log (her kosum kaydedilir).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/notify-rotation-overdue.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/notify-rotation-overdue.ps1 -WebhookUrl https://hooks.slack.com/services/X/Y/Z -MailTo ops@acme.test -MailHost smtp.acme.test -MailFrom alerts@acme.test
#>
param(
  [string]$WebhookUrl = '',
  [string]$MailTo = '',
  [string]$MailHost = '',
  [int]$MailPort = 0,
  [string]$MailFrom = '',
  [string]$MailUser = '',
  [string]$MailPassword = '',
  [string]$EnvPath = '.env',
  # SMTP kimlik dosyasi (register-rotation-check-task.ps1 gorev argumanina
  # parolayi DEGIL dosya yolunu gomer). Dosya MAIL_PASSWORD/MAIL_USER/
  # MAIL_HOST/MAIL_PORT/MAIL_FROM satirlarini icerir; verilmezse .env veya
  # parametreler kullanilir.
  [string]$MailCredentialsPath = '',
  [string]$SecretName = 'SECRET_KEY_BASE',
  # Son rotasyon icin kabul edilebilir en yuksek yas (gun); asimda rotasyon
  # overdue uyarisi uretilir (238 sozlesmesi; platform muadili ile ayni
  # varsayilan).
  [int]$SecretKeyRotationMaxDays = 180
)

$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$resolvedEnv = if ([IO.Path]::IsPathRooted($EnvPath)) { $EnvPath } else { Join-Path $root $EnvPath }
if (!(Test-Path -LiteralPath $resolvedEnv)) { throw "Env file not found: $resolvedEnv" }

$values = @{}
Get-Content -LiteralPath $resolvedEnv | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith('#')) { return }
  $index = $line.IndexOf('=')
  if ($index -gt 0) { $values[$line.Substring(0, $index).Trim()] = $line.Substring($index + 1).Trim() }
}

foreach ($key in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD')) {
  if (!$values.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$values[$key])) {
    throw "$key is required."
  }
}

if ($MailPort -eq 0) { $MailPort = 587 }

# SMTP kimlik dosyasi: gorev kaydi parolayi duz metin TUTMAZ; betik
# dosyayi okur. Dosya satirlari parametreleri EZER (acente .env'sinde
# MAIL_* sozlesmesi yoktur; bu dosya tek kaynaktir).
if ($MailCredentialsPath) {
  if (!(Test-Path -LiteralPath $MailCredentialsPath)) {
    throw "Mail credentials file not found: $MailCredentialsPath"
  }
  Get-Content -LiteralPath $MailCredentialsPath | ForEach-Object {
    $line = $_.Trim()
    if (!$line -or $line.StartsWith('#')) { return }
    $i = $line.IndexOf('=')
    if ($i -lt 1) { return }
    $k = $line.Substring(0, $i).Trim()
    $v = $line.Substring($i + 1).Trim()
    switch ($k) {
      'MAIL_PASSWORD' { $MailPassword = $v }
      'MAIL_USER' { $MailUser = $v }
      'MAIL_HOST' { $MailHost = $v }
      'MAIL_PORT' { $MailPort = [int]$v }
      'MAIL_FROM' { $MailFrom = $v }
    }
  }
}

$psql = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
if (!(Test-Path -LiteralPath $psql)) {
  $cmd = Get-Command psql -ErrorAction SilentlyContinue
  if (!$cmd) { throw 'psql executable not found.' }
  $psql = $cmd.Source
}

$logPath = Join-Path $root '.local/rotation-check.log'
function Write-CheckLog([string]$message) {
  $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message
  Write-Host $line
  New-Item -ItemType Directory -Path (Split-Path $logPath -Parent) -Force | Out-Null
  Add-Content -LiteralPath $logPath -Value $line
}

function Send-Alert([string]$subject, [string]$body) {
  $delivered = @()
  if ($WebhookUrl) {
    try {
      $payload = @{ text = "$subject`n$body" } | ConvertTo-Json -Compress
      Invoke-RestMethod -Method Post -Uri $WebhookUrl -ContentType 'application/json' `
        -Body $payload -TimeoutSec 15 | Out-Null
      $delivered += 'webhook'
    } catch {
      Write-CheckLog "[WARN] Webhook gonderimi basarisiz: $($_.Exception.Message)"
    }
  }
  if ($MailTo) {
    if (!$MailHost) {
      Write-CheckLog '[WARN] MailTo verildi ama MailHost tanimli degil; e-posta atlandi.'
    } else {
      try {
        $mail = @{
          SmtpServer = $MailHost
          Port       = $MailPort
          From       = $MailFrom
          To         = $MailTo
          Subject    = $subject
          Body       = $body
          UseSsl     = $true
          ErrorAction = 'Stop'
        }
        if ($MailUser -and $MailPassword) {
          $sec = ConvertTo-SecureString $MailPassword -AsPlainText -Force
          $mail.Credential = New-Object System.Management.Automation.PSCredential($MailUser, $sec)
        }
        Send-MailMessage @mail
        $delivered += 'mail'
      } catch {
        Write-CheckLog "[WARN] E-posta gonderimi basarisiz: $($_.Exception.Message)"
      }
    }
  }
  if ($delivered.Count -eq 0) { $delivered = @('console-only') }
  return ($delivered -join '+')
}

$nameEscaped = $SecretName -replace "'", "''"
$prevPresent = $values.ContainsKey('SECRET_KEY_BASE_PREVIOUS') -and -not [string]::IsNullOrWhiteSpace([string]$values['SECRET_KEY_BASE_PREVIOUS'])
$prevSql = if ($prevPresent) { 'true' } else { 'false' }
$sql = @"
SELECT agency.rotation_window_state('$nameEscaped') || '|' ||
       COALESCE(agency.latest_rotation_age_hours('$nameEscaped')::text, '-') || '|' ||
       agency.rotation_window_hours('$nameEscaped')::text || '|' ||
       d.exit_code || '|' || d.severity || '|' || d.alert_kind
FROM agency.rotation_check_decision(
       agency.rotation_window_state('$nameEscaped'),
       agency.latest_rotation_age_hours('$nameEscaped'),
       $SecretKeyRotationMaxDays,
       $prevSql) AS d;
"@

$state = $null
try {
  $env:PGPASSWORD = [string]$values['PGPASSWORD']
  $state = & $psql -X -w -v ON_ERROR_STOP=1 -h $values['PGHOST'] -p $values['PGPORT'] `
    -U $values['PGUSER'] -d $values['PGDATABASE'] -Atc $sql
} catch {
  Write-CheckLog "[ERROR] Rotasyon penceresi okunamadi: $($_.Exception.Message)"
  exit 2
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
if ($LASTEXITCODE -ne 0 -or !$state) {
  Write-CheckLog '[ERROR] Rotasyon penceresi sorgusu basarisiz.'
  exit 2
}

$parts = "$state" -split '\|'
$windowState = $parts[0]
$ageHours = $parts[1]
$windowHours = $parts[2]
$exitCode = $parts[3]
$severity = $parts[4]
$alertKind = $parts[5]
$host_ = $env:COMPUTERNAME
$ageDays = $null
if ($ageHours -ne '-') { $ageDays = [math]::Round(([double]$ageHours) / 24.0, 2) }

# Rotasyon yasi kapisi (238 sozlesmesi): son rotasyon kabul araligini astiysa
# kok-neden uyarisi uretilir; pencere durumundan bagimsizdir (switch'ten ONCE).
# Karar tablosu DB'de yasar (migration 271): yas kapisi, pencere durumu ve
# PREVIOUS varligi tek yerde degerlendirilir. Platform muadiliyle ayni
# fonksiyon; test/rotation_overdue_decisions.sql ayni kaynagi dogrular.
if ($alertKind -eq 'overdue') {
  $subject = "[AGENCY] SIR ROTASYONU GECIKTI: $SecretName yasi $ageDays gun (sinir $SecretKeyRotationMaxDays) ($host_)"
  $prevLine = ''
  if ($prevPresent) {
    $prevLine = "Ek sorun   : SECRET_KEY_BASE_PREVIOUS hala .env'de; kaldirin."
  }
  $body = @"
SECRET_KEY_BASE son rotasyon yasi kabul araligini asti (238 sozlesmesi).
Bilgisayar : $host_
Secret     : $SecretName
Durum      : rotasyon overdue
Yas        : $ageDays gun (en fazla $SecretKeyRotationMaxDays gun)
$prevLine
Eylem      : Yeni sir uretip rotasyonu kaydedin
             (scripts/record-secret-rotation.ps1 -Name $SecretName -Source planned).
             Detay: docs/secret-rotation-plan.md
Kontrol    : scripts/check-secret-hygiene.ps1
"@
  $via = Send-Alert -subject $subject -body $body
  Write-CheckLog "[ALERT] Rotasyon overdue (yas $ageDays gun > $SecretKeyRotationMaxDays). Uyari: $via"
  exit $exitCode
}

# Geri kalan kararlar alert_kind uzerinden yonlendirilir; 'ok' ve 'error'
# turleri icin betik yalnizca loglar.
if ($alertKind -eq 'window_expired_previous_present') {
      $subject = "[AGENCY] SIR ROTASYONU GECIKTI: $SecretName penceresi doldu ($host_)"
      $body = @"
SECRET_KEY_BASE rotasyon penceresi doldu.
Bilgisayar : $host_
Secret     : $SecretName
Durum      : expired
Yas        : $ageHours saat
Pencere    : $windowHours saat
Eylem      : SECRET_KEY_BASE_PREVIOUS degerini .env dosyasindan kaldirin ve
             uygulamayi yeniden baslatin. Detay: docs/secret-rotation-plan.md
Kontrol    : scripts/check-secret-hygiene.ps1
"@
      $via = Send-Alert -subject $subject -body $body
      Write-CheckLog "[ALERT] Pencere doldu (yas=${ageHours}h > ${windowHours}h). Uyari: $via"
      exit $exitCode
}

if ($alertKind -eq 'no_record') {
    $subject = "[AGENCY] SIR ROTASYONU KAYDI YOK: $SecretName denetlenemiyor ($host_)"
    $body = @"
SECRET_KEY_BASE icin rotasyon kaydi bulunamadi (fail-closed).
Bilgisayar : $host_
Secret     : $SecretName
Durum      : unknown
Eylem      : scripts/record-secret-rotation.ps1 ile mevcut sirrin baseline
             kaydini olusturun. Kayitsiz sir denetlenemez.
Kontrol    : scripts/check-secret-hygiene.ps1
"@
    $via = Send-Alert -subject $subject -body $body
    Write-CheckLog "[ALERT] Rotasyon kaydi yok (fail-closed). Uyari: $via"
    exit $exitCode
}

if ($alertKind -eq 'none') {
  if ($windowState -eq 'open') {
    Write-CheckLog "[OK] $SecretName penceresi acik (yas=${ageHours}h / pencere=${windowHours}h)."
  } else {
    Write-CheckLog "[OK] Pencere doldu (${ageHours}h > ${windowHours}h) ve SECRET_KEY_BASE_PREVIOUS kaldirilmis; yas $ageDays gun (sinir $SecretKeyRotationMaxDays). Saglikli durum, uyari yok."
  }
  exit $exitCode
}

Write-CheckLog "[ERROR] Beklenmeyen pencere durumu: $windowState (karar=$alertKind)"
exit 2
