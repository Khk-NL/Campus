# Campus 工具链安装器 / Campus toolchain installer
#
# 读取 .tools/download-manifest.json（由 fetch-tools.mjs 生成），把各压缩包解压到
# 常规安装位置。幂等：目标目录已存在则跳过。
#
# Reads .tools/download-manifest.json (written by fetch-tools.mjs) and unpacks each
# archive to a conventional location. Idempotent: existing targets are skipped.
#
# 用法 / Usage:
#   pwsh -File scripts/toolchain/install-tools.ps1
#   pwsh -File scripts/toolchain/install-tools.ps1 -Only flutter

[CmdletBinding()]
param(
  [string]$PgRoot = 'D:\pgsql',
  [string]$FlutterRoot = 'D:\flutter',
  [string]$AndroidRoot = 'D:\Android\sdk',
  [string]$GhRoot = 'D:\gh',
  [string[]]$Only = @(),
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$manifestPath = Join-Path $repoRoot '.tools\download-manifest.json'

if (-not (Test-Path $manifestPath)) {
  throw "manifest not found: $manifestPath (run fetch-tools.mjs first)"
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

function Write-Step([string]$msg) { Write-Host "[install] $msg" -ForegroundColor Cyan }
function Write-Skip([string]$msg) { Write-Host "[install] $msg" -ForegroundColor DarkGray }

# tar (bsdtar) 随 Windows 10+ 提供，处理 zip 远快于 Expand-Archive。
# tar (bsdtar) ships with Windows 10+ and unpacks zip far faster than Expand-Archive.
function Expand-ArchiveFast([string]$archive, [string]$destination) {
  New-Item -ItemType Directory -Force -Path $destination | Out-Null
  & tar.exe -xf $archive -C $destination
  if ($LASTEXITCODE -ne 0) { throw "tar failed ($LASTEXITCODE) for $archive" }
}

function Get-Artifact([string]$name) {
  $a = $manifest.artifacts | Where-Object { $_.name -eq $name }
  if (-not $a) { throw "artifact '$name' missing from manifest" }
  if ($a.error) { throw "artifact '$name' failed to download: $($a.error)" }
  if (-not (Test-Path $a.file)) { throw "artifact '$name' file missing: $($a.file)" }
  return $a
}

function Test-Selected([string]$name) {
  return ($Only.Count -eq 0) -or ($Only -contains $name)
}

# ---------- PostgreSQL ----------
function Install-Postgres {
  $a = Get-Artifact 'postgresql'
  if ((Test-Path (Join-Path $PgRoot 'bin\postgres.exe')) -and -not $Force) {
    Write-Skip "postgresql: already installed at $PgRoot"
    return
  }
  Write-Step "postgresql: extracting to $PgRoot"
  $staging = Join-Path $env:TEMP ('pg-stage-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  Expand-ArchiveFast $a.file $staging
  $inner = Join-Path $staging 'pgsql'
  if (-not (Test-Path $inner)) { throw "unexpected postgresql archive layout: $staging" }
  if (Test-Path $PgRoot) { Remove-Item -Recurse -Force $PgRoot }
  Move-Item $inner $PgRoot
  Remove-Item -Recurse -Force $staging -ErrorAction SilentlyContinue
  Write-Step "postgresql: installed -> $PgRoot"
}

# ---------- Flutter ----------
function Install-Flutter {
  $a = Get-Artifact 'flutter'
  if ((Test-Path (Join-Path $FlutterRoot 'bin\flutter.bat')) -and -not $Force) {
    Write-Skip "flutter: already installed at $FlutterRoot"
    return
  }
  Write-Step "flutter: extracting $([math]::Round((Get-Item $a.file).Length / 1GB, 2)) GB to $FlutterRoot"
  # flutter zip 内含顶层 flutter/ 目录；先解到目标父目录再改名，避免多复制 1.8GB。
  # The flutter zip has a top-level flutter/ dir; unpack next to the target and
  # rename, which avoids copying 1.8 GB around.
  $parent = Split-Path $FlutterRoot -Parent
  $leaf = Split-Path $FlutterRoot -Leaf
  $staging = Join-Path $parent (".$leaf-staging-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
  Expand-ArchiveFast $a.file $staging
  $inner = Join-Path $staging $leaf
  if (-not (Test-Path $inner)) {
    # 压缩包内目录名可能不叫 flutter / the archive's inner dir may not be named flutter
    $candidates = Get-ChildItem $staging -Directory
    if ($candidates.Count -ne 1) { throw "unexpected flutter archive layout: $staging" }
    $inner = $candidates[0].FullName
  }
  if (Test-Path $FlutterRoot) { Remove-Item -Recurse -Force $FlutterRoot }
  Move-Item $inner $FlutterRoot
  Remove-Item -Recurse -Force $staging -ErrorAction SilentlyContinue
  Write-Step "flutter: installed -> $FlutterRoot"
}

# ---------- Android cmdline-tools ----------
function Install-AndroidCmdlineTools {
  $a = Get-Artifact 'android-cmdline-tools'
  $target = Join-Path $AndroidRoot 'cmdline-tools\latest'
  if ((Test-Path (Join-Path $target 'bin\sdkmanager.bat')) -and -not $Force) {
    Write-Skip "android-cmdline-tools: already installed at $target"
    return
  }
  Write-Step "android-cmdline-tools: extracting to $target"
  $staging = Join-Path $env:TEMP ('android-stage-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  Expand-ArchiveFast $a.file $staging
  $inner = Join-Path $staging 'cmdline-tools'
  if (-not (Test-Path $inner)) { throw "unexpected cmdline-tools archive layout: $staging" }
  # sdkmanager 要求目录名必须为 latest / sdkmanager requires the dir to be named latest
  $renamed = Join-Path $staging 'latest-renamed'
  Move-Item $inner $renamed
  New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
  if (Test-Path $target) { Remove-Item -Recurse -Force $target }
  Move-Item $renamed $target
  Remove-Item -Recurse -Force $staging -ErrorAction SilentlyContinue
  Write-Step "android-cmdline-tools: installed -> $target"
}

# ---------- GitHub CLI ----------
function Install-Gh {
  $a = Get-Artifact 'gh'
  if ((Test-Path (Join-Path $GhRoot 'bin\gh.exe')) -and -not $Force) {
    Write-Skip "gh: already installed at $GhRoot"
    return
  }
  Write-Step "gh: extracting to $GhRoot"
  $staging = Join-Path $env:TEMP ('gh-stage-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  Expand-ArchiveFast $a.file $staging
  if (Test-Path $GhRoot) { Remove-Item -Recurse -Force $GhRoot }
  Move-Item $staging $GhRoot
  Write-Step "gh: installed -> $GhRoot"
}

if (Test-Selected 'postgresql') { Install-Postgres }
if (Test-Selected 'flutter') { Install-Flutter }
if (Test-Selected 'android-cmdline-tools') { Install-AndroidCmdlineTools }
if (Test-Selected 'gh') { Install-Gh }

Write-Host ''
Write-Step 'installed locations / 安装位置:'
foreach ($p in @($PgRoot, $FlutterRoot, $AndroidRoot, $GhRoot)) {
  $ok = Test-Path $p
  Write-Host ("  {0,-22} {1}" -f $(if ($ok) { '[ok]' } else { '[--]' }), $p)
}
