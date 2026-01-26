# =============================================================================
# Enhanced Logging and Error Tracking System
# 4 Categories: Errors, Events, Processing, Testing
# CORRECTED VERSION - Added session GUID to prevent log file collisions
# =============================================================================

# Global error tracking
$script:ErrorTracker = @{
    Errors = @()
    Warnings = @()
    Categories = @{
        API = @()
        FileSystem = @()
        Network = @()
        Validation = @()
        Processing = @()
        Configuration = @()
        Unknown = @()
    }
}

# FIXED: Added session GUID to prevent timestamp collisions
$script:SessionGuid = [guid]::NewGuid().ToString().Substring(0,8)

# Initialize organized log directories
function Clear-ErrorTracker {
    <#
    .SYNOPSIS
        Clears the error tracker for a new run
    #>
    [CmdletBinding()]
    param()
    
    $script:ErrorTracker.Errors = @()
    $script:ErrorTracker.Warnings = @()
    
    # FIXED: Create array copy of keys to avoid collection modification error
    $categoryKeys = @($script:ErrorTracker.Categories.Keys)
    foreach ($category in $categoryKeys) {
        $script:ErrorTracker.Categories[$category] = @()
    }
}

function Initialize-LogDirectories {
    [CmdletBinding()]
    param()
    
    $baseLogsPath = Join-Path $script:ModuleRoot 'Logs'
    
    # Create main subdirectories - 4 CATEGORIES ONLY
    $logFolders = @(
        'Errors',      # All errors, organized by module
        'Events',      # All non-error, non-processing events
        'Processing',  # All processing operations (including WhatIf)
        'Testing'      # All test results and validation
    )
    
    foreach ($folder in $logFolders) {
        $folderPath = Join-Path $baseLogsPath $folder
        if (-not (Test-Path $folderPath)) {
            try {
                New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
                Write-Verbose "Created log directory: $folder"
            }
            catch {
                Write-Warning "Failed to create log directory ${folder}: $($_.Exception.Message)"
            }
        }
    }
    
    # Set script-level log paths with session timestamp AND GUID
    # FIXED: Added $script:SessionGuid to prevent collisions
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:SessionTimestamp = $timestamp
    $script:EventLogFile = Join-Path $baseLogsPath "Events\Events_${timestamp}_${script:SessionGuid}.log"
    $script:ErrorLogFile = Join-Path $baseLogsPath "Errors\Errors_${timestamp}_${script:SessionGuid}.log"
    $script:ProcessingLogFile = Join-Path $baseLogsPath "Processing\Processing_${timestamp}_${script:SessionGuid}.log"
    $script:TestingLogFile = Join-Path $baseLogsPath "Testing\Testing_${timestamp}_${script:SessionGuid}.log"
}

function Write-LogMessage {
    <#
    .SYNOPSIS
        Writes log message to appropriate categorized log file
    
    .PARAMETER Message
        Message to log
    
    .PARAMETER Level
        Log level (Info, Success, Warning, Error, Debug)
    
    .PARAMETER Category
        Error category for tracking (API, FileSystem, Network, etc.)
    
    .PARAMETER Source
        Source function/module that generated the log
    
    .PARAMETER LogType
        Override log type (Errors, Events, Processing, Testing)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',
        
        [ValidateSet('API', 'FileSystem', 'Network', 'Validation', 'Processing', 'Configuration', 'Testing', 'Unknown')]
        [string]$Category = 'Unknown',
        
        [string]$Source = $null,
        
        [ValidateSet('Errors', 'Events', 'Processing', 'Testing')]
        [string]$LogType = $null
    )
    
    # Ensure log directories exist
    if (-not $script:EventLogFile) {
        Initialize-LogDirectories
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Get caller info if Source not provided
    if (-not $Source) {
        $callStack = Get-PSCallStack
        if ($callStack.Count -gt 1) {
            $caller = $callStack[1]
            $Source = "$($caller.Command):$($caller.ScriptLineNumber)"
        }
        else {
            $Source = "Unknown"
        }
    }
    
    $logEntry = "[$timestamp] [$Level] [$Category] [$Source] $Message"
    
    # Track errors and warnings
    if ($Level -eq 'Error') {
        $script:ErrorTracker.Errors += @{
            Timestamp = $timestamp
            Message = $Message
            Level = $Level
            Category = $Category
            Source = $Source
        }
        
        $script:ErrorTracker.Categories[$Category] += @{
            Timestamp = $timestamp
            Message = $Message
            Source = $Source
        }
    }
    elseif ($Level -eq 'Warning') {
        $script:ErrorTracker.Warnings += @{
            Timestamp = $timestamp
            Message = $Message
            Level = $Level
            Category = $Category
            Source = $Source
        }
    }
    
    # Determine which log file to write to based on rules:
    # 1. Errors (Level=Error or Warning) -> Errors folder
    # 2. Processing (Category=Processing) -> Processing folder
    # 3. Testing (Category=Testing or LogType=Testing) -> Testing folder
    # 4. Everything else -> Events folder
    
    $targetLogFile = if ($LogType) {
        # Explicit override
        switch ($LogType) {
            'Errors' { $script:ErrorLogFile }
            'Processing' { $script:ProcessingLogFile }
            'Testing' { $script:TestingLogFile }
            default { $script:EventLogFile }
        }
    }
    elseif ($Level -eq 'Error' -or $Level -eq 'Warning') {
        $script:ErrorLogFile
    }
    elseif ($Category -eq 'Processing') {
        $script:ProcessingLogFile
    }
    elseif ($Category -eq 'Testing') {
        $script:TestingLogFile
    }
    else {
        $script:EventLogFile
    }
    
    # Write to appropriate log file
    try {
        Add-Content -Path $targetLogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if log file can't be written
    }
    
    # Also write to main log file for completeness (backward compatibility)
    if ($script:LogFile) {
        try {
            Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
        }
        catch {}
    }
    
    # Write to GUI if available
    if ($script:GuiLogBox) {
        try {
            $script:GuiLogBox.AppendText("$logEntry`r`n")
            $script:GuiLogBox.SelectionStart = $script:GuiLogBox.Text.Length
            $script:GuiLogBox.ScrollToCaret()
            [System.Windows.Forms.Application]::DoEvents()
        }
        catch {
            # GUI may not be available
        }
    }
    
    # Write to console with color
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Debug' { 'Gray' }
        default { 'White' }
    }
    
    Write-Host $logEntry -ForegroundColor $color
}

function Start-ProgressTimer {
    <#
    .SYNOPSIS
        Starts a progress timer for tracking operation duration
    #>
    [CmdletBinding()]
    param(
        [string]$Activity = "Processing"
    )
    
    $script:ProgressStartTime = Get-Date
    $script:ProgressActivity = $Activity
    
    return @{
        StartTime = $script:ProgressStartTime
        Activity = $Activity
    }
}

function Stop-ProgressTimer {
    <#
    .SYNOPSIS
        Stops the progress timer and returns duration
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Timer
    )
    
    if ($script:ProgressStartTime) {
        $duration = (Get-Date) - $script:ProgressStartTime
        return $duration
    }
    
    return $null
}

function Show-ErrorSummary {
    <#
    .SYNOPSIS
        Displays a summary of errors from the error tracker
    #>
    [CmdletBinding()]
    param()
    
    $errorCount = $script:ErrorTracker.Errors.Count
    $warningCount = $script:ErrorTracker.Warnings.Count
    
    if ($errorCount -eq 0 -and $warningCount -eq 0) {
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "OPERATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        return
    }
    
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "OPERATION COMPLETED WITH ISSUES" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    # FIXED: Simplified color logic to avoid embedded script blocks
    if ($errorCount -gt 0) {
        Write-Host "Errors: $errorCount" -ForegroundColor Red
    }
    else {
        Write-Host "Errors: $errorCount" -ForegroundColor Green
    }
    
    if ($warningCount -gt 0) {
        Write-Host "Warnings: $warningCount" -ForegroundColor Yellow
    }
    else {
        Write-Host "Warnings: $warningCount" -ForegroundColor Green
    }
    
    if ($errorCount -gt 0) {
        Write-Host "`nError Breakdown by Category:" -ForegroundColor Red
        foreach ($category in $script:ErrorTracker.Categories.Keys) {
            $count = $script:ErrorTracker.Categories[$category].Count
            if ($count -gt 0) {
                Write-Host "  ${category}: $count" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
}

function Get-ErrorSummary {
    <#
    .SYNOPSIS
        Gets error summary data
    #>
    [CmdletBinding()]
    param()
    
    return @{
        Errors = $script:ErrorTracker.Errors.Count
        Warnings = $script:ErrorTracker.Warnings.Count
        Categories = $script:ErrorTracker.Categories
        Details = $script:ErrorTracker
    }
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initializes enhanced logging system with organized folders
    #>
    
    [CmdletBinding()]
    param()
    
    # Clear error tracker
    Clear-ErrorTracker
    
    # Create organized log directories
    Initialize-LogDirectories
    
    try {
        $header = @"
========================================
PlexAnimeTools Module
Version: 2.1.0
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Session: $script:SessionGuid
User: $env:USERNAME
Computer: $env:COMPUTERNAME
PowerShell: $($PSVersionTable.PSVersion)
OS: $($PSVersionTable.OS)
Module Path: $script:ModuleRoot
========================================
Log Organization (4 Categories):
  Events:     $script:EventLogFile
  Errors:     $script:ErrorLogFile
  Processing: $script:ProcessingLogFile
  Testing:    $script:TestingLogFile
========================================

"@
        # Write header to all 4 log category files
        $header | Out-File -FilePath $script:EventLogFile -Force -Encoding UTF8
        $header | Out-File -FilePath $script:ErrorLogFile -Force -Encoding UTF8
        $header | Out-File -FilePath $script:ProcessingLogFile -Force -Encoding UTF8
        $header | Out-File -FilePath $script:TestingLogFile -Force -Encoding UTF8
        
        # Backward compatibility - also write to main log
        if ($script:LogFile) {
            $header | Out-File -FilePath $script:LogFile -Force -Encoding UTF8
        }
        
        Write-Verbose "Enhanced logging initialized with 4 categories: Errors, Events, Processing, Testing"
        Write-Verbose "Session GUID: $script:SessionGuid"
    }
    catch {
        Write-Warning "Failed to initialize logging: $_"
    }
}