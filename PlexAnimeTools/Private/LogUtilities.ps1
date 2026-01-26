# =============================================================================
# Log Utility Functions
# Missing functions referenced in GUI and other modules
# Save as: Private/LogUtilities.ps1
# =============================================================================

function Write-ErrorLog {
    <#
    .SYNOPSIS
        Writes detailed error information to the error log
    
    .PARAMETER Message
        Error message to log
    
    .PARAMETER ErrorRecord
        The error record object ($_) from a catch block
    
    .PARAMETER Category
        Error category (API, FileSystem, Network, Validation, Processing, Configuration, Unknown)
    
    .PARAMETER Context
        Additional context information as a hashtable
    
    .PARAMETER Source
        Source function/module that generated the error
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [ValidateSet('API', 'FileSystem', 'Network', 'Validation', 'Processing', 'Configuration', 'Unknown')]
        [string]$Category = 'Unknown',
        
        [hashtable]$Context = @{},
        
        [string]$Source = $null
    )
    
    # Build detailed error message
    $errorDetails = $Message
    
    if ($ErrorRecord) {
        $errorDetails += "`n  Exception: $($ErrorRecord.Exception.Message)"
        $errorDetails += "`n  Type: $($ErrorRecord.Exception.GetType().FullName)"
        
        if ($ErrorRecord.InvocationInfo) {
            $errorDetails += "`n  Line: $($ErrorRecord.InvocationInfo.ScriptLineNumber)"
            $errorDetails += "`n  Command: $($ErrorRecord.InvocationInfo.MyCommand)"
        }
        
        if ($ErrorRecord.ScriptStackTrace) {
            $errorDetails += "`n  Stack Trace: $($ErrorRecord.ScriptStackTrace)"
        }
    }
    
    if ($Context.Count -gt 0) {
        $errorDetails += "`n  Context:"
        foreach ($key in $Context.Keys) {
            $errorDetails += "`n    $key = $($Context[$key])"
        }
    }
    
    # Log using Write-LogMessage if available, otherwise use Write-Error
    if (Get-Command Write-LogMessage -ErrorAction SilentlyContinue) {
        Write-LogMessage -Message $errorDetails `
            -Level Error `
            -Category $Category `
            -Source $Source
    }
    else {
        # Fallback to standard error logging
        Write-Error $errorDetails
        
        # Also try to write to a basic error log file
        try {
            $logPath = Join-Path $PSScriptRoot "..\Logs\Errors"
            if (-not (Test-Path $logPath)) {
                New-Item -Path $logPath -ItemType Directory -Force | Out-Null
            }
            
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $logFile = Join-Path $logPath "Errors_${timestamp}.log"
            
            $logEntry = "[$timestamp] [$Category] $(if($Source){"[$Source] "})$errorDetails"
            Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
        }
        catch {
            # Silently fail if we can't write to log
        }
    }
}

function Show-LatestLog {
    <#
    .SYNOPSIS
        Opens the most recent log file in notepad
    
    .PARAMETER Type
        Type of log to open (Main, Transcript, Events, Errors, Processing, Testing)
    #>
    
    [CmdletBinding()]
    param(
        [ValidateSet('Main', 'Transcript', 'Events', 'Errors', 'Processing', 'Testing')]
        [string]$Type = 'Main'
    )
    
    try {
        $logPath = Get-LatestLog -Type $Type
        
        if ($logPath -and (Test-Path $logPath)) {
            Start-Process notepad.exe -ArgumentList $logPath
            
            if (Get-Command Write-LogMessage -ErrorAction SilentlyContinue) {
                Write-LogMessage "Opened log file: $logPath" -Level Info -Category Events
            }
        }
        else {
            $message = "No $Type log file found"
            
            if (Get-Command Write-LogMessage -ErrorAction SilentlyContinue) {
                Write-LogMessage $message -Level Warning -Category Events
            }
            
            Write-Host "No $Type log file found in Logs directory" -ForegroundColor Yellow
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to open log file" `
            -ErrorRecord $_ `
            -Category FileSystem `
            -Context @{
                LogType = $Type
            } `
            -Source "Show-LatestLog"
    }
}

function Get-LatestLog {
    <#
    .SYNOPSIS
        Gets the path to the most recent log file
    
    .PARAMETER Type
        Type of log to retrieve (Main, Events, Errors, Processing, Testing, Transcript)
    #>
    
    [CmdletBinding()]
    param(
        [ValidateSet('Main', 'Transcript', 'Events', 'Errors', 'Processing', 'Testing')]
        [string]$Type = 'Main'
    )
    
    try {
        $logsPath = Join-Path $script:ModuleRoot 'Logs'
        
        if (-not (Test-Path $logsPath)) {
            Write-Verbose "Logs directory does not exist: $logsPath"
            return $null
        }
        
        # Determine search path and pattern based on type
        $searchPath = $logsPath
        $pattern = '*'
        
        switch ($Type) {
            'Main' { 
                # Main log is now in Events folder
                $pattern = 'PlexAnimeTools_*.log'
                $eventsFolder = Join-Path $logsPath 'Events'
                if (Test-Path $eventsFolder) {
                    $searchPath = $eventsFolder
                }
            }
            'Transcript' { 
                # Transcript is now in Events folder
                $pattern = 'Transcript_*.log'
                $eventsFolder = Join-Path $logsPath 'Events'
                if (Test-Path $eventsFolder) {
                    $searchPath = $eventsFolder
                }
            }
            'Events' {
                $pattern = 'Events_*.log'
                $eventsFolder = Join-Path $logsPath 'Events'
                if (Test-Path $eventsFolder) {
                    $searchPath = $eventsFolder
                }
            }
            'Errors' { 
                $pattern = 'Errors_*.log'
                $errorsFolder = Join-Path $logsPath 'Errors'
                if (Test-Path $errorsFolder) {
                    $searchPath = $errorsFolder
                }
            }
            'Processing' {
                $pattern = 'Processing_*.log'
                $processingFolder = Join-Path $logsPath 'Processing'
                if (Test-Path $processingFolder) {
                    $searchPath = $processingFolder
                }
            }
            'Testing' {
                $pattern = 'Testing_*.log'
                $testingFolder = Join-Path $logsPath 'Testing'
                if (Test-Path $testingFolder) {
                    $searchPath = $testingFolder
                }
            }
        }
        
        $latestLog = Get-ChildItem -Path $searchPath -Filter $pattern -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        
        if ($latestLog) {
            return $latestLog.FullName
        }
        
        return $null
    }
    catch {
        Write-Verbose "Error getting latest log: $_"
        return $null
    }
}

function Export-ErrorReport {
    <#
    .SYNOPSIS
        Exports error tracker data to a formatted report file
    
    .DESCRIPTION
        Creates a detailed error report from the error tracker and saves it to a file
    #>
    
    [CmdletBinding()]
    param()
    
    try {
        # Check if there are any errors to export
        if ($script:ErrorTracker.Errors.Count -eq 0 -and $script:ErrorTracker.Warnings.Count -eq 0) {
            Write-Verbose "No errors or warnings to export"
            return $null
        }
        
        # Create error report file
        $logsPath = Join-Path $script:ModuleRoot 'Logs\Errors'
        if (-not (Test-Path $logsPath)) {
            New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $reportPath = Join-Path $logsPath "ErrorReport_${timestamp}.txt"
        
        # Build report content
        $report = @"
========================================
PlexAnimeTools Error Report
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
========================================

SUMMARY
-------
Total Errors:   $($script:ErrorTracker.Errors.Count)
Total Warnings: $($script:ErrorTracker.Warnings.Count)

"@
        
        # Add errors by category
        if ($script:ErrorTracker.Errors.Count -gt 0) {
            $report += "`nERRORS BY CATEGORY`n"
            $report += "-------------------`n"
            
            foreach ($category in $script:ErrorTracker.Categories.Keys) {
                $categoryErrors = $script:ErrorTracker.Categories[$category]
                if ($categoryErrors.Count -gt 0) {
                    $report += "`n[$category] - $($categoryErrors.Count) error(s)`n"
                    foreach ($error in $categoryErrors) {
                        $report += "  Time: $($error.Timestamp)`n"
                        $report += "  Source: $($error.Source)`n"
                        $report += "  Message: $($error.Message)`n"
                        $report += "  ---`n"
                    }
                }
            }
        }
        
        # Add all errors in detail
        if ($script:ErrorTracker.Errors.Count -gt 0) {
            $report += "`n`nDETAILED ERROR LIST`n"
            $report += "===================`n"
            
            $errorNum = 1
            foreach ($error in $script:ErrorTracker.Errors) {
                $report += "`nError #${errorNum}:`n"
                $report += "  Timestamp: $($error.Timestamp)`n"
                $report += "  Level: $($error.Level)`n"
                $report += "  Category: $($error.Category)`n"
                $report += "  Source: $($error.Source)`n"
                $report += "  Message: $($error.Message)`n"
                $report += "  ---`n"
                $errorNum++
            }
        }
        
        # Add warnings
        if ($script:ErrorTracker.Warnings.Count -gt 0) {
            $report += "`n`nWARNINGS`n"
            $report += "=========`n"
            
            $warnNum = 1
            foreach ($warning in $script:ErrorTracker.Warnings) {
                $report += "`nWarning #${warnNum}:`n"
                $report += "  Timestamp: $($warning.Timestamp)`n"
                $report += "  Category: $($warning.Category)`n"
                $report += "  Source: $($warning.Source)`n"
                $report += "  Message: $($warning.Message)`n"
                $report += "  ---`n"
                $warnNum++
            }
        }
        
        $report += "`n`n========================================`n"
        $report += "End of Error Report`n"
        $report += "========================================`n"
        
        # Write report to file
        $report | Out-File -FilePath $reportPath -Encoding UTF8
        
        Write-Verbose "Error report exported to: $reportPath"
        return $reportPath
    }
    catch {
        Write-Warning "Failed to export error report: $_"
        return $null
    }
}

# Do NOT export from dot-sourced files - only from .psm1
# These functions will be available automatically when dot-sourced