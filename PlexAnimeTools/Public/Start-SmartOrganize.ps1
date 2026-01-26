# =============================================================================
# Start-SmartOrganize.ps1
# Master intelligent organization function - handles ANY input automatically
# =============================================================================

function Start-SmartOrganize {
    <#
    .SYNOPSIS
        Intelligently organizes ANY media content for Plex automatically
    
    .DESCRIPTION
        The ultimate "just work" function. Drop in any folder/file and it:
        1. Detects what it is (anime/TV/movie/series)
        2. Finds metadata from APIs
        3. Detects season/episode numbers from filenames
        4. Organizes into proper Plex structure
        5. Renames everything correctly
        6. Downloads artwork
        
        Handles:
        - Single files or folders
        - Any naming convention
        - Mixed content (movies + series in same folder)
        - Nested structures
        - Fansub tags and quality markers
        - Multiple seasons
        - Series movies/specials
    
    .PARAMETER InputPath
        Path to ANYTHING - file, folder, nested structure, whatever
    
    .PARAMETER OutputPath
        Where to create the organized Plex library
    
    .PARAMETER WhatIf
        Preview what will happen without making changes
    
    .PARAMETER Force
        Skip confirmations
    
    .EXAMPLE
        Start-SmartOrganize -InputPath "D:\Downloads" -OutputPath "D:\Plex\Anime"
        
        Processes everything in Downloads and organizes for Plex
    
    .EXAMPLE
        Start-SmartOrganize -InputPath "D:\Downloads\[SubsPlease] Attack on Titan - 01.mkv" -OutputPath "D:\Plex\Anime" -WhatIf
        
        Preview organizing a single file
    
    .EXAMPLE
        Start-SmartOrganize -InputPath "D:\Random Anime Stuff" -OutputPath "D:\Plex\Anime"
        
        Handles messy folder with mixed content
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$InputPath,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [switch]$Force
    )
    
    begin {
        Write-LogMessage "========================================" -Level Info -Category Processing
        Write-LogMessage "Smart Organize - Universal Media Processor" -Level Info -Category Processing
        Write-LogMessage "========================================" -Level Info -Category Processing
        Write-LogMessage "Input: $InputPath" -Level Info -Category Processing
        Write-LogMessage "Output: $OutputPath" -Level Info -Category Processing
        
        $script:ProcessedItems = @()
        $script:TotalSuccess = 0
        $script:TotalFailed = 0
        $script:TotalSkipped = 0
    }
    
    process {
        try {
            # Step 1: Analyze what we're dealing with
            Write-LogMessage "Step 1: Analyzing input..." -Level Info -Category Processing
            $analysis = Get-SmartAnalysis -Path $InputPath
            
            Write-LogMessage "Input Type: $($analysis.Type)" -Level Info -Category Processing
            Write-LogMessage "Content Type: $($analysis.ContentType)" -Level Info -Category Processing
            Write-LogMessage "Items Found: $($analysis.Items.Count)" -Level Info -Category Processing
            
            # Step 2: Process based on what we found
            switch ($analysis.Type) {
                'SingleFile' {
                    Write-LogMessage "Processing single file..." -Level Info -Category Processing
                    Process-SingleFile -FileInfo $analysis.Items[0] -OutputPath $OutputPath -WhatIf:$WhatIfPreference
                }
                
                'SingleShow' {
                    Write-LogMessage "Processing single show folder..." -Level Info -Category Processing
                    Process-SingleShow -FolderInfo $analysis.Items[0] -OutputPath $OutputPath -WhatIf:$WhatIfPreference
                }
                
                'MultipleShows' {
                    Write-LogMessage "Processing multiple shows..." -Level Info -Category Processing
                    foreach ($show in $analysis.Items) {
                        Process-SingleShow -FolderInfo $show -OutputPath $OutputPath -WhatIf:$WhatIfPreference
                    }
                }
                
                'MixedContent' {
                    Write-LogMessage "Processing mixed content..." -Level Info -Category Processing
                    Process-MixedContent -Items $analysis.Items -OutputPath $OutputPath -WhatIf:$WhatIfPreference
                }
                
                'ComplexNested' {
                    Write-LogMessage "Processing complex nested structure..." -Level Info -Category Processing
                    Process-NestedStructure -Items $analysis.Items -OutputPath $OutputPath -WhatIf:$WhatIfPreference
                }
            }
            
            # Step 3: Report results
            Write-LogMessage "========================================" -Level Info -Category Processing
            Write-LogMessage "Processing Complete" -Level Success -Category Processing
            Write-LogMessage "Success: $script:TotalSuccess | Failed: $script:TotalFailed | Skipped: $script:TotalSkipped" -Level Info -Category Processing
            Write-LogMessage "========================================" -Level Info -Category Processing
            
        }
        catch {
            Write-ErrorLog -Message "Smart organize failed" `
                -ErrorRecord $_ `
                -Category Processing `
                -Context @{
                    InputPath = $InputPath
                    OutputPath = $OutputPath
                } `
                -Source "Start-SmartOrganize"
        }
    }
}

function Get-SmartAnalysis {
    <#
    .SYNOPSIS
        Analyzes input and determines what type of content it is
    
    .DESCRIPTION
        Intelligently figures out:
        - Is it a file or folder?
        - Single show or multiple shows?
        - Mixed content (movies + series)?
        - How deeply nested is it?
        - What content type (anime/TV/cartoon/movie)?
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        throw "Path not found: $Path"
    }
    
    $item = Get-Item $Path
    
    # Single file?
    if (-not $item.PSIsContainer) {
        return @{
            Type = 'SingleFile'
            ContentType = 'Unknown'
            Items = @(@{
                File = $item
                Path = $item.FullName
                Name = $item.BaseName
            })
        }
    }
    
    # It's a folder - analyze structure
    Write-LogMessage "Analyzing folder structure..." -Level Info -Category Processing
    
    # Get all video files
    $allVideos = Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue | 
        Where-Object { $script:VideoExtensions -contains $_.Extension.ToLower() }
    
    if ($allVideos.Count -eq 0) {
        throw "No video files found in: $Path"
    }
    
    Write-LogMessage "Found $($allVideos.Count) video file(s)" -Level Info -Category Processing
    
    # Get immediate subfolders
    $subfolders = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
    
    # Detect structure type
    $structure = Get-FolderStructureType -FolderPath $Path
    
    # Single show with proper structure?
    if ($structure.SeasonFolders.Count -gt 0 -or $structure.Type -eq 'FlatSeries') {
        return @{
            Type = 'SingleShow'
            ContentType = (Test-ContentType -FolderPath $Path)
            Items = @(@{
                Folder = $item
                Path = $item.FullName
                Name = $item.Name
                Structure = $structure
            })
        }
    }
    
    # Check if each subfolder is a potential show
    $showFolders = @()
    foreach ($subfolder in $subfolders) {
        $subVideos = Get-ChildItem -Path $subfolder.FullName -File -Recurse -ErrorAction SilentlyContinue | 
            Where-Object { $script:VideoExtensions -contains $_.Extension.ToLower() }
        
        if ($subVideos.Count -gt 0) {
            $subStructure = Get-FolderStructureType -FolderPath $subfolder.FullName
            $showFolders += @{
                Folder = $subfolder
                Path = $subfolder.FullName
                Name = $subfolder.Name
                Structure = $subStructure
                VideoCount = $subVideos.Count
            }
        }
    }
    
    # Multiple distinct shows?
    if ($showFolders.Count -gt 1) {
        return @{
            Type = 'MultipleShows'
            ContentType = 'Mixed'
            Items = $showFolders
        }
    }
    
    # Check for mixed files in root
    $rootVideos = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue | 
        Where-Object { $script:VideoExtensions -contains $_.Extension.ToLower() }
    
    if ($rootVideos.Count -gt 0 -and $showFolders.Count -gt 0) {
        return @{
            Type = 'MixedContent'
            ContentType = 'Mixed'
            Items = @{
                RootFiles = $rootVideos
                Folders = $showFolders
            }
        }
    }
    
    # Complex nested structure
    if ($subfolders.Count -gt 5 -or $allVideos.Count -gt 100) {
        return @{
            Type = 'ComplexNested'
            ContentType = 'Mixed'
            Items = @{
                AllVideos = $allVideos
                Subfolders = $subfolders
                RootPath = $Path
            }
        }
    }
    
    # Default: treat as single show
    return @{
        Type = 'SingleShow'
        ContentType = (Test-ContentType -FolderPath $Path)
        Items = @(@{
            Folder = $item
            Path = $item.FullName
            Name = $item.Name
            Structure = $structure
        })
    }
}

function Process-SingleFile {
    <#
    .SYNOPSIS
        Processes a single video file
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$FileInfo,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    Write-LogMessage "Processing single file: $($FileInfo.Name)" -Level Info -Category Processing
    
    # Extract show name from filename
    $fileName = $FileInfo.Name
    $cleanName = Clean-SearchQuery -Query $fileName
    
    # Detect episode/season numbers
    $episodeNum = Get-EpisodeNumber -FileName $fileName
    $seasonNum = Get-SeasonNumber -Name $fileName
    
    Write-LogMessage "Detected - Show: $cleanName, Season: $seasonNum, Episode: $episodeNum" -Level Info -Category Processing
    
    # Search for show
    $contentType = Test-ContentType -FolderPath (Split-Path $FileInfo.Path -Parent)
    
    if ($contentType -eq 'Anime') {
        $results = Search-JikanAPI -Query $cleanName
    }
    else {
        $type = if ($episodeNum -gt 0) { 'tv' } else { 'movie' }
        $results = Search-TMDbAPI -Query $cleanName -Type $type
    }
    
    if (-not $results) {
        Write-LogMessage "No API results found for: $cleanName" -Level Warning -Category API
        $script:TotalSkipped++
        return
    }
    
    # Use first result
    $selected = $results[0]
    
    if ($contentType -eq 'Anime') {
        $title = if ($selected.title_english) { $selected.title_english } else { $selected.title }
    }
    else {
        $title = if ($selected.name) { $selected.name } else { $selected.title }
    }
    
    $title = Remove-InvalidFileNameChars -Name $title
    
    # Create structure
    $showPath = Join-Path $OutputPath $title
    
    if ($episodeNum -gt 0) {
        # Episode - create season folder
        $seasonPath = Join-Path $showPath "Season $($seasonNum.ToString('D2'))"
        
        if ($PSCmdlet.ShouldProcess($seasonPath, "Create season folder")) {
            New-Item -Path $seasonPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        
        # Format filename
        $newName = Format-PlexFileName -Title $title -Season $seasonNum -Episode $episodeNum -Extension $FileInfo.File.Extension -Type 'Episode'
        $destPath = Join-Path $seasonPath $newName
    }
    else {
        # Movie
        if ($PSCmdlet.ShouldProcess($showPath, "Create movie folder")) {
            New-Item -Path $showPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        
        $newName = Format-PlexFileName -Title $title -Extension $FileInfo.File.Extension -Type 'Movie'
        $destPath = Join-Path $showPath $newName
    }
    
    # Move file
    if ($PSCmdlet.ShouldProcess($FileInfo.Path, "Move to $destPath")) {
        Move-MediaFile -SourcePath $FileInfo.Path -DestinationPath $destPath
        $script:TotalSuccess++
    }
}

function Process-SingleShow {
    <#
    .SYNOPSIS
        Processes a folder containing a single show
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$FolderInfo,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    Write-LogMessage "Processing show folder: $($FolderInfo.Name)" -Level Info -Category Processing
    
    # Use existing Invoke-AnimeOrganize function
    try {
        if ($PSCmdlet.ShouldProcess($FolderInfo.Path, "Organize for Plex")) {
            $result = Invoke-AnimeOrganize -Path $FolderInfo.Path -OutputPath $OutputPath
            
            if ($result.Success -gt 0) {
                $script:TotalSuccess += $result.Success
            }
            if ($result.Failed -gt 0) {
                $script:TotalFailed += $result.Failed
            }
            if ($result.Skipped -gt 0) {
                $script:TotalSkipped += $result.Skipped
            }
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to process show folder" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                FolderPath = $FolderInfo.Path
                FolderName = $FolderInfo.Name
            } `
            -Source "Process-SingleShow"
        
        $script:TotalFailed++
    }
}

function Process-MixedContent {
    <#
    .SYNOPSIS
        Processes folder with mixed files and subfolders
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Items,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    Write-LogMessage "Processing mixed content..." -Level Info -Category Processing
    
    # Process root files first
    if ($Items.RootFiles) {
        Write-LogMessage "Processing $($Items.RootFiles.Count) root file(s)" -Level Info -Category Processing
        
        foreach ($file in $Items.RootFiles) {
            $fileInfo = @{
                File = $file
                Path = $file.FullName
                Name = $file.BaseName
            }
            
            Process-SingleFile -FileInfo $fileInfo -OutputPath $OutputPath -WhatIf:$WhatIfPreference
        }
    }
    
    # Then process subfolders
    if ($Items.Folders) {
        Write-LogMessage "Processing $($Items.Folders.Count) subfolder(s)" -Level Info -Category Processing
        
        foreach ($folder in $Items.Folders) {
            Process-SingleShow -FolderInfo $folder -OutputPath $OutputPath -WhatIf:$WhatIfPreference
        }
    }
}

function Process-NestedStructure {
    <#
    .SYNOPSIS
        Processes complex nested structures intelligently
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Items,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    Write-LogMessage "Processing complex nested structure..." -Level Info -Category Processing
    Write-LogMessage "This may take a while..." -Level Info -Category Processing
    
    # Group files by likely show
    $grouped = Group-FilesByShow -Files $Items.AllVideos
    
    Write-LogMessage "Identified $($grouped.Count) potential show(s)" -Level Info -Category Processing
    
    foreach ($group in $grouped) {
        Write-LogMessage "Processing group: $($group.ShowName) ($($group.Files.Count) files)" -Level Info -Category Processing
        
        # Create temporary structure for this group
        $tempPath = Join-Path $env:TEMP "PlexAnimeTools_Temp_$([Guid]::NewGuid())"
        $tempShowPath = Join-Path $tempPath $group.ShowName
        
        try {
            New-Item -Path $tempShowPath -ItemType Directory -Force | Out-Null
            
            # Copy files to temp structure
            foreach ($file in $group.Files) {
                Copy-Item -Path $file.FullName -Destination $tempShowPath -Force
            }
            
            # Process the temp folder
            Process-SingleShow -FolderInfo @{
                Folder = Get-Item $tempShowPath
                Path = $tempShowPath
                Name = $group.ShowName
            } -OutputPath $OutputPath -WhatIf:$WhatIfPreference
            
            # Clean up temp
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-ErrorLog -Message "Failed to process grouped files" `
                -ErrorRecord $_ `
                -Category Processing `
                -Context @{
                    ShowName = $group.ShowName
                    FileCount = $group.Files.Count
                } `
                -Source "Process-NestedStructure"
            
            $script:TotalFailed++
        }
    }
}

function Group-FilesByShow {
    <#
    .SYNOPSIS
        Groups video files by likely show name
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Files
    )
    
    $groups = @{}
    
    foreach ($file in $Files) {
        # Extract show name from filename
        $fileName = $file.BaseName
        
        # Remove episode numbers
        $showName = $fileName -replace '[-\s]+\d{1,4}[-\s]*', ''
        
        # Remove quality tags
        $showName = $showName -replace '\[.*?\]', ''
        $showName = $showName -replace '\b(1080p|720p|480p|2160p|4K|x264|x265|HEVC)\b', ''
        
        # Clean up
        $showName = $showName.Trim()
        
        if (-not $groups.ContainsKey($showName)) {
            $groups[$showName] = @()
        }
        
        $groups[$showName] += $file
    }
    
    # Convert to array of objects
    $result = @()
    foreach ($name in $groups.Keys) {
        $result += @{
            ShowName = $name
            Files = $groups[$name]
        }
    }
    
    return $result
}

Export-ModuleMember -Function Start-SmartOrganize
