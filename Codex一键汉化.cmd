@echo off
chcp 65001 >nul 2>&1
title Codex one-click Chinese localization
setlocal
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" set "PS=powershell.exe"
set "SCRIPT="
for %%f in ("%~dp0*.ps1") do if not defined SCRIPT set "SCRIPT=%%~ff"
if not defined SCRIPT (
  echo.
  echo [ERROR] No .ps1 file found next to this launcher.
  echo         Keep this .cmd together with the main .ps1 file.
  pause >nul
  exit /b 1
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo [exit code %EC%] press any key to close...
  pause >nul
)
endlocal
