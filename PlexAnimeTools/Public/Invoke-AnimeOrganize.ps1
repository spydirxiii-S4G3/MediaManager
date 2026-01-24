# =============================================================================
# Main Function - Invoke-AnimeOrganize
# Processes media folders and organizes for Plex
# Updated with Enhanced Error Logging
# =============================================================================

function Invoke-AnimeOrganize {
    <#
    .SYNOPSIS
        Organizes anime/TV/movie files for Plex Media Server
    
    .DESCRIPTION
        Main function to process media folders, fetch metadata from Jikan/TMDb,
        rename files with proper episode titles, create season folders,
        and download artwork
    
    .PARAMETER Path
        Path(s) to folder(s) containing media files
    
    .PARAMETER OutputPath
        Destination path for organized media (Plex library location)
    
    .PARAMETER ConfigProfile
        Configuration profile to use (default, plex-strict, fansub-chaos)
    
    .PARAMETER ForceType
        Force content type detection
    
    .PARAMETER WhatIf
        Preview changes without making them (dry run mode)
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [ValidateSet('default', 'plex-strict', 'fansub-chaos')]
        [string]$ConfigProfile = 'default',
        
        [ValidateSet('Auto', 'Anime', 'TV Series', 'Cartoon', 'Movie')]
        [string]$ForceType = 'Auto'
    )
    
    begin {
        # Clear error tracker for new run
        Clear-ErrorTracker
        
        Write-LogMessage "========================================" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
        Write-LogMessage "Invoke-AnimeOrganize Started" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
        Write-LogMessage "========================================" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
        Write-LogMessage "Config Profile: $ConfigProfile" -Level Info -Category Configuration -Source "Invoke-AnimeOrganize"
        Write-LogMessage "Output Path: $OutputPath" -Level Info -Category Configuration -Source "Invoke-AnimeOrganize"
        Write-LogMessage "WhatIf Mode: $($WhatIfPreference)" -Level Info -Category Configuration -Source "Invoke-AnimeOrganize"
        Write-LogMessage "Force Type: $ForceType" -Level Info -Category Configuration -Source "Invoke-AnimeOrganize"
        
        # Ensure Logs directory exists
        $logsPath = Join-Path $script:ModuleRoot 'Logs'
        if (-not (Test-Path $logsPath)) {
            try {
                New-Item -Path $logsPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            catch {
                Write-ErrorLog -Message "Failed to create Logs directory" `
                    -ErrorRecord $_ `
                    -Category FileSystem `
                    -Context @{
                        LogsPath = $logsPath
                        ModuleRoot = $script:ModuleRoot
                    } `
                    -Source "Invoke-AnimeOrganize"
            }
        }
        
        # Update log file path to Logs folder
        $script:LogFile = Join-Path $logsPath "PlexAnimeTools_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Initialize-Logging
        
        # Load config if not default
        if ($ConfigProfile -ne 'default') {
            $configPath = Join-Path $script:ConfigPath "$ConfigProfile.json"
            if (Test-Path $configPath) {
                try {
                    $script:DefaultConfig = Get-Content $configPath -Raw | ConvertFrom-Json
                    Write-LogMessage "Loaded config: $ConfigProfile" -Level Success -Category Configuration -Source "Invoke-AnimeOrganize"
                }
                catch {
                    Write-ErrorLog -Message "Failed to load configuration profile: $ConfigProfile" `
                        -ErrorRecord $_ `
                        -Category Configuration `
                        -Context @{
                            ConfigProfile = $ConfigProfile
                            ConfigPath = $configPath
                            ConfigPathExists = (Test-Path $configPath)
                        } `
                        -Source "Invoke-AnimeOrganize"
                    
                    Write-LogMessage "Using default configuration" -Level Warning -Category Configuration -Source "Invoke-AnimeOrganize"
                }
            }
        }
        
        # Validate output path
        if (-not $WhatIfPreference -and -not (Test-Path $OutputPath)) {
            Write-LogMessage "Output path does not exist, creating: $OutputPath" -Level Warning -Category FileSystem -Source "Invoke-AnimeOrganize"
            try {
                if ($PSCmdlet.ShouldProcess($OutputPath, "Create output directory")) {
                    New-Item -Path $OutputPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                }
            }
            catch {
                Write-ErrorLog -Message "Failed to create output directory" `
                    -ErrorRecord $_ `
                    -Category FileSystem `
                    -Context @{
                        OutputPath = $OutputPath
                        ParentPath = (Split-Path $OutputPath -Parent)
                        ParentExists = (Test-Path (Split-Path $OutputPath -Parent))
                    } `
                    -Source "Invoke-AnimeOrganize"
                
                Write-Error "Failed to create output directory: $OutputPath"
                return
            }
        }
        
        $script:TotalProcessed = 0
        $script:TotalSuccess = 0
        $script:TotalFailed = 0
        $script:TotalSkipped = 0
        
        # Initialize change tracking for WhatIf preview
        $script:PlannedChanges = @()
        $script:IsWhatIfMode = $WhatIfPreference
    }
    
    process {
        foreach ($folder in $Path) {
            $script:TotalProcessed++
            
            Write-LogMessage "========================================" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
            Write-LogMessage "Processing [$script:TotalProcessed]: $folder" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
            
            # Validate folder
            if (-not (Test-Path $folder)) {
                Write-ErrorLog -Message "Source path not found" `
                    -ErrorRecord $null `
                    -Category Validation `
                    -Context @{
                        FolderPath = $folder
                        ParentPath = (Split-Path $folder -Parent)
                        ParentExists = (Test-Path (Split-Path $folder -Parent))
                        OutputPath = $OutputPath
                    } `
                    -Source "Invoke-AnimeOrganize"
                
                $script:TotalSkipped++
                continue
            }
            
            try {
                $timer = Start-ProgressTimer -Activity "Processing $folder"
                
                # Get folder info
                $folderName = Split-Path $folder -Leaf
                
                # Detect or use forced content type
                if ($ForceType -eq 'Auto') {
                    $contentType = Test-ContentType -FolderPath $folder -AssumeAnime
                }
                else {
                    $contentType = $ForceType
                    Write-LogMessage "Forced content type: $ForceType" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
                }
                
                Write-LogMessage "Detected as: $contentType" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
                
                # Get video files
                $files = Get-VideoFiles -Path $folder -Recurse
                
                if ($files.Count -eq 0) {
                    Write-ErrorLog -Message "No video files found in folder" `
                        -ErrorRecord $null `
                        -Category Validation `
                        -Context @{
                            FolderPath = $folder
                            FolderName = $folderName
                            VideoExtensions = ($script:VideoExtensions -join ', ')
                        } `
                        -Source "Invoke-AnimeOrganize"
                    
                    $script:TotalSkipped++
                    continue
                }
                
                Write-LogMessage "Found $($files.Count) video file(s)" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
                
                # Clean query for API search
                $cleanQuery = Clean-SearchQuery -Query $folderName
                Write-LogMessage "Search query: $cleanQuery" -Level Debug -Category Processing -Source "Invoke-AnimeOrganize"
                
                # Search appropriate API
                $results = $null
                
                if ($contentType -eq 'Anime') {
                    $type = if ($files.Count -eq 1) { 'movie' } else { '' }
                    $results = Search-JikanAPI -Query $cleanQuery -Type $type
                }
                else {
                    $type = if ($contentType -eq 'Movie') { 'movie' } else { 'tv' }
                    $results = Search-TMDbAPI -Query $cleanQuery -Type $type
                }
                
                if (-not $results) {
                    Write-ErrorLog -Message "No API results found for folder" `
                        -ErrorRecord $null `
                        -Category API `
                        -Context @{
                            FolderName = $folderName
                            CleanQuery = $cleanQuery
                            ContentType = $contentType
                            FileCount = $files.Count
                            API = if ($contentType -eq 'Anime') { 'Jikan' } else { 'TMDb' }
                        } `
                        -Source "Invoke-AnimeOrganize"
                    
                    $script:TotalFailed++
                    continue
                }
                
                Write-LogMessage "Found $($results.Count) match(es)" -Level Success -Category API -Source "Invoke-AnimeOrganize"
                
                # Use first result
                $selected = $results[0]
                
                if ($contentType -eq 'Anime') {
                    $title = if ($selected.title_english) { $selected.title_english } else { $selected.title }
                    $imageUrl = $selected.images.jpg.large_image_url
                    
                    # Get episodes if series
                    $episodes = @()
                    if ($files.Count -gt 1) {
                        $episodes = Get-JikanEpisodes -MalId $selected.mal_id
                    }
                }
                else {
                    $title = if ($selected.name) { $selected.name } else { $selected.title }
                    $imageUrl = if ($selected.poster_path) { "https://image.tmdb.org/t/p/w500$($selected.poster_path)" } else { $null }
                    $episodes = @()
                }
                
                $title = Remove-InvalidFileNameChars -Name $title
                Write-LogMessage "Selected: $title" -Level Success -Category Processing -Source "Invoke-AnimeOrganize"
                
                # Build show info
                $showInfo = @{
                    Title = $title
                    Type = if ($files.Count -eq 1) { 'Movie' } else { 'Series' }
                    Category = $contentType
                    Episodes = $episodes
                    SourcePath = $folder
                    ImageUrl = $imageUrl
                    IsRelatedMovie = $false
                }
                
                # Create folder structure
                if ($PSCmdlet.ShouldProcess($showInfo.Title, "Create folder structure")) {
                    $showPath = New-PlexFolderStructure -ShowInfo $showInfo -OutputPath $OutputPath
                }
                else {
                    # WhatIf mode
                    $showPath = Join-Path $OutputPath $showInfo.Title
                    Write-LogMessage "[WHATIF] Would create: $showPath" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
                    
                    $script:PlannedChanges += [PSCustomObject]@{
                        Type = 'Folder'
                        ShowTitle = $title
                        Action = 'Create'
                        Source = "Source: $folder"
                        Destination = $showPath
                    }
                }
                
                # Process files based on type
                if ($showInfo.Type -eq 'Movie') {
                    # Single movie file
                    $file = $files[0]
                    $newName = Format-PlexFileName -Title $title -Extension $file.Extension -Type 'Movie'
                    $destPath = Join-Path $showPath $newName
                    
                    if ($PSCmdlet.ShouldProcess($file.FullName, "Move to $destPath")) {
                        Move-MediaFile -SourcePath $file.FullName -DestinationPath $destPath
                    }
                    else {
                        Write-LogMessage "[WHATIF] $($file.Name) -> $newName" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
                        
                        $script:PlannedChanges += [PSCustomObject]@{
                            Type = 'File'
                            ShowTitle = $title
                            Action = 'Move'
                            Source = $file.FullName
                            Destination = $destPath
                        }
                    }
                }
                else {
                    # Series - detect season
                    $detectedSeason = Get-SeasonNumber -Name $folderName
                    
                    if ($detectedSeason -eq 1 -and $files.Count -gt 0) {
                        $firstFileName = $files[0].Name
                        $fileSeasonNum = Get-SeasonNumber -Name $firstFileName
                        if ($fileSeasonNum -ne 1) {
                            $detectedSeason = $fileSeasonNum
                            Write-LogMessage "Detected season $detectedSeason from filename" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
                        }
                    }
                    
                    Write-LogMessage "Using Season: $detectedSeason" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
                    
                    # Create season folder
                    if ($PSCmdlet.ShouldProcess("Season $($detectedSeason.ToString('D2'))", "Create season folder")) {
                        $seasonPath = New-SeasonFolder -ShowPath $showPath -Season $detectedSeason
                    }
                    else {
                        $seasonPath = Join-Path $showPath "Season $($detectedSeason.ToString('D2'))"
                        Write-LogMessage "[WHATIF] Would create: $seasonPath" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
                        
                        $script:PlannedChanges += [PSCustomObject]@{
                            Type = 'Folder'
                            ShowTitle = $title
                            Action = 'Create'
                            Source = "Source: $folder"
                            Destination = $seasonPath
                        }
                    }
                    
                    # Process episode files
                    $epNum = 1
                    foreach ($file in $files) {
                        $extractedEpNum = Get-EpisodeNumber -FileName $file.Name
                        if ($extractedEpNum -gt 0) {
                            $epNum = $extractedEpNum
                        }
                        
                        # Get episode title if available
                        $epTitle = ''
                        if ($episodes -and $epNum -le $episodes.Count) {
                            $epTitle = $episodes[$epNum - 1].title
                            if ([string]::IsNullOrWhiteSpace($epTitle)) {
                                $epTitle = ''
                            }
                        }
                        
                        $newName = Format-PlexFileName -Title $title -Season $detectedSeason -Episode $epNum -EpisodeTitle $epTitle -Extension $file.Extension -Type 'Episode'
                        $destPath = Join-Path $seasonPath $newName
                        
                        if ($PSCmdlet.ShouldProcess($file.FullName, "Move to $destPath")) {
                            Move-MediaFile -SourcePath $file.FullName -DestinationPath $destPath
                        }
                        else {
                            Write-LogMessage "[WHATIF] $($file.Name) -> $newName" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
                            
                            $script:PlannedChanges += [PSCustomObject]@{
                                Type = 'File'
                                ShowTitle = $title
                                Action = 'Move'
                                Source = $file.FullName
                                Destination = $destPath
                            }
                        }
                        
                        if ($extractedEpNum -le 0) {
                            $epNum++
                        }
                    }
                }
                
                $script:TotalSuccess++
                Stop-ProgressTimer -Timer $timer
            }
            catch {
                Write-ErrorLog -Message "Failed to process folder: $folder" `
                    -ErrorRecord $_ `
                    -Category Processing `
                    -Context @{
                        FolderPath = $folder
                        FolderName = $folderName
                        OutputPath = $OutputPath
                        ConfigProfile = $ConfigProfile
                        ForceType = $ForceType
                        FilesFound = if ($files) { $files.Count } else { 0 }
                    } `
                    -Source "Invoke-AnimeOrganize"
                
                $script:TotalFailed++
            }
        }
    }
    
    end {
        Write-LogMessage "========================================" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
        Write-LogMessage "Processing Complete" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
        Write-LogMessage "Total: $script:TotalProcessed | Success: $script:TotalSuccess | Failed: $script:TotalFailed | Skipped: $script:TotalSkipped" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
        Write-LogMessage "========================================" -Level Info -Category Processing -Source "Invoke-AnimeOrganize"
        
        # Show preview window if in WhatIf mode
        if ($script:IsWhatIfMode -and $script:PlannedChanges.Count -gt 0) {
            Write-Host ""
            Write-Host "Opening preview window with $($script:PlannedChanges.Count) planned change(s)..." -ForegroundColor Cyan
            Write-Host ""
            
            $executeParams = @{
                Path = $Path
                OutputPath = $OutputPath
                ConfigProfile = $ConfigProfile
            }
            
            if ($ForceType -ne 'Auto') {
                $executeParams.ForceType = $ForceType
            }
            
            Show-WhatIfPreview -Changes $script:PlannedChanges -Parameters $executeParams
        }
        
        # Show error summary if errors occurred
        if ($script:ErrorTracker.Errors.Count -gt 0 -or $script:ErrorTracker.Warnings.Count -gt 0) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "OPERATION COMPLETED WITH ISSUES" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "Errors: $($script:ErrorTracker.Errors.Count)" -ForegroundColor Red
            Write-Host "Warnings: $($script:ErrorTracker.Warnings.Count)" -ForegroundColor Yellow
            Write-Host ""
            
            Show-ErrorSummary
        }
        
        # Return summary
        [PSCustomObject]@{
            TotalProcessed = $script:TotalProcessed
            Success = $script:TotalSuccess
            Failed = $script:TotalFailed
            Skipped = $script:TotalSkipped
            Errors = $script:ErrorTracker.Errors.Count
            Warnings = $script:ErrorTracker.Warnings.Count
            LogFile = $script:LogFile
            PlannedChanges = if ($script:IsWhatIfMode) { $script:PlannedChanges.Count } else { 0 }
        }
    }
}