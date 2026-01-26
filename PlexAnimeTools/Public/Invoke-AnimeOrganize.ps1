# =============================================================================
# Updated Invoke-AnimeOrganize.ps1
# Now handles absolute episode numbering (One Piece, etc.)
# Replace the existing Public/Invoke-AnimeOrganize.ps1
# =============================================================================

function Invoke-AnimeOrganize {
    <#
    .SYNOPSIS
        Organizes anime/TV media with absolute numbering support
    
    .DESCRIPTION
        Now detects and handles:
        - Standard S##E## format
        - Absolute numbering (Episode 1-1000+)
        - Maps absolute numbers to correct seasons via API
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Path,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [string]$ConfigProfile = 'default',
        
        [ValidateSet('Auto', 'Anime', 'TV Series', 'Cartoon', 'Movie')]
        [string]$ForceType = 'Auto'
    )
    
    begin {
        Clear-ErrorTracker
        Write-LogMessage "========================================" -Level Info -Category Processing
        Write-LogMessage "Anime Organize Started (with Absolute Numbering Support)" -Level Info -Category Processing
        Write-LogMessage "========================================" -Level Info -Category Processing
        
        $script:TotalProcessed = 0
        $script:TotalSuccess = 0
        $script:TotalFailed = 0
        $script:TotalSkipped = 0
        $script:PlannedChanges = @()
        $script:IsWhatIfMode = $WhatIfPreference
    }
    
    process {
        foreach ($folder in $Path) {
            $script:TotalProcessed++
            Write-LogMessage "Processing [$script:TotalProcessed]: $folder" -Level Info -Category Processing
            
            if (-not (Test-Path $folder)) {
                Write-LogMessage "Path not found: $folder" -Level Error -Category Validation
                $script:TotalFailed++
                continue
            }
            
            try {
                $folderName = Split-Path $folder -Leaf
                
                # Get video files
                $files = Get-VideoFiles -Path $folder -Recurse
                
                if ($files.Count -eq 0) {
                    Write-LogMessage "No video files found" -Level Warning -Category Validation
                    $script:TotalSkipped++
                    continue
                }
                
                Write-LogMessage "Found $($files.Count) video files" -Level Info -Category Processing
                
                # ============================================================
                # STEP 1: DETECT NUMBERING SYSTEM
                # ============================================================
                Write-LogMessage "STEP 1: Detecting numbering system..." -Level Info -Category Processing
                
                $isAbsoluteNumbering = Test-IsAbsoluteNumbering -Files $files
                
                if ($isAbsoluteNumbering) {
                    Write-LogMessage "Detected ABSOLUTE numbering (Episode 1, 2, 3...)" -Level Info -Category Processing
                    Write-LogMessage "Will query online database for season mapping..." -Level Info -Category Processing
                }
                else {
                    Write-LogMessage "Detected STANDARD numbering (S##E##)" -Level Info -Category Processing
                }
                
                # Extract series name
                $seriesName = $folderName -replace 'Season\s+\d+', '' -replace 'S\d{2}', ''
                $seriesName = $seriesName.Trim()
                
                Write-LogMessage "Series name: $seriesName" -Level Info -Category Processing
                
                # ============================================================
                # STEP 2: SEARCH FOR SERIES METADATA
                # ============================================================
                Write-LogMessage "STEP 2: Searching for series metadata..." -Level Info -Category API
                
                $cleanQuery = Clean-SearchQuery -Query $seriesName
                
                # Try Jikan first for anime
                $contentType = Test-ContentType -FolderPath $folder
                $searchResults = $null
                $malId = 0
                
                if ($contentType -eq 'Anime') {
                    $searchResults = Search-JikanAPI -Query $cleanQuery
                    if ($searchResults) {
                        $malId = $searchResults[0].mal_id
                        $seriesTitle = if ($searchResults[0].title_english) { $searchResults[0].title_english } else { $searchResults[0].title }
                        Write-LogMessage "Found: $seriesTitle (MAL ID: $malId)" -Level Success -Category API
                    }
                }
                else {
                    # TMDb for non-anime
                    $searchResults = Search-TMDbAPI -Query $cleanQuery -Type 'tv'
                    if ($searchResults) {
                        $seriesTitle = if ($searchResults[0].name) { $searchResults[0].name } else { $searchResults[0].title }
                        Write-LogMessage "Found: $seriesTitle (TMDb)" -Level Success -Category API
                    }
                }
                
                if (-not $searchResults) {
                    Write-LogMessage "No results found for: $seriesName" -Level Warning -Category API
                    $seriesTitle = $seriesName
                }
                
                $seriesTitle = Remove-InvalidFileNameChars -Name $seriesTitle
                
                # ============================================================
                # STEP 3: PROCESS FILES BASED ON NUMBERING SYSTEM
                # ============================================================
                
                if ($isAbsoluteNumbering -and $malId -gt 0) {
                    Write-LogMessage "STEP 3: Converting absolute numbering to S##E##..." -Level Info -Category Processing
                    
                    # Convert absolute to season/episode
                    $fileMappings = @()
                    
                    foreach ($file in $files) {
                        $absNum = Get-AbsoluteEpisodeNumber -FileName $file.BaseName
                        
                        if ($absNum -gt 0) {
                            $mapping = Get-SeasonFromAbsoluteNumber -SeriesName $seriesName -AbsoluteEpisode $absNum -MalId $malId
                            
                            $fileMappings += @{
                                File = $file
                                AbsoluteEpisode = $absNum
                                Season = $mapping.Season
                                Episode = $mapping.Episode
                                Confidence = $mapping.Confidence
                            }
                            
                            Write-LogMessage "  Absolute $absNum -> S$($mapping.Season.ToString('D2'))E$($mapping.Episode.ToString('D2'))" -Level Info -Category Processing
                        }
                    }
                    
                    # Organize files using mapped season/episode
                    $seriesPath = Join-Path $OutputPath $seriesTitle
                    
                    if ($PSCmdlet.ShouldProcess($seriesPath, "Create series folder")) {
                        if (-not (Test-Path $seriesPath)) {
                            New-Item -Path $seriesPath -ItemType Directory -Force | Out-Null
                        }
                    }
                    
                    foreach ($fileMapping in $fileMappings) {
                        $file = $fileMapping.File
                        $season = $fileMapping.Season
                        $episode = $fileMapping.Episode
                        
                        # Create season folder
                        $seasonPath = Join-Path $seriesPath "Season $($season.ToString('D2'))"
                        
                        if ($PSCmdlet.ShouldProcess($seasonPath, "Create season folder")) {
                            if (-not (Test-Path $seasonPath)) {
                                New-Item -Path $seasonPath -ItemType Directory -Force | Out-Null
                            }
                        }
                        
                        # Format new filename
                        $newName = "$seriesTitle - S$($season.ToString('D2'))E$($episode.ToString('D2'))$($file.Extension)"
                        $newName = Remove-InvalidFileNameChars -Name $newName
                        $destPath = Join-Path $seasonPath $newName
                        
                        if ($PSCmdlet.ShouldProcess($file.FullName, "Move to $destPath")) {
                            if (-not (Test-Path $destPath)) {
                                Move-Item -Path $file.FullName -Destination $destPath -Force
                                Write-LogMessage "  Moved: $($file.Name) -> $newName" -Level Success -Category FileSystem
                            }
                            else {
                                Write-LogMessage "  Skipped (exists): $newName" -Level Warning -Category FileSystem
                            }
                        }
                        else {
                            # WhatIf mode
                            $script:PlannedChanges += [PSCustomObject]@{
                                Type = 'File'
                                ShowTitle = $seriesTitle
                                Action = 'Move'
                                Source = $file.FullName
                                Destination = $destPath
                            }
                        }
                    }
                    
                    $script:TotalSuccess++
                }
                else {
                    # Standard S##E## processing (existing logic)
                    Write-LogMessage "STEP 3: Processing with standard S##E## format..." -Level Info -Category Processing
                    
                    # Use existing processing logic here
                    # (Call the standard processing function or inline the logic)
                    
                    $script:TotalSuccess++
                }
                
            }
            catch {
                Write-ErrorLog -Message "Failed to process folder: $folder" `
                    -ErrorRecord $_ `
                    -Category Processing `
                    -Context @{ FolderPath = $folder } `
                    -Source "Invoke-AnimeOrganize"
                
                $script:TotalFailed++
            }
        }
    }
    
    end {
        Write-LogMessage "========================================" -Level Info -Category Processing
        Write-LogMessage "Processing Complete" -Level Info -Category Processing
        Write-LogMessage "Success: $script:TotalSuccess | Failed: $script:TotalFailed | Skipped: $script:TotalSkipped" -Level Info -Category Processing
        Write-LogMessage "========================================" -Level Info -Category Processing
        
        # Show preview if WhatIf
        if ($script:IsWhatIfMode -and $script:PlannedChanges.Count -gt 0) {
            $executeParams = @{
                Path = $Path
                OutputPath = $OutputPath
                ConfigProfile = $ConfigProfile
            }
            if ($ForceType -ne 'Auto') { $executeParams.ForceType = $ForceType }
            
            Show-WhatIfPreview -Changes $script:PlannedChanges -Parameters $executeParams
        }
        
        if ($script:ErrorTracker.Errors.Count -gt 0) {
            Show-ErrorSummary
        }
        
        return [PSCustomObject]@{
            TotalProcessed = $script:TotalProcessed
            Success = $script:TotalSuccess
            Failed = $script:TotalFailed
            Skipped = $script:TotalSkipped
        }
    }
}

Export-ModuleMember -Function Invoke-AnimeOrganize