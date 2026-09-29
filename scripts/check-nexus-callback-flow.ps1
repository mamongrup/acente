$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

Get-Content (Join-Path $root ".env") | ForEach-Object {
  $line = $_.Trim()
  $index = $line.IndexOf("=")
  if ($index -gt 0) {
    $key = $line.Substring(0, $index).Trim()
    $value = $line.Substring($index + 1).Trim()
    if ($key -match "^(PG|NEXUS_API_KEY|SECRET_KEY_BASE|NEXUS_CONFIG_KEY)") {
      Set-Item "Env:$key" $value
    }
  }
}

if ([string]::IsNullOrWhiteSpace($env:NEXUS_API_KEY)) {
  throw "NEXUS_API_KEY must be configured for callback flow smoke test."
}

Push-Location $root
try {
  & gleam run -m nexus_connection_callback_test
  if ($LASTEXITCODE -ne 0) {
    throw "NEXUS callback flow test failed."
  }
} finally {
  Pop-Location
}
