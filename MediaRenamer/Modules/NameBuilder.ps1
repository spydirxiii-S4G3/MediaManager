# ===============================================================================
# NameBuilder.ps1 - Construct New Filenames from Template / Pattern
# ===============================================================================

# Default template: {show} - S{season}E{episode} - {title}.{ext}
# Variables: {show}, {season}, {episode}, {episode_end}, {title}, {ext}, {total}, {original}

$script:DefaultTemplate = "{show} - S{season}E{episode}"
$script:DefaultTemplateWithTitle = "{show} - S{season}E{episode} - {title}"

function Build-FileName {
    param(
        [string]$Template,
        [string]$ShowName,
        [int]$Season,
        [int]$Episode,
        [int]$EpisodeEnd = 0,
        [string]$EpisodeTitle = "",
        [int]$TotalEpisodes = 0,
        [string]$Extension = ".mp4",
        [string]$OriginalName = "",
        [int]$SeasonPad = 2,
        [int]$EpisodePad = 2
    )

    $seasonStr = $Season.ToString("D$SeasonPad")
    $episodeStr = $Episode.ToString("D$EpisodePad")
    $episodeEndStr = if ($EpisodeEnd -gt 0) { $EpisodeEnd.ToString("D$EpisodePad") } else { "" }
    $totalStr = if ($TotalEpisodes -gt 0) { $TotalEpisodes.ToString() } else { "" }

    # Pick template based on whether title exists
    $tmpl = $Template
    if ([string]::IsNullOrWhiteSpace($tmpl)) {
        if (-not [string]::IsNullOrWhiteSpace($EpisodeTitle)) {
            $tmpl = $script:DefaultTemplateWithTitle
        } else {
            $tmpl = $script:DefaultTemplate
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($EpisodeTitle) -and $tmpl -notmatch '\{title\}') {
        # Template doesn't have {title} placeholder but we have a title - auto-append
        $tmpl = "$tmpl - {title}"
    }

    # Build the episode number portion
    $epPortion = "E$episodeStr"
    if ($EpisodeEnd -gt 0 -and $EpisodeEnd -ne $Episode) {
        $epPortion = "E$episodeStr-E$episodeEndStr"
    }

    # Replace template variables (use string Replace to avoid regex issues with show names)
    $result = $tmpl
    $result = $result.Replace('{show}', $ShowName)
    $result = $result.Replace('{season}', $seasonStr)
    $result = $result.Replace('{episode}', $episodeStr)
    $result = $result.Replace('{episode_end}', $episodeEndStr)
    $result = $result.Replace('{ep_range}', $epPortion)
    $result = $result.Replace('{title}', $EpisodeTitle)
    $result = $result.Replace('{total}', $totalStr)
    $result = $result.Replace('{original}', [System.IO.Path]::GetFileNameWithoutExtension($OriginalName))
    $result = $result.Replace('{ext}', $Extension.TrimStart('.'))

    # Handle S01E01 format directly (replace E{episode} pattern with full range if multi-part)
    if ($EpisodeEnd -gt 0 -and $EpisodeEnd -ne $Episode) {
        $result = $result -replace "E$episodeStr", $epPortion
    }

    # Clean up orphan separators if title is empty
    if ([string]::IsNullOrWhiteSpace($EpisodeTitle)) {
        $result = $result -replace '\s*[-]\s*$', ''
        $result = $result -replace '\s*[-]\s*\.', '.'
    }

    # Remove illegal filename characters
    $result = Remove-IllegalChars -Name $result

    # Append extension if not in template
    if (-not $result.EndsWith($Extension)) {
        $result = "$result$Extension"
    }

    return $result
}

function Remove-IllegalChars {
    param([string]$Name)
    $illegal = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($char in $illegal) {
        $Name = $Name.Replace([string]$char, '')
    }
    return $Name
}

function Build-BatchNames {
    param(
        [array]$Files,
        [string]$ShowName,
        [int]$Season,
        [int]$StartEpisode = 1,
        [int]$TotalEpisodes = 0,
        [string]$Template = "",
        [hashtable]$EpisodeTitles = @{},
        [int]$SeasonPad = 2,
        [int]$EpisodePad = 2
    )

    if ($TotalEpisodes -eq 0) { $TotalEpisodes = $Files.Count }

    $epNum = $StartEpisode
    $results = @()

    foreach ($file in $Files) {
        if ($file.Excluded) {
            $results += $file
            continue
        }

        $title = ""
        if ($EpisodeTitles.ContainsKey($epNum)) {
            $title = $EpisodeTitles[$epNum]
        } elseif (-not [string]::IsNullOrWhiteSpace($file.EpisodeTitle)) {
            $title = $file.EpisodeTitle
        }

        # Check for multi-part episode
        $epEnd = 0
        if ($file.PSObject.Properties.Name -contains 'EpisodeEnd' -and $file.EpisodeEnd -gt 0) {
            $epEnd = $file.EpisodeEnd
        }

        $newName = Build-FileName `
            -Template $Template `
            -ShowName $ShowName `
            -Season $Season `
            -Episode $epNum `
            -EpisodeEnd $epEnd `
            -EpisodeTitle $title `
            -TotalEpisodes $TotalEpisodes `
            -Extension $file.Extension `
            -OriginalName $file.OriginalName `
            -SeasonPad $SeasonPad `
            -EpisodePad $EpisodePad

        $file.NewName = $newName
        $file.EpisodeNumber = $epNum
        if (-not [string]::IsNullOrWhiteSpace($title)) {
            $file.EpisodeTitle = $title
        }
        $file.Status = if ($file.OriginalName -eq $newName) { "No Change" } else { "Will Rename" }

        $results += $file
        $epNum++
    }

    return $results
}

function Get-TemplatePreview {
    param(
        [string]$Template,
        [string]$ShowName = "Show Name",
        [int]$Season = 1,
        [int]$Episode = 1,
        [string]$Title = "Episode Title"
    )

    $withTitle = Build-FileName -Template $Template -ShowName $ShowName -Season $Season -Episode $Episode -EpisodeTitle $Title -Extension ".mp4"
    $withoutTitle = Build-FileName -Template $Template -ShowName $ShowName -Season $Season -Episode $Episode -Extension ".mp4"

    return @{
        WithTitle    = $withTitle
        WithoutTitle = $withoutTitle
    }
}
