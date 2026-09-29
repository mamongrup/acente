$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
node (Join-Path $root 'scripts/local-nexus-connection-harness.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Local NEXUS connection harness failed.' }
