param()

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

$workers = @(
  "scripts\currency-worker.ps1",
  "scripts\ai-supervisor-worker.ps1",
  "scripts\ai-operation-worker.ps1",
  "scripts\commerce-feed-worker.ps1",
  "scripts\ai-knowledge-worker.ps1",
  "scripts\ai-campaign-worker.ps1",
  "scripts\ai-quality-worker.ps1",
  "scripts\notification-worker.ps1",
  "scripts\social-worker.ps1"
)

foreach ($relative in $workers) {
  $path = Join-Path $root $relative
  if (!(Test-Path -LiteralPath $path)) {
    throw "Worker script not found: $path"
  }

  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path -LiteralPath $path),
    [ref]$tokens,
    [ref]$errors
  ) | Out-Null

  if ($errors.Count -gt 0) {
    throw "PowerShell parse failed: $relative"
  }

  $content = Get-Content -LiteralPath $path -Raw
  # Operation is observation/approval only; campaign serialization happens in
  # ai_campaign_enqueue_email under a database row lock. Neither claims a queue.
  if ($relative -notin @("scripts\ai-operation-worker.ps1", "scripts\ai-campaign-worker.ps1") -and $content -notmatch "skip locked") {
    throw "Worker claim must use SKIP LOCKED: $relative"
  }
  if ($content -notmatch "tenant_id") {
    throw "Worker must keep tenant scope: $relative"
  }
}

$operation = Get-Content -LiteralPath (Join-Path $root "scripts\ai-operation-worker.ps1") -Raw
if ($operation -notmatch "no operation executor here" -or $operation -match "set status='running'") {
  throw "AI operation worker must not claim work without an executor."
}
$campaign = Get-Content -LiteralPath (Join-Path $root "scripts\ai-campaign-worker.ps1") -Raw
$campaignMigration = Get-Content -LiteralPath (Join-Path $root "db\migrations\223_ai_campaign_email_queue.sql") -Raw
if ($campaign -notmatch "ai_campaign_enqueue_email" -or $campaignMigration -notmatch "FOR UPDATE") {
  throw "Campaign enqueue must serialize the run in the database."
}

foreach ($relative in @("scripts\notification-worker.ps1", "scripts\social-worker.ps1")) {
  $content = Get-Content -LiteralPath (Join-Path $root $relative) -Raw
  if ($content -notmatch "function Assert-Uuid") {
    throw "Worker UUID guard missing: $relative"
  }
}

# ---------------------------------------------------------------------------
# Scheduled Task tabanli bakim isleri
# ---------------------------------------------------------------------------
# Kuyruk worker'lari surekli calisir ve izlenebilir; Scheduled Task tabanli
# bakim isleri (haftalik rotasyon denetimi gibi) ise SADECE kayitliysa
# calisir. Gorev kaydi unutuldugu veya bozuldugu zaman denetim sessizce
# calismaz ve rotasyon penceresi denetlenmez. Ayrica gorev argumanlari
# Windows Task Scheduler'da duz metin saklandigi icin sifre gommek sizinti
# riski yaratir. Asagidaki bolum bu iki riski kapatir.
#
# Envanter KENDI KENDINI tamamlar: scripts/ altindaki her register-*.ps1
# dosyasi bir bakim isi kabul edilir. Yeni bir kayit betigi eklenince burada
# degisiklik yapmak gerekmez; yalnizca ENVARTER listesine elle eklenirse
# denetim onu kapsar.
$maintenanceJobs = @(
  @{
    Relative = "scripts\register-rotation-check-task.ps1"
    # Kayit betigi hangi isi calistiriyor (gorev action'inin cagiracagi betik).
    Target = "scripts\notify-rotation-overdue.ps1"
  }
)

# Yeni register betikleri eklendiginde ENVARTER listesinde olmadiklari
# yakalansin: sessizce denetimsiz kalan bir bakim isi en kotu durumdur.
$registered = Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -Filter 'register-*.ps1' |
  ForEach-Object { "scripts\$($_.Name)" }
foreach ($found in $registered) {
  if ($maintenanceJobs.Relative -notcontains $found) {
    throw ("Scheduled Task bakim isi envanterde degil: $found " +
      "(scripts/check-worker-hygiene.ps1 icindeki `$maintenanceJobs listesine ekleyin)")
  }
}

foreach ($job in $maintenanceJobs) {
  $registerPath = Join-Path $root $job.Relative
  if (!(Test-Path -LiteralPath $registerPath)) {
    throw "Maintenance job registration not found: $($job.Relative)"
  }
  $targetPath = Join-Path $root $job.Target
  if (!(Test-Path -LiteralPath $targetPath)) {
    throw "Maintenance job target not found: $($job.Target) (kaydeden $($job.Relative))"
  }

  foreach ($path in @($registerPath, $targetPath)) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
      (Resolve-Path -LiteralPath $path), [ref]$tokens, [ref]$errors
    ) | Out-Null
    if ($errors.Count -gt 0) {
      throw "Maintenance job parse failed: $path"
    }
  }

  # Yalnizca KOD GOVDESI denetlenir: yorum satirlari bir ayari 'gecmis'
  # yapabilir. Ilk mutasyon denemesi bunu gosterdi: StartWhenAvailable
  # gercekten kaldirildiginde denetim yorum satirindaki gecmise bagli
  # kalip nedeniyle yesil kaldi. Blok yorumlari da temizlenir.
  $register = Get-Content -LiteralPath $registerPath -Raw
  $register = [regex]::Replace($register, '(?s)<#.*?#>', '')
  $register = ($register -split "`r?`n" |
    Where-Object { $_ -notmatch '^\s*#' }) -join "`n"

  # 1) Idempotent kayit: ayni isimli gorev sorgulanMALI ve varsa Set ile
  #    guncellenmeli. Yalniz 'Get-ScheduledTask' kelimesinin varligi yeterli
  #    DEGILDIR - mutasyon denemesi bunu gosterdi: Get-ScheduledTask yalnizca
  #    kullanilmayan bir ifade icinde birakildiginda denetim yesil kaldi.
  #    Bu yuzden hem sorgu hem de guncelleme yolu zorunlu kilinir.
  #    Arama bir ATAMAYA baglanir (`$existing = Get-ScheduledTask -TaskName`):
  #    dosyanin baska bir yerinde (ornegin raporlama satirinda) ayni cagrinin
  #    gecmesi denetimi sahte olarak saglamaz.
  if ($register -notmatch "Register-ScheduledTask") {
    throw "Maintenance job must register the task: $($job.Relative)"
  }
  if ($register -notmatch '\$existing\s*=\s*Get-ScheduledTask\s+-TaskName') {
    throw ("Maintenance job must look up the existing task by name: $($job.Relative) " +
      '(expected: $existing = Get-ScheduledTask -TaskName $TaskName)')
  }
  if ($register -notmatch "Set-ScheduledTask") {
    throw "Maintenance job must update an existing task instead of duplicating it: $($job.Relative) (Set-ScheduledTask)"
  }

  # 2) Telafi (StartWhenAvailable): makine kapali kaldiginda kacan haftalik
  #    calisma yapilmayacak sekilde birakilirsa pencere denetimi bir hafta
  #    sessizce kaybolur.
  if ($register -notmatch "StartWhenAvailable") {
    throw "Maintenance job must catch up a missed run: $($job.Relative) (StartWhenAvailable)"
  }

  # 3) Tek kopyalilik (MultipleInstances IgnoreNew): ust uste binen
  #    calismalar DB'ye es zamanli yazar.
  if ($register -notmatch "MultipleInstances\s+IgnoreNew") {
    throw "Maintenance job must reject overlapping runs: $($job.Relative) (MultipleInstances IgnoreNew)"
  }

  # 4) Calisma suresi tavani: kilitlenen bir gorev zamanlayici zincirini
  #    durdurur.
  if ($register -notmatch "ExecutionTimeLimit") {
    throw "Maintenance job must bound its runtime: $($job.Relative) (ExecutionTimeLimit)"
  }

  # 5) Sifre gomulmesi: Task Scheduler action argumanlari duz metin saklar ve
  #    `Get-ScheduledTask`/`schtasks /query` ile DOGRULANabilir. SMTP parolasi
  #    argumana gomulurse kimse okuyabilir. Kanallar .env okumasi veya
  #    dosya tabanli arguman ile verilmelidir.
  $secretArgs = @('MailPassword', 'MAIL_PASSWORD', 'PGPASSWORD', 'SECRET_KEY_BASE', 'NEXUS_CONFIG_KEY')
  foreach ($secret in $secretArgs) {
    # `$argument += " -MailPassword ..."` bicimi: gomulmus sifre.
    if ($register -match ('(?m)^\s*if\s*\(\$[A-Za-z]+\)\s*\{\s*\$argument\s*\+?=\s*"[^"]*-' + [regex]::Escape($secret))) {
      throw ("Maintenance job must not embed a secret in task arguments: $($job.Relative) " +
        "(-$secret). Task Scheduler action argumanlari duz metin saklar; " +
        "kanali .env okumasi veya dosya tabanli arguman ile verin.")
    }
  }

  # 6) Gorev, kaydedilen hedef betigi CALISTIRMALI (yoksa gorev bos olur).
  if ($register -notmatch [regex]::Escape((Split-Path $job.Target -Leaf))) {
    throw "Maintenance job must invoke its target script: $($job.Relative) -> $($job.Target)"
  }
}

Write-Host "Worker hygiene check passed ($($workers.Count) queue workers, $($maintenanceJobs.Count) scheduled maintenance jobs)." -ForegroundColor Green