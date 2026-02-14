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
        [string]$Language = ""
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
            $url = "https://api4.thetvdb.com/v4/series/$SeriesId/episodes/default?season=$Season&page=$page"
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
        [string]$Language = ""
    )
    switch ($Source) {
        "TMDB" { return Get-TmdbEpisodeTitles -ShowId ([int]$ShowId) -Season $Season -ApiKey $TmdbKey -Language $Language }
        "TVDB" { return Get-TvdbEpisodeTitles -SeriesId $ShowId -Season $Season -ApiKey $TvdbKey -Language $Language }
        default { return @{} }
    }
}

# -- Show Selection Dialog ----------------------------------------------------
function Show-SelectionDialog {
    param([array]$Shows)

    $selectForm = New-Object System.Windows.Forms.Form
    $selectForm.Text = "Select Show"
    $selectForm.Size = New-Object System.Drawing.Size(500, 350)
    $selectForm.StartPosition = "CenterParent"
    $selectForm.FormBorderStyle = "FixedDialog"
    $selectForm.MaximizeBox = $false
    $selectForm.MinimizeBox = $false

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Multiple shows found. Select the correct one:"
    $lbl.Location = New-Object System.Drawing.Point(12, 12)
    $lbl.Size = New-Object System.Drawing.Size(460, 20)
    $selectForm.Controls.Add($lbl)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(12, 40)
    $listBox.Size = New-Object System.Drawing.Size(460, 220)
    $listBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    $maxShows = [math]::Min($Shows.Count, 15)
    for ($i = 0; $i -lt $maxShows; $i++) {
        $s = $Shows[$i]
        $entry = "$($s.Name) ($($s.Year)) [$($s.Source)]"
        if ($s.Overview) { $entry += " - $($s.Overview)" }
        $listBox.Items.Add($entry) | Out-Null
    }
    if ($listBox.Items.Count -gt 0) { $listBox.SelectedIndex = 0 }
    $selectForm.Controls.Add($listBox)

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Select"
    $btnOK.Location = New-Object System.Drawing.Point(310, 270)
    $btnOK.Size = New-Object System.Drawing.Size(75, 28)
    $btnOK.DialogResult = "OK"
    $selectForm.AcceptButton = $btnOK
    $selectForm.Controls.Add($btnOK)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(395, 270)
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
