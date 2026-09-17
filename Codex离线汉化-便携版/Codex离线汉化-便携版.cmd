@echo off
rem Portable offline localization for the Codex desktop app (no network).
if not exist "%USERPROFILE%\.codex" mkdir "%USERPROFILE%\.codex"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Codex-Offline-CN.ps1"
pause
