# =============================================================================
# Enhanced Logging and Error Tracking System
# Replaces Threading.ps1 with comprehensive error breakdown
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

function Write-LogMessage {
    <#
    .SYNOPSIS
        Writes log message to file and console with enhanced tracking
    
    .PARAMETER Message
        Message to log
    
    .PARAMETER Level
        Log level (Info, Success, Warning, Error, Debug)
    
    .PARAMETER Category
        Error category for tracking (API, FileSystem, Network, etc.)
    
    .PARAMETER Source
        Source function/module that generated the log
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',
        
        [ValidateSet('API', 'FileSystem', 'Network', 'Validation', 'Processing', 'Configuration', 'Unknown')]
        [string]$Category = 'Unknown',
        
        [string]$Source = $null
    )
    
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
    
    # Write to log file
    try {
        Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if log file can't be written
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

function Write-ErrorLog {
    <#
    .SYNOPSIS
        Writes comprehensive error information with full breakdown
    
    .PARAMETER Message
        Error message
    
    .PARAMETER ErrorRecord
        PowerShell error record
    
    .PARAMETER Category
        Error category
    
    .PARAMETER Context
        Additional context information
    
    .PARAMETER Source
        Source function/module
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        $ErrorRecord = $null,
        
        [ValidateSet('API', 'FileSystem', 'Network', 'Validation', 'Processing', 'Configuration', 'Unknown')]
        [string]$Category = 'Unknown',
        
        [hashtable]$Context = @{},
        
        [string]$Source = $null
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Get caller info if Source not provided
    if (-not $Source) {
        $callStack = Get-PSCallStack
        if ($callStack.Count -gt 1) {
            $caller = $callStack[1]
            $Source = "$($caller.Command):$($caller.ScriptLineNumber)"
        }
    }
    
    # Build comprehensive error report
    $errorReport = @"

========================================
ERROR REPORT
========================================
Timestamp:       $timestamp
Category:        $Category
Source:          $Source
Message:         $Message
========================================

"@
    
    if ($ErrorRecord) {
        $errorReport += @"
EXCEPTION DETAILS:
------------------
Type:            $($ErrorRecord.Exception.GetType().FullName)
Message:         $($ErrorRecord.Exception.Message)
HResult:         $($ErrorRecord.Exception.HResult)

"@
        
        # Inner exceptions
        if ($ErrorRecord.Exception.InnerException) {
            $errorReport += @"
INNER EXCEPTION:
----------------
Type:            $($ErrorRecord.Exception.InnerException.GetType().FullName)
Message:         $($ErrorRecord.Exception.InnerException.Message)

"@
        }
        
        # Script stack trace
        if ($ErrorRecord.ScriptStackTrace) {
            $errorReport += @"
SCRIPT STACK TRACE:
-------------------
$($ErrorRecord.ScriptStackTrace)

"@
        }
        
        # Invocation info
        if ($ErrorRecord.InvocationInfo) {
            $errorReport += @"
INVOCATION DETAILS:
-------------------
Command:         $($ErrorRecord.InvocationInfo.MyCommand)
Script:          $($ErrorRecord.InvocationInfo.ScriptName)
Line:            $($ErrorRecord.InvocationInfo.ScriptLineNumber)
Column:          $($ErrorRecord.InvocationInfo.OffsetInLine)
Line Content:    $($ErrorRecord.InvocationInfo.Line)

Position Message:
$($ErrorRecord.InvocationInfo.PositionMessage)

"@
        }
        
        # Target object
        if ($ErrorRecord.TargetObject) {
            $errorReport += @"
TARGET OBJECT:
--------------
Type:            $($ErrorRecord.TargetObject.GetType().FullName)
Value:           $($ErrorRecord.TargetObject)

"@
        }
        
        # Category info
        $errorReport += @"
ERROR CATEGORY:
---------------
Category:        $($ErrorRecord.CategoryInfo.Category)
Activity:        $($ErrorRecord.CategoryInfo.Activity)
Reason:          $($ErrorRecord.CategoryInfo.Reason)
Target Name:     $($ErrorRecord.CategoryInfo.TargetName)
Target Type:     $($ErrorRecord.CategoryInfo.TargetType)

"@
        
        # Full error details
        if ($ErrorRecord.ErrorDetails) {
            $errorReport += @"
ADDITIONAL ERROR DETAILS:
-------------------------
$($ErrorRecord.ErrorDetails.Message)

"@
        }
    }
    
    # Add context information
    if ($Context.Count -gt 0) {
        $errorReport += @"
CONTEXT INFORMATION:
--------------------
"@
        foreach ($key in $Context.Keys) {
            $errorReport += "$key : $($Context[$key])`n"
        }
        $errorReport += "`n"
    }
    
    # Add environment info
    $errorReport += @"
ENVIRONMENT:
------------
PowerShell:      $($PSVersionTable.PSVersion)
OS:              $($PSVersionTable.OS)
User:            $env:USERNAME
Computer:        $env:COMPUTERNAME
Module Path:     $script:ModuleRoot

"@
    
    # Add call stack
    $callStack = Get-PSCallStack
    if ($callStack.Count -gt 1) {
        $errorReport += @"
CALL STACK:
-----------
"@
        for ($i = 1; $i -lt $callStack.Count; $i++) {
            $frame = $callStack[$i]
            $errorReport += "[$i] $($frame.Command) at $($frame.Location)`n"
        }
        $errorReport += "`n"
    }
    
    $errorReport += "========================================`n"
    
    # Track the error
    $errorEntry = @{
        Timestamp = $timestamp
        Category = $Category
        Source = $Source
        Message = $Message
        FullReport = $errorReport
        ErrorRecord = $ErrorRecord
        Context = $Context
    }
    
    $script:ErrorTracker.Errors += $errorEntry
    $script:ErrorTracker.Categories[$Category] += $errorEntry
    
    # Write to log file
    try {
        Add-Content -Path $script:LogFile -Value $errorReport -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Failed to write error log to file"
    }
    
    # Write summary to console
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Write-Host "Category: $Category | Source: $Source" -ForegroundColor Yellow
    if ($ErrorRecord) {
        Write-Host "Exception: $($ErrorRecord.Exception.Message)" -ForegroundColor Red
    }
    Write-Host "========================================" -ForegroundColor Red
}

function Get-ErrorSummary {
    <#
    .SYNOPSIS
        Generates comprehensive error summary report
    #>
    
    [CmdletBinding()]
    param()
    
    $summary = @"

========================================
ERROR SUMMARY REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
========================================

OVERVIEW:
---------
Total Errors:    $($script:ErrorTracker.Errors.Count)
Total Warnings:  $($script:ErrorTracker.Warnings.Count)

ERRORS BY CATEGORY:
-------------------
"@
    
    foreach ($category in $script:ErrorTracker.Categories.Keys | Sort-Object) {
        $count = $script:ErrorTracker.Categories[$category].Count
        if ($count -gt 0) {
            $summary += "$category : $count error(s)`n"
        }
    }
    
    if ($script:ErrorTracker.Errors.Count -gt 0) {
        $summary += @"

========================================
DETAILED ERROR BREAKDOWN:
========================================

"@
        
        $errorNum = 1
        foreach ($error in $script:ErrorTracker.Errors) {
            $summary += @"
ERROR #$errorNum
--------------
Time:     $($error.Timestamp)
Category: $($error.Category)
Source:   $($error.Source)
Message:  $($error.Message)

"@
            if ($error.FullReport) {
                $summary += $error.FullReport + "`n"
            }
            $errorNum++
        }
    }
    
    if ($script:ErrorTracker.Warnings.Count -gt 0) {
        $summary += @"

========================================
WARNINGS:
========================================

"@
        
        $warnNum = 1
        foreach ($warning in $script:ErrorTracker.Warnings) {
            $summary += @"
WARNING #$warnNum
-----------------
Time:     $($warning.Timestamp)
Category: $($warning.Category)
Source:   $($warning.Source)
Message:  $($warning.Message)

"@
            $warnNum++
        }
    }
    
    $summary += @"

========================================
END OF ERROR SUMMARY
========================================
"@
    
    return $summary
}

function Export-ErrorReport {
    <#
    .SYNOPSIS
        Exports comprehensive error report to file
    
    .PARAMETER Path
        Output file path
    #>
    
    [CmdletBinding()]
    param(
        [string]$Path = $null
    )
    
    if (-not $Path) {
        $Path = Join-Path $script:LogsPath "ErrorReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    }
    
    try {
        $summary = Get-ErrorSummary
        $summary | Out-File -FilePath $Path -Force -Encoding UTF8
        
        Write-Host "Error report exported to: $Path" -ForegroundColor Green
        return $Path
    }
    catch {
        Write-Warning "Failed to export error report: $_"
        return $null
    }
}

function Show-ErrorSummary {
    <#
    .SYNOPSIS
        Displays error summary in console with option to export
    #>
    
    [CmdletBinding()]
    param()
    
    $summary = Get-ErrorSummary
    Write-Host $summary -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  [1] Export detailed error report" -ForegroundColor Green
    Write-Host "  [2] Continue" -ForegroundColor Green
    Write-Host ""
    Write-Host "Select option: " -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    
    if ($choice -eq '1') {
        $reportPath = Export-ErrorReport
        if ($reportPath) {
            Write-Host ""
            Write-Host "Opening error report..." -ForegroundColor Cyan
            Start-Process notepad.exe -ArgumentList $reportPath
        }
    }
}

function Clear-ErrorTracker {
    <#
    .SYNOPSIS
        Clears error tracking data
    #>
    
    [CmdletBinding()]
    param()
    
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
    
    Write-Verbose "Error tracker cleared"
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initializes enhanced logging system
    #>
    
    [CmdletBinding()]
    param()
    
    # Clear error tracker
    Clear-ErrorTracker
    
    try {
        $header = @"
========================================
PlexAnimeTools Module
Version: 2.0.0
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
User: $env:USERNAME
Computer: $env:COMPUTERNAME
PowerShell: $($PSVersionTable.PSVersion)
OS: $($PSVersionTable.OS)
Module Path: $script:ModuleRoot
Log File: $script:LogFile
========================================

"@
        $header | Out-File -FilePath $script:LogFile -Force -Encoding UTF8
        Write-Verbose "Enhanced logging initialized: $script:LogFile"
    }
    catch {
        Write-Warning "Failed to initialize logging: $_"
    }
}

# Keep existing utility functions
function Get-LogFilePath {
    [CmdletBinding()]
    param()
    return $script:LogFile
}

function Clear-OldLogs {
    [CmdletBinding()]
    param([int]$Days = 30)
    
    try {
        $logsPath = Join-Path $script:ModuleRoot 'Logs'
        $cutoffDate = (Get-Date).AddDays(-$Days)
        
        $oldLogs = Get-ChildItem -Path $logsPath -Filter "*.log" | 
            Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        foreach ($log in $oldLogs) {
            Remove-Item -Path $log.FullName -Force
            Write-LogMessage "Removed old log: $($log.Name)" -Level Info -Category FileSystem
        }
        
        if ($oldLogs.Count -gt 0) {
            Write-LogMessage "Cleaned up $($oldLogs.Count) old log file(s)" -Level Success -Category FileSystem
        }
    }
    catch {
        Write-LogMessage "Failed to clean old logs: $($_.Exception.Message)" -Level Warning -Category FileSystem
    }
}

function Start-ProgressTimer {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Activity)
    
    return @{
        Activity = $Activity
        StartTime = Get-Date
    }
}

function Stop-ProgressTimer {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Timer)
    
    $duration = (Get-Date) - $Timer.StartTime
    $message = "$($Timer.Activity) completed in $($duration.TotalSeconds.ToString('F2')) seconds"
    Write-LogMessage $message -Level Success -Category Processing
}

function Format-FileSize {
    [CmdletBinding()]
    param([Parameter(Mandatory)][long]$Bytes)
    
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    elseif ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    else { return "$Bytes bytes" }
}

# Export functions
Export-ModuleMember -Function @(
    'Write-LogMessage',
    'Write-ErrorLog',
    'Get-ErrorSummary',
    'Export-ErrorReport',
    'Show-ErrorSummary',
    'Clear-ErrorTracker',
    'Initialize-Logging',
    'Get-LogFilePath',
    'Clear-OldLogs',
    'Start-ProgressTimer',
    'Stop-ProgressTimer',
    'Format-FileSize'
)