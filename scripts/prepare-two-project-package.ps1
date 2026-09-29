param(
  [string]$NexusRoot = '',
  [string]$OutputDirectory = '.local/releases'
)

$ErrorActionPreference = 'Stop'
$agencyRoot = Split-Path $PSScriptRoot -Parent
if (!$NexusRoot) { $NexusRoot = Join-Path (Split-Path $agencyRoot -Parent) 'Nexustraveltech' }
$NexusRoot = [IO.Path]::GetFullPath($NexusRoot)
if (!(Test-Path -LiteralPath (Join-Path $NexusRoot 'gleam.toml'))) { throw "NEXUS checkout missing: $NexusRoot" }
$outputRoot = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $agencyRoot $OutputDirectory }
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stage = Join-Path $outputRoot "nexus-two-projects-$stamp"
New-Item -ItemType Directory -Path $stage | Out-Null

function Copy-Project([string]$root, [string]$name) {
  $destination = Join-Path $stage $name
  New-Item -ItemType Directory -Path $destination | Out-Null
  Push-Location $root
  try {
    $paths = @(& git -c core.quotePath=false ls-files --cached --others --exclude-standard)
    if ($LASTEXITCODE -ne 0 -or $paths.Count -eq 0) { throw "Could not inventory $name." }
    $records = @()
    foreach ($relative in $paths) {
      $relative = $relative.Trim()
      if (!$relative) { continue }
      if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|/)\.\.?(/|$)' -or $relative -match ':') {
        throw "Unsafe package path: $relative"
      }
      if ($relative -match '(^|/)(\.env|\.local|node_modules|build|\.git)(/|$)' -or
          $relative -match '(^|/)(cookie(s)?\.txt|id_rsa)(/|$)' -or
          $relative -match '\.(pem|key|pfx|p12)$') {
        throw "Secret or generated path in package inventory: $relative"
      }
      $source = Join-Path $root $relative
      if (!(Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing package file: $source" }
      $resolved = (Resolve-Path -LiteralPath $source).Path
      if (!$resolved.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Package file escapes project: $source"
      }
      $target = Join-Path $destination $relative
      New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
      Copy-Item -LiteralPath $source -Destination $target
      $records += [pscustomobject]@{path=$relative.Replace('\','/'); sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
    $commit = (& git rev-parse HEAD).Trim()
    $dirty = @(& git status --porcelain).Count
    [pscustomobject]@{project=$name; commit=$commit; working_tree_entries=$dirty; files=$records} |
      ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $destination 'release-manifest.json') -Encoding utf8
    Write-Host "${name}: $($records.Count) files, $dirty working-tree changes included."
  } finally { Pop-Location }
}

Copy-Project $NexusRoot 'Nexustraveltech'
Copy-Project $agencyRoot 'acente'
$zipPath = "$stage.zip"
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipPath -CompressionLevel Optimal
$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
"$zipHash  $(Split-Path $zipPath -Leaf)" | Set-Content -LiteralPath "$zipPath.sha256" -Encoding ascii
Write-Host "Package: $zipPath"
Write-Host "SHA-256: $zipHash"
