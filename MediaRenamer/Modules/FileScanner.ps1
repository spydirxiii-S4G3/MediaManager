# ===============================================================================
# FileScanner.ps1 - Scan Folders, Filter Extensions, Retrieve File Metadata
# ===============================================================================

$script:DefaultVideoExtensions = @(".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".ts", ".mpg", ".mpeg")

function Get-MediaFiles {
    param(
        [string]$FolderPath,
        [string[]]$Extensions = $script:DefaultVideoExtensions,
        [bool]$IncludeSubfolders = $false,
        [long]$MinFileSizeBytes = 0,
        [bool]$SkipHidden = $false
    )

    if (-not (Test-Path $FolderPath)) { return @() }

    $searchOption = if ($IncludeSubfolders) { "AllDirectories" } else { "TopDirectoryOnly" }

    $files = Get-ChildItem -Path $FolderPath -File -Recurse:$IncludeSubfolders -ErrorAction SilentlyContinue |
        Where-Object {
            $ext = $_.Extension.ToLower()
            $extMatch = $Extensions -contains $ext
            $sizeMatch = $_.Length -ge $MinFileSizeBytes
            $hiddenMatch = if ($SkipHidden) { -not $_.Attributes.HasFlag([System.IO.FileAttributes]::Hidden) } else { $true }
            $extMatch -and $sizeMatch -and $hiddenMatch
        }

    $results = @()
    foreach ($file in $files) {
        $duration = Get-VideoDuration -FilePath $file.FullName
        $results += [PSCustomObject]@{
            FullPath       = $file.FullName
            Directory      = $file.DirectoryName
            OriginalName   = $file.Name
            BaseName       = $file.BaseName
            Extension      = $file.Extension
            FileSize       = $file.Length
            FileSizeText   = Format-FileSize -Bytes $file.Length
            Duration       = $duration
            DurationText   = Format-Duration -Seconds $duration
            DateModified   = $file.LastWriteTime
            DateCreated    = $file.CreationTime
            SubFolder      = if ($IncludeSubfolders) { 
                                $rel = $file.DirectoryName.Replace($FolderPath, "").TrimStart("\")
                                if ($rel -eq "") { "(root)" } else { $rel }
                             } else { "" }
            NewName        = ""
            EpisodeNumber  = 0
            EpisodeTitle   = ""
            Status         = "Pending"
            Excluded       = $false
            IsDuplicate    = $false
            MatchesPattern = $false
        }
    }

    return $results
}

function Get-VideoDuration {
    param([string]$FilePath)
    try {
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace((Split-Path $FilePath))
        $file = $folder.ParseName((Split-Path $FilePath -Leaf))
        # Property 27 = Duration in "HH:MM:SS" format
        $durationStr = $folder.GetDetailsOf($file, 27)
        if ($durationStr -match "(\d+):(\d+):(\d+)") {
            return ([int]$Matches[1] * 3600) + ([int]$Matches[2] * 60) + [int]$Matches[3]
        }
        return 0
    } catch {
        return 0
    }
}

function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N0} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Format-Duration {
    param([int]$Seconds)
    if ($Seconds -le 0) { return "-" }
    $h = [int][math]::Floor($Seconds / 3600)
    $m = [int][math]::Floor(($Seconds % 3600) / 60)
    $s = [int]($Seconds % 60)
    if ($h -gt 0) {
        return "{0}:{1:D2}:{2:D2}" -f $h, $m, $s
    }
    return "{0}:{1:D2}" -f $m, $s
}

function Get-NaturalSortKey {
    param([string]$Name)
    # Pad all number sequences to 10 digits for proper numeric sorting
    # "S01E100" -> "S0000000001E0000000100"
    return [regex]::Replace($Name, '\d+', { param($m) $m.Value.PadLeft(10, '0') })
}

function Sort-MediaFiles {
    param(
        [array]$Files,
        [string]$SortBy = "Name", # Name, DateModified, DateCreated, Size, Duration
        [bool]$Descending = $false
    )

    if ($SortBy -eq "Name" -or $SortBy -eq "") {
        # Natural sort: numeric-aware so E10 < E100
        if ($Descending) {
            $sorted = $Files | Sort-Object -Property { Get-NaturalSortKey $_.OriginalName } -Descending
        } else {
            $sorted = $Files | Sort-Object -Property { Get-NaturalSortKey $_.OriginalName }
        }
    } else {
        $prop = switch ($SortBy) {
            "Date Modified" { "DateModified" }
            "Date Created"  { "DateCreated" }
            "Size"          { "FileSize" }
            "Duration"      { "Duration" }
            default         { "OriginalName" }
        }
        if ($Descending) {
            $sorted = $Files | Sort-Object -Property $prop -Descending
        } else {
            $sorted = $Files | Sort-Object -Property $prop
        }
    }
    return @($sorted)
}

function Get-SeasonFromFolder {
    param([string]$FolderPath)
    $folderName = Split-Path $FolderPath -Leaf
    if ($folderName -match '[Ss](?:eason)?\s*(\d+)') {
        return [int]$Matches[1]
    }
    if ($folderName -match '(\d+)') {
        return [int]$Matches[1]
    }
    return 1
}

function Get-ShowNameFromFolder {
    param([string]$FolderPath)
    # Try parent folder (assumes structure: ShowName/Season X/)
    $parentName = Split-Path (Split-Path $FolderPath -Parent) -Leaf
    $currentName = Split-Path $FolderPath -Leaf

    # If current folder looks like a season folder, use parent
    if ($currentName -match '^[Ss](?:eason)?\s*\d+$') {
        return $parentName
    }
    return $currentName
}

function Find-DuplicatesBySize {
    param([array]$Files)
    $groups = $Files | Group-Object FileSize | Where-Object { $_.Count -gt 1 }
    $dupPaths = @()
    foreach ($group in $groups) {
        foreach ($file in $group.Group) {
            $dupPaths += $file.FullPath
        }
    }
    return $dupPaths
}

function Get-SeasonFolders {
    param(
        [string]$ShowFolderPath,
        [string[]]$Extensions = $script:DefaultVideoExtensions
    )
    if (-not (Test-Path $ShowFolderPath)) { return @() }

    $results = @()

    # Check for media files directly in root
    $rootFiles = Get-ChildItem -Path $ShowFolderPath -File -ErrorAction SilentlyContinue |
        Where-Object { $Extensions -contains $_.Extension.ToLower() }
    if ($rootFiles.Count -gt 0) {
        $results += [PSCustomObject]@{
            FolderName  = "(Root)"
            FolderPath  = $ShowFolderPath
            SeasonNum   = 0
            FileCount   = $rootFiles.Count
            IsRoot      = $true
        }
    }

    # Scan all subfolders
    $subDirs = Get-ChildItem -Path $ShowFolderPath -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name
    foreach ($dir in $subDirs) {
        $fileCount = (Get-ChildItem -Path $dir.FullName -File -ErrorAction SilentlyContinue |
            Where-Object { $Extensions -contains $_.Extension.ToLower() }).Count

        $seasonNum = 0
        if ($dir.Name -match '[Ss](?:eason)?\s*(\d+)') {
            $seasonNum = [int]$Matches[1]
        } elseif ($dir.Name -match '^(\d+)$') {
            $seasonNum = [int]$Matches[1]
        }

        $results += [PSCustomObject]@{
            FolderName  = $dir.Name
            FolderPath  = $dir.FullName
            SeasonNum   = $seasonNum
            FileCount   = $fileCount
            IsRoot      = $false
        }
    }

    return $results
}

# ===============================================================================
# ORGANIZE: Parse & Group Random Files by Show
# ===============================================================================

function Normalize-ShowName {
    param([string]$Name)
    $n = $Name.ToLower()
    $n = $n -replace '[\._\-\(\)\[\]\{\}]', ' '
    $n = $n -replace '\s+', ' '
    $n = $n.Trim()
    return $n
}

function Group-MediaFilesByShow {
    param(
        [string]$FolderPath,
        [string[]]$Extensions = @(".mp4", ".avi", ".mkv", ".mov", ".ts", ".wmv", ".flv", ".webm")
    )

    # Scan ALL files recursively
    $allFiles = Get-ChildItem -Path $FolderPath -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $Extensions -contains $_.Extension.ToLower() }

    $results = @()
    foreach ($file in $allFiles) {
        $parsed = Parse-ExistingFileName -FileName $file.Name
        $showName = if ($parsed.ShowName) { $parsed.ShowName } else { "Unknown" }
        $showName = Clean-FileName -Name $showName
        if ([string]::IsNullOrWhiteSpace($showName)) { $showName = "Unknown" }

        $detectedSeason = $parsed.Season

        # If no season detected from filename, try to get it from the parent folder name
        if ($detectedSeason -eq 0) {
            $parentFolder = Split-Path $file.FullName -Parent
            $parentName = Split-Path $parentFolder -Leaf
            # Check if parent folder is a season folder (e.g. "Season 01", "S01", "Season01")
            if ($parentName -match '[Ss](?:eason\s*)?0*(\d+)') {
                $detectedSeason = [int]$Matches[1]
            }
        }

        # If show name is "Unknown" or very short, try parent/grandparent folder
        if ($showName -eq "Unknown" -or $showName.Length -le 2) {
            $parentFolder = Split-Path $file.FullName -Parent
            $parentName = Split-Path $parentFolder -Leaf
            # If parent is a season folder, use grandparent as show name
            if ($parentName -match '^[Ss](?:eason)?\s*\d+') {
                $grandParent = Split-Path $parentFolder -Parent
                if ($grandParent -ne $FolderPath) {
                    $showName = Split-Path $grandParent -Leaf
                }
            } elseif ($parentFolder -ne $FolderPath) {
                # Parent is probably the show folder
                $showName = $parentName
            }
            $showName = Clean-FileName -Name $showName
            if ([string]::IsNullOrWhiteSpace($showName)) { $showName = "Unknown" }
        }

        # Default season to 1 only if no season info was found anywhere
        # Keep season 0 if filename explicitly contains S00/Season 00 (specials)
        if ($detectedSeason -eq 0) {
            $hasExplicitS00 = $file.Name -match '[Ss]0{1,2}[Ee]' -or $file.Name -match '[Ss]eason\s*0{1,2}[^1-9]'
            if (-not $hasExplicitS00) { $detectedSeason = 1 }
        }

        $results += [PSCustomObject]@{
            FullPath        = $file.FullName
            OriginalName    = $file.Name
            Extension       = $file.Extension
            FileSize        = $file.Length
            FileSizeText    = if ($file.Length -ge 1GB) { "{0:N2} GB" -f ($file.Length / 1GB) } elseif ($file.Length -ge 1MB) { "{0:N1} MB" -f ($file.Length / 1MB) } else { "{0:N0} KB" -f ($file.Length / 1KB) }
            DetectedShow    = $showName
            DetectedSeason  = $detectedSeason
            DetectedEpisode = $parsed.Episode
            ParsedOk        = $parsed.ParsedOk
            NormalizedShow  = Normalize-ShowName -Name $showName
            TargetPath      = ""
            NewName         = ""
            Status          = if ($parsed.ParsedOk) { "Detected" } else { "Needs Review" }
            Excluded        = $false
        }
    }

    # Fuzzy group: merge show names that normalize to the same string
    $groups = @{}
    foreach ($r in $results) {
        $key = $r.NormalizedShow
        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = $r.DetectedShow
        }
        $r.DetectedShow = $groups[$key]
    }

    return @($results | Sort-Object DetectedShow, DetectedSeason, DetectedEpisode)
}

function Build-OrganizePaths {
    param(
        [array]$Files,
        [string]$DestinationRoot,
        [string]$Template = "{show} - S{season}E{episode}",
        [bool]$PlexNaming = $false,
        [string]$PlexShowName = "",
        [string]$PlexYear = "",
        [string]$PlexId = "",
        [string]$PlexSource = ""
    )

    foreach ($f in $Files) {
        if ($f.Excluded) { continue }
        $show = $f.DetectedShow
        $season = $f.DetectedSeason
        $episode = $f.DetectedEpisode

        # Build show folder name
        $showFolder = $show
        if ($PlexNaming -and $PlexId) {
            $sourceTag = if ($PlexSource -eq "TVDB") { "tvdb" } else { "tmdb" }
            $yearPart = if ($PlexYear -and $PlexYear -ne "?") { " ($PlexYear)" } else { "" }
            $showFolder = "$PlexShowName$yearPart" + " {$sourceTag-$PlexId}"
        }

        $seasonFolder = "Season {0:D2}" -f [int]$season
        $targetDir = Join-Path $DestinationRoot (Join-Path $showFolder $seasonFolder)
        $newName = Build-FileName -Template $Template -ShowName $show -Season $season -Episode $episode -Extension $f.Extension
        if ([string]::IsNullOrWhiteSpace($newName)) { $newName = $f.OriginalName }
        $f.TargetPath = Join-Path $targetDir $newName
        $f.NewName = $newName
    }
    return $Files
}

function Invoke-OrganizeFiles {
    param(
        [array]$Files,
        [scriptblock]$OnProgress = $null
    )

    $total = ($Files | Where-Object { -not $_.Excluded -and $_.TargetPath }).Count
    $current = 0
    $success = 0
    $errors = 0
    $skipped = 0
    $rollback = @()

    foreach ($f in $Files) {
        if ($f.Excluded -or -not $f.TargetPath) { continue }
        $current++
        if ($OnProgress) { & $OnProgress $current $total $f.OriginalName }

        try {
            $targetDir = Split-Path $f.TargetPath -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }
            if (Test-Path $f.TargetPath) {
                $f.Status = "Skipped (exists)"
                $skipped++
                continue
            }
            Move-Item -Path $f.FullPath -Destination $f.TargetPath -Force
            $rollback += [PSCustomObject]@{
                OriginalPath = $f.FullPath
                NewPath      = $f.TargetPath
            }
            $f.Status = "Organized"
            $success++
        } catch {
            $f.Status = "Error: $($_.Exception.Message)"
            $errors++
        }
    }

    return @{
        Success      = $success
        Errors       = $errors
        Skipped      = $skipped
        RollbackData = $rollback
    }
}

function Invoke-OrganizeUndo {
    param([array]$RollbackData)
    $undone = 0
    $errors = 0

    foreach ($item in $RollbackData) {
        try {
            if (Test-Path $item.NewPath) {
                $origDir = Split-Path $item.OriginalPath -Parent
                if (-not (Test-Path $origDir)) {
                    New-Item -Path $origDir -ItemType Directory -Force | Out-Null
                }
                Move-Item -Path $item.NewPath -Destination $item.OriginalPath -Force
                $undone++
            }
        } catch { $errors++ }
    }
    return @{ Undone = $undone; Errors = $errors }
}
