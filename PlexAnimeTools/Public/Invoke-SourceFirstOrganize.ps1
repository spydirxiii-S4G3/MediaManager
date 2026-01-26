# =============================================================================
# Invoke-SourceFirstOrganize - SOURCE FILES TAKE PRIORITY + EDGE CASES
# Reads YOUR files first, uses APIs ONLY for episode titles
# Now with comprehensive edge case handling
# =============================================================================

# Import edge case handlers
. "$PSScriptRoot\..\Private\EdgeCaseHandlers.ps1"

function Invoke-SourceFirstOrganize {
    <#
    .SYNOPSIS
        Organizes media by reading SOURCE files first with edge case handling
    
    .DESCRIPTION
        Priority order:
        1. Extract ALL metadata from YOUR source files (series name, season, episode)
        2. Apply edge case handlers (normalize names, detect patterns, fix encoding)
        3. Use APIs ONLY to fetch episode titles (tries alternative titles)
        4. Never override your source file metadata with API data
        
        Edge Case Features:
        - Alternative title matching (Japanese ↔ English)
        - Special character normalization
        - 15+ filename pattern detection methods
        - Encoding corruption repair
        - Context-based season detection
        - Special/OVA numbering
        - Movie vs episode distinction
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
        Write-LogMessage "SOURCE-FIRST Organize Started" -Level Info -Category Processing
        Write-LogMessage "Priority: YOUR files > Wikipedia > Jikan > MAL > TMDb" -Level Info -Category Processing
        Write-LogMessage "Edge Cases: Dedup, multi-part, quality markers, season detection" -Level Info -Category Processing
        Write-LogMessage "========================================" -Level Info -Category Processing
        
        $script:TotalProcessed = 0
        $script:TotalSuccess = 0
        $script:TotalFailed = 0
        $script:PlannedChanges = @()
        $script:IsWhatIfMode = $WhatIfPreference
        
        # Track processed series to prevent duplicates
        $script:ProcessedSeries = @{}
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
                
                # Get all video files - non-recursive for this specific folder
                $files = Get-ChildItem -Path $folder -File -Filter *.* -ErrorAction SilentlyContinue | Where-Object {
                    $_.Extension -match '\.(mkv|mp4|avi|m4v|ts|wmv|flv|webm)$'
                }
                
                if ($files.Count -eq 0) {
                    Write-LogMessage "No video files found" -Level Warning -Category Validation
                    $script:TotalSkipped++
                    continue
                }
                
                Write-LogMessage "Found $($files.Count) video files" -Level Info -Category Processing
                
                # ============================================================
                # INTELLIGENT FOLDER STRUCTURE DETECTION
                # ============================================================
                Write-LogMessage "Analyzing folder structure..." -Level Info -Category Processing
                
                $sourceParent = Split-Path $folder -Parent
                $parentName = if ($sourceParent) { Split-Path $sourceParent -Leaf } else { '' }
                
                # Determine structure type and extract series name
                $structureType = 'Unknown'
                $detectedSeriesName = ''
                $isInSeasonFolder = $false
                
                # Pattern 1: "Series\Season XX\files"
                if ($folderName -match '^Season\s+\d+$' -and $parentName) {
                    $structureType = 'Organized'
                    $detectedSeriesName = $parentName
                    $isInSeasonFolder = $true
                    Write-LogMessage "  Pattern: Series\Season XX" -Level Info -Category Processing
                }
                # Pattern 2: "Show Name Season 1\files"
                elseif ($folderName -match '(.+?)\s+Season\s+\d+') {
                    $structureType = 'SeasonInName'
                    $detectedSeriesName = $Matches[1]
                    Write-LogMessage "  Pattern: Season in folder name" -Level Info -Category Processing
                }
                # Pattern 3: "Show Name Specials\files"
                elseif ($folderName -match '(.+?)\s+(Specials?|OVAs?|OADs?)') {
                    $structureType = 'Specials'
                    $detectedSeriesName = $Matches[1]
                    Write-LogMessage "  Pattern: Specials/OVA folder" -Level Info -Category Processing
                }
                # Pattern 4: Just series name with loose files
                else {
                    $structureType = 'Loose'
                    # If folder name is generic AND has multiple series, we need to group files
                    if ($files -and $files.Count -gt 0 -and $folderName -match '^(anime|shows?|tv|media|downloads?)$') {
                        Write-LogMessage "  Pattern: Generic folder detected - will group files by series" -Level Info -Category Processing
                        
                        # Group files by extracted series name
                        $seriesGroups = @{}
                        foreach ($file in $files) {
                            $fileName = $file.BaseName
                            $seriesGuess = $fileName -replace 'Season\s+\d+.*$', '' `
                                                      -replace 'Episode\s+\d+.*$', '' `
                                                      -replace 'Ep\.?\s+\d+.*$', '' `
                                                      -replace 'S\d+E\d+.*$', '' `
                                                      -replace '\d+x\d+.*$', '' `
                                                      -replace '\s*[-–—]\s*\d+\s*[-–—].*$', '' `
                                                      -replace '\s+(English|Dubbed|Online|Subbed).*$', '' `
                                                      -replace '\s*[-–—]\s*$', '' `
                                                      -replace '\s+$', ''
                            
                            if (-not $seriesGroups.ContainsKey($seriesGuess)) {
                                $seriesGroups[$seriesGuess] = @()
                            }
                            $seriesGroups[$seriesGuess] += $file
                        }
                        
                        Write-LogMessage "  Found $($seriesGroups.Count) series in generic folder" -Level Info -Category Processing
                        
                        # If only one series, continue normally
                        if ($seriesGroups.Count -eq 1) {
                            $detectedSeriesName = $seriesGroups.Keys[0]
                            Write-LogMessage "  Single series: $detectedSeriesName" -Level Info -Category Processing
                        }
                        else {
                            # Multiple series - need to process each separately
                            # This gets handled after structure detection
                            $detectedSeriesName = '__MULTI_SERIES__'
                            Write-LogMessage "  Multiple series detected - will process separately" -Level Info -Category Processing
                        }
                    }
                    else {
                        $detectedSeriesName = $folderName
                        Write-LogMessage "  Pattern: Loose files" -Level Info -Category Processing
                    }
                }
                
                Write-LogMessage "  Detected structure: $structureType" -Level Info -Category Processing
                Write-LogMessage "  Detected series: $detectedSeriesName" -Level Info -Category Processing
                
                # ============================================================
                # HANDLE MULTI-SERIES IN GENERIC FOLDER
                # ============================================================
                $seriesToProcess = @()
                
                if ($detectedSeriesName -eq '__MULTI_SERIES__' -and $seriesGroups) {
                    Write-LogMessage "Found $($seriesGroups.Count) different series in folder" -Level Info -Category Processing
                    
                    # Build list of series to process
                    foreach ($seriesName in $seriesGroups.Keys) {
                        $seriesToProcess += @{
                            Name = $seriesName
                            Files = $seriesGroups[$seriesName]
                        }
                    }
                }
                else {
                    # Single series
                    $seriesToProcess += @{
                        Name = $detectedSeriesName
                        Files = $files
                    }
                }
                
                # Process each series
                foreach ($seriesItem in $seriesToProcess) {
                    $seriesName = $seriesItem.Name
                    $files = $seriesItem.Files
                    
                    Write-LogMessage "Processing series: $seriesName ($($files.Count) files)" -Level Info -Category Processing
                
                # ============================================================
                # STEP 1: EXTRACT SERIES NAME
                # ============================================================
                Write-LogMessage "STEP 1: Extracting series name..." -Level Info -Category Processing
                
                # $seriesName is already set from the foreach loop above (line 199)
                # Don't overwrite it with $detectedSeriesName
                
                # Clean up series name
                $seriesName = $seriesName -replace 'Season\s+\d+', ''
                $seriesName = $seriesName -replace '\b(Specials?|OVAs?|OADs?)\b', ''
                $seriesName = $seriesName -replace 'S\d{2}', ''
                $seriesName = $seriesName.Trim()
                
                # If series name is empty, try to extract from filenames
                if ([string]::IsNullOrWhiteSpace($seriesName) -and $files.Count -gt 0) {
                    Write-LogMessage "  Series name empty, extracting from filenames..." -Level Info -Category Processing
                    
                    $firstFile = $files[0].BaseName
                    
                    # Try various patterns
                    if ($firstFile -match '^(.+?)\s*[-\s]+\s*S\d+E\d+') {
                        $seriesName = $Matches[1].Trim()
                    }
                    elseif ($firstFile -match '^(.+?)\s*[-\s]+\s*Episode\s+\d+') {
                        $seriesName = $Matches[1].Trim()
                    }
                    elseif ($firstFile -match '^(.+?)\s*[-\s]+\s*\d+') {
                        $seriesName = $Matches[1].Trim()
                    }
                    elseif ($parentName) {
                        $seriesName = $parentName
                    }
                    else {
                        $seriesName = $folderName
                    }
                    
                    Write-LogMessage "  Extracted from filename: $seriesName" -Level Info -Category Processing
                }
                
                # Apply edge case handling: Normalize series name
                $rawSeriesName = $seriesName
                $seriesName = Normalize-SeriesName -Name $seriesName
                if ($seriesName -ne $rawSeriesName) {
                    Write-LogMessage "  Normalized: '$rawSeriesName' -> '$seriesName'" -Level Debug -Category Processing
                }
                
                # Get alternative titles for API searching
                $alternativeTitles = Get-AlternativeTitles -SeriesName $seriesName
                if ($alternativeTitles.Count -gt 1) {
                    Write-LogMessage "  Found $($alternativeTitles.Count) title variations to try" -Level Debug -Category Processing
                }
                
                Write-LogMessage "  Final series name: $seriesName" -Level Success -Category Processing
                
                # Check if we've already processed this series
                $seriesKey = $seriesName.ToLower()
                if ($script:ProcessedSeries.ContainsKey($seriesKey)) {
                    Write-LogMessage "  SKIP: Already processed this series in this batch" -Level Warning -Category Processing
                    Write-LogMessage "  (Preventing duplicate processing of: $seriesName)" -Level Warning -Category Processing
                    continue
                }
                
                # Mark this series as processed
                $script:ProcessedSeries[$seriesKey] = $true
                
                # ============================================================
                # STEP 2: ANALYZE EACH FILE FOR SEASON/EPISODE
                # ============================================================
                Write-LogMessage "STEP 2: Analyzing files for season/episode numbers..." -Level Info -Category Processing
                
                # Analyze each file
                $sourceData = @{
                    SeriesName = $seriesName
                    Files = @()
                    DetectedSeasons = @()
                }
                
                foreach ($file in $files) {
                    $fileName = $file.BaseName
                    
                    # Apply edge case handling: Repair corrupted filenames
                    $repairedName = Repair-CorruptedFilename -FileName $fileName
                    if ($repairedName -ne $fileName) {
                        Write-LogMessage "  Repaired filename encoding: $fileName -> $repairedName" -Level Debug -Category Processing
                        $fileName = $repairedName
                    }
                    
                    # Extract season number - FOLDER TAKES PRIORITY!
                    $seasonNum = 1
                    # ============================================================
                    # ENHANCED: Use comprehensive pattern detection
                    # ============================================================
                    
                    $patternResult = Get-SeasonEpisodeFromFilename -FileName $fileName -FolderName $folderName -FolderPath $folder
                    
                    # Handle special/OVA detection
                    $isSpecial = $patternResult.IsSpecial
                    $specialSeasonNum = $null
                    
                    if ($isSpecial) {
                        $seasonNum = 0
                        if ($patternResult.SpecialType) {
                            Write-LogMessage "  Detected as $($patternResult.SpecialType)" -Level Debug -Category Processing
                        }
                    }
                    else {
                        $seasonNum = $patternResult.Season
                        
                        # If season still not detected, fall back to context
                        if ($seasonNum -eq $null) {
                            $seasonNum = Get-SeasonFromContext -FolderPath $folder -AllFiles $files
                            Write-LogMessage "  Determined season from context: $seasonNum (Confidence: Low)" -Level Debug -Category Processing
                        }
                        else {
                            Write-LogMessage "  Detected season: $seasonNum using pattern [$($patternResult.Pattern)] (Confidence: $($patternResult.Confidence)%)" -Level Debug -Category Processing
                        }
                    }
                    
                    # Extract episode number from comprehensive detection
                    $episodeNum = $patternResult.Episode
                    
                    if ($episodeNum -eq $null) {
                        # Fallback to legacy detection
                        $episodeNum = Test-EpisodeNumberInFilename -FileName $fileName
                    }
                    
                    if ($episodeNum -gt 0) {
                        Write-LogMessage "  Detected episode: $episodeNum using pattern [$($patternResult.Pattern)]" -Level Debug -Category Processing
                    }
                    
                    # If still not found, try special episode resolver
                    if ($episodeNum -eq -1 -and $isSpecial) {
                        $episodeNum = Resolve-SpecialEpisodeNumber -FileName $fileName -FolderName $folderName
                        if ($episodeNum -gt 0) {
                            Write-LogMessage "  Special episode number detected: $episodeNum" -Level Debug -Category Processing
                        }
                    }
                    
                    if ($episodeNum -eq -1) {
                        Write-LogMessage "  WARNING: Could not extract episode number from: $fileName" -Level Warning -Category Processing
                        continue
                    }
                    
                    # Check if this might be a movie instead of episode
                    if (Test-MovieFile -FileName $fileName -FileSize $file.Length) {
                        Write-LogMessage "  Detected as movie, skipping: $fileName" -Level Info -Category Processing
                        continue
                    }
                    
                    # Extract episode TITLE from source filename (PRIORITY!)
                    $sourceTitle = ''
                    
                    # Try pattern: "Show - S01E01 - Episode Title.ext"
                    if ($fileName -match 'S\d+E\d+\s*-\s*(.+)$') {
                        $sourceTitle = $Matches[1].Trim()
                    }
                    # Try pattern: "Show Season X - Episode Title.ext"
                    elseif ($fileName -match 'Season\s+\d+\s*-\s*(.+)$') {
                        $sourceTitle = $Matches[1].Trim()
                    }
                    # Try pattern: "Show - Episode 01 - Title.ext"
                    elseif ($fileName -match '(?:Episode|Ep)\s+\d+\s*-\s*(.+)$') {
                        $sourceTitle = $Matches[1].Trim()
                    }
                    
                    if ($sourceTitle) {
                        Write-LogMessage "  Extracted title from source: $sourceTitle" -Level Debug -Category Processing
                    }
                    
                    $sourceData.Files += @{
                        File = $file
                        FileName = $fileName
                        Season = $seasonNum
                        Episode = $episodeNum
                        SourceTitle = $sourceTitle
                        IsSpecial = $isSpecial
                        SpecialSeasonNum = $specialSeasonNum
                    }
                    
                    if ($sourceData.DetectedSeasons -notcontains $seasonNum) {
                        $sourceData.DetectedSeasons += $seasonNum
                    }
                    
                    Write-LogMessage "  File: $fileName -> Season $seasonNum, Episode $episodeNum$(if($sourceTitle){", Title: $sourceTitle"})" -Level Debug -Category Processing
                }
                
                Write-LogMessage "  Detected $($sourceData.Files.Count) episodes across $($sourceData.DetectedSeasons.Count) season(s)" -Level Success -Category Processing
                
                # ============================================================
                # STEP 3: GET EPISODE TITLES FROM APIs (ONLY TITLES!)
                # ============================================================
                Write-LogMessage "STEP 3: Fetching episode titles from APIs..." -Level Info -Category Processing
                
                $episodeTitles = @{}
                
                # Try Wikipedia with all alternative titles
                Write-LogMessage "  Trying Wikipedia (with $($alternativeTitles.Count) title variations)..." -Level Info -Category API
                foreach ($titleVariant in $alternativeTitles) {
                    $wikiEpisodes = Get-WikipediaEpisodeList -SeriesName $titleVariant
                    if ($wikiEpisodes) {
                        Write-LogMessage "  Found $($wikiEpisodes.Count) episodes on Wikipedia using: $titleVariant" -Level Success -Category API
                        foreach ($ep in $wikiEpisodes) {
                            $key = "S$($ep.Season)E$($ep.Number)"
                            $episodeTitles[$key] = $ep.Title
                        }
                        break  # Stop trying once we find a match
                    }
                }
                
                # Try Jikan if Wikipedia didn't work
                if ($episodeTitles.Count -eq 0) {
                    Write-LogMessage "  Wikipedia failed, trying Jikan with alternative titles..." -Level Info -Category API
                    
                    $cleanQuery = Clean-SearchQuery -Query $seriesName
                    $jikanResults = Search-JikanAPI -Query $cleanQuery
                    
                    if ($jikanResults) {
                        $malId = $jikanResults[0].mal_id
                        Write-LogMessage "  Found MAL ID: $malId" -Level Success -Category API
                        
                        $jikanEpisodes = Get-JikanEpisodes -MalId $malId
                        
                        if ($jikanEpisodes) {
                            Write-LogMessage "  Found $($jikanEpisodes.Count) episodes on Jikan" -Level Success -Category API
                            foreach ($ep in $jikanEpisodes) {
                                # Jikan episodes don't have season info, assume season 1
                                $key = "S1E$($ep.mal_id)"
                                if ($ep.title) {
                                    $episodeTitles[$key] = $ep.title
                                }
                            }
                        }
                    }
                }
                
                # ============================================================
                # STEP 4: CREATE/CORRECT FOLDER STRUCTURE
                # ============================================================
                Write-LogMessage "STEP 4: Creating/correcting folder structure..." -Level Info -Category Processing
                
                # Clean series name for folder
                $cleanSeriesName = Remove-InvalidFileNameChars -Name $seriesName
                
                # Check if source folder is ALREADY a series folder (not a season subfolder)
                $sourceParent = Split-Path $folder -Parent
                $sourceGrandparent = Split-Path $sourceParent -Parent
                
                # Determine if we're organizing FROM season folders or loose files
                $isAlreadyOrganized = $false
                $seriesPath = $null
                $needsRename = $false
                
                # Case 1: Source is "Series\Season XX" - check parent folder
                if ($folderName -match '^Season\s+\d+$' -and $sourceParent) {
                    $existingSeriesName = Split-Path $sourceParent -Leaf
                    $existingSeriesClean = Remove-InvalidFileNameChars -Name $existingSeriesName
                    
                    # Check if parent folder name matches our series (fuzzy match)
                    if ($existingSeriesName -like "*$seriesName*" -or $seriesName -like "*$existingSeriesName*") {
                        # Found existing series folder
                        
                        # Check if folder name needs correction
                        if ($existingSeriesClean -ne $cleanSeriesName) {
                            Write-LogMessage "  Series folder name needs correction:" -Level Info -Category Processing
                            Write-LogMessage "    Current: $existingSeriesName" -Level Info -Category Processing
                            Write-LogMessage "    Correct: $cleanSeriesName" -Level Info -Category Processing
                            
                            # Create corrected path
                            $correctedPath = Join-Path (Split-Path $sourceParent -Parent) $cleanSeriesName
                            
                            # Check if corrected path already exists (conflict)
                            if ((Test-Path $correctedPath) -and ($correctedPath -ne $sourceParent)) {
                                Write-LogMessage "    Corrected folder already exists, will merge into it" -Level Warning -Category Processing
                                $seriesPath = $correctedPath
                            }
                            else {
                                # Rename the series folder
                                if ($PSCmdlet.ShouldProcess($sourceParent, "Rename to $cleanSeriesName")) {
                                    try {
                                        Rename-Item -Path $sourceParent -NewName $cleanSeriesName -Force -ErrorAction Stop
                                        $seriesPath = $correctedPath
                                        Write-LogMessage "    Renamed series folder successfully" -Level Success -Category FileSystem
                                    }
                                    catch {
                                        Write-LogMessage "    Failed to rename folder: $_" -Level Warning -Category FileSystem
                                        $seriesPath = $sourceParent  # Use original if rename fails
                                    }
                                }
                                else {
                                    # WhatIf mode
                                    $seriesPath = $correctedPath
                                }
                            }
                        }
                        else {
                            # Name is already correct
                            $seriesPath = $sourceParent
                            Write-LogMessage "  Using existing series folder: $seriesPath" -Level Info -Category Processing
                        }
                        
                        $isAlreadyOrganized = $true
                    }
                }
                
                # Case 2: Not organized yet, or series name doesn't match
                if (-not $seriesPath) {
                    # Check if series folder exists in output path
                    $potentialPath = Join-Path $OutputPath $cleanSeriesName
                    if (Test-Path $potentialPath) {
                        $seriesPath = $potentialPath
                        Write-LogMessage "  Using existing series folder in output: $seriesPath" -Level Info -Category Processing
                    }
                    else {
                        $seriesPath = $potentialPath
                        Write-LogMessage "  Creating new series folder: $cleanSeriesName" -Level Info -Category Processing
                    }
                }
                
                # Create series folder if it doesn't exist
                if ($PSCmdlet.ShouldProcess($seriesPath, "Create series folder")) {
                    if (-not (Test-Path $seriesPath)) {
                        New-Item -Path $seriesPath -ItemType Directory -Force | Out-Null
                        Write-LogMessage "  Created: $seriesPath" -Level Success -Category FileSystem
                    }
                }
                
                # ============================================================
                # STEP 5: ORGANIZE FILES WITH CORRECTED NAMING
                # ============================================================
                Write-LogMessage "STEP 5: Organizing files..." -Level Info -Category Processing
                
                # Pre-sort files: Regular episodes first, then specials
                # Specials need sequential renumbering
                $regularFiles = @($sourceData.Files | Where-Object { -not $_.IsSpecial })
                $specialFiles = @($sourceData.Files | Where-Object { $_.IsSpecial } | Sort-Object { $_.SpecialSeasonNum }, { $_.Episode })
                
                # Renumber specials sequentially
                $specialCounter = 1
                foreach ($specialFile in $specialFiles) {
                    $specialFile.OriginalEpisode = $specialFile.Episode
                    $specialFile.Episode = $specialCounter
                    $specialCounter++
                }
                
                # Combine: process regular files, then specials
                $filesToProcess = @()
                if ($regularFiles) { $filesToProcess += $regularFiles }
                if ($specialFiles) { $filesToProcess += $specialFiles }
                
                foreach ($fileData in $filesToProcess) {
                    $file = $fileData.File
                    $season = $fileData.Season
                    $episode = $fileData.Episode
                    $sourceTitle = $fileData.SourceTitle
                    $isSpecial = $fileData.IsSpecial
                    $specialSeasonNum = $fileData.SpecialSeasonNum
                    
                    # For specials: MUST use S00 in both folder AND filename per Plex rules
                    $folderSeason = $season
                    $filenameSeason = $season
                    
                    if ($isSpecial) {
                        # Per Plex guidelines: ALL specials MUST be S00EXX in filename
                        # Cannot use S01EXX or S02EXX even if it was a "Season 1 OVA"
                        $folderSeason = 0
                        $filenameSeason = 0
                        
                        if ($specialSeasonNum) {
                            # Preserve season context in title, not filename
                            $epNumFormatted = $episode.ToString('D2')
                            Write-LogMessage "  Special from Season $specialSeasonNum - Folder=Season 00, Filename=S00E$epNumFormatted" -Level Debug -Category Processing
                        }
                        else {
                            $epNumFormatted = $episode.ToString('D2')
                            Write-LogMessage "  Special - Folder=Season 00, Filename=S00E$epNumFormatted" -Level Debug -Category Processing
                        }
                    }
                    
                    # Create season folder
                    $seasonPath = Join-Path $seriesPath "Season $($folderSeason.ToString('D2'))"
                    
                    if ($PSCmdlet.ShouldProcess($seasonPath, "Create season folder")) {
                        if (-not (Test-Path $seasonPath)) {
                            New-Item -Path $seasonPath -ItemType Directory -Force | Out-Null
                        }
                    }
                    
                    # PRIORITY: Use episode title from YOUR source file first!
                    $epTitle = ''
                    
                    if ($sourceTitle) {
                        # Use title from YOUR source file (HIGHEST PRIORITY)
                        $epTitle = $sourceTitle
                        Write-LogMessage "  Using title from source file: $epTitle" -Level Debug -Category Processing
                    }
                    else {
                        # Fall back to API title if no title in source
                        $key = "S${filenameSeason}E${episode}"
                        if ($episodeTitles.ContainsKey($key)) {
                            $epTitle = $episodeTitles[$key]
                            Write-LogMessage "  Using title from API: $epTitle" -Level Debug -Category Processing
                        }
                    }
                    
                    # Format filename using YOUR data (with special season handling)
                    if ($epTitle) {
                        $newName = "$cleanSeriesName - S$($filenameSeason.ToString('D2'))E$($episode.ToString('D2')) - $epTitle$($file.Extension)"
                    }
                    else {
                        $newName = "$cleanSeriesName - S$($filenameSeason.ToString('D2'))E$($episode.ToString('D2'))$($file.Extension)"
                    }
                    
                    $newName = Remove-InvalidFileNameChars -Name $newName
                    $destPath = Join-Path $seasonPath $newName
                    
                    Write-LogMessage "  $($file.Name) -> $newName" -Level Info -Category Processing
                    
                    if ($PSCmdlet.ShouldProcess($file.FullName, "Move to $destPath")) {
                        try {
                            if (-not (Test-Path $destPath)) {
                                Move-Item -Path $file.FullName -Destination $destPath -Force
                                Write-LogMessage "  Moved successfully" -Level Success -Category FileSystem
                            }
                            else {
                                Write-LogMessage "  Skipped (already exists)" -Level Warning -Category FileSystem
                            }
                        }
                        catch {
                            Write-LogMessage "  Failed to move: $_" -Level Error -Category FileSystem
                        }
                    }
                    else {
                        # WhatIf mode
                        $script:PlannedChanges += [PSCustomObject]@{
                            Type = 'File'
                            ShowTitle = $cleanSeriesName
                            Action = 'Move'
                            Source = $file.FullName
                            Destination = $destPath
                        }
                    }
                }
                
                $script:TotalSuccess++
                Write-LogMessage "Completed: $seriesName" -Level Success -Category Processing
                
                } # End foreach series
                
            }
            catch {
                Write-ErrorLog -Message "Failed to process folder: $folder" `
                    -ErrorRecord $_ `
                    -Category Processing `
                    -Context @{ FolderPath = $folder } `
                    -Source "Invoke-SourceFirstOrganize"
                
                $script:TotalFailed++
            }
        }
    }
    
    end {
        Write-LogMessage "========================================" -Level Info -Category Processing
        Write-LogMessage "Processing Complete" -Level Info -Category Processing
        Write-LogMessage "Success: $script:TotalSuccess | Failed: $script:TotalFailed" -Level Info -Category Processing
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

Export-ModuleMember -Function Invoke-SourceFirstOrganize