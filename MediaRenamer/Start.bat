@echo off
:: Auto-minimize: relaunch self minimized if not already
if not "%1"=="min" (
    start /min "" "%~f0" min
    exit
)
title Media File Renamer
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch.ps1"
if %ERRORLEVEL% neq 0 (
    echo.
    echo  Something went wrong. See the error above.
    echo.
    pause
)
exit
