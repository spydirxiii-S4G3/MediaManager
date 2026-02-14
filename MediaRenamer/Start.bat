@echo off
title Media File Renamer
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch.ps1"
if %ERRORLEVEL% neq 0 (
    echo.
    echo  Something went wrong. See the error above.
    echo.
    pause
)
