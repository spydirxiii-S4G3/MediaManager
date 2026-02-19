# ===============================================================================
# ApiLookup.ps1 - TVDB & TMDB Episode Title Lookup
# ===============================================================================

$script:TvdbToken = ""
$script:TmdbApiKey = ""
$script:TvdbApiKey = ""
$script:TitleLanguage = "en"

function Set-ApiKeys {
    param(
        [string]$TvdbKey = "",
        [string]$TmdbKey = ""
    )
    $script:TvdbApiKey = $TvdbKey
    $script:TmdbApiKey = $TmdbKey
}

function Set-TitleLanguage {
    param([string]$Lang = "en")
    $script:TitleLanguage = $Lang
}

# TVDB uses 3-letter codes, TMDB uses 2-letter codes
function Get-TvdbLanguageCode {
    param([string]$Lang)
    $map = @{
        "en" = "eng"; "ja" = "jpn"; "ko" = "kor"; "zh" = "zho"
        "de" = "deu"; "fr" = "fra"; "es" = "spa"; "pt" = "por"
        "it" = "ita"; "ru" = "rus"; "ar" = "ara"; "nl" = "nld"
        "pl" = "pol"; "sv" = "swe"; "th" = "tha"; "vi" = "vie"
    }
    if ($map.ContainsKey($Lang)) { return $map[$Lang] }
    return $Lang
}

# -- TMDB Functions -----------------------------------------------------------

function Search-TmdbShow {
    param(
        [string]$ShowName,
        [string]$ApiKey,
        [string]$Language = ""
    )
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { $ApiKey = $script:TmdbApiKey }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { return @() }
    if ([string]::IsNullOrWhiteSpace($Language)) { $Language = $script:TitleLanguage }

    try {
        $encoded = [uri]::EscapeDataString($ShowName)
        $url = "https://api.themoviedb.org/3/search/tv?api_key=$ApiKey&query=$encoded&language=$Language"
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        $results = @()
        foreach ($show in $response.results) {
            $results += [PSCustomObject]@{
                Id        = $show.id
                Name      = $show.name
                Year      = if ($show.first_air_date) { $show.first_air_date.Substring(0,4) } else { "?" }
                Overview  = if ($show.overview) { $show.overview.Substring(0, [math]::Min(120, $show.overview.Length)) } else { "" }
                Source    = "TMDB"
            }
        }
        return $results
    } catch {
        return @()
    }
}

function Get-TmdbEpisodeTitles {
    param(
        [int]$ShowId,
        [int]$Season,
        [string]$ApiKey,
        [string]$Language = ""
    )
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { $ApiKey = $script:TmdbApiKey }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { return @{} }
    if ([string]::IsNullOrWhiteSpace($Language)) { $Language = $script:TitleLanguage }

    try {
        $url = "https://api.themoviedb.org/3/tv/$ShowId/season/${Season}?api_key=$ApiKey&language=$Language"
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        $titles = @{}
        foreach ($ep in $response.episodes) {
            $titles[[int]$ep.episode_number] = $ep.name
        }
        return $titles
    } catch {
        return @{}
    }
}

# -- TVDB v4 Functions --------------------------------------------------------

function Connect-Tvdb {
    param([string]$ApiKey)
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { $ApiKey = $script:TvdbApiKey }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { return $false }

    try {
        $body = @{ apikey = $ApiKey } | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "https://api4.thetvdb.com/v4/login" `
            -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop

        if ($response.data -and $response.data.token) {
            $script:TvdbToken = $response.data.token
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Search-TvdbShow {
    param(
        [string]$ShowName,
        [string]$ApiKey
    )
    if ([string]::IsNullOrWhiteSpace($script:TvdbToken)) {
        if (-not (Connect-Tvdb -ApiKey $ApiKey)) { return @() }
    }

    try {
        $encoded = [uri]::EscapeDataString($ShowName)
        $url = "https://api4.thetvdb.com/v4/search?query=$encoded&type=series"
        $headers = @{ Authorization = "Bearer $($script:TvdbToken)" }
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -ErrorAction Stop
        $results = @()
        foreach ($show in $response.data) {
            # TVDB v4 search returns 'tvdb_id' as string - use it correctly
            $showId = if ($show.tvdb_id) { $show.tvdb_id.ToString() } elseif ($show.id) { $show.id.ToString() } else { "" }
            $showName = if ($show.name) { $show.name } elseif ($show.translations -and $show.translations.eng) { $show.translations.eng } else { "" }
            $showYear = if ($show.year) { $show.year.ToString() } elseif ($show.first_air_time) { $show.first_air_time.Substring(0,4) } else { "?" }

            if ($showId) {
                $results += [PSCustomObject]@{
                    Id        = $showId
                    Name      = $showName
                    Year      = $showYear
                    Overview  = if ($show.overview) { $show.overview.Substring(0, [math]::Min(120, $show.overview.Length)) } else { "" }
                    Source    = "TVDB"
                }
            }
        }
        return $results
    } catch {
        return @()
    }
}

function Get-TvdbEpisodeTitles {
    param(
        [string]$SeriesId,
        [int]$Season,
        [string]$ApiKey,
        [string]$Language = "",
        [string]$SeasonType = "default"
    )
    if ([string]::IsNullOrWhiteSpace($script:TvdbToken)) {
        if (-not (Connect-Tvdb -ApiKey $ApiKey)) { return @{} }
    }
    if ([string]::IsNullOrWhiteSpace($Language)) { $Language = $script:TitleLanguage }
    # Convert 2-letter to 3-letter code for TVDB
    $tvdbLang = Get-TvdbLanguageCode -Lang $Language

    $headers = @{ Authorization = "Bearer $($script:TvdbToken)" }
    $titles = @{}
    $page = 0

    try {
        # TVDB v4: paginated episode list - loop until no more pages
        do {
            $url = "https://api4.thetvdb.com/v4/series/$SeriesId/episodes/$SeasonType`?season=$Season&page=$page"
            $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -ErrorAction Stop

            if ($response.data -and $response.data.episodes) {
                foreach ($ep in $response.data.episodes) {
                    if ([int]$ep.seasonNumber -eq $Season) {
                        $epNum = [int]$ep.number

                        # Get title in preferred language
                        $title = $null

                        # Try requested language translation
                        if ($ep.nameTranslations -and ($ep.nameTranslations -contains $tvdbLang)) {
                            try {
                                $transUrl = "https://api4.thetvdb.com/v4/episodes/$($ep.id)/translations/$tvdbLang"
                                $transResp = Invoke-RestMethod -Uri $transUrl -Method Get -Headers $headers -ErrorAction Stop
                                if ($transResp.data -and $transResp.data.name) {
                                    $title = $transResp.data.name
                                }
                            } catch { }
                        }

                        # Fallback: try English if we requested something else
                        if (-not $title -and $tvdbLang -ne "eng" -and $ep.nameTranslations -and ($ep.nameTranslations -contains "eng")) {
                            try {
                                $transUrl = "https://api4.thetvdb.com/v4/episodes/$($ep.id)/translations/eng"
                                $transResp = Invoke-RestMethod -Uri $transUrl -Method Get -Headers $headers -ErrorAction Stop
                                if ($transResp.data -and $transResp.data.name) {
                                    $title = $transResp.data.name
                                }
                            } catch { }
                        }

                        # Last fallback: default name field
                        if (-not $title) {
                            $title = $ep.name
                        }

                        if ($title) {
                            $titles[$epNum] = $title
                        }
                    }
                }
            }

            # Check if there are more pages
            $hasMore = $false
            if ($response.links -and $response.links.next) {
                $page++
                $hasMore = $true
            }
        } while ($hasMore -and $page -lt 20)  # Safety limit

        return $titles
    } catch {
        return $titles  # Return whatever we collected so far
    }
}

# -- Jikan (MyAnimeList) Functions --------------------------------------------

function Search-JikanShow {
    param(
        [string]$ShowName,
        [string]$Language = ""
    )
    try {
        $encoded = [uri]::EscapeDataString($ShowName)
        $url = "https://api.jikan.moe/v4/anime?q=$encoded&limit=25"
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        $results = @()
        foreach ($show in $response.data) {
            $name = $show.title
            # Prefer English title if available
            if ($show.title_english) { $name = $show.title_english }
            $results += [PSCustomObject]@{
                Id        = $show.mal_id
                Name      = $name
                Year      = if ($show.year) { $show.year.ToString() } elseif ($show.aired -and $show.aired.from) { $show.aired.from.Substring(0,4) } else { "?" }
                Overview  = if ($show.synopsis) { $show.synopsis.Substring(0, [math]::Min(120, $show.synopsis.Length)) } else { "" }
                Source    = "MAL"
                Episodes  = if ($show.episodes) { $show.episodes } else { 0 }
            }
        }
        return $results
    } catch {
        return @()
    }
}

function Get-JikanEpisodeTitles {
    param(
        [int]$AnimeId,
        [int]$Season = 0,
        [string]$Language = ""
    )
    $titles = @{}
    $page = 1
    $hasMore = $true

    try {
        while ($hasMore -and $page -le 10) {
            $url = "https://api.jikan.moe/v4/anime/$AnimeId/episodes?page=$page"
            $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop

            if ($response.data -and $response.data.Count -gt 0) {
                foreach ($ep in $response.data) {
                    $epNum = [int]$ep.mal_id
                    $title = $null
                    # Prefer English title, fall back to Japanese, then romanized
                    if ($Language -eq "ja" -and $ep.title_japanese) {
                        $title = $ep.title_japanese
                    } elseif ($ep.title) {
                        $title = $ep.title
                    } elseif ($ep.title_romanji) {
                        $title = $ep.title_romanji
                    }
                    if ($title) { $titles[$epNum] = $title }
                }
                $hasMore = $response.pagination.has_next_page
                $page++
                # Jikan rate limit: 3 req/sec - wait between pages
                Start-Sleep -Milliseconds 350
            } else {
                $hasMore = $false
            }
        }
        return $titles
    } catch {
        return $titles
    }
}

# -- Unified Lookup -----------------------------------------------------------

function Search-Show {
    param(
        [string]$ShowName,
        [string]$Source = "TMDB",
        [string]$TmdbKey = "",
        [string]$TvdbKey = "",
        [string]$Language = ""
    )
    switch ($Source) {
        "TMDB" { return Search-TmdbShow -ShowName $ShowName -ApiKey $TmdbKey -Language $Language }
        "TVDB" { return Search-TvdbShow -ShowName $ShowName -ApiKey $TvdbKey }
        "MAL"  { return Search-JikanShow -ShowName $ShowName -Language $Language }
        default { return @() }
    }
}

function Get-EpisodeTitles {
    param(
        [string]$ShowId,
        [int]$Season,
        [string]$Source = "TMDB",
        [string]$TmdbKey = "",
        [string]$TvdbKey = "",
        [string]$Language = "",
        [string]$SeasonType = "default"
    )
    switch ($Source) {
        "TMDB" { return Get-TmdbEpisodeTitles -ShowId ([int]$ShowId) -Season $Season -ApiKey $TmdbKey -Language $Language }
        "TVDB" { return Get-TvdbEpisodeTitles -SeriesId $ShowId -Season $Season -ApiKey $TvdbKey -Language $Language -SeasonType $SeasonType }
        "MAL"  { return Get-JikanEpisodeTitles -AnimeId ([int]$ShowId) -Season $Season -Language $Language }
        default { return @{} }
    }
}

# -- Season Map Functions -----------------------------------------------------

function Get-TvdbSeasonMap {
    param(
        [string]$SeriesId,
        [string]$ApiKey,
        [string]$SeasonType = "default"
    )
    if ([string]::IsNullOrWhiteSpace($script:TvdbToken)) {
        if (-not (Connect-Tvdb -ApiKey $ApiKey)) { return @() }
    }
    $headers = @{ Authorization = "Bearer $($script:TvdbToken)" }
    $epCounts = @{}
    $page = 0

    try {
        do {
            $url = "https://api4.thetvdb.com/v4/series/$SeriesId/episodes/$SeasonType`?page=$page"
            $resp = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -ErrorAction Stop
            if ($resp.data -and $resp.data.episodes) {
                foreach ($ep in $resp.data.episodes) {
                    $sNum = [int]$ep.seasonNumber
                    if ($sNum -eq 0) { continue }  # Skip specials
                    if (-not $epCounts.ContainsKey($sNum)) { $epCounts[$sNum] = 0 }
                    $epCounts[$sNum]++
                }
            }
            $hasMore = $false
            if ($resp.links -and $resp.links.next) { $page++; $hasMore = $true }
        } while ($hasMore -and $page -lt 50)

        $result = @()
        $cumulative = 1
        foreach ($key in ($epCounts.Keys | Sort-Object)) {
            $result += [PSCustomObject]@{
                SeasonNumber    = $key
                EpisodeCount    = $epCounts[$key]
                CumulativeStart = $cumulative
                CumulativeEnd   = $cumulative + $epCounts[$key] - 1
            }
            $cumulative += $epCounts[$key]
        }
        return $result
    } catch {
        return @()
    }
}

function Get-TmdbSeasonMap {
    param(
        [int]$ShowId,
        [string]$ApiKey,
        [string]$Language = ""
    )
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { $ApiKey = $script:TmdbApiKey }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { return @() }
    if ([string]::IsNullOrWhiteSpace($Language)) { $Language = $script:TitleLanguage }

    try {
        $url = "https://api.themoviedb.org/3/tv/$ShowId`?api_key=$ApiKey&language=$Language"
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        $result = @()
        $cumulative = 1
        foreach ($s in ($response.seasons | Sort-Object season_number)) {
            if ([int]$s.season_number -eq 0) { continue }  # Skip specials
            $count = [int]$s.episode_count
            $result += [PSCustomObject]@{
                SeasonNumber    = [int]$s.season_number
                EpisodeCount    = $count
                CumulativeStart = $cumulative
                CumulativeEnd   = $cumulative + $count - 1
            }
            $cumulative += $count
        }
        return $result
    } catch {
        return @()
    }
}

function Get-TmdbEpisodeGroups {
    param(
        [int]$ShowId,
        [string]$ApiKey,
        [string]$Language = ""
    )
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { $ApiKey = $script:TmdbApiKey }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { return @() }

    try {
        $url = "https://api.themoviedb.org/3/tv/$ShowId/episode_groups?api_key=$ApiKey"
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        $groups = @()
        foreach ($g in $response.results) {
            $groups += [PSCustomObject]@{
                Id          = $g.id
                Name        = $g.name
                Type        = if ($g.type -eq 1) { "Original Air Date" } elseif ($g.type -eq 2) { "Absolute" } elseif ($g.type -eq 3) { "DVD" } elseif ($g.type -eq 4) { "Digital" } elseif ($g.type -eq 5) { "Story Arc" } elseif ($g.type -eq 6) { "Production" } elseif ($g.type -eq 7) { "TV" } else { "Other" }
                Description = if ($g.description) { $g.description } else { "" }
                GroupCount  = if ($g.group_count) { $g.group_count } else { 0 }
                EpCount     = if ($g.episode_count) { $g.episode_count } else { 0 }
            }
        }
        return $groups
    } catch {
        return @()
    }
}

function Get-TmdbGroupEpisodeTitles {
    param(
        [string]$GroupId,
        [string]$ApiKey,
        [int]$Season = 1,
        [string]$Language = ""
    )
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { $ApiKey = $script:TmdbApiKey }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { return @{} }

    try {
        $url = "https://api.themoviedb.org/3/tv/episode_group/$GroupId`?api_key=$ApiKey"
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        $titles = @{}
        # Groups have an array of groups, each is like a season
        if ($response.groups) {
            # Find the group that matches the requested season (0-indexed in groups array)
            $groupIdx = $Season - 1
            if ($groupIdx -ge 0 -and $groupIdx -lt $response.groups.Count) {
                $group = $response.groups[$groupIdx]
                foreach ($ep in $group.episodes) {
                    $epNum = [int]$ep.order + 1
                    $title = $ep.name
                    if ($title) { $titles[$epNum] = $title }
                }
            }
        }
        return $titles
    } catch {
        return @{}
    }
}

function Get-TmdbGroupSeasonMap {
    param(
        [string]$GroupId,
        [string]$ApiKey
    )
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { $ApiKey = $script:TmdbApiKey }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { return @() }

    try {
        $url = "https://api.themoviedb.org/3/tv/episode_group/$GroupId`?api_key=$ApiKey"
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        $result = @()
        $cumulative = 1
        $seasonNum = 1
        if ($response.groups) {
            foreach ($group in $response.groups) {
                $count = $group.episodes.Count
                $result += [PSCustomObject]@{
                    SeasonNumber    = $seasonNum
                    EpisodeCount    = $count
                    CumulativeStart = $cumulative
                    CumulativeEnd   = $cumulative + $count - 1
                    GroupName       = if ($group.name) { $group.name } else { "Group $seasonNum" }
                }
                $cumulative += $count
                $seasonNum++
            }
        }
        return $result
    } catch {
        return @()
    }
}

# -- Unified Season Map -------------------------------------------------------

function Get-SeasonMap {
    param(
        [string]$ShowId,
        [string]$Source = "TMDB",
        [string]$TmdbKey = "",
        [string]$TvdbKey = "",
        [string]$Language = "",
        [string]$SeasonType = "default",
        [string]$GroupId = ""
    )
    switch ($Source) {
        "TMDB" {
            if ($GroupId) {
                return Get-TmdbGroupSeasonMap -GroupId $GroupId -ApiKey $TmdbKey
            }
            return Get-TmdbSeasonMap -ShowId ([int]$ShowId) -ApiKey $TmdbKey -Language $Language
        }
        "TVDB" { return Get-TvdbSeasonMap -SeriesId $ShowId -ApiKey $TvdbKey -SeasonType $SeasonType }
        "MAL"  { return @() }  # MAL has no multi-season structure
        default { return @() }
    }
}

function Convert-AbsoluteToSeason {
    param(
        [int]$AbsoluteEpisode,
        [array]$SeasonMap
    )
    foreach ($s in $SeasonMap) {
        if ($AbsoluteEpisode -ge $s.CumulativeStart -and $AbsoluteEpisode -le $s.CumulativeEnd) {
            return [PSCustomObject]@{
                Season  = $s.SeasonNumber
                Episode = $AbsoluteEpisode - $s.CumulativeStart + 1
            }
        }
    }
    return $null
}

# -- Show Selection Dialog ----------------------------------------------------
function Show-SelectionDialog {
    param([array]$Shows)

    $selectForm = New-Object System.Windows.Forms.Form
    $selectForm.Text = "Select Show"
    $selectForm.Size = New-Object System.Drawing.Size(600, 500)
    $selectForm.StartPosition = "CenterParent"
    $selectForm.FormBorderStyle = "FixedDialog"
    $selectForm.MaximizeBox = $false
    $selectForm.MinimizeBox = $false

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Multiple shows found. Select the correct one:"
    $lbl.Location = New-Object System.Drawing.Point(12, 12)
    $lbl.Size = New-Object System.Drawing.Size(560, 20)
    $selectForm.Controls.Add($lbl)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(12, 40)
    $listBox.Size = New-Object System.Drawing.Size(560, 370)
    $listBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $listBox.HorizontalScrollbar = $true

    $maxShows = [math]::Min($Shows.Count, 25)
    for ($i = 0; $i -lt $maxShows; $i++) {
        $s = $Shows[$i]
        $entry = "$($s.Name) ($($s.Year)) [$($s.Source)]"
        if ($s.PSObject.Properties.Name -contains "Episodes" -and $s.Episodes -gt 0) {
            $entry += " - $($s.Episodes) eps"
        }
        if ($s.Overview) { $entry += " - $($s.Overview)" }
        $listBox.Items.Add($entry) | Out-Null
    }
    if ($listBox.Items.Count -gt 0) { $listBox.SelectedIndex = 0 }
    $selectForm.Controls.Add($listBox)

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Select"
    $btnOK.Location = New-Object System.Drawing.Point(400, 420)
    $btnOK.Size = New-Object System.Drawing.Size(75, 28)
    $btnOK.DialogResult = "OK"
    $selectForm.AcceptButton = $btnOK
    $selectForm.Controls.Add($btnOK)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(485, 420)
    $btnCancel.Size = New-Object System.Drawing.Size(75, 28)
    $btnCancel.DialogResult = "Cancel"
    $selectForm.CancelButton = $btnCancel
    $selectForm.Controls.Add($btnCancel)

    # Double-click to select
    $listBox.Add_DoubleClick({ $selectForm.DialogResult = "OK"; $selectForm.Close() })

    $result = $selectForm.ShowDialog()
    if ($result -eq "OK" -and $listBox.SelectedIndex -ge 0) {
        return $Shows[$listBox.SelectedIndex]
    }
    return $null
}
