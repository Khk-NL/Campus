@echo off
setlocal
set "PB_EXE=%~dp0.tools\pocketbase-bin\pocketbase.exe"
set "PB_DATA=%~dp0.tools\pocketbase-mvp-data"
if exist "E:\pocketbase_0.40.4_windows_amd64\pocketbase.exe" (
  set "PB_EXE=E:\pocketbase_0.40.4_windows_amd64\pocketbase.exe"
  set "PB_DATA=E:\pocketbase_0.40.4_windows_amd64\pb_data"
)
if defined POCKETBASE_EXE set "PB_EXE=%POCKETBASE_EXE%"
if defined POCKETBASE_DATA_DIR (
  set "PB_DATA=%POCKETBASE_DATA_DIR%"
)
set "PB_MIGRATIONS=%~dp0experiments\pocketbase\pb_migrations"
if not exist "%PB_EXE%" (
  echo PocketBase executable not found: %PB_EXE%
  echo Download the Windows binary from https://pocketbase.io/docs/ and put pocketbase.exe in .tools\pocketbase-bin\
  exit /b 1
)
"%PB_EXE%" serve --http 127.0.0.1:8090 --dir "%PB_DATA%" --migrationsDir "%PB_MIGRATIONS%"
