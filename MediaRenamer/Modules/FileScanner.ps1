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
    $h = [math]::Floor($Seconds / 3600)
    $m = [math]::Floor(($Seconds % 3600) / 60)
    $s = $Seconds % 60
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
