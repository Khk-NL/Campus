# Campus 本地 PostgreSQL 控制脚本 / local PostgreSQL control script
#
# 为什么需要这个脚本，而不是直接 `pg_ctl start`：
#
# 1. 本 harness 会等待**整个进程树**结束。`pg_ctl start` 拉起的 postgres 会继承 stdout
#    句柄，导致命令永不返回，最终被超时杀掉 —— 并且把 postgres 一起带走。
# 2. 因此必须用 WMI 的 Win32_Process.Create 创建**游离进程**，使其不属于当前 shell。
#
# Why this script exists instead of a plain `pg_ctl start`:
# 1. The harness waits for the entire process tree. A postgres started by `pg_ctl start`
#    inherits the stdout handle, so the command never returns, gets killed on timeout, and
#    takes postgres down with it.
# 2. So the postmaster must be created as a detached process via WMI's
#    Win32_Process.Create, outside the current shell's tree.
#
# 用法 / Usage:
#   pwsh -File scripts/toolchain/postgres.ps1 status
#   pwsh -File scripts/toolchain/postgres.ps1 start
#   pwsh -File scripts/toolchain/postgres.ps1 stop
#   pwsh -File scripts/toolchain/postgres.ps1 ensure    # 未运行则启动 / start if not running

[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('status', 'start', 'stop', 'restart', 'ensure')]
  [string]$Action = 'ensure',

  [string]$PgRoot = 'D:\pgsql',
  [string]$DataDir = 'D:\pgsql\data'
)

$ErrorActionPreference = 'Stop'
$pgCtl = Join-Path $PgRoot 'bin\pg_ctl.exe'
$logFile = Join-Path $PgRoot 'pg.log'

if (-not (Test-Path $pgCtl)) { throw "pg_ctl not found at $pgCtl" }
if (-not (Test-Path (Join-Path $DataDir 'PG_VERSION'))) {
  throw "no PostgreSQL data directory at $DataDir (run initdb first)"
}

function Test-Running {
  $out = & $pgCtl -D $DataDir status 2>&1
  return -not ($out -match 'no server running')
}

function Start-Detached {
  # WMI 创建的进程不属于当前进程树，因此命令可以立即返回，postgres 也不会被超时杀掉。
  # A WMI-created process is outside this process tree, so the command returns
  # immediately and postgres survives a timeout kill.
  $cmd = "`"$pgCtl`" -D `"$DataDir`" -l `"$logFile`" start"
  $result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd }
  if ($result.ReturnValue -ne 0) { throw "Win32_Process.Create failed with $($result.ReturnValue)" }

  for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-Running) { return $true }
  }
  return $false
}

switch ($Action) {
  'status' {
    if (Test-Running) {
      Write-Host 'postgres: running / 运行中' -ForegroundColor Green
      & $pgCtl -D $DataDir status
    } else {
      Write-Host 'postgres: not running / 未运行' -ForegroundColor Yellow
    }
  }

  'start' {
    if (Test-Running) { Write-Host 'postgres already running / 已在运行' -ForegroundColor DarkGray }
    elseif (Start-Detached) { Write-Host 'postgres started / 已启动' -ForegroundColor Green }
    else { throw "postgres did not come up; check $logFile" }
  }

  'stop' {
    if (-not (Test-Running)) { Write-Host 'postgres not running / 未运行' -ForegroundColor DarkGray; break }
    # 用 fast 模式做一次干净的关闭，避免下次启动走崩溃恢复。
    # Use fast mode for a clean shutdown so the next start skips crash recovery.
    & $pgCtl -D $DataDir -m fast stop
  }

  'restart' {
    if (Test-Running) { & $pgCtl -D $DataDir -m fast stop | Out-Null }
    if (Start-Detached) { Write-Host 'postgres restarted / 已重启' -ForegroundColor Green }
    else { throw "postgres did not come up; check $logFile" }
  }

  'ensure' {
    if (Test-Running) { Write-Host 'postgres already running / 已在运行' -ForegroundColor DarkGray }
    elseif (Start-Detached) { Write-Host 'postgres started / 已启动' -ForegroundColor Green }
    else { throw "postgres did not come up; check $logFile" }
  }
}
