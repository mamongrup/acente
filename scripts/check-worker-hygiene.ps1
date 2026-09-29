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

Write-Host "Worker hygiene check passed." -ForegroundColor Green
