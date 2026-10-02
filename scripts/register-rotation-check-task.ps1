<#
.SYNOPSIS
  Haftalik sifre rotasyonu denetimini Windows Gorev Zamanlayici'ya kaydeder.

.DESCRIPTION
  notify-rotation-overdue.ps1'i haftalik olarak calistiran bir gorev olusturur
  veya ayni isimle var olan gorevi guncelidir (idempotent). Platform
  (Nexustraveltech) register-rotation-check-task.ps1'in acente aynasidir:
  acente notify betigi .env'den PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD
  okur; gorev argumanlari EnvPath disindaki kanallari (webhook/e-posta)
  gomulur. Gorev gecerli kullanici altinda calisir; makine kapali kaldiginda
  kacan calisma (StartWhenAvailable) sonraki acilista telafi edilir.

  Uyari kanallari gorevin argumanlarina gomulur; degistirmek icin bu betigi
  yeniden calistirin. Acente .env'sinde MAIL_* sozlesmesi yoktur; SMTP
  ayarlari parametreyle verilir.

  GUVENLIK: SMTP PAROLASI gorev argumanina GOMULMEZ. Task Scheduler action
  argumanlarini duz metin saklar ve herkes tarafindan okunabilir
  (Get-ScheduledTask, schtasks /query); gomulen parola pratikte acik
  bir sir olur. -MailPassword verilirse betik parolayi yalnizca BU
  calismada okunacak gecici bir dosyaya yazar ve dosya yolunu gorev
  argumanina gomur. Gorel satis yapilmadigi icin arguman sirsizdir.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/register-rotation-check-task.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/register-rotation-check-task.ps1 -MailTo ops@acme.test -MailHost smtp.acme.test -MailFrom alerts@acme.test
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/register-rotation-check-task.ps1 -WebhookUrl https://hooks.slack.com/services/X/Y/Z -At 09:30 -DayOfWeek Friday
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
  # Haftalik calisma saati (ss:dd).
  [string]$At = '08:00',
  [ValidateSet('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')]
  [string]$DayOfWeek = 'Monday',
  [string]$TaskName = 'Agency Rotation Window Check'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $PSScriptRoot 'notify-rotation-overdue.ps1'
if (!(Test-Path -LiteralPath $scriptPath)) { throw 'notify-rotation-overdue.ps1 not found.' }
$resolvedEnv = if ([IO.Path]::IsPathRooted($EnvPath)) { $EnvPath } else { Join-Path $root $EnvPath }
if (!(Test-Path -LiteralPath $resolvedEnv)) { throw "Env file not found: $resolvedEnv" }

$argument = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -EnvPath `"$resolvedEnv`""
if ($WebhookUrl) { $argument += " -WebhookUrl `"$WebhookUrl`"" }
if ($MailTo) { $argument += " -MailTo `"$MailTo`"" }
if ($MailHost) { $argument += " -MailHost `"$MailHost`"" }
if ($MailPort) { $argument += " -MailPort $MailPort" }
if ($MailFrom) { $argument += " -MailFrom `"$MailFrom`"" }
if ($MailUser) { $argument += " -MailUser `"$MailUser`"" }

# SMTP parolasi gorev argumanina ASLA gomulmez (Task Scheduler argumanlari
# duz metin saklar). Onun yerine yalnizca bu calisma icin gecici bir
# kimlik dosyasi yazilir ve dosya YOLU argumana konur. Dosya goreli
# kullanici icindir ve icerigi yalnizca yerel sahipleri okuyabilir.
if ($MailPassword) {
  $secretDir = Join-Path $env:LOCALAPPDATA 'NEXUS\secrets'
  New-Item -ItemType Directory -Path $secretDir -Force | Out-Null
  $secretFile = Join-Path $secretDir 'rotation-mail-credentials.env'
  # Onceki bir dosyadan artik kalan degeri temizle.
  Remove-Item -LiteralPath $secretFile -Force -ErrorAction SilentlyContinue
  Set-Content -LiteralPath $secretFile -Encoding UTF8 -Value @(
    "MAIL_PASSWORD=$MailPassword",
    "MAIL_USER=$MailUser",
    "MAIL_HOST=$MailHost",
    "MAIL_PORT=$MailPort",
    "MAIL_FROM=$MailFrom"
  )
  # Yalnizca iceren kullanici okuyabilsin.
  & icacls.exe $secretFile /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null
  $argument += " -MailCredentialsPath `"$secretFile`""
} elseif ($MailUser) {
  throw 'MailUser verildi ama MailPassword yok; parola gorev argumanina gomulemez.'
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argument -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
  -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
  Set-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings | Out-Null
  Write-Host "Gorev guncellendi: $TaskName ($DayOfWeek $At)"
} else {
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
    -Description 'AGENCY: haftalik SECRET_KEY_BASE rotasyon penceresi denetimi (notify-rotation-overdue.ps1).' | Out-Null
  Write-Host "Gorev kaydedildi: $TaskName ($DayOfWeek $At)"
}

$task = Get-ScheduledTask -TaskName $TaskName
$info = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "Durum: $($task.State); Sonraki calisma: $($info.NextRunTime)"
Write-Host "Not: gorev gecerli kullanici ($env:USERNAME) oturumunda calisir; sunucuda oturum acik kalmali ya da gorev yogunlastirmasi (S4U/SYSTEM) tercih edilebilir."
