@echo off
title Media File Renamer - DEBUG MODE
cd /d "%~dp0"
echo ═══════════════════════════════════════════════════
echo  Media File Renamer — DEBUG MODE
echo  Window will stay open so you can see any errors
echo ═══════════════════════════════════════════════════
echo.
powershell.exe -NoProfile -NoExit -ExecutionPolicy Bypass -Command "& { Set-Location '%~dp0'; . '.\Launch.ps1' }"
