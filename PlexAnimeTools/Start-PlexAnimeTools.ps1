# =============================================================================
# Start-PlexAnimeTools.ps1
# Launcher script for PlexAnimeTools module
# Place this in the PlexAnimeTools base folder
# =============================================================================

#Requires -Version 5.1

<#
.SYNOPSIS
    Starts PlexAnimeTools module with GUI or CLI options.

.DESCRIPTION
    This launcher script handles module loading and provides easy access to
    PlexAnimeTools functionality. Run without parameters for interactive menu.

.PARAMETER GUI
    Launch the graphical user interface

.PARAMETER CLI
    Start in command-line mode with prompt

.PARAMETER Test
    Run compatibility tests on a Plex library folder

.PARAMETER Info
    Display module information and help

.EXAMPLE
    .\Start-PlexAnimeTools.ps1
    Shows interactive menu

.EXAMPLE
    .\Start-PlexAnimeTools.ps1 -GUI
    Launches GUI directly

.EXAMPLE
    .\Start-PlexAnimeTools.ps1 -Info
    Displays module information
#>

[CmdletBinding(DefaultParameterSetName='Menu')]
param(
    [Parameter(ParameterSetName='GUI')]
    [switch]$GUI,
    
    [Parameter(ParameterSetName='CLI')]
    [switch]$CLI,
    
    [Parameter(ParameterSetName='Test')]
    [switch]$Test,
    
    [Parameter(ParameterSetName='Info')]
    [switch]$Info
)

# =============================================================================
# Functions
# =============================================================================

function Show-Banner {
    $banner = @"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              PlexAnimeTools v2.0.0                            ║
║              Media Organization for Plex                      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Cyan
}

function Show-Menu {
    Write-Host ""
    Write-Host "  [1] Launch GUI (Graphical Interface)" -ForegroundColor Green
    Write-Host "  [2] CLI Mode (Command Line)" -ForegroundColor Green
    Write-Host "  [3] Quick Start Guide" -ForegroundColor Yellow
    Write-Host "  [4] Test Plex Library" -ForegroundColor Yellow
    Write-Host "  [5] Module Information" -ForegroundColor Cyan
    Write-Host "  [6] View README" -ForegroundColor Cyan
    Write-Host "  [0] Exit" -ForegroundColor Red
    Write-Host ""
}

function Show-QuickStart {
    Clear-Host
    Show-Banner
    
    Write-Host "QUICK START GUIDE" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "1. ORGANIZE MEDIA (Preview Mode):" -ForegroundColor Yellow
    Write-Host "   Invoke-AnimeOrganize -Path 'D:\Downloads\Anime' -OutputPath 'D:\Plex\Anime' -WhatIf" -ForegroundColor White
    Write-Host ""
    
    Write-Host "2. ORGANIZE MEDIA (Execute):" -ForegroundColor Yellow
    Write-Host "   Invoke-AnimeOrganize -Path 'D:\Downloads\Anime' -OutputPath 'D:\Plex\Anime'" -ForegroundColor White
    Write-Host ""
    
    Write-Host "3. GET ANIME INFO:" -ForegroundColor Yellow
    Write-Host "   Get-AnimeInfo -Title 'Attack on Titan' -IncludeEpisodes" -ForegroundColor White
    Write-Host ""
    
    Write-Host "4. TEST PLEX COMPATIBILITY:" -ForegroundColor Yellow
    Write-Host "   Test-PlexScan -Path 'D:\Plex\Anime\ShowName' -Detailed" -ForegroundColor White
    Write-Host ""
    
    Write-Host "5. BATCH PROCESS FOLDERS:" -ForegroundColor Yellow
    Write-Host "   Get-ChildItem 'D:\Downloads' -Directory | Invoke-AnimeOrganize -OutputPath 'D:\Plex'" -ForegroundColor White
    Write-Host ""
    
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Show-ModuleInfo {
    Clear-Host
    Show-Banner
    
    Write-Host "MODULE INFORMATION" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Get module info
    $module = Get-Module PlexAnimeTools
    
    if ($module) {
        Write-Host "  Version:        " -NoNewline -ForegroundColor Gray
        Write-Host $module.Version -ForegroundColor White
        
        Write-Host "  Author:         " -NoNewline -ForegroundColor Gray
        Write-Host $module.Author -ForegroundColor White
        
        Write-Host "  Module Path:    " -NoNewline -ForegroundColor Gray
        Write-Host $module.ModuleBase -ForegroundColor White
        
        Write-Host ""
        Write-Host "  Available Commands:" -ForegroundColor Yellow
        
        $commands = Get-Command -Module PlexAnimeTools | Sort-Object Name
        foreach ($cmd in $commands) {
            Write-Host "    • " -NoNewline -ForegroundColor Gray
            Write-Host $cmd.Name -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "  Configuration Profiles:" -ForegroundColor Yellow
        
        $configPath = Join-Path $module.ModuleBase 'Config'
        if (Test-Path $configPath) {
            $configs = Get-ChildItem -Path $configPath -Filter "*.json"
            foreach ($config in $configs) {
                Write-Host "    • " -NoNewline -ForegroundColor Gray
                Write-Host $config.BaseName -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "  Module not loaded!" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Show-ReadMe {
    $readmePath = Join-Path $PSScriptRoot "README.md"
    
    if (Test-Path $readmePath) {
        # Try to open with default markdown viewer
        try {
            Start-Process $readmePath
            Write-Host "Opening README.md..." -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
        catch {
            # Fallback: display in console
            Clear-Host
            Show-Banner
            Write-Host "README CONTENTS" -ForegroundColor Cyan
            Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host ""
            Get-Content $readmePath | Write-Host
            Write-Host ""
        }
    }
    else {
        Write-Host "README.md not found at: $readmePath" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

function Start-CLIMode {
    Clear-Host
    Show-Banner
    
    Write-Host "CLI MODE - Interactive PowerShell" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "All PlexAnimeTools commands are available." -ForegroundColor White
    Write-Host "Type 'Get-Command -Module PlexAnimeTools' to see available commands." -ForegroundColor White
    Write-Host "Type 'exit' to return to menu." -ForegroundColor White
    Write-Host ""
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Interactive prompt
    while ($true) {
        Write-Host "PlexAnimeTools> " -NoNewline -ForegroundColor Green
        $command = Read-Host
        
        if ($command -eq 'exit' -or $command -eq 'quit') {
            break
        }
        
        if ([string]::IsNullOrWhiteSpace($command)) {
            continue
        }
        
        try {
            Invoke-Expression $command
        }
        catch {
            Write-Host "Error: $_" -ForegroundColor Red
        }
        
        Write-Host ""
    }
}

function Start-TestMode {
    Clear-Host
    Show-Banner
    
    Write-Host "PLEX LIBRARY TEST MODE" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Prompt for path
    Write-Host "Enter path to your Plex library folder:" -ForegroundColor Yellow
    Write-Host "(Example: D:\Plex\Anime)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Path> " -NoNewline -ForegroundColor Green
    $path = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($path)) {
        Write-Host "No path provided. Returning to menu..." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }
    
    if (-not (Test-Path $path)) {
        Write-Host "Path not found: $path" -ForegroundColor Red
        Start-Sleep -Seconds 3
        return
    }
    
    Write-Host ""
    Write-Host "Testing Plex library at: $path" -ForegroundColor Cyan
    Write-Host ""
    
    # Run tests
    try {
        $folders = Get-ChildItem -Path $path -Directory -ErrorAction Stop
        
        if ($folders.Count -eq 0) {
            Write-Host "No subdirectories found in: $path" -ForegroundColor Yellow
            Write-Host ""
            Start-Sleep -Seconds 2
            return
        }
        
        # Process each folder
        foreach ($folder in $folders) {
            Test-PlexScan -Path $folder.FullName -Detailed
        }
        
        # Now show the summary and menu
        Write-Host ""
        Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Cyan
        Write-Host "  [1] Continue" -ForegroundColor Green
        Write-Host "  [2] Log detailed error report" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Select option: " -NoNewline -ForegroundColor Yellow
        
        $choice = Read-Host
        
        if ($choice -eq '2') {
            $logsPath = Join-Path (Split-Path $modulePath -Parent) 'Logs'
            if (-not (Test-Path $logsPath)) {
                New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
            }
            $errorLogPath = Join-Path $logsPath "PlexScan_Errors_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            
            $errorReport = @"
========================================
Plex Compatibility Error Report
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Path Tested: $path
========================================

"@
            
            # Get test results from module scope
            if ($script:TestResults -and $script:TestResults.Count -gt 0) {
                foreach ($result in $script:TestResults) {
                    if (-not $result.Valid -or $result.Warnings.Count -gt 0) {
                        $errorReport += @"

----------------------------------------
Show: $($result.ShowName)
Path: $($result.Path)
Score: $($result.Score)%
Status: $($result.Status)
Valid: $($result.Valid)

Issues:
$($result.Issues | ForEach-Object { "  - $_" } | Out-String)

Warnings:
$($result.Warnings | ForEach-Object { "  - $_" } | Out-String)
----------------------------------------

"@
                    }
                }
                
                $errorReport | Out-File -FilePath $errorLogPath -Force -Encoding UTF8
                Write-Host ""
                Write-Host "Error report saved to: $errorLogPath" -ForegroundColor Green
                Write-Host ""
            }
            else {
                Write-Host ""
                Write-Host "No test results available to log." -ForegroundColor Yellow
                Write-Host ""
            }
        }
    }
    catch {
        Write-Host ""
        Write-Host "Error during testing: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
    }
    
    Write-Host ""
}

# =============================================================================
# Main Script
# =============================================================================

# Get script directory
$scriptPath = $PSScriptRoot
$modulePath = Join-Path $scriptPath "PlexAnimeTools.psd1"

# Check if module manifest exists
if (-not (Test-Path $modulePath)) {
    Write-Host "ERROR: PlexAnimeTools.psd1 not found!" -ForegroundColor Red
    Write-Host "Expected location: $modulePath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please ensure this script is in the PlexAnimeTools base folder." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Import module
try {
    Write-Host "Loading PlexAnimeTools module..." -ForegroundColor Cyan
    Import-Module $modulePath -Force -ErrorAction Stop
    Write-Host "Module loaded successfully!" -ForegroundColor Green
    Write-Host ""
    Start-Sleep -Seconds 1
}
catch {
    Write-Host "ERROR: Failed to load module!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Handle parameter-based execution
if ($GUI) {
    Clear-Host
    Show-Banner
    Write-Host "Launching GUI..." -ForegroundColor Cyan
    Write-Host ""
    Start-Sleep -Seconds 1
    Start-PlexGUI
    exit 0
}

if ($CLI) {
    Start-CLIMode
    exit 0
}

if ($Test) {
    Start-TestMode
    exit 0
}

if ($Info) {
    Show-ModuleInfo
    exit 0
}

# Interactive menu mode (default)
while ($true) {
    Clear-Host
    Show-Banner
    Show-Menu
    
    Write-Host "Select an option: " -NoNewline -ForegroundColor Yellow
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            Clear-Host
            Show-Banner
            Write-Host "Launching GUI..." -ForegroundColor Cyan
            Write-Host ""
            Start-Sleep -Seconds 1
            Start-PlexGUI
        }
        '2' {
            Start-CLIMode
        }
        '3' {
            Show-QuickStart
        }
        '4' {
            Start-TestMode
        }
        '5' {
            Show-ModuleInfo
        }
        '6' {
            Show-ReadMe
        }
        '0' {
            Write-Host ""
            Write-Host "Exiting PlexAnimeTools..." -ForegroundColor Cyan
            Write-Host ""
            Start-Sleep -Seconds 1
            exit 0
        }
        default {
            Write-Host ""
            Write-Host "Invalid selection. Please choose 0-6." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}