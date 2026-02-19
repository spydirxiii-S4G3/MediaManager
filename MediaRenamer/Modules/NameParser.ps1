# ===============================================================================
# NameParser.ps1 - Parse Existing Filenames, Regex Matching, Junk Cleanup
# ===============================================================================

# Common junk patterns found in media filenames
$script:JunkPatterns = @(
    '\b\d{3,4}p\b',              # 720p, 1080p, 2160p
    '\b[xXhH]\.?26[45]\b',      # x264, x265, H.264, H.265, h264
    '\bHEVC\b',
    '\bHDTV\b',
    '\bHDRip\b',
    '\bBluRay\b',
    '\bBlu-Ray\b',
    '\bBDRip\b',
    '\bBRRip\b',
    '\bWEB-?DL\b',
    '\bWEB-?Rip\b',
    '\bDVDRip\b',
    '\bDVDScr\b',
    '\bAAC\b',
    '\bAC3\b',
    '\bDTS\b',
    '\bFLAC\b',
    '\bMP3\b',
    '\b5\.1\b',
    '\b7\.1\b',
    '\bATMOS\b',
    '\bREPACK\b',
    '\bPROPER\b',
    '\bDUAL\b',
    '\bMULTI\b',
    '\bSUBBED\b',
    '\bHARDSUB\b',
    '\bSOFTSUB\b',
    '\bENG?\b(?=[\.\s-_])',
    '\bJPN?\b(?=[\.\s-_])',
    '\bReMux\b',
    '\bNF\b',
    '\bAMZN\b',
    '\bDSNP?\b',
    '\bHMAX\b',
    '\bHulu\b',
    '\bCR\b',
    '\bFUNi?\b',
    '\bHIDIVE\b',
    '\b10bit\b',
    '\b8bit\b',
    '\bHDR\b',
    '\bSDR\b',
    '\bDolby\s*Vision\b',
    '\bDV\b(?=[\.\s-_])',
    '\bTrueHD\b',
    '\bLossless\b'
)

function Clean-FileName {
    param(
        [string]$Name,
        [bool]$StripJunk = $true,
        [bool]$RemoveBrackets = $true,
        [bool]$ReplaceDotsUnderscores = $true,
        [bool]$TrimWhitespace = $true
    )

    $cleaned = $Name

    # Remove brackets and their contents: [SubGroup], (720p), {info}
    if ($RemoveBrackets) {
        $cleaned = $cleaned -replace '\[[^\]]*\]', ''
        $cleaned = $cleaned -replace '\([^\)]*\)', ''
        $cleaned = $cleaned -replace '\{[^\}]*\}', ''
    }

    # Strip common junk tags
    if ($StripJunk) {
        foreach ($pattern in $script:JunkPatterns) {
            $cleaned = $cleaned -replace $pattern, ''
        }
    }

    # Replace dots and underscores with spaces
    if ($ReplaceDotsUnderscores) {
        $cleaned = $cleaned -replace '[\._]', ' '
    }

    # Trim extra whitespace
    if ($TrimWhitespace) {
        $cleaned = $cleaned -replace '\s+', ' '
        $cleaned = $cleaned -replace '^\s*[-]\s*', ''
        $cleaned = $cleaned -replace '\s*[-]\s*$', ''
        $cleaned = $cleaned.Trim()
        $cleaned = $cleaned.Trim('-', ' ')
    }

    return $cleaned
}

function Parse-ExistingFileName {
    param([string]$FileName)

    $result = [PSCustomObject]@{
        ShowName       = ""
        Season         = 0
        Episode        = 0
        EpisodeEnd     = 0  # For multi-part
        Title          = ""
        Junk           = ""
        ParsedOk       = $false
    }

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

    # Pattern 1: Show Name - S01E01 - Title
    if ($baseName -match '^(.+?)\s*[-]\s*[Ss](\d+)[Ee](\d+)(?:[-Ee](\d+))?\s*(?:[-]\s*(.+))?$') {
        $result.ShowName = $Matches[1].Trim()
        $result.Season = [int]$Matches[2]
        $result.Episode = [int]$Matches[3]
        if ($Matches[4]) { $result.EpisodeEnd = [int]$Matches[4] }
        if ($Matches[5]) { $result.Title = $Matches[5].Trim() }
        $result.ParsedOk = $true
        return $result
    }

    # Pattern 2: Show.Name.S01E01.Title.720p.x264
    if ($baseName -match '^(.+?)[.\s]+[Ss](\d+)[Ee](\d+)(?:[-Ee](\d+))?[.\s]*(.*)$') {
        $result.ShowName = ($Matches[1] -replace '[\._]', ' ').Trim()
        $result.Season = [int]$Matches[2]
        $result.Episode = [int]$Matches[3]
        if ($Matches[4]) { $result.EpisodeEnd = [int]$Matches[4] }
        if ($Matches[5]) { $result.Title = Clean-FileName -Name $Matches[5] }
        $result.ParsedOk = $true
        return $result
    }

    # Pattern 3: Show Name - 01 - Title (no season)
    if ($baseName -match '^(.+?)\s*[-]\s*(\d+)\s*(?:[-]\s*(.+))?$') {
        $result.ShowName = $Matches[1].Trim()
        $result.Episode = [int]$Matches[2]
        if ($Matches[3]) { $result.Title = $Matches[3].Trim() }
        $result.ParsedOk = $true
        return $result
    }

    # Pattern 4: [SubGroup] Show Name - 01 (v2) [720p]
    if ($baseName -match '(?:\[.*?\]\s*)?(.+?)\s*[-]\s*(\d+)\s*(?:\(v\d+\))?\s*(?:\[.*?\])?$') {
        $result.ShowName = $Matches[1].Trim()
        $result.Episode = [int]$Matches[2]
        $result.ParsedOk = $true
        return $result
    }

    # Pattern 5: Show Name Season 2 Episode 3
    if ($baseName -match '^(.+?)\s*[Ss]eason\s*(\d+)\s*[Ee]pisode\s*(\d+)\s*(.*)$') {
        $result.ShowName = $Matches[1].Trim().TrimEnd('-', ' ')
        $result.Season = [int]$Matches[2]
        $result.Episode = [int]$Matches[3]
        if ($Matches[4]) { $result.Title = Clean-FileName -Name $Matches[4] }
        $result.ParsedOk = $true
        return $result
    }

    # Pattern 6: Show Name Episode 01
    if ($baseName -match '^(.+?)\s*[Ee](?:p(?:isode)?)?\s*(\d+)\s*(.*)$') {
        $result.ShowName = $Matches[1].Trim()
        $result.Episode = [int]$Matches[2]
        if ($Matches[3]) { $result.Title = Clean-FileName -Name $Matches[3] }
        $result.ParsedOk = $true
        return $result
    }

    # Fallback: couldn't parse
    $result.ShowName = Clean-FileName -Name $baseName
    return $result
}

function Test-MatchesNamingPattern {
    param(
        [string]$FileName,
        [string]$ShowName,
        [int]$Season
    )
    $escaped = [regex]::Escape($ShowName)
    $seasonStr = $Season.ToString("D2")
    $pattern = "^$escaped\s*-\s*S${seasonStr}E\d+"
    return $FileName -match $pattern
}

function Parse-WithCustomRegex {
    param(
        [string]$FileName,
        [string]$Pattern
    )
    try {
        if ($FileName -match $Pattern) {
            return $Matches
        }
    } catch {
        return $null
    }
    return $null
}
