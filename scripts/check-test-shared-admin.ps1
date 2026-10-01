param()

# Static check: the shared integration admin account must not gain new
# usages in the Gleam test suite. auth.login against the shared
# integration-admin@nexus.local account races with parallel tests (login
# counters, session rows) and is a proven flakiness source. New tests must
# use unique users instead:
#   unique_username(...) / create_unique_admin(...) / with_unique_session(...)
# See docs/testing-parallel-safe-helpers.md.
#
# Existing, deliberately kept usages are allowlisted below with a baseline
# count (Max). Any unlisted hit, or a pattern matched more times than its
# baseline, fails this check. Extend the allowlist only for deliberate,
# reviewed usage (e.g. bodies running under the global env lock).

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$testDir = Join-Path $root "test"

if (!(Test-Path -LiteralPath $testDir)) {
  throw "Test directory not found: $testDir"
}

$literal = "integration-admin@nexus.local"

# Case-insensitive matching MUST be culture-invariant. Under the default
# culture-specific IgnoreCase (this repo is developed on a tr-TR Windows),
# 'i' does not case-fold to 'I' and patterns like 'insert into' would fail
# against 'INSERT INTO' — or worse, behave differently on CI vs locally.
function Test-InvariantMatch([string]$Text, [string]$Pattern) {
  $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
  return [System.Text.RegularExpressions.Regex]::IsMatch($Text, $Pattern, $options)
}

# Pattern is applied (case-insensitive) to the whitespace-trimmed line.
# Max = allowed number of matching lines in the whole suite; $null = unlimited.
$allowlist = @(
  @{ Pattern = 'insert\s+into\s+agency\.users\b'; Max = 1; Reason = "fixture seed INSERT (real_db)" },
  @{ Pattern = '^const\s+pref_email\s*=\s*"integration-admin@nexus\.local"$'; Max = 1; Reason = "shared const definition (router_test)" },
  @{ Pattern = '^"integration-admin@nexus\.local",$'; Max = 3; Reason = "inline login argument in serial tests (router_test)" },
  @{ Pattern = '^auth\.login\(db, pref_email, "admin123456", session_token\)$'; Max = 3; Reason = "rotation window bodies under the global env lock (router_test)" }
)

$counts = @{}
$violations = @()
$hits = 0

$files = Get-ChildItem -LiteralPath $testDir -Recurse -Filter "*.gleam" | Sort-Object FullName
foreach ($file in $files) {
  $relative = "test/" + $file.FullName.Substring($testDir.Length + 1).Replace("\", "/")
  $lines = @(Get-Content -LiteralPath $file.FullName)
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $isHit = $line.IndexOf($literal, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    if (-not $isHit) { $isHit = Test-InvariantMatch $line "\bpref_email\b" }
    if (-not $isHit) { continue }

    $trimmed = $line.Trim()
    # Comments are documentation, not code.
    if ($trimmed -match "^//") { continue }  # no letters, culture-safe

    $hits++

    $matched = $false
    for ($p = 0; $p -lt $allowlist.Count; $p++) {
      if (Test-InvariantMatch $trimmed $allowlist[$p].Pattern) {
        $matched = $true
        $key = "pattern$p"
        $count = 1
        if ($counts.ContainsKey($key)) { $count = $counts[$key] + 1 }
        $counts[$key] = $count
        if ($null -ne $allowlist[$p].Max -and $count -gt $allowlist[$p].Max) {
          $violations += ("{0}:{1}: allowlist baseline exceeded (max {2}, {3}): {4}" -f $relative, ($i + 1), $allowlist[$p].Max, $allowlist[$p].Reason, $trimmed)
        }
        break
      }
    }
    if (-not $matched) {
      $violations += ("{0}:{1}: unlisted shared-admin usage: {2}" -f $relative, ($i + 1), $trimmed)
    }
  }
}

if ($violations.Count -gt 0) {
  Write-Host ("FAIL: {0} shared-admin violation(s) in the test suite:" -f $violations.Count) -ForegroundColor Red
  foreach ($v in $violations) {
    Write-Host ("  " + $v)
  }
  Write-Host ""
  Write-Host "New tests must use unique users, not the shared integration admin:"
  Write-Host "  unique_username(...) / create_unique_admin(...) / with_unique_session(...)"
  Write-Host "See docs/testing-parallel-safe-helpers.md. To register a deliberate new"
  Write-Host "usage, update the allowlist in scripts/check-test-shared-admin.ps1."
  exit 1
}

Write-Host ("Shared test admin check passed ({0} allowlisted usages, no new ones)." -f $hits) -ForegroundColor Green
exit 0
