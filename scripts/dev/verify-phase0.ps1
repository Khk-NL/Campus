# Campus Phase 0 一键验证 / one-shot Phase 0 verification
#
# 把 Phase 0 的验收标准变成可重复执行的检查：
#   1. 数据库可连（必要时自动拉起）
#   2. 8 个包构建通过
#   3. 4 个契约冒烟测试通过
#   4. 后端可启动，7 个接口行为正确（含错误码与同步幂等性）
#   5. Flutter 客户端 analyze 干净、测试通过
#
# Turns Phase 0's acceptance criteria into a repeatable check.
#
# 用法 / Usage:
#   powershell -File scripts/dev/verify-phase0.ps1
#   powershell -File scripts/dev/verify-phase0.ps1 -SkipFlutter    # 只验后端与契约
#   powershell -File scripts/dev/verify-phase0.ps1 -KeepApiRunning # 验完不关后端
#
# 注意 / note: 本脚本必须保存为**带 UTF-8 BOM** 的 UTF-8。本 harness 的 shell 是
# Windows PowerShell 5.1，无 BOM 时它会按 ANSI 解码，中文会破坏脚本结构。

[CmdletBinding()]
param(
  [switch]$SkipFlutter,
  [switch]$SkipBuild,
  [switch]$KeepApiRunning,
  [int]$Port = 3000
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Pnpm = 'D:\npm-global\pnpm.cmd'
$Flutter = 'D:\flutter\bin\flutter.bat'
$AndroidSdk = 'D:\Android\sdk'
$JavaHome = 'D:\Code\JDK'
$ApiBase = "http://127.0.0.1:$Port/api"

$script:Results = New-Object System.Collections.ArrayList

function Add-Result([string]$Name, [bool]$Ok, [string]$Detail) {
  [void]$script:Results.Add([pscustomobject]@{ Name = $Name; Ok = $Ok; Detail = $Detail })
  if ($Ok) { Write-Host ("  [PASS] " + $Name) -ForegroundColor Green }
  else { Write-Host ("  [FAIL] " + $Name + "  -> " + $Detail) -ForegroundColor Red }
}

function Write-Section([string]$Title) {
  Write-Host ''
  Write-Host ("=== " + $Title + " ===") -ForegroundColor Cyan
}

# 5.1 没有 `??`，用这个取默认值 / PS 5.1 has no `??`
function Invoke-Checked([string]$File, [string[]]$Arguments, [string]$WorkingDirectory) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $File
  $psi.Arguments = ($Arguments -join ' ')
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $proc = [System.Diagnostics.Process]::Start($psi)
  $stdout = $proc.StandardOutput.ReadToEnd()
  $stderr = $proc.StandardError.ReadToEnd()
  $proc.WaitForExit()
  return [pscustomobject]@{ ExitCode = $proc.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

function Get-HttpStatus([string]$Url, [string]$Method = 'GET') {
  try {
    $response = Invoke-WebRequest -Uri $Url -Method $Method -TimeoutSec 20 -UseBasicParsing
    return [int]$response.StatusCode
  } catch {
    $resp = $_.Exception.Response
    if ($resp -and $resp.StatusCode) { return [int]$resp.StatusCode }
    return -1
  }
}

function Get-HttpBody([string]$Url, [string]$Method = 'GET') {
  try {
    return (Invoke-WebRequest -Uri $Url -Method $Method -TimeoutSec 20 -UseBasicParsing).Content
  } catch {
    return $null
  }
}

# 数 JSON 数组的元素个数。
#
# 必须显式区分三种情况，否则结果会说谎：请求失败返回 **-1**，空响应返回 0，正常返回元素个数。
# 不能写成 `@($body | ConvertFrom-Json).Count` —— PowerShell 里 `@($null).Count` 等于 **1**，
# 于是"请求失败"会被伪装成"有 1 条记录"。
#
# Counts the elements of a JSON array. The three cases must be told apart or the result lies: a
# failed request returns **-1**, an empty payload 0, otherwise the element count. Writing
# `@($body | ConvertFrom-Json).Count` is wrong because `@($null).Count` is **1** in PowerShell,
# which disguises a failed request as "one record".
function Get-JsonArrayCount([string]$Body) {
  if (-not $Body) { return -1 }
  $parsed = $Body | ConvertFrom-Json
  if ($null -eq $parsed) { return 0 }
  return @($parsed).Count
}

# ---------------------------------------------------------------------------
Write-Section '0. 环境 / environment'
# ---------------------------------------------------------------------------

Add-Result 'pnpm 存在' (Test-Path $Pnpm) $Pnpm
if (-not $SkipFlutter) {
  Add-Result 'Flutter 存在' (Test-Path $Flutter) $Flutter
  Add-Result 'Android SDK 存在' (Test-Path $AndroidSdk) $AndroidSdk
}

# 数据库：没起就拉起来。用仓库自带的脚本，它用 WMI 游离进程启动，
# 避免被 harness 的进程树超时带走。
# Bring the database up if needed via the repo's script (detached WMI start).
$pgScript = Join-Path $RepoRoot 'scripts\toolchain\postgres.ps1'
if (Test-Path $pgScript) {
  & $pgScript ensure | Out-Null
  $pgRunning = (Test-NetConnection -ComputerName 127.0.0.1 -Port 5432 -InformationLevel Quiet -WarningAction SilentlyContinue)
  Add-Result 'PostgreSQL 在 5432 上可达' $pgRunning 'postgres 未运行，请执行 scripts\toolchain\postgres.ps1 start'
} else {
  Add-Result 'postgres.ps1 存在' $false $pgScript
}

# ---------------------------------------------------------------------------
if (-not $SkipBuild) {
  Write-Section '1. 构建全部包 / build every package'
  Push-Location $RepoRoot
  try {
    $build = Invoke-Checked $Pnpm @('turbo', 'run', 'build') $RepoRoot
    $ok = $build.ExitCode -eq 0
    $detail = if ($ok) { '8/8 通过' } else { ($build.StdErr + $build.StdOut) }
    Add-Result 'turbo run build' $ok $detail
  } finally { Pop-Location }
}

# ---------------------------------------------------------------------------
Write-Section '2. 契约冒烟测试 / contract smoke tests'
Push-Location $RepoRoot
try {
  $smoke = Invoke-Checked $Pnpm @('run', 'smoke') $RepoRoot
  $combined = $smoke.StdOut + $smoke.StdErr
  $passCount = ([regex]::Matches($combined, 'checks passed')).Count
  $ok = ($smoke.ExitCode -eq 0) -and ($passCount -eq 4)
  Add-Result '4 个契约测试脚本全部通过' $ok ("exit=" + $smoke.ExitCode + " 通过脚本数=" + $passCount)
} finally { Pop-Location }

# ---------------------------------------------------------------------------
Write-Section '3. 后端接口 / backend endpoints'

$apiDir = Join-Path $RepoRoot 'apps\api'
$apiProcess = $null
$started = $false

if (Get-HttpStatus "$ApiBase/health" | Where-Object { $_ -eq 200 }) {
  Write-Host '  后端已在运行，直接复用 / reusing the running backend' -ForegroundColor DarkGray
  $started = $false
} else {
  $mainJs = Join-Path $apiDir 'dist\src\main.js'
  if (-not (Test-Path $mainJs)) {
    Add-Result 'apps/api 已构建' $false $mainJs
  } else {
    # Start-Process 而非 & ：脚本结束时能精确 Stop-Process，不会留下游离进程。
    # Start-Process rather than `&`, so the script can stop exactly this process.
    $apiProcess = Start-Process -FilePath 'node' -ArgumentList @('dist/src/main.js') `
      -WorkingDirectory $apiDir -PassThru -WindowStyle Hidden `
      -RedirectStandardOutput (Join-Path $env:TEMP 'campus-api.out') `
      -RedirectStandardError (Join-Path $env:TEMP 'campus-api.err')
    Write-Host ("  已启动后端 PID " + $apiProcess.Id) -ForegroundColor DarkGray

    $healthy = $false
    for ($i = 0; $i -lt 40; $i++) {
      Start-Sleep -Milliseconds 500
      if ((Get-HttpStatus "$ApiBase/health") -eq 200) { $healthy = $true; break }
    }
    $started = $healthy
    Add-Result '后端启动并 /api/health 返回 200' $healthy '健康检查超时，见 %TEMP%\campus-api.err'
  }
}

if ($started -or ((Get-HttpStatus "$ApiBase/health") -eq 200)) {
  $health = Get-HttpBody "$ApiBase/health"
  $dbUp = $health -and ($health -match '"database":"up"')
  Add-Result '健康检查报告数据库可达' ([bool]$dbUp) $health

  $services = Get-HttpBody "$ApiBase/services?universityId=ecnu"
  $count = Get-JsonArrayCount $services
  Add-Result '服务目录返回 7 条' ($count -eq 7) ("实际 " + $count + " 条（-1 表示请求失败）")

  # §11 标签搜索：搜「羽毛球」应命中「体育场馆预约」
  $search = Get-HttpBody ("$ApiBase/services?universityId=ecnu&q=" + [uri]::EscapeDataString('羽毛球'))
  $searchOk = $search -and ($search -match '体育场馆预约')
  Add-Result '§11 标签搜索命中场馆' ([bool]$searchOk) '搜「羽毛球」未命中「体育场馆预约」'

  # 校验与错误码
  Add-Result '缺少 universityId 返回 400' ((Get-HttpStatus "$ApiBase/services") -eq 400) '期望 400'
  Add-Result '非法 category 返回 400' ((Get-HttpStatus "$ApiBase/services?universityId=ecnu&category=nope") -eq 400) '期望 400'
  Add-Result '未注册高校返回 404' ((Get-HttpStatus "$ApiBase/universities/pku/capabilities") -eq 404) '期望 404'
  Add-Result '不存在的服务返回 404' ((Get-HttpStatus "$ApiBase/services/does-not-exist") -eq 404) '期望 404'

  # 能力对比：适配器上报 vs 数据库声明
  $caps = Get-HttpBody "$ApiBase/universities/ecnu/capabilities"
  $capsOk = $caps -and ($caps -match '"adapterCapabilities":\["services"\]') -and ($caps -match '"declaredCapabilities":\["services"\]')
  Add-Result '适配器能力与数据库声明一致' ([bool]$capsOk) $caps

  # 同步幂等性：连做两次，第二次必须 0 新增，且总数不变
  $sync1 = Get-HttpBody "$ApiBase/universities/ecnu/services/sync" 'POST'
  $sync2 = Get-HttpBody "$ApiBase/universities/ecnu/services/sync" 'POST'
  $idempotent = $sync1 -and $sync2 -and ($sync2 -match '"created":0')
  Add-Result '服务同步幂等（第二次 0 新增）' ([bool]$idempotent) ("1st=" + $sync1 + " 2nd=" + $sync2)

  $after = Get-HttpBody "$ApiBase/services?universityId=ecnu"
  $afterCount = Get-JsonArrayCount $after
  Add-Result '同步后条目数仍为 7（无重复）' ($afterCount -eq 7) ("实际 " + $afterCount + "（-1 表示请求失败）")

  # 括号是必需的：不加的话 PowerShell 会把 'http://127.0.0.1:' 当成唯一实参，
  # 后面的 + $Port + '/api/docs' 变成多余的位置参数，URL 实际是残缺的。
  # The parentheses are required: without them PowerShell treats 'http://127.0.0.1:' as the sole
  # argument and the concatenation becomes stray positional arguments.
  $docsUrl = 'http://127.0.0.1:' + $Port + '/api/docs'
  Add-Result 'OpenAPI 文档可访问' ((Get-HttpStatus $docsUrl) -eq 200) ('期望 200，URL=' + $docsUrl)
}

if ($apiProcess -and -not $KeepApiRunning) {
  Stop-Process -Id $apiProcess.Id -Force -ErrorAction SilentlyContinue
  Write-Host '  已关闭后端 / backend stopped' -ForegroundColor DarkGray
} elseif ($apiProcess -and $KeepApiRunning) {
  Write-Host ("  后端保留运行中 PID " + $apiProcess.Id + " / left running") -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
if (-not $SkipFlutter) {
  Write-Section '4. Flutter 客户端 / the Flutter client'
  $mobileDir = Join-Path $RepoRoot 'apps\mobile'
  $env:JAVA_HOME = $JavaHome
  $env:ANDROID_HOME = $AndroidSdk
  $env:ANDROID_SDK_ROOT = $AndroidSdk

  if (-not (Test-Path $mobileDir)) {
    Add-Result 'apps/mobile 存在' $false $mobileDir
  } else {
    $analyze = Invoke-Checked $Flutter @('analyze') $mobileDir
    $analyzeOutput = $analyze.StdOut + $analyze.StdErr
    $analyzeClean = $analyzeOutput -match 'No issues found'
    $analyzeTail = (($analyzeOutput -split "`n" | Select-Object -Last 2) -join ' ').Trim()
    Add-Result 'flutter analyze 零问题' $analyzeClean $analyzeTail

    $test = Invoke-Checked $Flutter @('test') $mobileDir
    $testOutput = $test.StdOut + $test.StdErr
    $allPassed = $testOutput -match 'All tests passed'
    $testTail = (($testOutput -split "`n" | Select-Object -Last 2) -join ' ').Trim()
    Add-Result 'flutter test 全部通过' $allPassed $testTail

    # 架构硬要求（§3.1）：高校专有字样只允许出现在约定的位置。
    # architecture_test.dart 已经在 flutter test 里跑过，这里只做提示。
    Write-Host '  提示：§3.1 的高校隔离由 test/architecture_test.dart 断言 / §3.1 isolation is asserted by architecture_test.dart' -ForegroundColor DarkGray
  }
}

# ---------------------------------------------------------------------------
Write-Section '汇总 / summary'
$passed = @($script:Results | Where-Object { $_.Ok }).Count
$total = @($script:Results).Count
foreach ($r in $script:Results) {
  $mark = if ($r.Ok) { 'PASS' } else { 'FAIL' }
  $color = if ($r.Ok) { 'Green' } else { 'Red' }
  Write-Host ("  " + $mark.PadRight(5) + $r.Name) -ForegroundColor $color
}
Write-Host ''
if ($passed -eq $total) {
  Write-Host ("全部通过 / all passed: " + $passed + "/" + $total) -ForegroundColor Green
  exit 0
} else {
  Write-Host ("有失败项 / failures: " + ($total - $passed) + " of " + $total) -ForegroundColor Red
  exit 1
}
