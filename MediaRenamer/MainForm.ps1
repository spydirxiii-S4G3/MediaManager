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
$form = New-Object System.Windows.Forms.Form
$form.Text = "Media File Renamer"
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
$tabSettings = New-Object System.Windows.Forms.TabPage "  Settings  "

$tabControl.TabPages.AddRange(@($tabRename, $tabSettings))
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
$cmbTitleSource.Items.AddRange(@("None", "Parse from file", "Manual edit", "TMDB Lookup", "TVDB Lookup"))
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
$cmbLanguage.Location = New-Object System.Drawing.Point(527, 109)
$cmbLanguage.Size = New-Object System.Drawing.Size(70, 23)
$cmbLanguage.DropDownStyle = "DropDownList"
$cmbLanguage.Items.AddRange(@("en", "ja", "ko", "zh", "de", "fr", "es", "pt", "it", "ru"))
$cmbLanguage.SelectedIndex = 0
$cmbLanguage.Visible = $false
$toolTip.SetToolTip($cmbLanguage, "Language for episode titles (en=English, ja=Japanese, etc.)")
$panelTop.Controls.Add($cmbLanguage)

$btnFetchTitles = New-Object System.Windows.Forms.Button
$btnFetchTitles.Text = "Fetch Titles"
$btnFetchTitles.Location = New-Object System.Drawing.Point(605, 108)
$btnFetchTitles.Size = New-Object System.Drawing.Size(90, 25)
$btnFetchTitles.FlatStyle = "Flat"
$btnFetchTitles.BackColor = $t.ButtonNeutral
$btnFetchTitles.ForeColor = $t.ButtonFore
$btnFetchTitles.Visible = $false
$toolTip.SetToolTip($btnFetchTitles, "Download episode titles from TMDB or TVDB")
$panelTop.Controls.Add($btnFetchTitles)

$cmbTitleSource.Add_SelectedIndexChanged({
    $isApi = ($cmbTitleSource.SelectedItem -match "TMDB|TVDB")
    $btnFetchTitles.Visible = $isApi
    $lblLang.Visible = $isApi
    $cmbLanguage.Visible = $isApi
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
$grid.MultiSelect = $false
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
$menuEditTitle = $contextMenu.Items.Add("Edit Episode Title (F2 or double-click)")
$menuExclude   = $contextMenu.Items.Add("Exclude / Include")
$contextMenu.Items.Add("-") | Out-Null
$menuMoveUp    = $contextMenu.Items.Add("Move Up")
$menuMoveDown  = $contextMenu.Items.Add("Move Down")
$grid.ContextMenuStrip = $contextMenu

# ===============================================================================
# TAB 2: SETTINGS
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
$lblTmplExamples.Text = @"
  {show} - S{season}E{episode}                         -> Show - S01E01.mp4
  {show} - S{season}E{episode} - {title}               -> Show - S01E01 - Title.mp4
  S{season}E{episode} - {show}                         -> S01E01 - Show.mp4
"@
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
    $script:Settings.ThemePreference = $newTheme
    Apply-GridTheme
    Refresh-ListViewFromFileList
})

# -- Context Menu handlers -----------------------------------------------------
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
    $source = if ($cmbTitleSource.SelectedItem -match "TMDB") { "TMDB" } else { "TVDB" }
    $tmdbKey = $txtTmdbKey.Text
    $tvdbKey = $txtTvdbKey.Text
    $lang = if ($cmbLanguage.SelectedItem) { $cmbLanguage.SelectedItem.ToString() } else { "en" }
    if (($source -eq "TMDB" -and -not $tmdbKey) -or ($source -eq "TVDB" -and -not $tvdbKey)) {
        [System.Windows.Forms.MessageBox]::Show("Enter your $source API key in Settings first.", "API Key Required", "OK", "Warning")
        return
    }
    $statusLabel.Text = "Searching '$($txtShowName.Text)' on $source..."
    [System.Windows.Forms.Application]::DoEvents()
    $shows = Search-Show -ShowName $txtShowName.Text -Source $source -TmdbKey $tmdbKey -TvdbKey $tvdbKey -Language $lang
    if ($shows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No shows found on $source.", "Not Found", "OK", "Warning")
        $statusLabel.Text = "Ready"
        return
    }
    $selectedShow = if ($shows.Count -eq 1) { $shows[0] } else { Show-SelectionDialog -Shows $shows }
    if (-not $selectedShow) { $statusLabel.Text = "Cancelled"; return }
    $statusLabel.Text = "Fetching titles for '$($selectedShow.Name)' S$([int]$numSeason.Value) ($lang)..."
    [System.Windows.Forms.Application]::DoEvents()
    $titles = Get-EpisodeTitles -ShowId $selectedShow.Id -Season ([int]$numSeason.Value) -Source $source -TmdbKey $tmdbKey -TvdbKey $tvdbKey -Language $lang
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
    $statusLabel.Text = "$($titles.Count) titles fetched from $source"
    # Auto re-preview with titles
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
