# ===============================================================================
# MainForm.ps1 - Main GUI Form (v3 - UX Improvements)
# ===============================================================================

[System.Windows.Forms.Application]::EnableVisualStyles()
$ErrorActionPreference = "Continue"

# -- Initialize settings -------------------------------------------------------
Initialize-PresetManager

# -- State ---------------------------------------------------------------------
$script:FileList = @()
$script:RollbackData = @()
$script:LastRenameResults = @{}
$script:Settings = Load-AppSettings
$script:EpisodeTitlesCache = @{}
$script:SeasonFileListCache = @{}
$script:IsDryRun = $false
$script:CurrentSeasonPath = ""
$script:ShowFolderPath = ""

# -- Initialize Theme ----------------------------------------------------------
Initialize-Theme -Preference $script:Settings.ThemePreference
$t = Get-Theme

# -- Fonts ---------------------------------------------------------------------
$fontNormal   = New-Object System.Drawing.Font("Segoe UI", 9)
$fontBold     = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$fontSmall    = New-Object System.Drawing.Font("Segoe UI", 8)
$fontHeader   = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$fontLegend   = New-Object System.Drawing.Font("Segoe UI", 7.5)
$monoFontName = "Consolas"
try {
    $testFont = New-Object System.Drawing.Font("Cascadia Code", 9)
    if ($testFont.Name -eq "Cascadia Code") { $monoFontName = "Cascadia Code" }
    $testFont.Dispose()
} catch { }
$fontMono = New-Object System.Drawing.Font($monoFontName, 9)

# -- Tooltip -------------------------------------------------------------------
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 8000
$toolTip.InitialDelay = 400
$toolTip.ReshowDelay = 200

# ===============================================================================
# MAIN FORM
# ===============================================================================
$script:AppVersion = "V1.2.4"

$form = New-Object System.Windows.Forms.Form
$form.Text = "Media File Renamer  $script:AppVersion  |  Creator: S4G3"
$form.Font = $fontNormal
$form.MinimumSize = New-Object System.Drawing.Size(950, 650)
$form.StartPosition = "CenterScreen"
$form.AllowDrop = $true
$form.KeyPreview = $true
$form.Icon = [System.Drawing.SystemIcons]::Application

if ($script:Settings.WindowWidth -gt 0) {
    $form.Size = New-Object System.Drawing.Size($script:Settings.WindowWidth, $script:Settings.WindowHeight)
}
if ($script:Settings.WindowX -ge 0) {
    $form.StartPosition = "Manual"
    $form.Location = New-Object System.Drawing.Point($script:Settings.WindowX, $script:Settings.WindowY)
}

# ===============================================================================
# TAB CONTROL
# ===============================================================================
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = "Fill"
$tabControl.Font = $fontNormal

$tabRename   = New-Object System.Windows.Forms.TabPage "  Rename  "
$tabOrganize = New-Object System.Windows.Forms.TabPage "  Organize  "
$tabSettings = New-Object System.Windows.Forms.TabPage "  Settings  "

$tabControl.TabPages.AddRange(@($tabRename, $tabOrganize, $tabSettings))
$form.Controls.Add($tabControl)

# ===============================================================================
# TAB 1: RENAME
# ===============================================================================

# -- Top Panel (controls) ------------------------------------------------------
$panelTop = New-Object System.Windows.Forms.Panel
$panelTop.Dock = "Top"
$panelTop.Height = 210

# -- Row 1: Folder Selection ---------------------------------------------------
$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = "Folder:"
$lblFolder.Location = New-Object System.Drawing.Point(12, 12)
$lblFolder.Size = New-Object System.Drawing.Size(48, 23)
$panelTop.Controls.Add($lblFolder)

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Location = New-Object System.Drawing.Point(62, 10)
$txtFolder.Size = New-Object System.Drawing.Size(760, 23)
$txtFolder.Anchor = "Top,Left,Right"
$txtFolder.ReadOnly = $true
$toolTip.SetToolTip($txtFolder, "The show root folder containing season subfolders")
$panelTop.Controls.Add($txtFolder)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(830, 8)
$btnBrowse.Anchor = "Top,Right"
$btnBrowse.Size = New-Object System.Drawing.Size(85, 27)
$btnBrowse.FlatStyle = "Flat"
$btnBrowse.BackColor = $t.ButtonPrimary
$btnBrowse.ForeColor = $t.ButtonFore
$btnBrowse.Cursor = "Hand"
$toolTip.SetToolTip($btnBrowse, "Select a show folder (e.g. D:\TV\Bleach)")
$panelTop.Controls.Add($btnBrowse)

# -- Row 2: Show Name / Season -------------------------------------------------
$lblShow = New-Object System.Windows.Forms.Label
$lblShow.Text = "Show:"
$lblShow.Location = New-Object System.Drawing.Point(12, 43)
$lblShow.Size = New-Object System.Drawing.Size(48, 23)
$panelTop.Controls.Add($lblShow)

$txtShowName = New-Object System.Windows.Forms.TextBox
$txtShowName.Location = New-Object System.Drawing.Point(62, 41)
$txtShowName.Size = New-Object System.Drawing.Size(250, 23)
$txtShowName.ReadOnly = $true
$toolTip.SetToolTip($txtShowName, "Show name used in renamed filenames")
$panelTop.Controls.Add($txtShowName)

$chkShowFromFolder = New-Object System.Windows.Forms.CheckBox
$chkShowFromFolder.Text = "From folder"
$chkShowFromFolder.Location = New-Object System.Drawing.Point(320, 43)
$chkShowFromFolder.Size = New-Object System.Drawing.Size(95, 23)
$chkShowFromFolder.Checked = $true
$toolTip.SetToolTip($chkShowFromFolder, "Auto-detect show name from folder. Uncheck to type manually")
$panelTop.Controls.Add($chkShowFromFolder)

$chkShowFromFolder.Add_CheckedChanged({
    $txtShowName.ReadOnly = $chkShowFromFolder.Checked
    if ($chkShowFromFolder.Checked -and $script:ShowFolderPath) {
        $txtShowName.Text = Get-ShowNameFromFolder -FolderPath $script:ShowFolderPath
    }
})

$lblSeason = New-Object System.Windows.Forms.Label
$lblSeason.Text = "Season:"
$lblSeason.Location = New-Object System.Drawing.Point(420, 43)
$lblSeason.Size = New-Object System.Drawing.Size(55, 23)
$panelTop.Controls.Add($lblSeason)

$numSeason = New-Object System.Windows.Forms.NumericUpDown
$numSeason.Location = New-Object System.Drawing.Point(478, 41)
$numSeason.Size = New-Object System.Drawing.Size(55, 23)
$numSeason.Minimum = 0
$numSeason.Maximum = 99
$numSeason.Value = 1
$numSeason.Enabled = $false
$toolTip.SetToolTip($numSeason, "Season number for filenames (S01, S02, etc.)")
$panelTop.Controls.Add($numSeason)

$chkSeasonFromFolder = New-Object System.Windows.Forms.CheckBox
$chkSeasonFromFolder.Text = "Auto-detect"
$chkSeasonFromFolder.Location = New-Object System.Drawing.Point(540, 43)
$chkSeasonFromFolder.Size = New-Object System.Drawing.Size(100, 23)
$chkSeasonFromFolder.Checked = $true
$toolTip.SetToolTip($chkSeasonFromFolder, "Auto-detect season number from folder name. Uncheck to set manually")
$panelTop.Controls.Add($chkSeasonFromFolder)

$chkSeasonFromFolder.Add_CheckedChanged({
    $numSeason.Enabled = -not $chkSeasonFromFolder.Checked
})

# -- Row 3: Start Ep, Sort, Action ---------------------------------------------
$lblStartEp = New-Object System.Windows.Forms.Label
$lblStartEp.Text = "Start Ep:"
$lblStartEp.Location = New-Object System.Drawing.Point(12, 76)
$lblStartEp.Size = New-Object System.Drawing.Size(55, 23)
$panelTop.Controls.Add($lblStartEp)

$numStartEpisode = New-Object System.Windows.Forms.NumericUpDown
$numStartEpisode.Location = New-Object System.Drawing.Point(70, 74)
$numStartEpisode.Size = New-Object System.Drawing.Size(55, 23)
$numStartEpisode.Minimum = 0
$numStartEpisode.Maximum = 9999
$numStartEpisode.Value = 1
$toolTip.SetToolTip($numStartEpisode, "First episode number (E01, E02...). Change if season doesn't start at 1")
$panelTop.Controls.Add($numStartEpisode)

$lblSort = New-Object System.Windows.Forms.Label
$lblSort.Text = "Sort by:"
$lblSort.Location = New-Object System.Drawing.Point(140, 76)
$lblSort.Size = New-Object System.Drawing.Size(50, 23)
$panelTop.Controls.Add($lblSort)

$cmbSort = New-Object System.Windows.Forms.ComboBox
$cmbSort.Location = New-Object System.Drawing.Point(193, 74)
$cmbSort.Size = New-Object System.Drawing.Size(110, 23)
$cmbSort.DropDownStyle = "DropDownList"
$cmbSort.Items.AddRange(@("Name", "Date Modified", "Date Created", "Size", "Duration"))
$cmbSort.SelectedIndex = 0
$toolTip.SetToolTip($cmbSort, "How to sort files before numbering episodes")
$panelTop.Controls.Add($cmbSort)

$chkSortDesc = New-Object System.Windows.Forms.CheckBox
$chkSortDesc.Text = "Descending"
$chkSortDesc.Location = New-Object System.Drawing.Point(310, 76)
$chkSortDesc.Size = New-Object System.Drawing.Size(95, 23)
$toolTip.SetToolTip($chkSortDesc, "Reverse the sort order (Z-A, newest first, etc.)")
$panelTop.Controls.Add($chkSortDesc)

$lblAction = New-Object System.Windows.Forms.Label
$lblAction.Text = "Action:"
$lblAction.Location = New-Object System.Drawing.Point(420, 76)
$lblAction.Size = New-Object System.Drawing.Size(50, 23)
$panelTop.Controls.Add($lblAction)

$cmbAction = New-Object System.Windows.Forms.ComboBox
$cmbAction.Location = New-Object System.Drawing.Point(478, 74)
$cmbAction.Size = New-Object System.Drawing.Size(100, 23)
$cmbAction.DropDownStyle = "DropDownList"
$cmbAction.Items.AddRange(@("Rename", "Copy", "Move"))
$cmbAction.SelectedIndex = 0
$toolTip.SetToolTip($cmbAction, "Rename = change name in place. Copy = make renamed copy. Move = rename and move to new folder")
$panelTop.Controls.Add($cmbAction)

# -- Row 4: Extension Filter & Title Source ------------------------------------
$lblExtFilter = New-Object System.Windows.Forms.Label
$lblExtFilter.Text = "Extensions:"
$lblExtFilter.Location = New-Object System.Drawing.Point(12, 111)
$lblExtFilter.Size = New-Object System.Drawing.Size(70, 23)
$panelTop.Controls.Add($lblExtFilter)

$txtExtensions = New-Object System.Windows.Forms.TextBox
$txtExtensions.Location = New-Object System.Drawing.Point(85, 109)
$txtExtensions.Size = New-Object System.Drawing.Size(220, 23)
$txtExtensions.Text = ".mp4, .avi, .mkv, .mov"
$toolTip.SetToolTip($txtExtensions, "Only show files with these extensions (comma-separated)")
$panelTop.Controls.Add($txtExtensions)

$lblTitleSrc = New-Object System.Windows.Forms.Label
$lblTitleSrc.Text = "Titles:"
$lblTitleSrc.Location = New-Object System.Drawing.Point(315, 111)
$lblTitleSrc.Size = New-Object System.Drawing.Size(42, 23)
$panelTop.Controls.Add($lblTitleSrc)

$cmbTitleSource = New-Object System.Windows.Forms.ComboBox
$cmbTitleSource.Location = New-Object System.Drawing.Point(360, 109)
$cmbTitleSource.Size = New-Object System.Drawing.Size(120, 23)
$cmbTitleSource.DropDownStyle = "DropDownList"
$cmbTitleSource.Items.AddRange(@("None", "Parse from file", "Manual edit", "TMDB Lookup", "TVDB Lookup", "MAL (Jikan)"))
$cmbTitleSource.SelectedIndex = 0
$toolTip.SetToolTip($cmbTitleSource, "Where to get episode titles. TMDB/TVDB fetch from the internet (needs API key in Settings)")
$panelTop.Controls.Add($cmbTitleSource)

$lblLang = New-Object System.Windows.Forms.Label
$lblLang.Text = "Lang:"
$lblLang.Location = New-Object System.Drawing.Point(490, 111)
$lblLang.Size = New-Object System.Drawing.Size(35, 23)
$lblLang.Visible = $false
$panelTop.Controls.Add($lblLang)

$cmbLanguage = New-Object System.Windows.Forms.ComboBox
$cmbLanguage.Location = New-Object System.Drawing.Point(525, 109)
$cmbLanguage.Size = New-Object System.Drawing.Size(55, 23)
$cmbLanguage.DropDownStyle = "DropDownList"
$cmbLanguage.Items.AddRange(@("en", "ja", "ko", "zh", "de", "fr", "es", "pt", "it", "ru"))
$cmbLanguage.SelectedIndex = 0
$cmbLanguage.Visible = $false
$toolTip.SetToolTip($cmbLanguage, "Language for episode titles (en=English, ja=Japanese, etc.)")
$panelTop.Controls.Add($cmbLanguage)

$lblOrdering = New-Object System.Windows.Forms.Label
$lblOrdering.Text = "Order:"
$lblOrdering.Location = New-Object System.Drawing.Point(585, 111)
$lblOrdering.Size = New-Object System.Drawing.Size(40, 23)
$lblOrdering.Visible = $false
$panelTop.Controls.Add($lblOrdering)

$cmbOrdering = New-Object System.Windows.Forms.ComboBox
$cmbOrdering.Location = New-Object System.Drawing.Point(627, 109)
$cmbOrdering.Size = New-Object System.Drawing.Size(100, 23)
$cmbOrdering.DropDownStyle = "DropDownList"
$cmbOrdering.Visible = $false
$toolTip.SetToolTip($cmbOrdering, "Episode ordering type (TVDB: Aired/DVD/Absolute/International)")
$panelTop.Controls.Add($cmbOrdering)

$btnFetchTitles = New-Object System.Windows.Forms.Button
$btnFetchTitles.Text = "Fetch Titles"
$btnFetchTitles.Location = New-Object System.Drawing.Point(735, 108)
$btnFetchTitles.Size = New-Object System.Drawing.Size(90, 25)
$btnFetchTitles.FlatStyle = "Flat"
$btnFetchTitles.BackColor = $t.ButtonNeutral
$btnFetchTitles.ForeColor = $t.ButtonFore
$btnFetchTitles.Visible = $false
$toolTip.SetToolTip($btnFetchTitles, "Download episode titles from TMDB, TVDB, or MAL")
$panelTop.Controls.Add($btnFetchTitles)

$cmbTitleSource.Add_SelectedIndexChanged({
    $isApi = ($cmbTitleSource.SelectedItem -match "TMDB|TVDB|MAL")
    $btnFetchTitles.Visible = $isApi
    $lblLang.Visible = $isApi
    $cmbLanguage.Visible = $isApi

    # Show ordering dropdown for TVDB and TMDB
    $showOrder = ($cmbTitleSource.SelectedItem -match "TVDB|TMDB")
    $lblOrdering.Visible = $showOrder
    $cmbOrdering.Visible = $showOrder

    # Populate ordering options based on source
    $cmbOrdering.Items.Clear()
    if ($cmbTitleSource.SelectedItem -match "TVDB") {
        $cmbOrdering.Items.AddRange(@("Aired", "DVD", "Absolute", "International"))
        $cmbOrdering.SelectedIndex = 0
    } elseif ($cmbTitleSource.SelectedItem -match "TMDB") {
        $cmbOrdering.Items.Add("Default")
        $cmbOrdering.SelectedIndex = 0
    }
})

# -- Row 5: Search / Filter & Presets ------------------------------------------
$lblFilter = New-Object System.Windows.Forms.Label
$lblFilter.Text = "Filter:"
$lblFilter.Location = New-Object System.Drawing.Point(12, 144)
$lblFilter.Size = New-Object System.Drawing.Size(42, 23)
$panelTop.Controls.Add($lblFilter)

$txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Location = New-Object System.Drawing.Point(55, 142)
$txtFilter.Size = New-Object System.Drawing.Size(180, 23)
$toolTip.SetToolTip($txtFilter, "Type to filter files by name (instant search)")
$panelTop.Controls.Add($txtFilter)

$txtFilter.Add_TextChanged({
    Filter-ListView
})

$lblPreset = New-Object System.Windows.Forms.Label
$lblPreset.Text = "Preset:"
$lblPreset.Location = New-Object System.Drawing.Point(255, 144)
$lblPreset.Size = New-Object System.Drawing.Size(48, 23)
$panelTop.Controls.Add($lblPreset)

$cmbPresets = New-Object System.Windows.Forms.ComboBox
$cmbPresets.Location = New-Object System.Drawing.Point(305, 142)
$cmbPresets.Size = New-Object System.Drawing.Size(160, 23)
$cmbPresets.DropDownStyle = "DropDownList"
$toolTip.SetToolTip($cmbPresets, "Saved naming presets (template, sort, extensions, etc.)")
$panelTop.Controls.Add($cmbPresets)

$btnSavePreset = New-Object System.Windows.Forms.Button
$btnSavePreset.Text = "Save"
$btnSavePreset.Location = New-Object System.Drawing.Point(475, 141)
$btnSavePreset.Size = New-Object System.Drawing.Size(55, 25)
$btnSavePreset.FlatStyle = "Flat"
$btnSavePreset.BackColor = $t.ButtonNeutral
$btnSavePreset.ForeColor = $t.ButtonFore
$toolTip.SetToolTip($btnSavePreset, "Save current settings as a reusable preset")
$panelTop.Controls.Add($btnSavePreset)

$btnLoadPreset = New-Object System.Windows.Forms.Button
$btnLoadPreset.Text = "Load"
$btnLoadPreset.Location = New-Object System.Drawing.Point(535, 141)
$btnLoadPreset.Size = New-Object System.Drawing.Size(55, 25)
$btnLoadPreset.FlatStyle = "Flat"
$btnLoadPreset.BackColor = $t.ButtonNeutral
$btnLoadPreset.ForeColor = $t.ButtonFore
$toolTip.SetToolTip($btnLoadPreset, "Load a saved preset")
$panelTop.Controls.Add($btnLoadPreset)

# -- Row 6: Preview Text -------------------------------------------------------
$lblPreview = New-Object System.Windows.Forms.Label
$lblPreview.Text = "Preview:"
$lblPreview.Location = New-Object System.Drawing.Point(12, 178)
$lblPreview.Size = New-Object System.Drawing.Size(60, 23)
$lblPreview.Font = $fontBold
$panelTop.Controls.Add($lblPreview)

$lblPreviewText = New-Object System.Windows.Forms.Label
$lblPreviewText.Text = ""
$lblPreviewText.Location = New-Object System.Drawing.Point(75, 178)
$lblPreviewText.Size = New-Object System.Drawing.Size(700, 23)
$lblPreviewText.Anchor = "Top,Left,Right"
$lblPreviewText.Font = $fontMono
$lblPreviewText.ForeColor = $t.AccentColor
$toolTip.SetToolTip($lblPreviewText, "Example of what the first renamed file will look like")
$panelTop.Controls.Add($lblPreviewText)

$tabRename.Controls.Add($panelTop)

# -- Button Bar ----------------------------------------------------------------
$panelButtons = New-Object System.Windows.Forms.Panel
$panelButtons.Dock = "Top"
$panelButtons.Height = 42

$btnPreview = New-Object System.Windows.Forms.Button
$btnPreview.Text = "Preview"
$btnPreview.Location = New-Object System.Drawing.Point(12, 6)
$btnPreview.Size = New-Object System.Drawing.Size(80, 30)
$btnPreview.FlatStyle = "Flat"
$btnPreview.BackColor = $t.ButtonPrimary
$btnPreview.ForeColor = $t.ButtonFore
$btnPreview.Cursor = "Hand"
$btnPreview.Enabled = $false
$toolTip.SetToolTip($btnPreview, "Generate new filenames without changing anything")
$panelButtons.Controls.Add($btnPreview)

$btnRename = New-Object System.Windows.Forms.Button
$btnRename.Text = "Rename Files"
$btnRename.Location = New-Object System.Drawing.Point(100, 6)
$btnRename.Size = New-Object System.Drawing.Size(110, 30)
$btnRename.FlatStyle = "Flat"
$btnRename.BackColor = $t.ButtonSuccess
$btnRename.ForeColor = $t.ButtonFore
$btnRename.Cursor = "Hand"
$btnRename.Enabled = $false
$toolTip.SetToolTip($btnRename, "Apply the rename. Click Preview first to see changes")
$panelButtons.Controls.Add($btnRename)

$btnTestRun = New-Object System.Windows.Forms.Button
$btnTestRun.Text = "Test Run"
$btnTestRun.Location = New-Object System.Drawing.Point(218, 6)
$btnTestRun.Size = New-Object System.Drawing.Size(80, 30)
$btnTestRun.FlatStyle = "Flat"
$btnTestRun.BackColor = $t.ButtonNeutral
$btnTestRun.ForeColor = $t.ButtonFore
$btnTestRun.Cursor = "Hand"
$btnTestRun.Enabled = $false
$toolTip.SetToolTip($btnTestRun, "Preview changes and show a summary - no files are changed")
$panelButtons.Controls.Add($btnTestRun)

$btnUndo = New-Object System.Windows.Forms.Button
$btnUndo.Text = "Undo"
$btnUndo.Location = New-Object System.Drawing.Point(306, 6)
$btnUndo.Size = New-Object System.Drawing.Size(70, 30)
$btnUndo.FlatStyle = "Flat"
$btnUndo.BackColor = $t.ButtonNeutral
$btnUndo.ForeColor = $t.ButtonFore
$btnUndo.Cursor = "Hand"
$btnUndo.Enabled = $false
$toolTip.SetToolTip($btnUndo, "Reverse the last rename operation")
$panelButtons.Controls.Add($btnUndo)

$btnExportLog = New-Object System.Windows.Forms.Button
$btnExportLog.Text = "Export Log"
$btnExportLog.Location = New-Object System.Drawing.Point(384, 6)
$btnExportLog.Size = New-Object System.Drawing.Size(90, 30)
$btnExportLog.FlatStyle = "Flat"
$btnExportLog.BackColor = $t.ButtonNeutral
$btnExportLog.ForeColor = $t.ButtonFore
$btnExportLog.Cursor = "Hand"
$btnExportLog.Enabled = $false
$toolTip.SetToolTip($btnExportLog, "Save a log of all renames to a text or CSV file")
$panelButtons.Controls.Add($btnExportLog)

$btnReset = New-Object System.Windows.Forms.Button
$btnReset.Text = "Reset"
$btnReset.Location = New-Object System.Drawing.Point(482, 6)
$btnReset.Size = New-Object System.Drawing.Size(70, 30)
$btnReset.FlatStyle = "Flat"
$btnReset.BackColor = $t.ButtonNeutral
$btnReset.ForeColor = $t.ButtonFore
$btnReset.Cursor = "Hand"
$toolTip.SetToolTip($btnReset, "Clear everything and start fresh")
$panelButtons.Controls.Add($btnReset)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh"
$btnRefresh.Location = New-Object System.Drawing.Point(560, 6)
$btnRefresh.Size = New-Object System.Drawing.Size(75, 30)
$btnRefresh.FlatStyle = "Flat"
$btnRefresh.BackColor = $t.ButtonNeutral
$btnRefresh.ForeColor = $t.ButtonFore
$btnRefresh.Cursor = "Hand"
$btnRefresh.Enabled = $false
$toolTip.SetToolTip($btnRefresh, "Rescan current season. Hold Shift + click to rescan all seasons")
$panelButtons.Controls.Add($btnRefresh)

$btnThemeToggle = New-Object System.Windows.Forms.Button
$btnThemeToggle.Text = if ((Get-ThemeName) -eq "Dark") { "Light" } else { "Dark" }
$btnThemeToggle.Location = New-Object System.Drawing.Point(820, 6)
$btnThemeToggle.Anchor = "Top,Right"
$btnThemeToggle.Size = New-Object System.Drawing.Size(80, 30)
$btnThemeToggle.FlatStyle = "Flat"
$btnThemeToggle.BackColor = $t.ButtonNeutral
$btnThemeToggle.ForeColor = $t.ButtonFore
$btnThemeToggle.Cursor = "Hand"
$toolTip.SetToolTip($btnThemeToggle, "Switch between dark and light theme")
$panelButtons.Controls.Add($btnThemeToggle)

$tabRename.Controls.Add($panelButtons)

# -- Progress Bar --------------------------------------------------------------
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Dock = "Top"
$progressBar.Height = 4
$progressBar.Style = "Continuous"
$progressBar.Visible = $false
$tabRename.Controls.Add($progressBar)

# -- SplitContainer: Tree (left) + Grid (right) --------------------------------
$splitContainer = New-Object System.Windows.Forms.SplitContainer
$splitContainer.Dock = "Fill"
$splitContainer.Orientation = "Vertical"
$splitContainer.SplitterWidth = 5
$splitContainer.FixedPanel = "None"
$splitContainer.BorderStyle = "None"
$splitContainer.Panel1MinSize = 30
$splitContainer.Panel2MinSize = 100
$splitContainer.SplitterDistance = 200

# -- Season Tree (left panel) --------------------------------------------------
$seasonTree = New-Object System.Windows.Forms.TreeView
$seasonTree.Dock = "Fill"
$seasonTree.Font = $fontNormal
$seasonTree.CheckBoxes = $true
$seasonTree.HideSelection = $false
$seasonTree.ShowLines = $true
$seasonTree.ShowPlusMinus = $true
$seasonTree.ShowRootLines = $true
$seasonTree.FullRowSelect = $true
$toolTip.SetToolTip($seasonTree, "Click a season to view files. Check seasons for batch rename")

$splitContainer.Panel1.Controls.Add($seasonTree)

# -- File Grid (right panel) ---------------------------------------------------
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = "Fill"
$grid.AllowDrop = $true
$grid.Font = $fontSmall
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToResizeColumns = $true
$grid.AllowUserToResizeRows = $false
$grid.AllowUserToOrderColumns = $true
$grid.AutoSizeColumnsMode = "None"
$grid.SelectionMode = "FullRowSelect"
$grid.MultiSelect = $true
$grid.RowHeadersVisible = $false
$grid.ColumnHeadersHeightSizeMode = "AutoSize"
$grid.EnableHeadersVisualStyles = $false
$grid.ColumnHeadersDefaultCellStyle.Alignment = "MiddleCenter"
$grid.ScrollBars = "Both"
$grid.BorderStyle = "None"
$grid.ColumnHeadersVisible = $true
$grid.AutoGenerateColumns = $false
$grid.EditMode = "EditOnEnter"

# Track header checkbox state
$script:HeaderCheckState = $true

# Columns
$colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$colCheck.Name = "Include"
$colCheck.HeaderText = [string][char]0x2611
$colCheck.Width = 35
$colCheck.Resizable = "False"
$colCheck.SortMode = "NotSortable"
$grid.Columns.Add($colCheck) | Out-Null

$colNum = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colNum.Name = "Num"
$colNum.HeaderText = "#"
$colNum.Width = 45
$colNum.Resizable = "False"
$colNum.ReadOnly = $true
$grid.Columns.Add($colNum) | Out-Null

$colOrig = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colOrig.Name = "OriginalName"
$colOrig.HeaderText = "Original Name"
$colOrig.MinimumWidth = 100
$colOrig.FillWeight = 35
$colOrig.AutoSizeMode = "Fill"
$colOrig.ReadOnly = $true
$grid.Columns.Add($colOrig) | Out-Null

$colNew = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colNew.Name = "NewName"
$colNew.HeaderText = "New Name"
$colNew.MinimumWidth = 100
$colNew.FillWeight = 35
$colNew.AutoSizeMode = "Fill"
$colNew.ReadOnly = $true
$grid.Columns.Add($colNew) | Out-Null

$colTitle = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colTitle.Name = "EpisodeTitle"
$colTitle.HeaderText = "Episode Title"
$colTitle.MinimumWidth = 80
$colTitle.FillWeight = 20
$colTitle.AutoSizeMode = "Fill"
$colTitle.ReadOnly = $false
$grid.Columns.Add($colTitle) | Out-Null

$colSize = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colSize.Name = "Size"
$colSize.HeaderText = "Size"
$colSize.Width = 75
$colSize.ReadOnly = $true
$grid.Columns.Add($colSize) | Out-Null

$colDuration = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colDuration.Name = "Duration"
$colDuration.HeaderText = "Duration"
$colDuration.Width = 70
$colDuration.ReadOnly = $true
$grid.Columns.Add($colDuration) | Out-Null

$colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colStatus.Name = "Status"
$colStatus.HeaderText = "Status"
$colStatus.Width = 90
$colStatus.ReadOnly = $true
$grid.Columns.Add($colStatus) | Out-Null

$splitContainer.Panel2.Controls.Add($grid)

# -- Color Legend Bar ----------------------------------------------------------
$panelLegend = New-Object System.Windows.Forms.Panel
$panelLegend.Dock = "Bottom"
$panelLegend.Height = 22
$panelLegend.BackColor = $t.FormBack

function Build-LegendLabel {
    param([string]$Text, [System.Drawing.Color]$Color, [int]$X)
    $swatch = New-Object System.Windows.Forms.Panel
    $swatch.Location = New-Object System.Drawing.Point($X, 4)
    $swatch.Size = New-Object System.Drawing.Size(14, 14)
    $swatch.BackColor = $Color
    $swatch.BorderStyle = "FixedSingle"
    $panelLegend.Controls.Add($swatch)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.Location = New-Object System.Drawing.Point(($X + 17), 4)
    $lbl.Size = New-Object System.Drawing.Size(80, 16)
    $lbl.Font = $fontLegend
    $panelLegend.Controls.Add($lbl)
    return ($X + 100)
}

$nextX = 12
$nextX = Build-LegendLabel -Text "Will Rename" -Color $t.RowHighlight -X $nextX
$nextX = Build-LegendLabel -Text "Done" -Color $t.RowSuccess -X $nextX
$nextX = Build-LegendLabel -Text "Warning" -Color $t.RowWarning -X $nextX
$nextX = Build-LegendLabel -Text "Error" -Color $t.RowError -X $nextX
$nextX = Build-LegendLabel -Text "No Change" -Color $t.ListBack -X $nextX

$splitContainer.Panel2.Controls.Add($panelLegend)

$tabRename.Controls.Add($splitContainer)

# -- Status Bar ----------------------------------------------------------------
$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusBar.Dock = "Bottom"
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Ready - Click Browse to select a show folder"
$statusLabel.Spring = $true
$statusLabel.TextAlign = "MiddleLeft"
$statusBar.Items.Add($statusLabel) | Out-Null
$statusCountLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusCountLabel.Text = ""
$statusBar.Items.Add($statusCountLabel) | Out-Null
$tabRename.Controls.Add($statusBar)

# -- Docking order -------------------------------------------------------------
$splitContainer.SendToBack()
$statusBar.SendToBack()
$progressBar.SendToBack()
$panelButtons.SendToBack()
$panelTop.SendToBack()

# -- Context Menu --------------------------------------------------------------
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$menuRenameThis = $contextMenu.Items.Add("Rename This File")
$menuRenameSelected = $contextMenu.Items.Add("Rename Selected Files")
$contextMenu.Items.Add("-") | Out-Null
$menuEditTitle = $contextMenu.Items.Add("Edit Episode Title (F2 or double-click)")
$menuExclude   = $contextMenu.Items.Add("Exclude / Include")
$contextMenu.Items.Add("-") | Out-Null
$menuMoveUp    = $contextMenu.Items.Add("Move Up")
$menuMoveDown  = $contextMenu.Items.Add("Move Down")
$grid.ContextMenuStrip = $contextMenu

# ===============================================================================
# TAB 2: ORGANIZE
# ===============================================================================

# -- Organize State
$script:OrganizeFiles = @()
$script:OrganizeRollback = @()
$script:OrgSeasonMap = @()
$script:OrgSelectedShowId = ""
$script:OrgSelectedShowName = ""
$script:OrgSelectedShowYear = ""
$script:OrgSelectedSource = ""

# -- Top Panel -----------------------------------------------------------------
$orgPanelTop = New-Object System.Windows.Forms.Panel
$orgPanelTop.Dock = "Top"
$orgPanelTop.Height = 140

$lblOrgInfo = New-Object System.Windows.Forms.Label
$lblOrgInfo.Text = "Scan a folder of mixed/random files. The app detects show names, seasons, and episodes, then organizes them into folders."
$lblOrgInfo.Location = New-Object System.Drawing.Point(12, 8)
$lblOrgInfo.Size = New-Object System.Drawing.Size(800, 20)
$lblOrgInfo.Font = $fontSmall
$lblOrgInfo.ForeColor = $t.AccentColor
$orgPanelTop.Controls.Add($lblOrgInfo)

# Row 1: Source folder
$lblOrgSource = New-Object System.Windows.Forms.Label
$lblOrgSource.Text = "Source:"
$lblOrgSource.Location = New-Object System.Drawing.Point(12, 36)
$lblOrgSource.Size = New-Object System.Drawing.Size(55, 23)
$orgPanelTop.Controls.Add($lblOrgSource)

$txtOrgSource = New-Object System.Windows.Forms.TextBox
$txtOrgSource.Location = New-Object System.Drawing.Point(70, 34)
$txtOrgSource.Size = New-Object System.Drawing.Size(750, 23)
$txtOrgSource.Anchor = "Top,Left,Right"
$txtOrgSource.ReadOnly = $true
$toolTip.SetToolTip($txtOrgSource, "The folder containing your mixed/random files")
$orgPanelTop.Controls.Add($txtOrgSource)

$btnOrgBrowseSource = New-Object System.Windows.Forms.Button
$btnOrgBrowseSource.Text = "Browse..."
$btnOrgBrowseSource.Location = New-Object System.Drawing.Point(830, 32)
$btnOrgBrowseSource.Anchor = "Top,Right"
$btnOrgBrowseSource.Size = New-Object System.Drawing.Size(85, 27)
$btnOrgBrowseSource.FlatStyle = "Flat"
$btnOrgBrowseSource.BackColor = $t.ButtonPrimary
$btnOrgBrowseSource.ForeColor = $t.ButtonFore
$btnOrgBrowseSource.Cursor = "Hand"
$toolTip.SetToolTip($btnOrgBrowseSource, "Select the folder with random/mixed episode files")
$orgPanelTop.Controls.Add($btnOrgBrowseSource)

# Row 2: Destination folder
$lblOrgDest = New-Object System.Windows.Forms.Label
$lblOrgDest.Text = "Dest:"
$lblOrgDest.Location = New-Object System.Drawing.Point(12, 68)
$lblOrgDest.Size = New-Object System.Drawing.Size(55, 23)
$orgPanelTop.Controls.Add($lblOrgDest)

$txtOrgDest = New-Object System.Windows.Forms.TextBox
$txtOrgDest.Location = New-Object System.Drawing.Point(70, 66)
$txtOrgDest.Size = New-Object System.Drawing.Size(750, 23)
$txtOrgDest.Anchor = "Top,Left,Right"
$txtOrgDest.ReadOnly = $true
$toolTip.SetToolTip($txtOrgDest, "Where to create the organized show/season folders (e.g. your TV Shows folder)")
$orgPanelTop.Controls.Add($txtOrgDest)

$btnOrgBrowseDest = New-Object System.Windows.Forms.Button
$btnOrgBrowseDest.Text = "Browse..."
$btnOrgBrowseDest.Location = New-Object System.Drawing.Point(830, 64)
$btnOrgBrowseDest.Anchor = "Top,Right"
$btnOrgBrowseDest.Size = New-Object System.Drawing.Size(85, 27)
$btnOrgBrowseDest.FlatStyle = "Flat"
$btnOrgBrowseDest.BackColor = $t.ButtonPrimary
$btnOrgBrowseDest.ForeColor = $t.ButtonFore
$btnOrgBrowseDest.Cursor = "Hand"
$toolTip.SetToolTip($btnOrgBrowseDest, "Select your main TV Shows / Anime folder")
$orgPanelTop.Controls.Add($btnOrgBrowseDest)

# Row 3: Season Lookup
$lblOrgLookup = New-Object System.Windows.Forms.Label
$lblOrgLookup.Text = "Lookup:"
$lblOrgLookup.Location = New-Object System.Drawing.Point(12, 100)
$lblOrgLookup.Size = New-Object System.Drawing.Size(55, 23)
$orgPanelTop.Controls.Add($lblOrgLookup)

$cmbOrgSource = New-Object System.Windows.Forms.ComboBox
$cmbOrgSource.Location = New-Object System.Drawing.Point(70, 98)
$cmbOrgSource.Size = New-Object System.Drawing.Size(110, 23)
$cmbOrgSource.DropDownStyle = "DropDownList"
$cmbOrgSource.Items.AddRange(@("TMDB", "TVDB", "MAL (Jikan)"))
$cmbOrgSource.SelectedIndex = 1
$toolTip.SetToolTip($cmbOrgSource, "Source for season map lookup")
$orgPanelTop.Controls.Add($cmbOrgSource)

$lblOrgOrder = New-Object System.Windows.Forms.Label
$lblOrgOrder.Text = "Order:"
$lblOrgOrder.Location = New-Object System.Drawing.Point(188, 100)
$lblOrgOrder.Size = New-Object System.Drawing.Size(40, 23)
$orgPanelTop.Controls.Add($lblOrgOrder)

$cmbOrgOrdering = New-Object System.Windows.Forms.ComboBox
$cmbOrgOrdering.Location = New-Object System.Drawing.Point(230, 98)
$cmbOrgOrdering.Size = New-Object System.Drawing.Size(105, 23)
$cmbOrgOrdering.DropDownStyle = "DropDownList"
$cmbOrgOrdering.Items.AddRange(@("Aired", "DVD", "Absolute", "International"))
$cmbOrgOrdering.SelectedIndex = 0
$toolTip.SetToolTip($cmbOrgOrdering, "Episode ordering type for TVDB")
$orgPanelTop.Controls.Add($cmbOrgOrdering)

$btnOrgFetchMap = New-Object System.Windows.Forms.Button
$btnOrgFetchMap.Text = "Fetch Season Map"
$btnOrgFetchMap.Location = New-Object System.Drawing.Point(345, 96)
$btnOrgFetchMap.Size = New-Object System.Drawing.Size(120, 25)
$btnOrgFetchMap.FlatStyle = "Flat"
$btnOrgFetchMap.BackColor = $t.ButtonNeutral
$btnOrgFetchMap.ForeColor = $t.ButtonFore
$btnOrgFetchMap.Cursor = "Hand"
$toolTip.SetToolTip($btnOrgFetchMap, "Fetch season breakdown from API to auto-map episode numbers")
$orgPanelTop.Controls.Add($btnOrgFetchMap)

$lblOrgMapInfo = New-Object System.Windows.Forms.Label
$lblOrgMapInfo.Text = ""
$lblOrgMapInfo.Location = New-Object System.Drawing.Point(475, 100)
$lblOrgMapInfo.Size = New-Object System.Drawing.Size(400, 20)
$lblOrgMapInfo.Font = $fontSmall
$lblOrgMapInfo.ForeColor = $t.AccentColor
$lblOrgMapInfo.Anchor = "Top,Left,Right"
$orgPanelTop.Controls.Add($lblOrgMapInfo)

$cmbOrgSource.Add_SelectedIndexChanged({
    $isTvdb = ($cmbOrgSource.SelectedItem -match "TVDB")
    $lblOrgOrder.Visible = $isTvdb
    $cmbOrgOrdering.Visible = $isTvdb
})

$chkAbsoluteMode = New-Object System.Windows.Forms.CheckBox
$chkAbsoluteMode.Text = "Treat as Absolute"
$chkAbsoluteMode.Location = New-Object System.Drawing.Point(475, 100)
$chkAbsoluteMode.Size = New-Object System.Drawing.Size(130, 20)
$chkAbsoluteMode.Checked = $false
$toolTip.SetToolTip($chkAbsoluteMode, "Episode numbers are absolute (continuous across seasons). Auto-Map will convert to season/episode.")
$orgPanelTop.Controls.Add($chkAbsoluteMode)

$chkPlexNaming = New-Object System.Windows.Forms.CheckBox
$chkPlexNaming.Text = "Plex naming"
$chkPlexNaming.Location = New-Object System.Drawing.Point(610, 100)
$chkPlexNaming.Size = New-Object System.Drawing.Size(105, 20)
$chkPlexNaming.Checked = $false
$toolTip.SetToolTip($chkPlexNaming, "Use Plex-style folder: Show Name (Year) {tvdb-ID} or {tmdb-ID}")
$orgPanelTop.Controls.Add($chkPlexNaming)

$lblOrgMapInfo.Location = New-Object System.Drawing.Point(12, 122)
$lblOrgMapInfo.Size = New-Object System.Drawing.Size(900, 18)

$tabOrganize.Controls.Add($orgPanelTop)

# -- Button Bar ----------------------------------------------------------------
$orgPanelButtons = New-Object System.Windows.Forms.Panel
$orgPanelButtons.Dock = "Top"
$orgPanelButtons.Height = 42

$btnOrgScan = New-Object System.Windows.Forms.Button
$btnOrgScan.Text = "Scan Files"
$btnOrgScan.Location = New-Object System.Drawing.Point(12, 6)
$btnOrgScan.Size = New-Object System.Drawing.Size(100, 30)
$btnOrgScan.FlatStyle = "Flat"
$btnOrgScan.BackColor = $t.ButtonPrimary
$btnOrgScan.ForeColor = $t.ButtonFore
$btnOrgScan.Cursor = "Hand"
$btnOrgScan.Enabled = $false
$toolTip.SetToolTip($btnOrgScan, "Scan the source folder and detect shows/seasons/episodes")
$orgPanelButtons.Controls.Add($btnOrgScan)

$btnOrgPreview = New-Object System.Windows.Forms.Button
$btnOrgPreview.Text = "Preview"
$btnOrgPreview.Location = New-Object System.Drawing.Point(120, 6)
$btnOrgPreview.Size = New-Object System.Drawing.Size(85, 30)
$btnOrgPreview.FlatStyle = "Flat"
$btnOrgPreview.BackColor = $t.ButtonNeutral
$btnOrgPreview.ForeColor = $t.ButtonFore
$btnOrgPreview.Cursor = "Hand"
$btnOrgPreview.Enabled = $false
$toolTip.SetToolTip($btnOrgPreview, "Generate target paths - see where files will end up")
$orgPanelButtons.Controls.Add($btnOrgPreview)

$btnOrgExecute = New-Object System.Windows.Forms.Button
$btnOrgExecute.Text = "Organize Files"
$btnOrgExecute.Location = New-Object System.Drawing.Point(213, 6)
$btnOrgExecute.Size = New-Object System.Drawing.Size(120, 30)
$btnOrgExecute.FlatStyle = "Flat"
$btnOrgExecute.BackColor = $t.ButtonSuccess
$btnOrgExecute.ForeColor = $t.ButtonFore
$btnOrgExecute.Cursor = "Hand"
$btnOrgExecute.Enabled = $false
$toolTip.SetToolTip($btnOrgExecute, "Move and rename files into organized show/season folders")
$orgPanelButtons.Controls.Add($btnOrgExecute)

$btnOrgUndo = New-Object System.Windows.Forms.Button
$btnOrgUndo.Text = "Undo"
$btnOrgUndo.Location = New-Object System.Drawing.Point(341, 6)
$btnOrgUndo.Size = New-Object System.Drawing.Size(70, 30)
$btnOrgUndo.FlatStyle = "Flat"
$btnOrgUndo.BackColor = $t.ButtonNeutral
$btnOrgUndo.ForeColor = $t.ButtonFore
$btnOrgUndo.Cursor = "Hand"
$btnOrgUndo.Enabled = $false
$toolTip.SetToolTip($btnOrgUndo, "Move files back to their original locations")
$orgPanelButtons.Controls.Add($btnOrgUndo)

$btnOrgClear = New-Object System.Windows.Forms.Button
$btnOrgClear.Text = "Clear"
$btnOrgClear.Location = New-Object System.Drawing.Point(419, 6)
$btnOrgClear.Size = New-Object System.Drawing.Size(70, 30)
$btnOrgClear.FlatStyle = "Flat"
$btnOrgClear.BackColor = $t.ButtonNeutral
$btnOrgClear.ForeColor = $t.ButtonFore
$btnOrgClear.Cursor = "Hand"
$toolTip.SetToolTip($btnOrgClear, "Clear the scan results and start over")
$orgPanelButtons.Controls.Add($btnOrgClear)

$btnOrgAutoMap = New-Object System.Windows.Forms.Button
$btnOrgAutoMap.Text = "Auto-Map"
$btnOrgAutoMap.Location = New-Object System.Drawing.Point(497, 6)
$btnOrgAutoMap.Size = New-Object System.Drawing.Size(90, 30)
$btnOrgAutoMap.FlatStyle = "Flat"
$btnOrgAutoMap.BackColor = $t.ButtonNeutral
$btnOrgAutoMap.ForeColor = $t.ButtonFore
$btnOrgAutoMap.Cursor = "Hand"
$btnOrgAutoMap.Enabled = $false
$toolTip.SetToolTip($btnOrgAutoMap, "Auto-map absolute episode numbers to correct seasons using the fetched season map")
$orgPanelButtons.Controls.Add($btnOrgAutoMap)

$btnOrgBatchAssign = New-Object System.Windows.Forms.Button
$btnOrgBatchAssign.Text = "Batch Assign"
$btnOrgBatchAssign.Location = New-Object System.Drawing.Point(595, 6)
$btnOrgBatchAssign.Size = New-Object System.Drawing.Size(100, 30)
$btnOrgBatchAssign.FlatStyle = "Flat"
$btnOrgBatchAssign.BackColor = $t.ButtonNeutral
$btnOrgBatchAssign.ForeColor = $t.ButtonFore
$btnOrgBatchAssign.Cursor = "Hand"
$btnOrgBatchAssign.Enabled = $false
$toolTip.SetToolTip($btnOrgBatchAssign, "Assign selected rows to a specific season")
$orgPanelButtons.Controls.Add($btnOrgBatchAssign)

$tabOrganize.Controls.Add($orgPanelButtons)

# -- Progress ------------------------------------------------------------------
$orgProgressBar = New-Object System.Windows.Forms.ProgressBar
$orgProgressBar.Dock = "Top"
$orgProgressBar.Height = 4
$orgProgressBar.Style = "Continuous"
$orgProgressBar.Visible = $false
$tabOrganize.Controls.Add($orgProgressBar)

# -- Season Reference Panel ----------------------------------------------------
$orgSeasonPanel = New-Object System.Windows.Forms.Panel
$orgSeasonPanel.Dock = "Top"
$orgSeasonPanel.Height = 60
$orgSeasonPanel.Visible = $false

$txtOrgSeasonRef = New-Object System.Windows.Forms.TextBox
$txtOrgSeasonRef.Dock = "Fill"
$txtOrgSeasonRef.Multiline = $true
$txtOrgSeasonRef.ReadOnly = $true
$txtOrgSeasonRef.ScrollBars = "Horizontal"
$txtOrgSeasonRef.Font = $fontSmall
$txtOrgSeasonRef.BackColor = $t.ControlBack
$txtOrgSeasonRef.ForeColor = $t.AccentColor
$orgSeasonPanel.Controls.Add($txtOrgSeasonRef)

$tabOrganize.Controls.Add($orgSeasonPanel)

# -- Grid ----------------------------------------------------------------------
$orgGrid = New-Object System.Windows.Forms.DataGridView
$orgGrid.Dock = "Fill"
$orgGrid.Font = $fontSmall
$orgGrid.AllowUserToAddRows = $false
$orgGrid.AllowUserToDeleteRows = $false
$orgGrid.AllowUserToResizeColumns = $true
$orgGrid.AllowUserToResizeRows = $false
$orgGrid.AutoSizeColumnsMode = "None"
$orgGrid.SelectionMode = "FullRowSelect"
$orgGrid.MultiSelect = $true
$orgGrid.RowHeadersVisible = $false
$orgGrid.ColumnHeadersHeightSizeMode = "AutoSize"
$orgGrid.EnableHeadersVisualStyles = $false
$orgGrid.ColumnHeadersDefaultCellStyle.Alignment = "MiddleCenter"
$orgGrid.ScrollBars = "Both"
$orgGrid.BorderStyle = "None"
$orgGrid.AutoGenerateColumns = $false
$orgGrid.EditMode = "EditOnEnter"

$orgColCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$orgColCheck.Name = "OrgInclude"
$orgColCheck.HeaderText = [string][char]0x2611
$orgColCheck.Width = 35
$orgColCheck.Resizable = "False"
$orgGrid.Columns.Add($orgColCheck) | Out-Null

$orgColOrig = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$orgColOrig.Name = "OrgOriginal"
$orgColOrig.HeaderText = "Original File"
$orgColOrig.MinimumWidth = 100
$orgColOrig.FillWeight = 30
$orgColOrig.AutoSizeMode = "Fill"
$orgColOrig.ReadOnly = $true
$orgGrid.Columns.Add($orgColOrig) | Out-Null

$orgColShow = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$orgColShow.Name = "OrgShow"
$orgColShow.HeaderText = "Detected Show"
$orgColShow.MinimumWidth = 80
$orgColShow.FillWeight = 25
$orgColShow.AutoSizeMode = "Fill"
$orgColShow.ReadOnly = $false
$orgGrid.Columns.Add($orgColShow) | Out-Null

$orgColSeason = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$orgColSeason.Name = "OrgSeason"
$orgColSeason.HeaderText = "S#"
$orgColSeason.Width = 40
$orgColSeason.Resizable = "False"
$orgColSeason.ReadOnly = $false
$orgGrid.Columns.Add($orgColSeason) | Out-Null

$orgColEpisode = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$orgColEpisode.Name = "OrgEpisode"
$orgColEpisode.HeaderText = "Ep#"
$orgColEpisode.Width = 45
$orgColEpisode.Resizable = "False"
$orgColEpisode.ReadOnly = $false
$orgGrid.Columns.Add($orgColEpisode) | Out-Null

$orgColTarget = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$orgColTarget.Name = "OrgTarget"
$orgColTarget.HeaderText = "Target Path"
$orgColTarget.MinimumWidth = 100
$orgColTarget.FillWeight = 35
$orgColTarget.AutoSizeMode = "Fill"
$orgColTarget.ReadOnly = $true
$orgGrid.Columns.Add($orgColTarget) | Out-Null

$orgColSize = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$orgColSize.Name = "OrgSize"
$orgColSize.HeaderText = "Size"
$orgColSize.Width = 75
$orgColSize.ReadOnly = $true
$orgGrid.Columns.Add($orgColSize) | Out-Null

$orgColStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$orgColStatus.Name = "OrgStatus"
$orgColStatus.HeaderText = "Status"
$orgColStatus.Width = 100
$orgColStatus.ReadOnly = $true
$orgGrid.Columns.Add($orgColStatus) | Out-Null

$tabOrganize.Controls.Add($orgGrid)

# -- Organize Status Bar -------------------------------------------------------
$orgStatusBar = New-Object System.Windows.Forms.StatusStrip
$orgStatusBar.Dock = "Bottom"
$orgStatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$orgStatusLabel.Text = "Browse to a source folder and set destination, then click Scan"
$orgStatusLabel.Spring = $true
$orgStatusLabel.TextAlign = "MiddleLeft"
$orgStatusBar.Items.Add($orgStatusLabel) | Out-Null
$orgStatusCountLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$orgStatusCountLabel.Text = ""
$orgStatusBar.Items.Add($orgStatusCountLabel) | Out-Null
$tabOrganize.Controls.Add($orgStatusBar)

# -- Organize Docking Order
$orgGrid.SendToBack()
$orgStatusBar.SendToBack()
$orgSeasonPanel.SendToBack()
$orgProgressBar.SendToBack()
$orgPanelButtons.SendToBack()
$orgPanelTop.SendToBack()

# ===============================================================================
# TAB 3: SETTINGS
# ===============================================================================

# -- Template Group ------------------------------------------------------------
$grpTemplate = New-Object System.Windows.Forms.GroupBox
$grpTemplate.Text = "Naming Template"
$grpTemplate.Location = New-Object System.Drawing.Point(12, 12)
$grpTemplate.Size = New-Object System.Drawing.Size(750, 190)
$tabSettings.Controls.Add($grpTemplate)

$lblVars = New-Object System.Windows.Forms.Label
$lblVars.Text = "Variables:  {show}  {season}  {episode}  {ep_range}  {title}  {total}  {original}  {ext}"
$lblVars.Location = New-Object System.Drawing.Point(15, 25)
$lblVars.Size = New-Object System.Drawing.Size(700, 20)
$lblVars.Font = $fontMono
$lblVars.ForeColor = $t.AccentColor
$grpTemplate.Controls.Add($lblVars)

$lblTmplEdit = New-Object System.Windows.Forms.Label
$lblTmplEdit.Text = "Template:"
$lblTmplEdit.Location = New-Object System.Drawing.Point(15, 55)
$lblTmplEdit.Size = New-Object System.Drawing.Size(65, 23)
$grpTemplate.Controls.Add($lblTmplEdit)

$txtTemplate = New-Object System.Windows.Forms.TextBox
$txtTemplate.Location = New-Object System.Drawing.Point(85, 53)
$txtTemplate.Size = New-Object System.Drawing.Size(500, 23)
$txtTemplate.Text = "{show} - S{season}E{episode}"
$txtTemplate.Font = $fontMono
$toolTip.SetToolTip($txtTemplate, "The pattern for new filenames. Use {variables} as placeholders")
$grpTemplate.Controls.Add($txtTemplate)

$lblTmplPreview = New-Object System.Windows.Forms.Label
$lblTmplPreview.Text = "Preview (no title):"
$lblTmplPreview.Location = New-Object System.Drawing.Point(15, 88)
$lblTmplPreview.Size = New-Object System.Drawing.Size(120, 20)
$grpTemplate.Controls.Add($lblTmplPreview)

$lblTmplPreviewVal = New-Object System.Windows.Forms.Label
$lblTmplPreviewVal.Text = ""
$lblTmplPreviewVal.Location = New-Object System.Drawing.Point(140, 88)
$lblTmplPreviewVal.Size = New-Object System.Drawing.Size(500, 20)
$lblTmplPreviewVal.Font = $fontMono
$lblTmplPreviewVal.ForeColor = $t.AccentColor
$grpTemplate.Controls.Add($lblTmplPreviewVal)

$lblTmplPreview2 = New-Object System.Windows.Forms.Label
$lblTmplPreview2.Text = "Preview (with title):"
$lblTmplPreview2.Location = New-Object System.Drawing.Point(15, 112)
$lblTmplPreview2.Size = New-Object System.Drawing.Size(120, 20)
$grpTemplate.Controls.Add($lblTmplPreview2)

$lblTmplPreviewVal2 = New-Object System.Windows.Forms.Label
$lblTmplPreviewVal2.Text = ""
$lblTmplPreviewVal2.Location = New-Object System.Drawing.Point(140, 112)
$lblTmplPreviewVal2.Size = New-Object System.Drawing.Size(500, 20)
$lblTmplPreviewVal2.Font = $fontMono
$lblTmplPreviewVal2.ForeColor = $t.AccentColor
$grpTemplate.Controls.Add($lblTmplPreviewVal2)

$txtTemplate.Add_TextChanged({
    $showN = if ($txtShowName.Text) { $txtShowName.Text } else { "Show Name" }
    $p = Get-TemplatePreview -Template $txtTemplate.Text -ShowName $showN -Season ([int]$numSeason.Value) -Episode 1 -Title "Episode Title"
    $lblTmplPreviewVal.Text = $p.WithoutTitle
    $lblTmplPreviewVal2.Text = $p.WithTitle
})

$lblTmplExamples = New-Object System.Windows.Forms.Label
$lblTmplExamples.Text = @'
  {show} - S{season}E{episode}                         -> Show - S01E01.mp4
  {show} - S{season}E{episode} - {title}               -> Show - S01E01 - Title.mp4
  S{season}E{episode} - {show}                         -> S01E01 - Show.mp4
'@
$lblTmplExamples.Location = New-Object System.Drawing.Point(15, 138)
$lblTmplExamples.Size = New-Object System.Drawing.Size(720, 45)
$lblTmplExamples.Font = $fontMono
$grpTemplate.Controls.Add($lblTmplExamples)

$btnSaveTemplate = New-Object System.Windows.Forms.Button
$btnSaveTemplate.Text = "Save Template"
$btnSaveTemplate.Location = New-Object System.Drawing.Point(600, 51)
$btnSaveTemplate.Size = New-Object System.Drawing.Size(130, 27)
$btnSaveTemplate.FlatStyle = "Flat"
$btnSaveTemplate.BackColor = $t.ButtonSuccess
$btnSaveTemplate.ForeColor = $t.ButtonFore
$btnSaveTemplate.Cursor = "Hand"
$toolTip.SetToolTip($btnSaveTemplate, "Save this template so it persists between sessions")
$grpTemplate.Controls.Add($btnSaveTemplate)

# -- API Keys Group ------------------------------------------------------------
$grpApi = New-Object System.Windows.Forms.GroupBox
$grpApi.Text = "API Keys (Episode Title Lookup)"
$grpApi.Location = New-Object System.Drawing.Point(12, 212)
$grpApi.Size = New-Object System.Drawing.Size(750, 110)
$tabSettings.Controls.Add($grpApi)

$lblTmdbKey = New-Object System.Windows.Forms.Label
$lblTmdbKey.Text = "TMDB API Key:"
$lblTmdbKey.Location = New-Object System.Drawing.Point(15, 30)
$lblTmdbKey.Size = New-Object System.Drawing.Size(100, 23)
$grpApi.Controls.Add($lblTmdbKey)

$txtTmdbKey = New-Object System.Windows.Forms.TextBox
$txtTmdbKey.Location = New-Object System.Drawing.Point(120, 28)
$txtTmdbKey.Size = New-Object System.Drawing.Size(400, 23)
$txtTmdbKey.Text = $script:Settings.TmdbApiKey
$txtTmdbKey.UseSystemPasswordChar = $true
$toolTip.SetToolTip($txtTmdbKey, "Get a free key at themoviedb.org/settings/api")
$grpApi.Controls.Add($txtTmdbKey)

$lblTvdbKey = New-Object System.Windows.Forms.Label
$lblTvdbKey.Text = "TVDB API Key:"
$lblTvdbKey.Location = New-Object System.Drawing.Point(15, 63)
$lblTvdbKey.Size = New-Object System.Drawing.Size(100, 23)
$grpApi.Controls.Add($lblTvdbKey)

$txtTvdbKey = New-Object System.Windows.Forms.TextBox
$txtTvdbKey.Location = New-Object System.Drawing.Point(120, 61)
$txtTvdbKey.Size = New-Object System.Drawing.Size(400, 23)
$txtTvdbKey.Text = $script:Settings.TvdbApiKey
$txtTvdbKey.UseSystemPasswordChar = $true
$toolTip.SetToolTip($txtTvdbKey, "Get a key at thetvdb.com/api-information")
$grpApi.Controls.Add($txtTvdbKey)

$btnShowKeys = New-Object System.Windows.Forms.Button
$btnShowKeys.Text = "Show"
$btnShowKeys.Location = New-Object System.Drawing.Point(530, 28)
$btnShowKeys.Size = New-Object System.Drawing.Size(55, 23)
$btnShowKeys.FlatStyle = "Flat"
$btnShowKeys.BackColor = $t.ButtonNeutral
$btnShowKeys.ForeColor = $t.ButtonFore
$btnShowKeys.Add_Click({
    $show = -not $txtTmdbKey.UseSystemPasswordChar
    $txtTmdbKey.UseSystemPasswordChar = $show
    $txtTvdbKey.UseSystemPasswordChar = $show
    $btnShowKeys.Text = if ($show) { "Show" } else { "Hide" }
})
$grpApi.Controls.Add($btnShowKeys)

$btnSaveApi = New-Object System.Windows.Forms.Button
$btnSaveApi.Text = "Save API Keys"
$btnSaveApi.Location = New-Object System.Drawing.Point(600, 28)
$btnSaveApi.Size = New-Object System.Drawing.Size(130, 27)
$btnSaveApi.FlatStyle = "Flat"
$btnSaveApi.BackColor = $t.ButtonSuccess
$btnSaveApi.ForeColor = $t.ButtonFore
$btnSaveApi.Cursor = "Hand"
$toolTip.SetToolTip($btnSaveApi, "Save API keys so you don't have to enter them again")
$grpApi.Controls.Add($btnSaveApi)

# -- General Group -------------------------------------------------------------
$grpGeneral = New-Object System.Windows.Forms.GroupBox
$grpGeneral.Text = "General"
$grpGeneral.Location = New-Object System.Drawing.Point(12, 332)
$grpGeneral.Size = New-Object System.Drawing.Size(750, 70)
$tabSettings.Controls.Add($grpGeneral)

$lblPresetLoc = New-Object System.Windows.Forms.Label
$lblPresetLoc.Text = "Preset folder:"
$lblPresetLoc.Location = New-Object System.Drawing.Point(15, 30)
$lblPresetLoc.Size = New-Object System.Drawing.Size(85, 23)
$grpGeneral.Controls.Add($lblPresetLoc)

$txtPresetLocation = New-Object System.Windows.Forms.TextBox
$txtPresetLocation.Location = New-Object System.Drawing.Point(105, 28)
$txtPresetLocation.Size = New-Object System.Drawing.Size(400, 23)
$txtPresetLocation.Text = $script:Settings.PresetSaveLocation
$toolTip.SetToolTip($txtPresetLocation, "Where to save/load naming presets")
$grpGeneral.Controls.Add($txtPresetLocation)

$btnPresetLocBrowse = New-Object System.Windows.Forms.Button
$btnPresetLocBrowse.Text = "Browse..."
$btnPresetLocBrowse.Location = New-Object System.Drawing.Point(515, 27)
$btnPresetLocBrowse.Size = New-Object System.Drawing.Size(75, 25)
$btnPresetLocBrowse.FlatStyle = "Flat"
$btnPresetLocBrowse.BackColor = $t.ButtonNeutral
$btnPresetLocBrowse.ForeColor = $t.ButtonFore
$btnPresetLocBrowse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Select folder for presets"
    if ($txtPresetLocation.Text -and (Test-Path $txtPresetLocation.Text)) { $d.SelectedPath = $txtPresetLocation.Text }
    if ($d.ShowDialog() -eq "OK") { $txtPresetLocation.Text = $d.SelectedPath }
})
$grpGeneral.Controls.Add($btnPresetLocBrowse)

$btnSaveGeneral = New-Object System.Windows.Forms.Button
$btnSaveGeneral.Text = "Save General"
$btnSaveGeneral.Location = New-Object System.Drawing.Point(600, 27)
$btnSaveGeneral.Size = New-Object System.Drawing.Size(130, 27)
$btnSaveGeneral.FlatStyle = "Flat"
$btnSaveGeneral.BackColor = $t.ButtonSuccess
$btnSaveGeneral.ForeColor = $t.ButtonFore
$btnSaveGeneral.Cursor = "Hand"
$grpGeneral.Controls.Add($btnSaveGeneral)

# -- Help Button ---------------------------------------------------------------
$btnOpenReadme = New-Object System.Windows.Forms.Button
$btnOpenReadme.Text = "Open User Guide"
$btnOpenReadme.Location = New-Object System.Drawing.Point(12, 415)
$btnOpenReadme.Size = New-Object System.Drawing.Size(150, 32)
$btnOpenReadme.FlatStyle = "Flat"
$btnOpenReadme.BackColor = $t.ButtonPrimary
$btnOpenReadme.ForeColor = $t.ButtonFore
$btnOpenReadme.Cursor = "Hand"
$btnOpenReadme.Font = $fontBold
$toolTip.SetToolTip($btnOpenReadme, "Open the README user guide in your default text editor")
$btnOpenReadme.Add_Click({
    $readmePath = Join-Path $global:AppRootDir "README.md"
    if (Test-Path $readmePath) {
        Start-Process $readmePath
    } else {
        [System.Windows.Forms.MessageBox]::Show("README.md not found.`nExpected at: $readmePath", "Not Found", "OK", "Warning")
    }
})
$tabSettings.Controls.Add($btnOpenReadme)

# ===============================================================================
# HELPER FUNCTIONS
# ===============================================================================

function Update-ButtonStates {
    $hasFiles = ($script:FileList.Count -gt 0)
    $hasFolder = ($script:ShowFolderPath -ne "")
    $hasRollback = ($script:RollbackData.Count -gt 0)
    $hasPreviewed = $false
    if ($hasFiles) {
        $hasPreviewed = ($script:FileList | Where-Object { $_.Status -eq "Will Rename" -and -not $_.Excluded }).Count -gt 0
    }

    $btnPreview.Enabled = $hasFiles
    $btnTestRun.Enabled = $hasFiles
    $btnExportLog.Enabled = $hasFiles
    $btnRefresh.Enabled = $hasFolder
    $btnUndo.Enabled = $hasRollback

    if ($hasPreviewed) {
        $count = ($script:FileList | Where-Object { $_.Status -eq "Will Rename" -and -not $_.Excluded }).Count
        $btnRename.Enabled = ($count -gt 0)
        $btnRename.Text = "Rename $count Files"
    } else {
        $btnRename.Enabled = $false
        $btnRename.Text = "Rename Files"
    }
}

function Update-TemplatePreview {
    $show = if ($txtShowName.Text) { $txtShowName.Text } else { "Show Name" }
    $season = [int]$numSeason.Value
    $ep = [int]$numStartEpisode.Value
    $template = $txtTemplate.Text
    $preview = Build-FileName -Template $template -ShowName $show -Season $season -Episode $ep -Extension ".mp4"
    $lblPreviewText.Text = $preview
    $p = Get-TemplatePreview -Template $template -ShowName $show -Season $season -Episode $ep -Title "Episode Title"
    $lblTmplPreviewVal.Text = $p.WithoutTitle
    $lblTmplPreviewVal2.Text = $p.WithTitle
}

function Get-ParsedExtensions {
    $raw = $txtExtensions.Text -split '[,;\s]+'
    $exts = @()
    foreach ($e in $raw) {
        $e = $e.Trim()
        if ($e -and -not $e.StartsWith('.')) { $e = ".$e" }
        if ($e) { $exts += $e.ToLower() }
    }
    if ($exts.Count -eq 0) { $exts = @(".mp4", ".avi", ".mkv", ".mov") }
    return $exts
}

function Invoke-AutoPreview {
    if ($script:FileList.Count -eq 0) { return }
    $show = $txtShowName.Text
    $season = [int]$numSeason.Value
    $startEp = [int]$numStartEpisode.Value
    $template = $txtTemplate.Text
    $titles = if ($script:EpisodeTitlesCache.ContainsKey($script:CurrentSeasonPath)) {
        $script:EpisodeTitlesCache[$script:CurrentSeasonPath]
    } else { @{} }
    $script:FileList = Build-BatchNames -Files $script:FileList -ShowName $show -Season $season `
        -StartEpisode $startEp -Template $template -EpisodeTitles $titles
    $script:SeasonFileListCache[$script:CurrentSeasonPath] = $script:FileList
    Refresh-ListViewFromFileList
    Update-ButtonStates
}

function Populate-SeasonTree {
    param([string]$ShowFolderPath)
    $seasonTree.Nodes.Clear()
    $script:ShowFolderPath = $ShowFolderPath
    $exts = Get-ParsedExtensions
    $showName = Get-ShowNameFromFolder -FolderPath $ShowFolderPath
    $statusLabel.Text = "Scanning folders..."
    [System.Windows.Forms.Application]::DoEvents()
    $seasons = Get-SeasonFolders -ShowFolderPath $ShowFolderPath -Extensions $exts

    if ($seasons.Count -eq 0) {
        $statusLabel.Text = "No media files found"
        Update-ButtonStates
        return
    }

    $hasOnlyRoot = ($seasons.Count -eq 1 -and $seasons[0].IsRoot)
    if ($hasOnlyRoot) {
        $input = [Microsoft.VisualBasic.Interaction]::InputBox("Files found directly in folder (no season subfolders).`nEnter season number:", "Season Number", "1")
        if (-not $input) { $input = "1" }
        try { $seasons[0].SeasonNum = [int]$input } catch { $seasons[0].SeasonNum = 1 }
    }

    $rootNode = $seasonTree.Nodes.Add($showName)
    $rootNode.Tag = $ShowFolderPath
    $rootNode.NodeFont = $fontBold
    $rootNode.Checked = $false

    foreach ($s in $seasons) {
        $label = if ($s.IsRoot) { "Season $($s.SeasonNum) (root) - $($s.FileCount) files" } else { "$($s.FolderName) - $($s.FileCount) files" }
        $node = $rootNode.Nodes.Add($label)
        $node.Tag = [PSCustomObject]@{
            FolderPath = $s.FolderPath
            SeasonNum  = $s.SeasonNum
            FileCount  = $s.FileCount
            IsRoot     = $s.IsRoot
        }
        $node.Checked = $true
    }

    $rootNode.Expand()
    if ($rootNode.Nodes.Count -gt 0) {
        $seasonTree.SelectedNode = $rootNode.Nodes[0]
    }

    $totalFiles = ($seasons | Measure-Object -Property FileCount -Sum).Sum
    $statusLabel.Text = "$($seasons.Count) folder(s), $totalFiles total files"
    Update-ButtonStates
}

function Load-SeasonFiles {
    param([string]$FolderPath, [int]$SeasonNum)
    $grid.Rows.Clear()
    $t = Get-Theme
    $script:CurrentSeasonPath = $FolderPath
    $script:HeaderCheckState = $true
    $grid.Columns[0].HeaderText = [string][char]0x2611

    if ($script:SeasonFileListCache.ContainsKey($FolderPath)) {
        $script:FileList = $script:SeasonFileListCache[$FolderPath]
    } else {
        $exts = Get-ParsedExtensions
        $sortBy = $cmbSort.SelectedItem
        if (-not $sortBy) { $sortBy = "Name" }
        $script:FileList = Get-MediaFiles -FolderPath $FolderPath -Extensions $exts
        $script:FileList = Sort-MediaFiles -Files $script:FileList -SortBy $sortBy -Descending $chkSortDesc.Checked
        $dupPaths = Find-DuplicatesBySize -Files $script:FileList
        foreach ($f in $script:FileList) {
            $f.IsDuplicate = $dupPaths -contains $f.FullPath
        }
        if ($cmbTitleSource.SelectedItem -eq "Parse from file") {
            foreach ($f in $script:FileList) {
                $parsed = Parse-ExistingFileName -FileName $f.OriginalName
                if ($parsed.ParsedOk -and $parsed.Title) {
                    $f.EpisodeTitle = Clean-FileName -Name $parsed.Title
                }
            }
        }
        if ($script:EpisodeTitlesCache.ContainsKey($FolderPath)) {
            $titles = $script:EpisodeTitlesCache[$FolderPath]
            $epNum = [int]$numStartEpisode.Value
            for ($i = 0; $i -lt $script:FileList.Count; $i++) {
                if ($script:FileList[$i].Excluded) { continue }
                if ($titles.ContainsKey($epNum)) {
                    $script:FileList[$i].EpisodeTitle = $titles[$epNum]
                }
                $epNum++
            }
        }
        $script:SeasonFileListCache[$FolderPath] = $script:FileList
    }

    if ($chkSeasonFromFolder.Checked) { $numSeason.Value = $SeasonNum }

    $count = 0
    foreach ($f in $script:FileList) {
        $count++
        $statusText = if ($f.IsDuplicate) { "Dup?" } else { $f.Status }
        $rowIdx = $grid.Rows.Add((-not $f.Excluded), $count, $f.OriginalName, $f.NewName, $f.EpisodeTitle, $f.FileSizeText, $f.DurationText, $statusText)
        $row = $grid.Rows[$rowIdx]
        $row.Tag = $f.FullPath
        if ($f.IsDuplicate -and $f.Status -eq "Pending") { $row.DefaultCellStyle.BackColor = $t.RowWarning }
        if ($f.Status -eq "Will Rename") { $row.DefaultCellStyle.BackColor = $t.RowHighlight }
        if ($f.Status -eq "Done") { $row.DefaultCellStyle.BackColor = $t.RowSuccess }
    }

    Apply-GridTheme
    if ($grid.Rows.Count -gt 0) {
        $grid.ClearSelection()
        $grid.FirstDisplayedScrollingRowIndex = 0
    }
    $statusLabel.Text = "$count file(s) loaded - preview generated automatically"
    $statusCountLabel.Text = "$count files"
    Update-TemplatePreview

    # Auto-preview
    Invoke-AutoPreview
}

function Apply-GridTheme {
    $t = Get-Theme
    $grid.BackgroundColor = $t.ListBack
    $grid.GridColor = $t.BorderColor
    $grid.DefaultCellStyle.BackColor = $t.ListBack
    $grid.DefaultCellStyle.ForeColor = $t.ListFore
    $grid.DefaultCellStyle.SelectionBackColor = $t.AccentColor
    $grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.ColumnHeadersDefaultCellStyle.BackColor = $t.ControlBack
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = $t.ControlFore
    $grid.ColumnHeadersDefaultCellStyle.Font = $fontBold
    $grid.AlternatingRowsDefaultCellStyle.BackColor = $t.RowAlt
}

function Filter-ListView {
    $filterText = $txtFilter.Text.ToLower()
    foreach ($row in $grid.Rows) {
        $name = $row.Cells["OriginalName"].Value
        if (-not $name) { continue }
        if ($filterText -eq "" -or $name.ToLower().Contains($filterText)) {
            $row.Visible = $true
        } else {
            try { $row.Visible = $false } catch { }
        }
    }
}

function Refresh-ListViewFromFileList {
    $grid.Rows.Clear()
    $t = Get-Theme
    $count = 0
    foreach ($f in $script:FileList) {
        $count++
        $rowIdx = $grid.Rows.Add((-not $f.Excluded), $count, $f.OriginalName, $f.NewName, $f.EpisodeTitle, $f.FileSizeText, $f.DurationText, $f.Status)
        $row = $grid.Rows[$rowIdx]
        $row.Tag = $f.FullPath
        switch -Wildcard ($f.Status) {
            "Will Rename" { $row.DefaultCellStyle.BackColor = $t.RowHighlight }
            "Done"        { $row.DefaultCellStyle.BackColor = $t.RowSuccess }
            "No Change"   { $row.DefaultCellStyle.BackColor = $t.ListBack }
            "Error*"      { $row.DefaultCellStyle.BackColor = $t.RowError }
            "Skipped*"    { $row.DefaultCellStyle.BackColor = $t.RowWarning }
        }
        if ($f.IsDuplicate -and $f.Status -eq "Pending") { $row.DefaultCellStyle.BackColor = $t.RowWarning }
        if ($f.Excluded) { $row.DefaultCellStyle.ForeColor = $t.DisabledFore }
    }
    Apply-GridTheme
    if ($grid.Rows.Count -gt 0) {
        $grid.ClearSelection()
        $grid.FirstDisplayedScrollingRowIndex = 0
    }
}

function Refresh-PresetList {
    $cmbPresets.Items.Clear()
    $customFolder = $txtPresetLocation.Text
    $presets = Get-AllPresets -CustomFolder $customFolder
    foreach ($p in $presets) { $cmbPresets.Items.Add($p.Name) | Out-Null }
}

function Get-SelectedGridIndex {
    if ($grid.SelectedRows.Count -eq 0) { return -1 }
    return $grid.SelectedRows[0].Index
}

function Get-CheckedSeasonNodes {
    $checked = @()
    if ($seasonTree.Nodes.Count -eq 0) { return $checked }
    $root = $seasonTree.Nodes[0]
    foreach ($node in $root.Nodes) {
        if ($node.Checked -and $node.Tag) { $checked += $node }
    }
    return $checked
}

function Reset-All {
    $grid.Rows.Clear()
    $seasonTree.Nodes.Clear()
    $txtFolder.Text = ""
    $txtShowName.Text = ""
    $numSeason.Value = 1
    $numStartEpisode.Value = 1
    $txtFilter.Text = ""
    $lblPreviewText.Text = ""
    $script:FileList = @()
    $script:RollbackData = @()
    $script:LastRenameResults = @{}
    $script:EpisodeTitlesCache = @{}
    $script:SeasonFileListCache = @{}
    $script:CurrentSeasonPath = ""
    $script:ShowFolderPath = ""
    $statusLabel.Text = "Ready - Click Browse to select a show folder"
    $statusCountLabel.Text = ""
    Update-ButtonStates
}

# ===============================================================================
# EVENT HANDLERS
# ===============================================================================

$tabRename.Add_Resize({
    $w = $tabRename.ClientSize.Width
    $txtFolder.Width = $w - 170
    $btnBrowse.Left = $w - 97
    $lblPreviewText.Width = $w - 85
    $btnThemeToggle.Left = $w - 95
})

$tabOrganize.Add_Resize({
    $w = $tabOrganize.ClientSize.Width
    $txtOrgSource.Width = $w - 170
    $btnOrgBrowseSource.Left = $w - 97
    $txtOrgDest.Width = $w - 170
    $btnOrgBrowseDest.Left = $w - 97
})

# -- Season Tree ---------------------------------------------------------------
$seasonTree.Add_AfterSelect({
    $node = $seasonTree.SelectedNode
    if (-not $node -or -not $node.Tag) { return }
    if ($node.Tag -is [string]) { return }
    $info = $node.Tag
    if ($chkShowFromFolder.Checked -and $script:ShowFolderPath) {
        $txtShowName.Text = Split-Path $script:ShowFolderPath -Leaf
    }
    Load-SeasonFiles -FolderPath $info.FolderPath -SeasonNum $info.SeasonNum
})

$seasonTree.Add_AfterCheck({
    $node = $_.Node
    if ($node.Tag -is [string] -and $node.Nodes.Count -gt 0) {
        foreach ($child in $node.Nodes) { $child.Checked = $node.Checked }
    }
})

# -- Browse --------------------------------------------------------------------
$btnBrowse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Select show folder (containing season subfolders) or season folder"
    if ($txtFolder.Text -and (Test-Path $txtFolder.Text)) { $d.SelectedPath = $txtFolder.Text }
    if ($d.ShowDialog() -eq "OK") {
        $txtFolder.Text = $d.SelectedPath
        $script:SeasonFileListCache = @{}
        $script:EpisodeTitlesCache = @{}
        if ($chkShowFromFolder.Checked) {
            $txtShowName.Text = Get-ShowNameFromFolder -FolderPath $d.SelectedPath
        }
        Populate-SeasonTree -ShowFolderPath $d.SelectedPath
    }
})

# -- Drag & Drop ---------------------------------------------------------------
$grid.Add_DragEnter({
    if ($_.Data.GetDataPresent("FileDrop")) { $_.Effect = "Copy" }
})

$grid.Add_DragDrop({
    if ($_.Data.GetDataPresent("FileDrop")) {
        $paths = $_.Data.GetData("FileDrop")
        if ($paths.Count -gt 0) {
            $firstPath = $paths[0]
            if (Test-Path $firstPath -PathType Container) {
                $txtFolder.Text = $firstPath
                $script:SeasonFileListCache = @{}
                $script:EpisodeTitlesCache = @{}
                if ($chkShowFromFolder.Checked) {
                    $txtShowName.Text = Get-ShowNameFromFolder -FolderPath $firstPath
                }
                Populate-SeasonTree -ShowFolderPath $firstPath
            }
        }
    }
})

# -- Double-click grid to edit episode title -----------------------------------
$grid.Add_ColumnHeaderMouseClick({
    if ($_.ColumnIndex -eq 0) {
        # Toggle all checkboxes
        $script:HeaderCheckState = -not $script:HeaderCheckState
        foreach ($row in $grid.Rows) {
            $row.Cells["Include"].Value = $script:HeaderCheckState
        }
        for ($i = 0; $i -lt $script:FileList.Count; $i++) {
            $script:FileList[$i].Excluded = -not $script:HeaderCheckState
        }
        $grid.Columns[0].HeaderText = if ($script:HeaderCheckState) { [char]0x2611 } else { [char]0x2610 }
        $grid.RefreshEdit()
    }
})

$grid.Add_CellDoubleClick({
    $rowIdx = $_.RowIndex
    $colIdx = $_.ColumnIndex
    if ($rowIdx -lt 0 -or $rowIdx -ge $script:FileList.Count) { return }

    # Allow editing Episode Title column directly (already editable), but for other columns open dialog
    $colName = $grid.Columns[$colIdx].Name
    if ($colName -eq "EpisodeTitle") { return } # let inline edit handle it

    # Double-click anywhere else opens title edit dialog
    $current = $script:FileList[$rowIdx].EpisodeTitle
    $newTitle = [Microsoft.VisualBasic.Interaction]::InputBox("Enter episode title:", "Edit Title", $current)
    if ($newTitle -ne $null) {
        $script:FileList[$rowIdx].EpisodeTitle = $newTitle
        $grid.Rows[$rowIdx].Cells["EpisodeTitle"].Value = $newTitle
    }
})

# -- Preview -------------------------------------------------------------------
$btnPreview.Add_Click({
    if ($script:FileList.Count -eq 0) { return }
    for ($i = 0; $i -lt $script:FileList.Count; $i++) {
        if ($i -ge $grid.Rows.Count) { break }
        $script:FileList[$i].Excluded = -not $grid.Rows[$i].Cells["Include"].Value
        $editedTitle = $grid.Rows[$i].Cells["EpisodeTitle"].Value
        if ($editedTitle) { $script:FileList[$i].EpisodeTitle = $editedTitle }
    }
    $show = $txtShowName.Text
    $season = [int]$numSeason.Value
    $startEp = [int]$numStartEpisode.Value
    $template = $txtTemplate.Text
    $titles = if ($script:EpisodeTitlesCache.ContainsKey($script:CurrentSeasonPath)) {
        $script:EpisodeTitlesCache[$script:CurrentSeasonPath]
    } else { @{} }
    $script:FileList = Build-BatchNames -Files $script:FileList -ShowName $show -Season $season `
        -StartEpisode $startEp -Template $template -EpisodeTitles $titles
    $script:SeasonFileListCache[$script:CurrentSeasonPath] = $script:FileList
    Refresh-ListViewFromFileList
    $willRename = ($script:FileList | Where-Object { $_.Status -eq "Will Rename" -and -not $_.Excluded }).Count
    $noChange = ($script:FileList | Where-Object { $_.Status -eq "No Change" }).Count
    $statusLabel.Text = "$willRename file(s) will be renamed, $noChange unchanged"
    Update-ButtonStates
})

# -- Rename Files --------------------------------------------------------------
$btnRename.Add_Click({
    $checkedNodes = Get-CheckedSeasonNodes
    $mode = $cmbAction.SelectedItem

    # --- Batch rename (multiple seasons checked) ---
    if ($checkedNodes.Count -gt 1) {
        $totalSeasons = $checkedNodes.Count
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Batch rename $totalSeasons seasons using mode '$mode'?`nStart Ep: $([int]$numStartEpisode.Value) per season",
            "Confirm Batch", "YesNo", "Question")
        if ($confirm -ne "Yes") { return }
        $template = $txtTemplate.Text
        $show = $txtShowName.Text
        $startEp = [int]$numStartEpisode.Value
        $allRollback = @()
        $batchSuccess = 0
        $batchErrors = 0
        $batchSkipped = 0

        $progressBar.Visible = $true
        $progressBar.Style = "Continuous"

        foreach ($node in $checkedNodes) {
            $info = $node.Tag
            $statusLabel.Text = "[$($info.FolderPath)]..."
            [System.Windows.Forms.Application]::DoEvents()
            if ($script:SeasonFileListCache.ContainsKey($info.FolderPath)) {
                $files = $script:SeasonFileListCache[$info.FolderPath]
            } else {
                $exts = Get-ParsedExtensions
                $files = Get-MediaFiles -FolderPath $info.FolderPath -Extensions $exts
                $files = Sort-MediaFiles -Files $files -SortBy ($cmbSort.SelectedItem) -Descending $chkSortDesc.Checked
            }
            $titles = if ($script:EpisodeTitlesCache.ContainsKey($info.FolderPath)) {
                $script:EpisodeTitlesCache[$info.FolderPath]
            } else { @{} }
            $files = Build-BatchNames -Files $files -ShowName $show -Season $info.SeasonNum `
                -StartEpisode $startEp -Template $template -EpisodeTitles $titles
            $destFolder = ""
            if ($mode -ne "Rename") {
                $d = New-Object System.Windows.Forms.FolderBrowserDialog
                $d.Description = "Destination for $($info.FolderPath)"
                if ($d.ShowDialog() -ne "OK") { continue }
                $destFolder = $d.SelectedPath
            }
            $results = Invoke-RenameFiles -Files $files -Mode $mode -DestinationFolder $destFolder `
                -ConflictAction "Suffix" `
                -OnProgress {
                    param($current, $total, $name)
                    $statusLabel.Text = "[$current/$total] $name"
                    [System.Windows.Forms.Application]::DoEvents()
                }
            $allRollback += $results.RollbackData
            $batchSuccess += $results.Success
            $batchErrors += $results.Errors
            $batchSkipped += $results.Skipped
            $script:SeasonFileListCache[$info.FolderPath] = $files
        }

        $script:RollbackData = $allRollback
        $progressBar.Visible = $false

        # Summary popup
        $summary = "Batch Rename Complete`n`n"
        $summary += "Seasons processed: $totalSeasons`n"
        $summary += "Files renamed: $batchSuccess`n"
        $summary += "Skipped: $batchSkipped`n"
        $summary += "Errors: $batchErrors"
        [System.Windows.Forms.MessageBox]::Show($summary, "Batch Complete", "OK", "Information")

        $statusLabel.Text = "Batch: $batchSuccess renamed, $batchSkipped skipped, $batchErrors errors"
        if ($script:CurrentSeasonPath -and $script:SeasonFileListCache.ContainsKey($script:CurrentSeasonPath)) {
            $script:FileList = $script:SeasonFileListCache[$script:CurrentSeasonPath]
            Refresh-ListViewFromFileList
        }
        Update-ButtonStates
        return
    }

    # --- Single season rename ---
    if ($script:FileList.Count -eq 0) { return }
    $willRename = ($script:FileList | Where-Object { $_.Status -eq "Will Rename" -and -not $_.Excluded }).Count
    if ($willRename -eq 0) { return }

    # Show confirmation with examples
    $examples = ""
    $exCount = 0
    foreach ($f in $script:FileList) {
        if ($f.Status -eq "Will Rename" -and -not $f.Excluded -and $exCount -lt 3) {
            $examples += "  $($f.OriginalName)`n  -> $($f.NewName)`n`n"
            $exCount++
        }
    }
    $confirmMsg = "Rename $willRename file(s) using '$mode'?`n`nExamples:`n$examples"
    $confirm = [System.Windows.Forms.MessageBox]::Show($confirmMsg, "Confirm Rename", "YesNo", "Question")
    if ($confirm -ne "Yes") { return }

    $destFolder = ""
    if ($mode -ne "Rename") {
        $d = New-Object System.Windows.Forms.FolderBrowserDialog
        $d.Description = "Destination for $mode"
        if ($txtFolder.Text -and (Test-Path $txtFolder.Text)) { $d.SelectedPath = $txtFolder.Text }
        if ($d.ShowDialog() -ne "OK") { return }
        $destFolder = $d.SelectedPath
    }
    $progressBar.Visible = $true
    $progressBar.Maximum = $willRename
    $progressBar.Value = 0
    $results = Invoke-RenameFiles -Files $script:FileList -Mode $mode -DestinationFolder $destFolder `
        -ConflictAction "Ask" `
        -OnProgress {
            param($current, $total, $name)
            $progressBar.Value = $current
            $statusLabel.Text = "[$current/$total] $name"
            [System.Windows.Forms.Application]::DoEvents()
        } `
        -OnConflict {
            param($oldName, $newName, $targetPath)
            $r = [System.Windows.Forms.MessageBox]::Show("File exists:`n$targetPath`n`nOverwrite, Skip, or Suffix?", "Conflict", "YesNoCancel", "Warning")
            switch ($r) { "Yes" { "Overwrite" } "No" { "Skip" } "Cancel" { "Cancel" } }
        }
    $script:RollbackData = $results.RollbackData
    $script:LastRenameResults = $results
    $script:SeasonFileListCache[$script:CurrentSeasonPath] = $script:FileList
    $progressBar.Visible = $false
    Refresh-ListViewFromFileList

    # Summary popup
    $summary = "Rename Complete`n`n"
    $summary += "Successful: $($results.Success)`n"
    $summary += "Skipped: $($results.Skipped)`n"
    $summary += "Errors: $($results.Errors)"
    if ($results.Errors -gt 0) {
        $errFiles = ($script:FileList | Where-Object { $_.Status -match "^Error" } | Select-Object -First 3)
        $summary += "`n`nFirst errors:"
        foreach ($ef in $errFiles) { $summary += "`n  $($ef.OriginalName): $($ef.Status)" }
    }
    [System.Windows.Forms.MessageBox]::Show($summary, "Rename Complete", "OK", "Information")

    $statusLabel.Text = "$($results.Success) renamed, $($results.Skipped) skipped, $($results.Errors) errors"
    Update-ButtonStates
})

# -- Test Run ------------------------------------------------------------------
$btnTestRun.Add_Click({
    $script:IsDryRun = $true
    $btnPreview.PerformClick()
    if ($script:FileList.Count -gt 0) {
        $willRename = ($script:FileList | Where-Object { $_.Status -eq "Will Rename" -and -not $_.Excluded }).Count
        $noChange = ($script:FileList | Where-Object { $_.Status -eq "No Change" }).Count
        $excluded = ($script:FileList | Where-Object { $_.Excluded }).Count
        $msg = "TEST RUN - No files were changed`n`n"
        $msg += "Would rename: $willRename file(s)`n"
        $msg += "No change needed: $noChange`n"
        $msg += "Excluded: $excluded`n"
        $msg += "Total: $($script:FileList.Count)"
        [System.Windows.Forms.MessageBox]::Show($msg, "Test Run Results", "OK", "Information")
    }
    $script:IsDryRun = $false
})

# -- Undo ----------------------------------------------------------------------
$btnUndo.Add_Click({
    if ($script:RollbackData.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nothing to undo.", "Undo", "OK", "Information")
        return
    }
    $confirm = [System.Windows.Forms.MessageBox]::Show("Undo $($script:RollbackData.Count) operation(s)?", "Confirm Undo", "YesNo", "Question")
    if ($confirm -ne "Yes") { return }
    $result = Invoke-Undo -RollbackData $script:RollbackData
    $script:RollbackData = @()
    $script:SeasonFileListCache = @{}
    [System.Windows.Forms.MessageBox]::Show("$($result.Undone) restored, $($result.Errors) errors", "Undo Complete", "OK", "Information")
    if ($script:CurrentSeasonPath) {
        Load-SeasonFiles -FolderPath $script:CurrentSeasonPath -SeasonNum ([int]$numSeason.Value)
    }
    $statusLabel.Text = "Undo complete"
    Update-ButtonStates
})

# -- Export Log ----------------------------------------------------------------
$btnExportLog.Add_Click({
    if ($script:FileList.Count -eq 0) { return }
    $d = New-Object System.Windows.Forms.SaveFileDialog
    $d.Filter = "Text Files|*.txt|CSV Files|*.csv"
    $d.FileName = "$($txtShowName.Text)_S$([int]$numSeason.Value)_log"
    if ($d.ShowDialog() -eq "OK") {
        $success = $false
        if ($d.FileName -match '\.csv$') {
            $success = Export-CsvLog -Files $script:FileList -OutputPath $d.FileName
        } else {
            $success = Export-RenameLog -Files $script:FileList -OutputPath $d.FileName `
                -RenameResults $script:LastRenameResults -ShowName $txtShowName.Text `
                -Season ([int]$numSeason.Value) -Mode $cmbAction.SelectedItem
        }
        if ($success) { [System.Windows.Forms.MessageBox]::Show("Log exported!", "Exported", "OK", "Information") }
    }
})

# -- Reset ---------------------------------------------------------------------
$btnReset.Add_Click({ Reset-All })

# -- Refresh -------------------------------------------------------------------
$btnRefresh.Add_Click({
    if (-not $script:ShowFolderPath) { return }
    $shiftHeld = ([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Shift) -eq [System.Windows.Forms.Keys]::Shift

    if ($shiftHeld) {
        # Shift+click: full tree rescan
        $script:SeasonFileListCache = @{}
        $script:EpisodeTitlesCache = @{}
        Populate-SeasonTree -ShowFolderPath $script:ShowFolderPath
        $statusLabel.Text = "All seasons rescanned"
    } else {
        # Normal click: rescan current season only
        if ($script:CurrentSeasonPath) {
            $script:SeasonFileListCache.Remove($script:CurrentSeasonPath)
            Load-SeasonFiles -FolderPath $script:CurrentSeasonPath -SeasonNum ([int]$numSeason.Value)
            $statusLabel.Text = "Current season rescanned"
        }
    }
})

# -- Theme Toggle --------------------------------------------------------------
$btnThemeToggle.Add_Click({
    $newTheme = Toggle-Theme
    Apply-ThemeToForm -Form $form
    $t = Get-Theme
    $btnThemeToggle.Text = if ($newTheme -eq "Dark") { "Light" } else { "Dark" }
    $btnThemeToggle.BackColor = $t.ButtonNeutral
    $btnBrowse.BackColor = $t.ButtonPrimary
    $btnPreview.BackColor = $t.ButtonPrimary
    $btnRename.BackColor = $t.ButtonSuccess
    $btnTestRun.BackColor = $t.ButtonNeutral
    $btnUndo.BackColor = $t.ButtonNeutral
    $btnExportLog.BackColor = $t.ButtonNeutral
    $btnReset.BackColor = $t.ButtonNeutral
    $btnRefresh.BackColor = $t.ButtonNeutral
    $btnFetchTitles.BackColor = $t.ButtonNeutral
    $btnFetchTitles.ForeColor = $t.ButtonFore
    $btnSaveTemplate.BackColor = $t.ButtonSuccess
    $btnSaveApi.BackColor = $t.ButtonSuccess
    $btnSaveGeneral.BackColor = $t.ButtonSuccess
    $btnOpenReadme.BackColor = $t.ButtonPrimary
    $btnOpenReadme.ForeColor = $t.ButtonFore
    $lblPreviewText.ForeColor = $t.AccentColor
    $lblTmplPreviewVal.ForeColor = $t.AccentColor
    $lblTmplPreviewVal2.ForeColor = $t.AccentColor
    $lblVars.ForeColor = $t.AccentColor
    $panelLegend.BackColor = $t.FormBack
    # Organize tab
    $btnOrgBrowseSource.BackColor = $t.ButtonPrimary
    $btnOrgBrowseSource.ForeColor = $t.ButtonFore
    $btnOrgBrowseDest.BackColor = $t.ButtonPrimary
    $btnOrgBrowseDest.ForeColor = $t.ButtonFore
    $btnOrgScan.BackColor = $t.ButtonPrimary
    $btnOrgScan.ForeColor = $t.ButtonFore
    $btnOrgPreview.BackColor = $t.ButtonNeutral
    $btnOrgPreview.ForeColor = $t.ButtonFore
    $btnOrgExecute.BackColor = $t.ButtonSuccess
    $btnOrgExecute.ForeColor = $t.ButtonFore
    $btnOrgUndo.BackColor = $t.ButtonNeutral
    $btnOrgUndo.ForeColor = $t.ButtonFore
    $btnOrgClear.BackColor = $t.ButtonNeutral
    $btnOrgClear.ForeColor = $t.ButtonFore
    $btnOrgAutoMap.BackColor = $t.ButtonNeutral
    $btnOrgAutoMap.ForeColor = $t.ButtonFore
    $btnOrgBatchAssign.BackColor = $t.ButtonNeutral
    $btnOrgBatchAssign.ForeColor = $t.ButtonFore
    $btnOrgFetchMap.BackColor = $t.ButtonNeutral
    $btnOrgFetchMap.ForeColor = $t.ButtonFore
    $lblOrgInfo.ForeColor = $t.AccentColor
    $lblOrgMapInfo.ForeColor = $t.AccentColor
    $txtOrgSeasonRef.BackColor = $t.ControlBack
    $txtOrgSeasonRef.ForeColor = $t.AccentColor
    $script:Settings.ThemePreference = $newTheme
    Apply-GridTheme
    Refresh-ListViewFromFileList
    if ($script:OrganizeFiles.Count -gt 0) { Refresh-OrgGrid }
})

# -- Context Menu handlers -----------------------------------------------------
$menuRenameThis.Add_Click({
    $idx = Get-SelectedGridIndex
    if ($idx -lt 0 -or $idx -ge $script:FileList.Count) { return }
    $f = $script:FileList[$idx]

    # Auto-preview this file if no NewName yet
    if ([string]::IsNullOrWhiteSpace($f.NewName) -or $f.Status -eq "Pending") {
        $show = $txtShowName.Text
        $season = [int]$numSeason.Value
        $template = $txtTemplate.Text
        $f.NewName = Build-FileName -Template $template -ShowName $show -Season $season -Episode $f.EpisodeNumber -EpisodeTitle $f.EpisodeTitle -Extension $f.Extension -OriginalName $f.OriginalName
        if ($f.OriginalName -eq $f.NewName) {
            $statusLabel.Text = "File already has the correct name"
            return
        }
    }
    if ($f.OriginalName -eq $f.NewName) {
        $statusLabel.Text = "No change needed for this file"
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Rename:`n  $($f.OriginalName)`n->`n  $($f.NewName)", "Rename This File", "YesNo", "Question")
    if ($confirm -ne "Yes") { return }

    try {
        $targetPath = Join-Path $f.Directory $f.NewName
        if (Test-Path $targetPath) {
            [System.Windows.Forms.MessageBox]::Show("Target file already exists: $($f.NewName)", "Conflict", "OK", "Warning")
            return
        }
        Rename-Item -Path $f.FullPath -NewName $f.NewName -Force
        $script:FileList[$idx].FullPath = $targetPath
        $script:FileList[$idx].OriginalName = $f.NewName
        $script:FileList[$idx].Status = "Done"
        $script:RollbackData += @([PSCustomObject]@{
            OriginalPath = (Join-Path $f.Directory $f.OriginalName)
            NewPath      = $targetPath
            Mode         = "Rename"
        })
        $script:SeasonFileListCache[$script:CurrentSeasonPath] = $script:FileList
        Refresh-ListViewFromFileList
        $statusLabel.Text = "Renamed: $($f.NewName)"
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Rename Failed", "OK", "Error")
    }
    Update-ButtonStates
})

$menuRenameSelected.Add_Click({
    $selectedRows = @($grid.SelectedRows | ForEach-Object { $_.Index } | Sort-Object)
    if ($selectedRows.Count -eq 0) { return }

    # Filter to only files that can be renamed
    $toRename = @()
    foreach ($idx in $selectedRows) {
        if ($idx -ge $script:FileList.Count) { continue }
        $f = $script:FileList[$idx]
        if ($f.Excluded) { continue }

        # Auto-preview if needed
        if ([string]::IsNullOrWhiteSpace($f.NewName) -or $f.Status -eq "Pending") {
            $show = $txtShowName.Text
            $season = [int]$numSeason.Value
            $template = $txtTemplate.Text
            $f.NewName = Build-FileName -Template $template -ShowName $show -Season $season -Episode $f.EpisodeNumber -EpisodeTitle $f.EpisodeTitle -Extension $f.Extension -OriginalName $f.OriginalName
        }
        if ($f.OriginalName -ne $f.NewName) { $toRename += $idx }
    }

    if ($toRename.Count -eq 0) {
        $statusLabel.Text = "No changes needed for selected files"
        return
    }

    $examples = ""
    $exCount = 0
    foreach ($idx in $toRename) {
        if ($exCount -ge 3) { break }
        $f = $script:FileList[$idx]
        $examples += "  $($f.OriginalName)`n  -> $($f.NewName)`n`n"
        $exCount++
    }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Rename $($toRename.Count) file(s)?`n`n$examples", "Rename Selected", "YesNo", "Question")
    if ($confirm -ne "Yes") { return }

    $success = 0; $errors = 0
    foreach ($idx in $toRename) {
        $f = $script:FileList[$idx]
        try {
            $targetPath = Join-Path $f.Directory $f.NewName
            if (Test-Path $targetPath) {
                $script:FileList[$idx].Status = "Skipped (exists)"
                continue
            }
            Rename-Item -Path $f.FullPath -NewName $f.NewName -Force
            $script:FileList[$idx].FullPath = $targetPath
            $script:FileList[$idx].OriginalName = $f.NewName
            $script:FileList[$idx].Status = "Done"
            $script:RollbackData += @([PSCustomObject]@{
                OriginalPath = (Join-Path $f.Directory $f.OriginalName)
                NewPath      = $targetPath
                Mode         = "Rename"
            })
            $success++
        } catch { $errors++; $script:FileList[$idx].Status = "Error: $($_.Exception.Message)" }
    }

    $script:SeasonFileListCache[$script:CurrentSeasonPath] = $script:FileList
    Refresh-ListViewFromFileList
    $statusLabel.Text = "$success renamed, $errors errors"
    Update-ButtonStates
})

$menuEditTitle.Add_Click({
    $idx = Get-SelectedGridIndex
    if ($idx -lt 0) { return }
    $current = $script:FileList[$idx].EpisodeTitle
    $newTitle = [Microsoft.VisualBasic.Interaction]::InputBox("Enter episode title:", "Edit Title", $current)
    if ($newTitle -ne $null) {
        $script:FileList[$idx].EpisodeTitle = $newTitle
        $grid.Rows[$idx].Cells["EpisodeTitle"].Value = $newTitle
    }
})

$menuExclude.Add_Click({
    $idx = Get-SelectedGridIndex
    if ($idx -lt 0) { return }
    $script:FileList[$idx].Excluded = -not $script:FileList[$idx].Excluded
    $grid.Rows[$idx].Cells["Include"].Value = -not $script:FileList[$idx].Excluded
})

$menuMoveUp.Add_Click({
    $idx = Get-SelectedGridIndex
    if ($idx -le 0) { return }
    $temp = $script:FileList[$idx]
    $script:FileList[$idx] = $script:FileList[$idx - 1]
    $script:FileList[$idx - 1] = $temp
    Refresh-ListViewFromFileList
    $grid.ClearSelection()
    $grid.Rows[$idx - 1].Selected = $true
})

$menuMoveDown.Add_Click({
    $idx = Get-SelectedGridIndex
    if ($idx -lt 0 -or $idx -ge ($script:FileList.Count - 1)) { return }
    $temp = $script:FileList[$idx]
    $script:FileList[$idx] = $script:FileList[$idx + 1]
    $script:FileList[$idx + 1] = $temp
    Refresh-ListViewFromFileList
    $grid.ClearSelection()
    $grid.Rows[$idx + 1].Selected = $true
})

# -- Keyboard shortcuts --------------------------------------------------------
$form.Add_KeyDown({
    if ($_.KeyCode -eq "F2" -and $tabControl.SelectedTab -eq $tabRename) {
        $menuEditTitle.PerformClick()
    }
})

# -- Fetch Titles (API) --------------------------------------------------------
$btnFetchTitles.Add_Click({
    $sourceItem = $cmbTitleSource.SelectedItem
    $source = if ($sourceItem -match "TMDB") { "TMDB" } elseif ($sourceItem -match "TVDB") { "TVDB" } elseif ($sourceItem -match "MAL") { "MAL" } else { "" }
    if (-not $source) { return }
    $tmdbKey = $txtTmdbKey.Text
    $tvdbKey = $txtTvdbKey.Text
    $lang = if ($cmbLanguage.SelectedItem) { $cmbLanguage.SelectedItem.ToString() } else { "en" }
    if ($source -eq "TMDB" -and -not $tmdbKey) {
        [System.Windows.Forms.MessageBox]::Show("Enter your TMDB API key in Settings first.", "API Key Required", "OK", "Warning")
        return
    }
    if ($source -eq "TVDB" -and -not $tvdbKey) {
        [System.Windows.Forms.MessageBox]::Show("Enter your TVDB API key in Settings first.", "API Key Required", "OK", "Warning")
        return
    }

    # Map ordering dropdown to TVDB season type
    $seasonType = "default"
    if ($source -eq "TVDB" -and $cmbOrdering.SelectedItem) {
        switch ($cmbOrdering.SelectedItem.ToString()) {
            "Aired"         { $seasonType = "default" }
            "DVD"           { $seasonType = "dvd" }
            "Absolute"      { $seasonType = "absolute" }
            "International" { $seasonType = "regional" }
        }
    }

    $statusLabel.Text = "Searching '$($txtShowName.Text)' on $source..."
    [System.Windows.Forms.Application]::DoEvents()

    $shows = @()
    if ($source -eq "MAL") {
        $statusLabel.Text = "Searching '$($txtShowName.Text)' on MAL..."
        [System.Windows.Forms.Application]::DoEvents()
        $shows = Search-Show -ShowName $txtShowName.Text -Source $source -Language $lang
    } else {
        $shows = Search-Show -ShowName $txtShowName.Text -Source $source -TmdbKey $tmdbKey -TvdbKey $tvdbKey -Language $lang
    }
    if ($shows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No shows found on $source.", "Not Found", "OK", "Warning")
        $statusLabel.Text = "Ready"
        return
    }
    $selectedShow = if ($source -ne "MAL" -and $shows.Count -eq 1) { $shows[0] } else { Show-SelectionDialog -Shows $shows }
    if (-not $selectedShow) { $statusLabel.Text = "Cancelled"; return }

    # TMDB: Check for episode groups and offer to use them
    $tmdbGroupId = ""
    if ($source -eq "TMDB") {
        $statusLabel.Text = "Checking for episode groups..."
        [System.Windows.Forms.Application]::DoEvents()
        $groups = Get-TmdbEpisodeGroups -ShowId ([int]$selectedShow.Id) -ApiKey $tmdbKey
        if ($groups.Count -gt 0) {
            $groupShows = @()
            $groupShows += [PSCustomObject]@{ Id = ""; Name = "Default (Standard Ordering)"; Year = ""; Overview = ""; Source = "TMDB" }
            foreach ($g in $groups) {
                $groupShows += [PSCustomObject]@{
                    Id = $g.Id; Name = "$($g.Name) ($($g.Type))"; Year = "$($g.EpCount) eps"
                    Overview = $g.Description; Source = "TMDB"
                }
            }
            $selectedGroup = Show-SelectionDialog -Shows $groupShows
            if ($selectedGroup -and $selectedGroup.Id) {
                $tmdbGroupId = $selectedGroup.Id
            }
        }
    }

    $statusLabel.Text = "Fetching titles for '$($selectedShow.Name)' S$([int]$numSeason.Value) ($lang)..."
    [System.Windows.Forms.Application]::DoEvents()

    $titles = @{}
    if ($tmdbGroupId) {
        $titles = Get-TmdbGroupEpisodeTitles -GroupId $tmdbGroupId -ApiKey $tmdbKey -Season ([int]$numSeason.Value) -Language $lang
    } else {
        $titles = Get-EpisodeTitles -ShowId $selectedShow.Id -Season ([int]$numSeason.Value) -Source $source -TmdbKey $tmdbKey -TvdbKey $tvdbKey -Language $lang -SeasonType $seasonType
    }

    if ($titles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No titles found for S$([int]$numSeason.Value).", "Not Found", "OK", "Warning")
        $statusLabel.Text = "Ready"
        return
    }
    $script:EpisodeTitlesCache[$script:CurrentSeasonPath] = $titles
    $epNum = [int]$numStartEpisode.Value
    for ($i = 0; $i -lt $script:FileList.Count; $i++) {
        if ($script:FileList[$i].Excluded) { continue }
        if ($titles.ContainsKey($epNum)) { $script:FileList[$i].EpisodeTitle = $titles[$epNum] }
        $epNum++
    }
    $script:SeasonFileListCache[$script:CurrentSeasonPath] = $script:FileList
    Refresh-ListViewFromFileList
    $orderInfo = if ($source -eq "TVDB") { " [$($cmbOrdering.SelectedItem)]" } elseif ($tmdbGroupId) { " [Episode Group]" } else { "" }
    $statusLabel.Text = "$($titles.Count) titles fetched from $source$orderInfo"
    Invoke-AutoPreview
})

# -- Settings Save Handlers ----------------------------------------------------
$btnSaveTemplate.Add_Click({
    $script:Settings.NamingTemplate = $txtTemplate.Text
    Save-AppSettings -Settings $script:Settings
    [System.Windows.Forms.MessageBox]::Show("Template saved!", "Saved", "OK", "Information")
})

$btnSaveApi.Add_Click({
    $script:Settings.TmdbApiKey = $txtTmdbKey.Text
    $script:Settings.TvdbApiKey = $txtTvdbKey.Text
    Set-ApiKeys -TmdbKey $txtTmdbKey.Text -TvdbKey $txtTvdbKey.Text
    Save-AppSettings -Settings $script:Settings
    [System.Windows.Forms.MessageBox]::Show("API keys saved!", "Saved", "OK", "Information")
})

$btnSaveGeneral.Add_Click({
    $script:Settings.PresetSaveLocation = $txtPresetLocation.Text
    if ($txtPresetLocation.Text) { Initialize-PresetManager -SettingsPath $txtPresetLocation.Text }
    Save-AppSettings -Settings $script:Settings
    Refresh-PresetList
    [System.Windows.Forms.MessageBox]::Show("General settings saved!", "Saved", "OK", "Information")
})

# -- Preset Save/Load ----------------------------------------------------------
$btnSavePreset.Add_Click({
    $name = [Microsoft.VisualBasic.Interaction]::InputBox("Enter preset name:", "Save Preset", "My Preset")
    if (-not $name) { return }
    $preset = Get-PresetTemplate
    $preset.Name = $name
    $preset.ShowName = $txtShowName.Text
    $preset.SeasonNumber = [int]$numSeason.Value
    $preset.NamingTemplate = $txtTemplate.Text
    $preset.SortOrder = $cmbSort.SelectedItem
    $preset.SortDescending = $chkSortDesc.Checked
    $preset.StartEpisode = [int]$numStartEpisode.Value
    $preset.Extensions = (Get-ParsedExtensions)
    $preset.EpisodeTitleSource = $cmbTitleSource.SelectedItem
    $preset.FileAction = $cmbAction.SelectedItem
    $path = Save-Preset -Preset $preset -CustomFolder $txtPresetLocation.Text
    if ($path) {
        Refresh-PresetList
        [System.Windows.Forms.MessageBox]::Show("Preset '$name' saved!", "Saved", "OK", "Information")
    }
})

$btnLoadPreset.Add_Click({
    if ($cmbPresets.SelectedItem -eq $null) { return }
    $presetName = $cmbPresets.SelectedItem.ToString()
    $presets = Get-AllPresets -CustomFolder $txtPresetLocation.Text
    $match = $presets | Where-Object { $_.Name -eq $presetName } | Select-Object -First 1
    if (-not $match) { return }
    $data = $match.Data
    $txtShowName.Text = $data.ShowName
    $numSeason.Value = $data.SeasonNumber
    $txtTemplate.Text = $data.NamingTemplate
    $numStartEpisode.Value = $data.StartEpisode
    $txtExtensions.Text = ($data.Extensions -join ", ")
    $sortIdx = $cmbSort.Items.IndexOf($data.SortOrder)
    if ($sortIdx -ge 0) { $cmbSort.SelectedIndex = $sortIdx }
    $chkSortDesc.Checked = $data.SortDescending
    $titleIdx = $cmbTitleSource.Items.IndexOf($data.EpisodeTitleSource)
    if ($titleIdx -ge 0) { $cmbTitleSource.SelectedIndex = $titleIdx }
    $actionIdx = $cmbAction.Items.IndexOf($data.FileAction)
    if ($actionIdx -ge 0) { $cmbAction.SelectedIndex = $actionIdx }
    Update-TemplatePreview
    $statusLabel.Text = "Preset '$presetName' loaded"
})

# -- Sort change = re-sort and auto-preview ------------------------------------
$cmbSort.Add_SelectedIndexChanged({
    if ($script:CurrentSeasonPath -and $script:FileList.Count -gt 0) {
        $script:FileList = Sort-MediaFiles -Files $script:FileList -SortBy $cmbSort.SelectedItem -Descending $chkSortDesc.Checked
        $script:SeasonFileListCache[$script:CurrentSeasonPath] = $script:FileList
        Refresh-ListViewFromFileList
        Invoke-AutoPreview
    }
})

$chkSortDesc.Add_CheckedChanged({
    if ($script:CurrentSeasonPath -and $script:FileList.Count -gt 0) {
        $script:FileList = Sort-MediaFiles -Files $script:FileList -SortBy $cmbSort.SelectedItem -Descending $chkSortDesc.Checked
        $script:SeasonFileListCache[$script:CurrentSeasonPath] = $script:FileList
        Refresh-ListViewFromFileList
        Invoke-AutoPreview
    }
})

# ===============================================================================
# ORGANIZE TAB - EVENT HANDLERS
# ===============================================================================

function Update-OrgButtonStates {
    $hasSrc = ($txtOrgSource.Text -ne "")
    $hasDest = ($txtOrgDest.Text -ne "")
    $hasFiles = ($script:OrganizeFiles.Count -gt 0)
    $hasRollback = ($script:OrganizeRollback.Count -gt 0)
    $hasSeasonMap = ($script:OrgSeasonMap.Count -gt 0)
    $hasPreviewed = $false
    if ($hasFiles) {
        $hasPreviewed = ($script:OrganizeFiles | Where-Object { $_.TargetPath -ne "" -and -not $_.Excluded }).Count -gt 0
    }
    $btnOrgScan.Enabled = ($hasSrc)
    $btnOrgPreview.Enabled = ($hasFiles -and $hasDest)
    $btnOrgExecute.Enabled = $hasPreviewed
    $btnOrgUndo.Enabled = $hasRollback
    $btnOrgAutoMap.Enabled = ($hasFiles -and $hasSeasonMap)
    $btnOrgBatchAssign.Enabled = $hasFiles

    if ($hasPreviewed) {
        $count = ($script:OrganizeFiles | Where-Object { $_.TargetPath -ne "" -and -not $_.Excluded }).Count
        $btnOrgExecute.Text = "Organize $count Files"
    } else {
        $btnOrgExecute.Text = "Organize Files"
    }
}

function Refresh-OrgGrid {
    $orgGrid.Rows.Clear()
    $t = Get-Theme
    foreach ($f in $script:OrganizeFiles) {
        $rowIdx = $orgGrid.Rows.Add(
            (-not $f.Excluded),
            $f.OriginalName,
            $f.DetectedShow,
            $f.DetectedSeason,
            $f.DetectedEpisode,
            $f.TargetPath,
            $f.FileSizeText,
            $f.Status
        )
        $row = $orgGrid.Rows[$rowIdx]
        $row.Tag = $f.FullPath
        switch -Wildcard ($f.Status) {
            "Detected"       { $row.DefaultCellStyle.BackColor = $t.RowHighlight }
            "Needs Review"   { $row.DefaultCellStyle.BackColor = $t.RowWarning }
            "Organized"      { $row.DefaultCellStyle.BackColor = $t.RowSuccess }
            "Error*"         { $row.DefaultCellStyle.BackColor = $t.RowError }
            "Skipped*"       { $row.DefaultCellStyle.BackColor = $t.RowWarning }
        }
        if ($f.Excluded) { $row.DefaultCellStyle.ForeColor = $t.DisabledFore }
    }
    # Apply theme to organize grid
    $orgGrid.BackgroundColor = $t.ListBack
    $orgGrid.GridColor = $t.BorderColor
    $orgGrid.DefaultCellStyle.BackColor = $t.ListBack
    $orgGrid.DefaultCellStyle.ForeColor = $t.ListFore
    $orgGrid.DefaultCellStyle.SelectionBackColor = $t.AccentColor
    $orgGrid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    $orgGrid.ColumnHeadersDefaultCellStyle.BackColor = $t.ControlBack
    $orgGrid.ColumnHeadersDefaultCellStyle.ForeColor = $t.ControlFore
    $orgGrid.ColumnHeadersDefaultCellStyle.Font = $fontBold
    $orgGrid.AlternatingRowsDefaultCellStyle.BackColor = $t.RowAlt
}

$btnOrgBrowseSource.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Select folder containing random/mixed episode files"
    if ($txtOrgSource.Text -and (Test-Path $txtOrgSource.Text)) { $d.SelectedPath = $txtOrgSource.Text }
    if ($d.ShowDialog() -eq "OK") {
        $txtOrgSource.Text = $d.SelectedPath
        Update-OrgButtonStates
    }
})

$btnOrgBrowseDest.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Select your TV Shows / Anime root folder (organized folders will be created here)"
    if ($txtOrgDest.Text -and (Test-Path $txtOrgDest.Text)) { $d.SelectedPath = $txtOrgDest.Text }
    if ($d.ShowDialog() -eq "OK") {
        $txtOrgDest.Text = $d.SelectedPath
        Update-OrgButtonStates
    }
})

$btnOrgScan.Add_Click({
    if (-not $txtOrgSource.Text -or -not (Test-Path $txtOrgSource.Text)) { return }
    $orgStatusLabel.Text = "Scanning files..."
    [System.Windows.Forms.Application]::DoEvents()

    $script:OrganizeFiles = Group-MediaFilesByShow -FolderPath $txtOrgSource.Text
    Refresh-OrgGrid

    $detected = ($script:OrganizeFiles | Where-Object { $_.ParsedOk }).Count
    $review = ($script:OrganizeFiles | Where-Object { -not $_.ParsedOk }).Count
    $shows = ($script:OrganizeFiles | Select-Object -ExpandProperty DetectedShow -Unique).Count
    $msg = "$($script:OrganizeFiles.Count) files found, $shows shows detected, $detected auto-detected, $review need review"
    if ($script:OrgSeasonMap.Count -gt 0) {
        $msg += " | Season map cached - click Auto-Map to apply"
    }
    $orgStatusLabel.Text = $msg
    $orgStatusCountLabel.Text = "$($script:OrganizeFiles.Count) files"
    Update-OrgButtonStates
})

$btnOrgPreview.Add_Click({
    if ($script:OrganizeFiles.Count -eq 0 -or -not $txtOrgDest.Text) { return }

    # Sync edits from grid back to data
    for ($i = 0; $i -lt $script:OrganizeFiles.Count; $i++) {
        if ($i -ge $orgGrid.Rows.Count) { break }
        $script:OrganizeFiles[$i].Excluded = -not $orgGrid.Rows[$i].Cells["OrgInclude"].Value
        $editShow = $orgGrid.Rows[$i].Cells["OrgShow"].Value
        if ($editShow) { $script:OrganizeFiles[$i].DetectedShow = $editShow.ToString() }
        $editSeason = $orgGrid.Rows[$i].Cells["OrgSeason"].Value
        if ($editSeason -ne $null) { try { $script:OrganizeFiles[$i].DetectedSeason = [int]$editSeason } catch {} }
        $editEp = $orgGrid.Rows[$i].Cells["OrgEpisode"].Value
        if ($editEp -ne $null) { try { $script:OrganizeFiles[$i].DetectedEpisode = [int]$editEp } catch {} }
    }

    $template = $txtTemplate.Text
    $usePlex = $chkPlexNaming.Checked
    $script:OrganizeFiles = Build-OrganizePaths -Files $script:OrganizeFiles -DestinationRoot $txtOrgDest.Text -Template $template `
        -PlexNaming $usePlex -PlexShowName $script:OrgSelectedShowName -PlexYear $script:OrgSelectedShowYear `
        -PlexId $script:OrgSelectedShowId -PlexSource $script:OrgSelectedSource
    Refresh-OrgGrid

    # Build folder structure preview
    $folderMap = @{}
    foreach ($f in ($script:OrganizeFiles | Where-Object { $_.TargetPath -ne "" -and -not $_.Excluded })) {
        $rel = $f.TargetPath.Replace($txtOrgDest.Text, "").TrimStart("\", "/")
        $parts = $rel -split "[/\\]"
        if ($parts.Count -ge 2) {
            $showFolder = $parts[0]
            $seasonFolder = $parts[1]
            $key = "$showFolder|$seasonFolder"
            if (-not $folderMap.ContainsKey($key)) { $folderMap[$key] = 0 }
            $folderMap[$key]++
        }
    }
    if ($folderMap.Count -gt 0) {
        $previewLines = @()
        $lastShow = ""
        foreach ($key in ($folderMap.Keys | Sort-Object)) {
            $parts = $key -split "\|"
            $show = $parts[0]
            $season = $parts[1]
            $count = $folderMap[$key]
            if ($show -ne $lastShow) {
                if ($lastShow -ne "") { $previewLines += "" }
                $previewLines += $show
                $lastShow = $show
            }
            $previewLines += "    $season - $count file(s)"
        }
        $txtOrgSeasonRef.Text = ($previewLines -join "`r`n")
        $orgSeasonPanel.Visible = $true
        $orgSeasonPanel.Height = [math]::Min(120, 20 + ($previewLines.Count * 15))
    }

    $orgStatusLabel.Text = "Preview ready - review target paths, then click Organize"
    Update-OrgButtonStates
})

$btnOrgExecute.Add_Click({
    $toOrganize = ($script:OrganizeFiles | Where-Object { $_.TargetPath -ne "" -and -not $_.Excluded }).Count
    if ($toOrganize -eq 0) { return }

    # Show examples in confirmation
    $examples = ""
    $exCount = 0
    foreach ($f in $script:OrganizeFiles) {
        if ($f.TargetPath -and -not $f.Excluded -and $exCount -lt 3) {
            $examples += "  $($f.OriginalName)`n  -> $($f.TargetPath)`n`n"
            $exCount++
        }
    }
    $msg = "Move and rename $toOrganize file(s) into organized folders?`n`nExamples:`n$examples"
    $confirm = [System.Windows.Forms.MessageBox]::Show($msg, "Confirm Organize", "YesNo", "Question")
    if ($confirm -ne "Yes") { return }

    $orgProgressBar.Visible = $true
    $orgProgressBar.Maximum = $toOrganize
    $orgProgressBar.Value = 0

    $results = Invoke-OrganizeFiles -Files $script:OrganizeFiles -OnProgress {
        param($current, $total, $name)
        $orgProgressBar.Value = $current
        $orgStatusLabel.Text = "[$current/$total] $name"
        [System.Windows.Forms.Application]::DoEvents()
    }

    $script:OrganizeRollback = $results.RollbackData
    $orgProgressBar.Visible = $false
    Refresh-OrgGrid

    $summary = "Organize Complete`n`n"
    $summary += "Moved & renamed: $($results.Success)`n"
    $summary += "Skipped: $($results.Skipped)`n"
    $summary += "Errors: $($results.Errors)"
    [System.Windows.Forms.MessageBox]::Show($summary, "Organize Complete", "OK", "Information")

    $orgStatusLabel.Text = "$($results.Success) organized, $($results.Skipped) skipped, $($results.Errors) errors"
    Update-OrgButtonStates
})

$btnOrgUndo.Add_Click({
    if ($script:OrganizeRollback.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nothing to undo.", "Undo", "OK", "Information")
        return
    }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Move $($script:OrganizeRollback.Count) file(s) back to their original locations?",
        "Confirm Undo", "YesNo", "Question")
    if ($confirm -ne "Yes") { return }

    $result = Invoke-OrganizeUndo -RollbackData $script:OrganizeRollback
    $script:OrganizeRollback = @()
    [System.Windows.Forms.MessageBox]::Show("$($result.Undone) restored, $($result.Errors) errors", "Undo Complete", "OK", "Information")
    $orgStatusLabel.Text = "Undo complete"

    # Re-scan to refresh
    if ($txtOrgSource.Text -and (Test-Path $txtOrgSource.Text)) {
        $script:OrganizeFiles = Group-MediaFilesByShow -FolderPath $txtOrgSource.Text
        Refresh-OrgGrid
    }
    Update-OrgButtonStates
})

$btnOrgClear.Add_Click({
    $orgGrid.Rows.Clear()
    $script:OrganizeFiles = @()
    $script:OrganizeRollback = @()
    $script:OrgSeasonMap = @()
    $script:OrgSelectedShowId = ""
    $script:OrgSelectedShowName = ""
    $script:OrgSelectedShowYear = ""
    $script:OrgSelectedSource = ""
    $txtOrgSource.Text = ""
    $txtOrgDest.Text = ""
    $orgSeasonPanel.Visible = $false
    $txtOrgSeasonRef.Text = ""
    $lblOrgMapInfo.Text = ""
    $chkAbsoluteMode.Checked = $false
    $chkPlexNaming.Checked = $false
    $orgStatusLabel.Text = "Browse to a source folder and set destination, then click Scan"
    $orgStatusCountLabel.Text = ""
    Update-OrgButtonStates
})

# -- Fetch Season Map ----------------------------------------------------------
$btnOrgFetchMap.Add_Click({
    if ($script:OrganizeFiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Scan files first before fetching a season map.", "No Files", "OK", "Warning")
        return
    }

    $orgSourceItem = $cmbOrgSource.SelectedItem
    $orgSource = if ($orgSourceItem -match "TMDB") { "TMDB" } elseif ($orgSourceItem -match "TVDB") { "TVDB" } elseif ($orgSourceItem -match "MAL") { "MAL" } else { "" }
    $tmdbKey = $txtTmdbKey.Text
    $tvdbKey = $txtTvdbKey.Text

    if ($orgSource -eq "TMDB" -and -not $tmdbKey) {
        [System.Windows.Forms.MessageBox]::Show("Enter your TMDB API key in Settings first.", "API Key Required", "OK", "Warning")
        return
    }
    if ($orgSource -eq "TVDB" -and -not $tvdbKey) {
        [System.Windows.Forms.MessageBox]::Show("Enter your TVDB API key in Settings first.", "API Key Required", "OK", "Warning")
        return
    }
    if ($orgSource -eq "MAL") {
        [System.Windows.Forms.MessageBox]::Show("MAL does not support multi-season mapping.`nUse TMDB or TVDB for season maps.", "Not Supported", "OK", "Information")
        return
    }

    # Get the most common show name from scanned files
    $showNames = $script:OrganizeFiles | Where-Object { $_.DetectedShow -ne "Unknown" } | Group-Object DetectedShow | Sort-Object Count -Descending
    $searchName = if ($showNames.Count -gt 0) { $showNames[0].Name } else { "Unknown" }

    $orgStatusLabel.Text = "Searching '$searchName' on $orgSource..."
    [System.Windows.Forms.Application]::DoEvents()

    $shows = Search-Show -ShowName $searchName -Source $orgSource -TmdbKey $tmdbKey -TvdbKey $tvdbKey
    if ($shows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No shows found for '$searchName' on $orgSource.", "Not Found", "OK", "Warning")
        $orgStatusLabel.Text = "Ready"
        return
    }
    $selectedShow = Show-SelectionDialog -Shows $shows
    if (-not $selectedShow) { $orgStatusLabel.Text = "Cancelled"; return }

    $script:OrgSelectedShowId = $selectedShow.Id
    $script:OrgSelectedShowName = $selectedShow.Name
    $script:OrgSelectedShowYear = $selectedShow.Year
    $script:OrgSelectedSource = $orgSource

    # Map ordering
    $seasonType = "default"
    if ($orgSource -eq "TVDB" -and $cmbOrgOrdering.SelectedItem) {
        switch ($cmbOrgOrdering.SelectedItem.ToString()) {
            "Aired"         { $seasonType = "default" }
            "DVD"           { $seasonType = "dvd" }
            "Absolute"      { $seasonType = "absolute" }
            "International" { $seasonType = "regional" }
        }
    }

    $orgStatusLabel.Text = "Fetching season map for '$($selectedShow.Name)'..."
    [System.Windows.Forms.Application]::DoEvents()

    $script:OrgSeasonMap = Get-SeasonMap -ShowId $selectedShow.Id -Source $orgSource -TmdbKey $tmdbKey -TvdbKey $tvdbKey -SeasonType $seasonType

    if ($script:OrgSeasonMap.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No season data found.", "Not Found", "OK", "Warning")
        $orgStatusLabel.Text = "Ready"
        return
    }

    # Build season reference text
    $refLines = @()
    $totalEps = 0
    foreach ($s in $script:OrgSeasonMap) {
        $refLines += "S$($s.SeasonNumber.ToString('00')): $($s.EpisodeCount) eps (Ep $($s.CumulativeStart)-$($s.CumulativeEnd))"
        $totalEps += $s.EpisodeCount
    }
    $txtOrgSeasonRef.Text = ($refLines -join "  |  ")
    $orgSeasonPanel.Visible = $true
    $lblOrgMapInfo.Text = "$($script:OrgSeasonMap.Count) seasons, $totalEps total episodes - $($selectedShow.Name)"

    $orgStatusLabel.Text = "Season map loaded: $($script:OrgSeasonMap.Count) seasons, $totalEps episodes. Click Auto-Map to apply."
    Update-OrgButtonStates
})

# -- Auto-Map Seasons ----------------------------------------------------------
$btnOrgAutoMap.Add_Click({
    if ($script:OrganizeFiles.Count -eq 0 -or $script:OrgSeasonMap.Count -eq 0) { return }

    $isAbsolute = $chkAbsoluteMode.Checked
    $mapped = 0
    $unmapped = 0
    $skipped = 0
    for ($i = 0; $i -lt $script:OrganizeFiles.Count; $i++) {
        $f = $script:OrganizeFiles[$i]
        if ($f.Excluded) { continue }

        # If not absolute mode, skip files that already have season info (season > 1 or explicitly set)
        if (-not $isAbsolute -and $f.DetectedSeason -gt 1) {
            $skipped++
            continue
        }

        $absEp = $f.DetectedEpisode
        if ($absEp -le 0) { $unmapped++; continue }

        $result = Convert-AbsoluteToSeason -AbsoluteEpisode $absEp -SeasonMap $script:OrgSeasonMap
        if ($result) {
            $script:OrganizeFiles[$i].DetectedSeason = $result.Season
            $script:OrganizeFiles[$i].DetectedEpisode = $result.Episode
            $script:OrganizeFiles[$i].Status = "Detected"
            $script:OrganizeFiles[$i].ParsedOk = $true
            $mapped++
        } else {
            $script:OrganizeFiles[$i].Status = "Needs Review"
            $unmapped++
        }
    }

    Refresh-OrgGrid
    $msg = "Auto-mapped $mapped file(s) to seasons."
    if ($skipped -gt 0) { $msg += " $skipped skipped (already had season)." }
    if ($unmapped -gt 0) { $msg += " $unmapped could not be mapped." }
    $orgStatusLabel.Text = $msg
    Update-OrgButtonStates
})

# -- Batch Assign Season -------------------------------------------------------
$btnOrgBatchAssign.Add_Click({
    if ($script:OrganizeFiles.Count -eq 0) { return }

    $selectedRows = @()
    foreach ($row in $orgGrid.SelectedRows) {
        $selectedRows += $row.Index
    }
    if ($selectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Select one or more rows first.", "No Selection", "OK", "Information")
        return
    }

    $input = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Assign $($selectedRows.Count) selected file(s) to season number:",
        "Batch Assign Season", "1")
    if (-not $input) { return }
    try { $newSeason = [int]$input } catch { return }

    foreach ($idx in $selectedRows) {
        if ($idx -lt $script:OrganizeFiles.Count) {
            $script:OrganizeFiles[$idx].DetectedSeason = $newSeason
            $script:OrganizeFiles[$idx].Status = "Detected"
        }
    }

    Refresh-OrgGrid
    $orgStatusLabel.Text = "$($selectedRows.Count) file(s) assigned to Season $newSeason"
    Update-OrgButtonStates
})

# Header checkbox toggle for organize grid
$orgGrid.Add_ColumnHeaderMouseClick({
    if ($_.ColumnIndex -eq 0) {
        $script:OrgHeaderCheck = -not $script:OrgHeaderCheck
        foreach ($row in $orgGrid.Rows) { $row.Cells["OrgInclude"].Value = $script:OrgHeaderCheck }
        for ($i = 0; $i -lt $script:OrganizeFiles.Count; $i++) {
            $script:OrganizeFiles[$i].Excluded = -not $script:OrgHeaderCheck
        }
        $orgGrid.Columns[0].HeaderText = if ($script:OrgHeaderCheck) { [char]0x2611 } else { [char]0x2610 }
        $orgGrid.RefreshEdit()
    }
})
$script:OrgHeaderCheck = $true

# Sync cell edits back to data
$orgGrid.Add_CellEndEdit({
    $rowIdx = $_.RowIndex
    $colName = $orgGrid.Columns[$_.ColumnIndex].Name
    if ($rowIdx -lt 0 -or $rowIdx -ge $script:OrganizeFiles.Count) { return }
    $val = $orgGrid.Rows[$rowIdx].Cells[$colName].Value
    switch ($colName) {
        "OrgShow" { if ($val) { $script:OrganizeFiles[$rowIdx].DetectedShow = $val.ToString() } }
        "OrgSeason" { if ($val -ne $null) { try { $script:OrganizeFiles[$rowIdx].DetectedSeason = [int]$val } catch {} } }
        "OrgEpisode" { if ($val -ne $null) { try { $script:OrganizeFiles[$rowIdx].DetectedEpisode = [int]$val } catch {} } }
    }
})

# Right-click context menu for organize grid
$orgContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$orgMenuAssignSeason = $orgContextMenu.Items.Add("Assign Season...")
$orgMenuAssignEpisode = $orgContextMenu.Items.Add("Assign Episode Number...")
$orgMenuAssignShow = $orgContextMenu.Items.Add("Assign Show Name...")
$orgContextMenu.Items.Add("-")  # separator
$orgMenuRenameFolder = $orgContextMenu.Items.Add("Rename Show Folder (Plex Style)")
$orgGrid.ContextMenuStrip = $orgContextMenu

$orgMenuAssignSeason.Add_Click({
    $selectedRows = @()
    foreach ($row in $orgGrid.SelectedRows) { $selectedRows += $row.Index }
    if ($selectedRows.Count -eq 0) { return }
    $input = [Microsoft.VisualBasic.Interaction]::InputBox("Assign $($selectedRows.Count) file(s) to season:", "Assign Season", "1")
    if (-not $input) { return }
    try { $newSeason = [int]$input } catch { return }
    foreach ($idx in $selectedRows) {
        if ($idx -lt $script:OrganizeFiles.Count) {
            $script:OrganizeFiles[$idx].DetectedSeason = $newSeason
            $script:OrganizeFiles[$idx].Status = "Detected"
        }
    }
    Refresh-OrgGrid
    $orgStatusLabel.Text = "$($selectedRows.Count) file(s) assigned to Season $newSeason"
})

$orgMenuAssignEpisode.Add_Click({
    $selectedRows = @($orgGrid.SelectedRows | ForEach-Object { $_.Index } | Sort-Object)
    if ($selectedRows.Count -eq 0) { return }
    $startEp = $script:OrganizeFiles[$selectedRows[0]].DetectedEpisode
    if ($startEp -le 0) { $startEp = 1 }
    $input = [Microsoft.VisualBasic.Interaction]::InputBox("Starting episode number for $($selectedRows.Count) file(s):`n(Will assign sequentially)", "Assign Episode", "$startEp")
    if (-not $input) { return }
    try { $epNum = [int]$input } catch { return }
    foreach ($idx in $selectedRows) {
        if ($idx -lt $script:OrganizeFiles.Count) {
            $script:OrganizeFiles[$idx].DetectedEpisode = $epNum
            $script:OrganizeFiles[$idx].Status = "Detected"
            $script:OrganizeFiles[$idx].ParsedOk = $true
            $epNum++
        }
    }
    Refresh-OrgGrid
    $orgStatusLabel.Text = "$($selectedRows.Count) file(s) assigned episode numbers"
})

$orgMenuAssignShow.Add_Click({
    $selectedRows = @()
    foreach ($row in $orgGrid.SelectedRows) { $selectedRows += $row.Index }
    if ($selectedRows.Count -eq 0) { return }
    $currentShow = $script:OrganizeFiles[$selectedRows[0]].DetectedShow
    $input = [Microsoft.VisualBasic.Interaction]::InputBox("Show name for $($selectedRows.Count) file(s):", "Assign Show", $currentShow)
    if (-not $input) { return }
    foreach ($idx in $selectedRows) {
        if ($idx -lt $script:OrganizeFiles.Count) {
            $script:OrganizeFiles[$idx].DetectedShow = $input
        }
    }
    Refresh-OrgGrid
    $orgStatusLabel.Text = "$($selectedRows.Count) file(s) assigned to '$input'"
})

$orgMenuRenameFolder.Add_Click({
    if (-not $script:OrgSelectedShowId -or -not $script:OrgSelectedShowName) {
        [System.Windows.Forms.MessageBox]::Show("Fetch a Season Map first to get show info.", "No Show Selected", "OK", "Warning")
        return
    }
    $destRoot = $txtOrgDest.Text
    if (-not $destRoot) {
        [System.Windows.Forms.MessageBox]::Show("Set a destination folder first.", "No Destination", "OK", "Warning")
        return
    }

    # Find existing show folder
    $showNames = $script:OrganizeFiles | Where-Object { $_.DetectedShow -ne "Unknown" } | Group-Object DetectedShow | Sort-Object Count -Descending
    $currentShowName = if ($showNames.Count -gt 0) { $showNames[0].Name } else { $script:OrgSelectedShowName }
    $existingPath = Join-Path $destRoot $currentShowName

    $sourceTag = if ($script:OrgSelectedSource -eq "TVDB") { "tvdb" } else { "tmdb" }
    $plexName = "$($script:OrgSelectedShowName) ($($script:OrgSelectedShowYear))" + " {$sourceTag-$($script:OrgSelectedShowId)}"
    $newPath = Join-Path $destRoot $plexName

    if (Test-Path $existingPath) {
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Rename folder:`n`n$existingPath`n->`n$newPath`n`nProceed?",
            "Rename Show Folder", "YesNo", "Question")
        if ($confirm -eq "Yes") {
            try {
                Rename-Item -Path $existingPath -NewName $plexName -Force
                [System.Windows.Forms.MessageBox]::Show("Folder renamed successfully!", "Done", "OK", "Information")
                $orgStatusLabel.Text = "Folder renamed to Plex format"
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Rename Failed", "OK", "Error")
            }
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Folder not found: $existingPath`n`nOrganize files first to create the folder, then rename.", "Folder Not Found", "OK", "Information")
    }
})

# -- Restore last folder / template --------------------------------------------
if ($script:Settings.LastFolder -and (Test-Path $script:Settings.LastFolder)) {
    $txtFolder.Text = $script:Settings.LastFolder
}
if ($script:Settings.NamingTemplate) {
    $txtTemplate.Text = $script:Settings.NamingTemplate
}

# -- Form Closing --------------------------------------------------------------
$form.Add_FormClosing({
    try {
        $s = $script:Settings
        if (-not $s) { $s = @{} }
        $s.WindowWidth = $form.Size.Width
        $s.WindowHeight = $form.Size.Height
        $s.WindowX = $form.Location.X
        $s.WindowY = $form.Location.Y
        $s.LastFolder = $txtFolder.Text
        $s.NamingTemplate = $txtTemplate.Text
        $s.TmdbApiKey = $txtTmdbKey.Text
        $s.TvdbApiKey = $txtTvdbKey.Text
        $s.PresetSaveLocation = $txtPresetLocation.Text
        $s.ThemePreference = if ((Get-ThemeName) -eq "Dark") { "Dark" } else { "Light" }
        Save-AppSettings -Settings $s
    } catch { }
})

# ===============================================================================
# INITIALIZE & SHOW
# ===============================================================================
if (-not [string]::IsNullOrWhiteSpace($script:Settings.PresetSaveLocation)) {
    Initialize-PresetManager -SettingsPath $script:Settings.PresetSaveLocation
}
Set-ApiKeys -TmdbKey $script:Settings.TmdbApiKey -TvdbKey $script:Settings.TvdbApiKey
Refresh-PresetList
Apply-ThemeToForm -Form $form
Update-TemplatePreview
Update-ButtonStates

# Set splitter to 25/75 after form is rendered
$form.Add_Shown({
    $form.Activate()
    $totalWidth = $splitContainer.ClientSize.Width
    if ($totalWidth -gt 0) {
        $splitContainer.SplitterDistance = [int]($totalWidth * 0.25)
    }
})
[void]$form.ShowDialog()
$form.Dispose()
