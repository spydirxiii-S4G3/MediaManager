# =============================================================================
# Test-PlexScan Function
# Validates Plex compatibility of organized media
# =============================================================================

function Test-PlexScan {
    <#
    .SYNOPSIS
        Tests if organized media is Plex-compatible
    
    .DESCRIPTION
        Validates folder structure, file naming, and artwork for Plex Media Server compatibility
    
    .PARAMETER Path
        Path to organized media folder
    
    .PARAMETER Detailed
        Show detailed validation results
    
    .EXAMPLE
        Test-PlexScan -Path "D:\Plex\Anime\Attack on Titan"
        
        Validates Attack on Titan folder structure
    
    .EXAMPLE
        Test-PlexScan -Path "D:\Plex\Anime" -Detailed
        
        Tests all shows in Anime library with detailed output
    
    .EXAMPLE
        Get-ChildItem "D:\Plex\Anime" -Directory | Test-PlexScan
        
        Pipeline support - test multiple shows
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$Path,
        
        [switch]$Detailed,
        
        [switch]$NoPrompt
    )
    
    begin {
        Write-LogMessage "Starting Plex compatibility tests..." -Level Info
        $script:TestResults = @()
    }
    
    process {
        Write-LogMessage "Testing: $Path" -Level Info
        
        $issues = @()
        $warnings = @()
        $showName = Split-Path $Path -Leaf
        
        # Test 1: Path exists
        if (-not (Test-Path $Path)) {
            $issues += "Path does not exist"
            
            $result = [PSCustomObject]@{
                ShowName = $showName
                Path = $Path
                Valid = $false
                Issues = $issues
                Warnings = $warnings
                Score = 0
            }
            
            $script:TestResults += $result
            return $result
        }
        
        $score = 0
        $maxScore = 10
        
        # Test 2: Poster artwork (2 points)
        $posterPath = Join-Path $Path 'poster.jpg'
        if (Test-Path $posterPath) {
            $score += 2
            if ($Detailed) {
                Write-LogMessage "  [OK] Poster found" -Level Success
            }
        }
        else {
            $warnings += "Missing poster.jpg"
            if ($Detailed) {
                Write-LogMessage "  [WARNING] Poster missing" -Level Warning
            }
        }
        
        # Test 3: Season folders (3 points)
        $seasonFolders = Get-ChildItem -Path $Path -Directory | Where-Object {
            $_.Name -match '^Season \d{2}$'
        }
        
        if ($seasonFolders.Count -gt 0) {
            $score += 3
            if ($Detailed) {
                Write-LogMessage "  [OK] Found $($seasonFolders.Count) season folder(s)" -Level Success
            }
        }
        else {
            # Check if it's a movie
            $videoFiles = Get-VideoFiles -Path $Path
            if ($videoFiles.Count -eq 1) {
                $score += 3  # Single video file is OK for movies
                if ($Detailed) {
                    Write-LogMessage "  [OK] Single video file (movie)" -Level Success
                }
            }
            else {
                $issues += "No season folders found"
                if ($Detailed) {
                    Write-LogMessage "  [ERROR] No season folders" -Level Error
                }
            }
        }
        
        # Test 4: File naming (5 points)
        $namingValid = $true
        $fileCount = 0
        $validFiles = 0
        
        foreach ($season in $seasonFolders) {
            $files = Get-VideoFiles -Path $season.FullName
            $fileCount += $files.Count
            
            foreach ($file in $files) {
                # Check for S##E## pattern
                if ($file.Name -match 'S\d{2}E\d{2}') {
                    $validFiles++
                }
                else {
                    $namingValid = $false
                    $issues += "Invalid file naming: $($file.Name)"
                    if ($Detailed) {
                        Write-LogMessage "  [ERROR] Invalid naming: $($file.Name)" -Level Error
                    }
                }
            }
        }
        
        # Also check movie files
        if ($seasonFolders.Count -eq 0) {
            $movieFiles = Get-VideoFiles -Path $Path
            if ($movieFiles.Count -eq 1) {
                $fileCount = 1
                if ($movieFiles[0].Name -match '\(Movie\)' -or $movieFiles[0].Name -match '\(\d{4}\)') {
                    $validFiles = 1
                }
            }
        }
        
        if ($fileCount -gt 0) {
            $namingScore = [Math]::Round(($validFiles / $fileCount) * 5, 1)
            $score += $namingScore
            
            if ($Detailed -and $namingValid) {
                Write-LogMessage "  [OK] All files properly named ($validFiles/$fileCount)" -Level Success
            }
        }
        
        # Calculate final score percentage
        $scorePercent = [Math]::Round(($score / $maxScore) * 100, 0)
        $valid = $issues.Count -eq 0
        
        # Determine status
        $status = if ($scorePercent -ge 90) {
            "Excellent"
        }
        elseif ($scorePercent -ge 70) {
            "Good"
        }
        elseif ($scorePercent -ge 50) {
            "Acceptable"
        }
        else {
            "Needs Work"
        }
        
        # Log results
        if ($valid) {
            Write-LogMessage "  [PASS] PASSED ($scorePercent% - $status)" -Level Success
        }
        else {
            Write-LogMessage "  [FAIL] FAILED ($scorePercent% - $status)" -Level Warning
            foreach ($issue in $issues) {
                Write-LogMessage "    - $issue" -Level Warning
            }
        }
        
        # Create result object
        $result = [PSCustomObject]@{
            ShowName = $showName
            Path = $Path
            Valid = $valid
            Score = $scorePercent
            Status = $status
            Issues = $issues
            Warnings = $warnings
            SeasonCount = $seasonFolders.Count
            FileCount = $fileCount
            HasPoster = (Test-Path $posterPath)
        }
        
        $script:TestResults += $result
        
        return $result
    }
    
    end {
        if ($script:TestResults.Count -gt 1) {
            Write-LogMessage "========================================" -Level Info
            Write-LogMessage "Test Summary" -Level Info
            Write-LogMessage "Total Tested: $($script:TestResults.Count)" -Level Info
            
            $passed = ($script:TestResults | Where-Object { $_.Valid }).Count
            $failed = $script:TestResults.Count - $passed
            $avgScore = ($script:TestResults | Measure-Object -Property Score -Average).Average
            
            Write-LogMessage "Passed: $passed | Failed: $failed" -Level Info
            Write-LogMessage "Average Score: $([Math]::Round($avgScore, 1))%" -Level Info
            Write-LogMessage "========================================" -Level Info
        }
        
        # Only show interactive prompt if not suppressed
        if (-not $NoPrompt) {
            Write-Host ""
            Write-Host "Options:" -ForegroundColor Cyan
            Write-Host "  [1] Continue" -ForegroundColor Green
            Write-Host "  [2] Log detailed error report" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Select option: " -NoNewline -ForegroundColor Yellow
            
            $choice = Read-Host
            
            if ($choice -eq '2') {
                $errorLogPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "PlexScan_Errors_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                
                $errorReport = @"
========================================
Plex Compatibility Error Report
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
========================================

"@
                
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
        }
    }
}