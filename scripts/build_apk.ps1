$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$mobileDir = Join-Path $repoRoot 'apps\mobile'
$releaseDir = Join-Path $repoRoot 'release'
$pubspec = Join-Path $mobileDir 'pubspec.yaml'
$flutter = 'D:\flutter\bin\flutter.bat'

function Get-ApkSha256([string]$path) {
    $stream = [System.IO.File]::OpenRead($path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-', '')
        } finally {
            $sha256.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

if (-not (Test-Path -LiteralPath $flutter)) {
    throw "Flutter was not found at $flutter"
}

$versionLine = Get-Content -LiteralPath $pubspec |
    Where-Object { $_ -match '^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$' } |
    Select-Object -First 1
if (-not $versionLine) {
    throw 'Expected a version such as 1.0.0+2 in apps/mobile/pubspec.yaml'
}
$version = [regex]::Match($versionLine, '^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$').Groups[1].Value

if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = 'D:\Android\sdk' }
if (-not $env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME }

Write-Host "Building Campus $version..."
Push-Location -LiteralPath $mobileDir
try {
    & $flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw "Flutter build failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

$source = Join-Path $mobileDir 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path -LiteralPath $source)) { throw "APK not found: $source" }

New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
$target = Join-Path $releaseDir "Campus-$version-preview.apk"
$sourceHash = Get-ApkSha256 $source
if (Test-Path -LiteralPath $target) {
    $existingHash = Get-ApkSha256 $target
    if ($existingHash -ne $sourceHash) {
        throw "An APK for $version already exists with different contents. Increase the version before packaging."
    }
} else {
    Copy-Item -LiteralPath $source -Destination $target
}

Write-Host "APK: $target"
Write-Host "SHA-256: $sourceHash"
