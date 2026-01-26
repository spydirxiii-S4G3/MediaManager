# =============================================================================
# Start-AutoOrganize - FileBot Style Auto-Organization
# Just point it at media and it figures everything out
# Save as: Public/Start-AutoOrganize.ps1
# =============================================================================

function Start-AutoOrganize {
    <#
    .SYNOPSIS
        FileBot-style automatic media organization - just works!
    
    .DESCRIPTION
        Point at any media folder and it:
        - Auto-detects content type (anime/TV/movie)
        - Searches MAL/Jikan/TMDb automatically
        - Extracts all metadata from filenames
        - Organizes into perfect Plex structure
        - Renames with episode titles
        - No manual intervention needed
    
    .PARAMETER InputPath
        Path to media folder (or file)
    
    .PARAMETER OutputPath
        Plex library destination
    
    .PARAMETER Library
        Library type: Auto (default), Anime, TV, Movies
    
    .PARAMETER Action
        Move (default), Copy, Hardlink, Test
    
    .EXAMPLE
        Start-AutoOrganize -InputPath "D:\Downloads" -OutputPath "D:\Plex\Anime"
        
        Automatically organizes everything in Downloads to Plex
    
    .EXAMPLE
        Start-AutoOrganize "D:\Downloads\Pokemon Advanced" "D:\Plex\Anime" -Action Test
        
        Preview what will happen (like FileBot's test mode)
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$InputPath,
        
        [Parameter(Mandatory, Position = 1)]
        [string]$OutputPath,
        
        [Parameter(Position = 2)]
        [ValidateSet('Auto', 'Anime', 'TV', 'Movies')]
        [string]$Library = 'Auto',
        
        [Parameter(Position = 3)]
        [ValidateSet('Move', 'Copy', 'Hardlink', 'Test')]
        [string]$Action = 'Move',
        
        [switch]$Recursive
    )
    
    # FileBot style: Test mode = WhatIf
    if ($Action -eq 'Test') {
        $WhatIfPreference = $true
    }
    
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         PlexAnimeTools - FileBot Style Auto-Organize       ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Validate paths
    if (-not (Test-Path $InputPath)) {
        Write-Host "✗ Input path not found: $InputPath" -ForegroundColor Red
        return
    }
    
    if (-not (Test-Path $OutputPath)) {
        Write-Host "⚠ Creating output directory: $OutputPath" -ForegroundColor Yellow
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    Write-Host "📂 Input:  $InputPath" -ForegroundColor White
    Write-Host "📂 Output: $OutputPath" -ForegroundColor White
    Write-Host "📚 Library: $Library" -ForegroundColor White
    Write-Host "⚡ Action: $Action" -ForegroundColor White
    Write-Host ""
    
    # Get all media files
    $allFiles = @()
    
    if ((Get-Item $InputPath).PSIsContainer) {
        if ($Recursive) {
            Write-Host "🔍 Scanning recursively..." -ForegroundColor Cyan
            $folders = Get-ChildItem -Path $InputPath -Directory -Recurse
            $folders = @($InputPath) + $folders.FullName
        }
        else {
            $folders = @(Get-ChildItem -Path $InputPath -Directory | Select-Object -ExpandProperty FullName)
            if ($folders.Count -eq 0) {
                $folders = @($InputPath)
            }
        }
    }
    else {
        # Single file
        $folders = @(Split-Path $InputPath -Parent)
    }
    
    Write-Host "📊 Found $($folders.Count) folder(s) to process" -ForegroundColor Green
    Write-Host ""
    
    $processedCount = 0
    $successCount = 0
    $failedCount = 0
    
    foreach ($folderPath in $folders) {
        $processedCount++
        $folderName = Split-Path $folderPath -Leaf
        
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "[$processedCount/$($folders.Count)] Processing: $folderName" -ForegroundColor Cyan
        Write-Host ""
        
        # Get video files
        $files = Get-VideoFiles -Path $folderPath
        if ($files.Count -eq 0) {
            Write-Host "  ⊘ No video files found, skipping" -ForegroundColor DarkGray
            continue
        }
        
        Write-Host "  📹 Found $($files.Count) video file(s)" -ForegroundColor White
        
        # STEP 1: Auto-detect content
        Write-Host "  🔎 Detecting content type..." -ForegroundColor Yellow
        
        $contentType = if ($Library -ne 'Auto') { 
            $Library 
        } else { 
            Detect-MediaType -FolderPath $folderPath -Files $files 
        }
        
        Write-Host "  ✓ Detected: $contentType" -ForegroundColor Green
        
        # STEP 2: Extract metadata from source files
        Write-Host "  📊 Analyzing file metadata..." -ForegroundColor Yellow
        $metadata = Get-FileMetadata -Files $files -FolderName $folderName
        
        if ($metadata.HasSeasonMarkers) {
            Write-Host "  ✓ Found season/episode markers in filenames" -ForegroundColor Green
        }
        
        Write-Host "  ✓ Episode range: $($metadata.EpisodeRange.Min)-$($metadata.EpisodeRange.Max)" -ForegroundColor Green
        
        # STEP 3: Search for series info
        Write-Host "  🌐 Searching online databases..." -ForegroundColor Yellow
        
        # Check for existing series first
        $existingSeries = Find-ExistingSeries -FolderName $folderName -OutputPath $OutputPath
        
        if ($existingSeries) {
            Write-Host "  ✓ Found existing series: $($existingSeries.Name)" -ForegroundColor Green
            $seriesTitle = $existingSeries.Name
            $seriesPath = $existingSeries.FullName
            $seasonNum = $metadata.PrimarySeason
            $episodes = @()
            
            # Get episode titles
            $cleanName = Clean-SearchQuery -Query $seriesTitle
            if ($contentType -eq 'Anime') {
                $results = Search-JikanAPI -Query $cleanName
                if ($results) {
                    $episodes = Get-JikanEpisodes -MalId $results[0].mal_id
                }
            }
        }
        else {
            # Search APIs
            $cleanName = Clean-SearchQuery -Query $folderName
            
            if ($contentType -eq 'Anime') {
                $results = Search-JikanAPI -Query $cleanName
                if ($results) {
                    $seriesTitle = if ($results[0].title_english) { 
                        $results[0].title_english 
                    } else { 
                        $results[0].title 
                    }
                    $episodes = Get-JikanEpisodes -MalId $results[0].mal_id
                    Write-Host "  ✓ Found: $seriesTitle (MAL)" -ForegroundColor Green
                }
            }
            else {
                $type = if ($metadata.IsMovie) { 'movie' } else { 'tv' }
                $results = Search-TMDbAPI -Query $cleanName -Type $type
                if ($results) {
                    $seriesTitle = if ($results[0].name) { $results[0].name } else { $results[0].title }
                    Write-Host "  ✓ Found: $seriesTitle (TMDb)" -ForegroundColor Green
                }
            }
            
            if (-not $results) {
                Write-Host "  ✗ Not found in databases, using folder name" -ForegroundColor Red
                $failedCount++
                continue
            }
            
            $seriesTitle = Remove-InvalidFileNameChars -Name $seriesTitle
            $seasonNum = $metadata.PrimarySeason
        }
        
        # STEP 4: Create folder structure
        Write-Host "  📁 Creating folder structure..." -ForegroundColor Yellow
        
        if (-not $existingSeries) {
            $seriesPath = Join-Path $OutputPath $seriesTitle
            if ($PSCmdlet.ShouldProcess($seriesPath, "Create series folder")) {
                if (-not (Test-Path $seriesPath)) {
                    New-Item -Path $seriesPath -ItemType Directory -Force | Out-Null
                }
            }
        }
        
        $seasonPath = Join-Path $seriesPath "Season $($seasonNum.ToString('D2'))"
        if ($PSCmdlet.ShouldProcess($seasonPath, "Create season folder")) {
            if (-not (Test-Path $seasonPath)) {
                New-Item -Path $seasonPath -ItemType Directory -Force | Out-Null
            }
        }
        
        Write-Host "  ✓ $seriesTitle/Season $($seasonNum.ToString('D2'))" -ForegroundColor Green
        
        # STEP 5: Rename and move files
        Write-Host "  📝 Organizing files..." -ForegroundColor Yellow
        
        $fileCount = 0
        foreach ($fileInfo in $metadata.Files) {
            $fileCount++
            $file = $fileInfo.File
            $epNum = $fileInfo.EpisodeNumber
            
            # Get episode title if available
            $epTitle = ''
            if ($episodes) {
                $epData = $episodes | Where-Object { $_.mal_id -eq $epNum } | Select-Object -First 1
                if ($epData -and $epData.title) {
                    $epTitle = $epData.title
                }
            }
            
            # Format new filename
            $newName = Format-PlexFileName `
                -Title $seriesTitle `
                -Season $seasonNum `
                -Episode $epNum `
                -EpisodeTitle $epTitle `
                -Extension $file.Extension `
                -Type 'Episode'
            
            $destPath = Join-Path $seasonPath $newName
            
            # Perform action
            if ($PSCmdlet.ShouldProcess($file.FullName, "$Action to $destPath")) {
                switch ($Action) {
                    'Move' { 
                        Move-Item -Path $file.FullName -Destination $destPath -Force
                        Write-Host "    ✓ [$fileCount/$($metadata.Files.Count)] Moved: $newName" -ForegroundColor Green
                    }
                    'Copy' { 
                        Copy-Item -Path $file.FullName -Destination $destPath -Force
                        Write-Host "    ✓ [$fileCount/$($metadata.Files.Count)] Copied: $newName" -ForegroundColor Green
                    }
                    'Hardlink' {
                        # Create hardlink (Windows only)
                        $null = New-Item -ItemType HardLink -Path $destPath -Target $file.FullName -Force
                        Write-Host "    ✓ [$fileCount/$($metadata.Files.Count)] Linked: $newName" -ForegroundColor Green
                    }
                    'Test' {
                        Write-Host "    ⊕ [$fileCount/$($metadata.Files.Count)] Would move: $newName" -ForegroundColor Cyan
                    }
                }
            }
        }
        
        $successCount++
        Write-Host ""
    }
    
    # Summary
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                     SUMMARY                                ║" -ForegroundColor Green
    Write-Host "╠════════════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║  Total Processed: $($processedCount.ToString().PadLeft(3))                                      ║" -ForegroundColor Green
    Write-Host "║  Successful:      $($successCount.ToString().PadLeft(3))                                      ║" -ForegroundColor Green
    Write-Host "║  Failed:          $($failedCount.ToString().PadLeft(3))                                      ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    if ($Action -eq 'Test') {
        Write-Host "💡 This was a test run. Use -Action Move to execute." -ForegroundColor Cyan
    }
    
    Write-Host "📋 Log file: $script:LogFile" -ForegroundColor DarkGray
    Write-Host ""
}

# =============================================================================
# Helper Functions for FileBot-style operation
# =============================================================================

function Detect-MediaType {
    param($FolderPath, $Files)
    
    $folderName = Split-Path $FolderPath -Leaf
    
    # Check for anime indicators
    $animeKeywords = @('anime', 'season', 'ova', 'ona', '\[.*?\]', 'BD', 'BluRay')
    foreach ($keyword in $animeKeywords) {
        if ($folderName -match $keyword) { return 'Anime' }
    }
    
    # Check files for anime groups
    foreach ($file in $Files) {
        if ($file.Name -match '\[(SubsPlease|HorribleSubs|Erai-raws|Commie|GJM)\]') {
            return 'Anime'
        }
    }
    
    # Check for movie
    if ($Files.Count -eq 1 -or $folderName -match '\bmovie\b|\bfilm\b') {
        return 'Movies'
    }
    
    # Default to TV
    return 'TV'
}

function Get-FileMetadata {
    param($Files, $FolderName)
    
    $metadata = @{
        Files = @()
        HasSeasonMarkers = $false
        EpisodeRange = @{ Min = 999; Max = 0 }
        PrimarySeason = 1
        IsMovie = $false
    }
    
    foreach ($file in $Files) {
        $fileName = $file.Name
        
        $fileInfo = @{
            File = $file
            EpisodeNumber = 1
            SeasonNumber = 1
        }
        
        # Extract season/episode
        if ($fileName -match 'S0*(\d+)E0*(\d+)') {
            $fileInfo.SeasonNumber = [int]$Matches[1]
            $fileInfo.EpisodeNumber = [int]$Matches[2]
            $metadata.HasSeasonMarkers = $true
        }
        elseif ($fileName -match '(?:E|Episode|Ep)\s*0*(\d+)') {
            $fileInfo.EpisodeNumber = [int]$Matches[1]
        }
        elseif ($fileName -match '\s-\s0*(\d+)[\s\.]') {
            $fileInfo.EpisodeNumber = [int]$Matches[1]
        }
        
        # Track episode range
        $ep = $fileInfo.EpisodeNumber
        if ($ep -lt $metadata.EpisodeRange.Min) { $metadata.EpisodeRange.Min = $ep }
        if ($ep -gt $metadata.EpisodeRange.Max) { $metadata.EpisodeRange.Max = $ep }
        
        $metadata.Files += $fileInfo
    }
    
    # Pokemon-specific season detection
    if ($FolderName -match 'Pokemon.*Advanced' -and -not $metadata.HasSeasonMarkers) {
        $epMax = $metadata.EpisodeRange.Max
        if ($epMax -le 40) { $metadata.PrimarySeason = 6 }
        elseif ($epMax -le 92) { $metadata.PrimarySeason = 7 }
        elseif ($epMax -le 146) { $metadata.PrimarySeason = 8 }
        elseif ($epMax -le 193) { $metadata.PrimarySeason = 9 }
    }
    elseif ($metadata.HasSeasonMarkers) {
        # Use most common season
        $seasonCounts = $metadata.Files | Group-Object SeasonNumber | Sort-Object Count -Descending
        $metadata.PrimarySeason = $seasonCounts[0].Name
    }
    elseif ($FolderName -match 'Season\s*0*(\d+)') {
        $metadata.PrimarySeason = [int]$Matches[1]
    }
    
    # Check if movie
    if ($Files.Count -eq 1) {
        $metadata.IsMovie = $true
    }
    
    return $metadata
}

function Find-ExistingSeries {
    param($FolderName, $OutputPath)
    
    $existingFolders = Get-ChildItem -Path $OutputPath -Directory -ErrorAction SilentlyContinue
    if (-not $existingFolders) { return $null }
    
    # Check for franchise match
    $franchises = @{
        'Pokemon' = 'Pokemon|Pokémon'
        'Naruto' = 'Naruto'
        'Dragon Ball' = 'Dragon\s*Ball'
        'One Piece' = 'One\s*Piece'
    }
    
    foreach ($franchise in $franchises.Keys) {
        if ($FolderName -match $franchises[$franchise]) {
            $match = $existingFolders | Where-Object { $_.Name -match $franchises[$franchise] } | Select-Object -First 1
            if ($match) { return $match }
        }
    }
    
    # Fuzzy match
    $cleanFolder = $FolderName -replace 'Season\s+\d+', '' -replace '[^\w\s]', '' -replace '\s+', ' '
    $cleanFolder = $cleanFolder.Trim().ToLower()
    
    foreach ($existing in $existingFolders) {
        $cleanExisting = $existing.Name -replace '[^\w\s]', '' -replace '\s+', ' '
        $cleanExisting = $cleanExisting.Trim().ToLower()
        
        if ($cleanFolder.Contains($cleanExisting) -or $cleanExisting.Contains($cleanFolder)) {
            return $existing
        }
    }
    
    return $null
}

Export-ModuleMember -Function Start-AutoOrganize
