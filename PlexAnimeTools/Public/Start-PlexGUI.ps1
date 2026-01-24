# =============================================================================
# Start-PlexGUI Function
# Launches Windows Forms GUI with ALL available commands
# =============================================================================

function Start-PlexGUI {
    <#
    .SYNOPSIS
        Launches a Windows Forms GUI for PlexAnimeTools.
    
    .DESCRIPTION
        Provides a graphical interface for organizing anime and media files.
        Allows folder selection, configuration, and preview of changes.
        Includes buttons for ALL available commands.
    
    .EXAMPLE
        Start-PlexGUI
    #>
    
    [CmdletBinding()]
    param()
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName Microsoft.VisualBasic
    
    # Main Form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'PlexAnimeTools - Media Organizer'
    $form.Size = New-Object System.Drawing.Size(900, 750)
    $form.StartPosition = 'CenterScreen'
    
    # Source Folder
    $lblSource = New-Object System.Windows.Forms.Label
    $lblSource.Location = New-Object System.Drawing.Point(10, 20)
    $lblSource.Size = New-Object System.Drawing.Size(100, 20)
    $lblSource.Text = 'Source Folder:'
    $form.Controls.Add($lblSource)
    
    $txtSource = New-Object System.Windows.Forms.TextBox
    $txtSource.Location = New-Object System.Drawing.Point(120, 20)
    $txtSource.Size = New-Object System.Drawing.Size(650, 20)
    $form.Controls.Add($txtSource)
    
    $btnBrowseSource = New-Object System.Windows.Forms.Button
    $btnBrowseSource.Location = New-Object System.Drawing.Point(780, 18)
    $btnBrowseSource.Size = New-Object System.Drawing.Size(90, 24)
    $btnBrowseSource.Text = 'Browse...'
    $btnBrowseSource.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = 'Select source folder'
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $txtSource.Text = $folderBrowser.SelectedPath
        }
    })
    $form.Controls.Add($btnBrowseSource)
    
    # Destination Folder
    $lblDest = New-Object System.Windows.Forms.Label
    $lblDest.Location = New-Object System.Drawing.Point(10, 55)
    $lblDest.Size = New-Object System.Drawing.Size(100, 20)
    $lblDest.Text = 'Destination:'
    $form.Controls.Add($lblDest)
    
    $txtDest = New-Object System.Windows.Forms.TextBox
    $txtDest.Location = New-Object System.Drawing.Point(120, 55)
    $txtDest.Size = New-Object System.Drawing.Size(650, 20)
    $form.Controls.Add($txtDest)
    
    $btnBrowseDest = New-Object System.Windows.Forms.Button
    $btnBrowseDest.Location = New-Object System.Drawing.Point(780, 53)
    $btnBrowseDest.Size = New-Object System.Drawing.Size(90, 24)
    $btnBrowseDest.Text = 'Browse...'
    $btnBrowseDest.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = 'Select destination folder'
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $txtDest.Text = $folderBrowser.SelectedPath
        }
    })
    $form.Controls.Add($btnBrowseDest)
    
    # Options GroupBox
    $grpOptions = New-Object System.Windows.Forms.GroupBox
    $grpOptions.Location = New-Object System.Drawing.Point(10, 90)
    $grpOptions.Size = New-Object System.Drawing.Size(860, 120)
    $grpOptions.Text = 'Options'
    $form.Controls.Add($grpOptions)
    
    $chkWhatIf = New-Object System.Windows.Forms.CheckBox
    $chkWhatIf.Location = New-Object System.Drawing.Point(10, 25)
    $chkWhatIf.Size = New-Object System.Drawing.Size(200, 20)
    $chkWhatIf.Text = 'Preview Only (WhatIf)'
    $chkWhatIf.Checked = $true
    $grpOptions.Controls.Add($chkWhatIf)
    
    $chkRecursive = New-Object System.Windows.Forms.CheckBox
    $chkRecursive.Location = New-Object System.Drawing.Point(10, 50)
    $chkRecursive.Size = New-Object System.Drawing.Size(200, 20)
    $chkRecursive.Text = 'Process Subfolders'
    $chkRecursive.Checked = $true
    $grpOptions.Controls.Add($chkRecursive)
    
    $lblConfig = New-Object System.Windows.Forms.Label
    $lblConfig.Location = New-Object System.Drawing.Point(220, 25)
    $lblConfig.Size = New-Object System.Drawing.Size(100, 20)
    $lblConfig.Text = 'Config Profile:'
    $grpOptions.Controls.Add($lblConfig)
    
    $cmbConfig = New-Object System.Windows.Forms.ComboBox
    $cmbConfig.Location = New-Object System.Drawing.Point(325, 23)
    $cmbConfig.Size = New-Object System.Drawing.Size(150, 20)
    $cmbConfig.DropDownStyle = 'DropDownList'
    $cmbConfig.Items.AddRange(@('default', 'plex-strict', 'fansub-chaos'))
    $cmbConfig.SelectedIndex = 0
    $grpOptions.Controls.Add($cmbConfig)
    
    $lblForceType = New-Object System.Windows.Forms.Label
    $lblForceType.Location = New-Object System.Drawing.Point(220, 53)
    $lblForceType.Size = New-Object System.Drawing.Size(100, 20)
    $lblForceType.Text = 'Force Type:'
    $grpOptions.Controls.Add($lblForceType)
    
    $cmbForceType = New-Object System.Windows.Forms.ComboBox
    $cmbForceType.Location = New-Object System.Drawing.Point(325, 51)
    $cmbForceType.Size = New-Object System.Drawing.Size(150, 20)
    $cmbForceType.DropDownStyle = 'DropDownList'
    $cmbForceType.Items.AddRange(@('Auto', 'Anime', 'TV Series', 'Cartoon', 'Movie'))
    $cmbForceType.SelectedIndex = 0
    $grpOptions.Controls.Add($cmbForceType)
    
    $lblHelp = New-Object System.Windows.Forms.Label
    $lblHelp.Location = New-Object System.Drawing.Point(10, 80)
    $lblHelp.Size = New-Object System.Drawing.Size(840, 30)
    $lblHelp.Text = 'Tip: Always use Preview mode first! Review changes in the preview window, then click Proceed to execute.'
    $lblHelp.Font = New-Object System.Drawing.Font('Arial', 8, [System.Drawing.FontStyle]::Italic)
    $lblHelp.ForeColor = [System.Drawing.Color]::DarkBlue
    $grpOptions.Controls.Add($lblHelp)
    
    # Progress Bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 220)
    $progressBar.Size = New-Object System.Drawing.Size(860, 25)
    $form.Controls.Add($progressBar)
    
    # Output TextBox
    $txtOutput = New-Object System.Windows.Forms.TextBox
    $txtOutput.Location = New-Object System.Drawing.Point(10, 255)
    $txtOutput.Size = New-Object System.Drawing.Size(860, 350)
    $txtOutput.Multiline = $true
    $txtOutput.ScrollBars = 'Vertical'
    $txtOutput.Font = New-Object System.Drawing.Font('Consolas', 9)
    $txtOutput.ReadOnly = $true
    $form.Controls.Add($txtOutput)
    
    # Set GUI log reference
    $script:GuiLogBox = $txtOutput
    
    # ========================================
    # BUTTON PANEL - ALL COMMANDS
    # ========================================
    
    # Row 1: Main Processing
    $btnProcess = New-Object System.Windows.Forms.Button
    $btnProcess.Location = New-Object System.Drawing.Point(10, 615)
    $btnProcess.Size = New-Object System.Drawing.Size(100, 35)
    $btnProcess.Text = 'Process'
    $btnProcess.BackColor = [System.Drawing.Color]::LightGreen
    $btnProcess.Add_Click({
        if (-not $txtSource.Text) {
            [System.Windows.Forms.MessageBox]::Show('Please select a source folder.', 'Error')
            return
        }
        
        if (-not $txtDest.Text) {
            [System.Windows.Forms.MessageBox]::Show('Please select a destination folder.', 'Error')
            return
        }
        
        $txtOutput.Clear()
        $txtOutput.AppendText("Processing started...`r`n")
        $form.Refresh()
        
        try {
            # Build parameters
            $params = @{
                Path = $txtSource.Text
                OutputPath = $txtDest.Text
                ConfigProfile = $cmbConfig.SelectedItem
            }
            
            # Add ForceType if not Auto
            if ($cmbForceType.SelectedItem -ne 'Auto') {
                $params.ForceType = $cmbForceType.SelectedItem
            }
            
            # Add WhatIf if checked
            if ($chkWhatIf.Checked) {
                $params.WhatIf = $true
            }
            
            # Process based on recursive option
            if ($chkRecursive.Checked) {
                # Get all subdirectories and process each
                $folders = Get-ChildItem -Path $txtSource.Text -Directory
                if ($folders) {
                    $txtOutput.AppendText("Found $($folders.Count) subfolder(s) to process...`r`n`r`n")
                    $form.Refresh()
                    
                    $progressBar.Maximum = $folders.Count
                    $progressBar.Value = 0
                    
                    foreach ($folder in $folders) {
                        $params.Path = $folder.FullName
                        $result = Invoke-AnimeOrganize @params
                        
                        $progressBar.Value++
                        $form.Refresh()
                    }
                }
                else {
                    $txtOutput.AppendText("No subfolders found in source directory.`r`n")
                }
            }
            else {
                # Process single folder
                $result = Invoke-AnimeOrganize @params
            }
            
            $txtOutput.AppendText("`r`nProcessing complete!`r`n")
            $txtOutput.AppendText("`r`nLogs saved to: $script:LogFile`r`n")
            $progressBar.Value = $progressBar.Maximum
            
        } catch {
            $errorMsg = "Error: $_"
            $txtOutput.AppendText("`r`n$errorMsg`r`n")
            
            # Log the error
            Write-ErrorLog "GUI Processing Error" $_
            
            [System.Windows.Forms.MessageBox]::Show($errorMsg, 'Error')
        }
        finally {
            # Clear GUI log reference
            $script:GuiLogBox = $null
        }
    })
    $form.Controls.Add($btnProcess)
    
    # Get Anime Info
    $btnAnimeInfo = New-Object System.Windows.Forms.Button
    $btnAnimeInfo.Location = New-Object System.Drawing.Point(120, 615)
    $btnAnimeInfo.Size = New-Object System.Drawing.Size(100, 35)
    $btnAnimeInfo.Text = 'Anime Info'
    $btnAnimeInfo.Add_Click({
        $animeTitle = [Microsoft.VisualBasic.Interaction]::InputBox("Enter anime title to search:", "Get Anime Info", "")
        
        if (-not [string]::IsNullOrWhiteSpace($animeTitle)) {
            $txtOutput.Clear()
            $txtOutput.AppendText("Searching for: $animeTitle...`r`n`r`n")
            $form.Refresh()
            
            try {
                $info = Get-AnimeInfo -Title $animeTitle -IncludeEpisodes
                
                if ($info) {
                    $txtOutput.AppendText("Title: $($info.Title)`r`n")
                    $txtOutput.AppendText("English: $($info.EnglishTitle)`r`n")
                    $txtOutput.AppendText("Type: $($info.Type)`r`n")
                    $txtOutput.AppendText("Episodes: $($info.Episodes)`r`n")
                    $txtOutput.AppendText("Status: $($info.Status)`r`n")
                    $txtOutput.AppendText("Score: $($info.Score)`r`n")
                    $txtOutput.AppendText("Year: $($info.Year)`r`n")
                    $txtOutput.AppendText("Genres: $($info.Genres)`r`n")
                    $txtOutput.AppendText("`r`nSynopsis:`r`n$($info.Synopsis)`r`n")
                    
                    if ($info.EpisodeList -and $info.EpisodeList.Count -gt 0) {
                        $txtOutput.AppendText("`r`nFirst 10 Episodes:`r`n")
                        $info.EpisodeList | Select-Object -First 10 | ForEach-Object {
                            $txtOutput.AppendText("  $($_.Number): $($_.Title)`r`n")
                        }
                    }
                }
                else {
                    $txtOutput.AppendText("No results found for: $animeTitle`r`n")
                }
            }
            catch {
                $txtOutput.AppendText("Error: $_`r`n")
            }
        }
    })
    $form.Controls.Add($btnAnimeInfo)
    
    # Test Plex
    $btnTestPlex = New-Object System.Windows.Forms.Button
    $btnTestPlex.Location = New-Object System.Drawing.Point(230, 615)
    $btnTestPlex.Size = New-Object System.Drawing.Size(100, 35)
    $btnTestPlex.Text = 'Test Plex'
    $btnTestPlex.Add_Click({
        $testPath = [Microsoft.VisualBasic.Interaction]::InputBox("Enter path to test:", "Test Plex Library", $txtDest.Text)
        
        if (-not [string]::IsNullOrWhiteSpace($testPath)) {
            if (Test-Path $testPath) {
                $txtOutput.Clear()
                $txtOutput.AppendText("Testing Plex library at: $testPath...`r`n`r`n")
                $form.Refresh()
                
                try {
                    $folders = Get-ChildItem -Path $testPath -Directory -ErrorAction Stop
                    
                    if ($folders) {
                        foreach ($folder in $folders) {
                            $result = Test-PlexScan -Path $folder.FullName -NoPrompt
                            
                            $txtOutput.AppendText("$($result.ShowName): $($result.Score)% - $($result.Status)`r`n")
                            
                            if ($result.Issues) {
                                foreach ($issue in $result.Issues) {
                                    $txtOutput.AppendText("  [!] $issue`r`n")
                                }
                            }
                            
                            $txtOutput.AppendText("`r`n")
                        }
                    }
                    else {
                        $txtOutput.AppendText("No subdirectories found.`r`n")
                    }
                }
                catch {
                    $txtOutput.AppendText("Error: $_`r`n")
                }
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Path not found: $testPath", 'Error')
            }
        }
    })
    $form.Controls.Add($btnTestPlex)
    
    # Row 1: Utility Commands
    
    # View Main Log
    $btnViewLog = New-Object System.Windows.Forms.Button
    $btnViewLog.Location = New-Object System.Drawing.Point(340, 615)
    $btnViewLog.Size = New-Object System.Drawing.Size(100, 35)
    $btnViewLog.Text = 'View Main Log'
    $btnViewLog.Add_Click({
        try {
            $logPath = Get-LatestLog -Type Main
            if ($logPath -and (Test-Path $logPath)) {
                Start-Process notepad.exe -ArgumentList $logPath
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("No log file found.", 'Info')
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error opening log: $_", 'Error')
        }
    })
    $form.Controls.Add($btnViewLog)
    
    # View Transcript
    $btnViewTranscript = New-Object System.Windows.Forms.Button
    $btnViewTranscript.Location = New-Object System.Drawing.Point(450, 615)
    $btnViewTranscript.Size = New-Object System.Drawing.Size(100, 35)
    $btnViewTranscript.Text = 'View Transcript'
    $btnViewTranscript.Add_Click({
        try {
            $logPath = Get-LatestLog -Type Transcript
            if ($logPath -and (Test-Path $logPath)) {
                Start-Process notepad.exe -ArgumentList $logPath
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("No transcript file found.", 'Info')
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error opening transcript: $_", 'Error')
        }
    })
    $form.Controls.Add($btnViewTranscript)
    
    # Clear Old Logs
    $btnClearLogs = New-Object System.Windows.Forms.Button
    $btnClearLogs.Location = New-Object System.Drawing.Point(560, 615)
    $btnClearLogs.Size = New-Object System.Drawing.Size(100, 35)
    $btnClearLogs.Text = 'Clear Old Logs'
    $btnClearLogs.Add_Click({
        $days = [Microsoft.VisualBasic.Interaction]::InputBox("Delete logs older than how many days?", "Clear Old Logs", "30")
        
        if ($days -match '^\d+$') {
            try {
                Clear-OldLogs -Days ([int]$days)
                [System.Windows.Forms.MessageBox]::Show("Old logs cleared successfully!", 'Success')
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("Error clearing logs: $_", 'Error')
            }
        }
    })
    $form.Controls.Add($btnClearLogs)
    
    # Row 2: Additional Commands
    
    # Test MAL API
    $btnTestMAL = New-Object System.Windows.Forms.Button
    $btnTestMAL.Location = New-Object System.Drawing.Point(10, 660)
    $btnTestMAL.Size = New-Object System.Drawing.Size(100, 35)
    $btnTestMAL.Text = 'Test MAL API'
    $btnTestMAL.Add_Click({
        $txtOutput.Clear()
        $txtOutput.AppendText("Testing MAL Official API...`r`n`r`n")
        $form.Refresh()
        
        try {
            Test-MALOfficialAPI
        }
        catch {
            $txtOutput.AppendText("Error: $_`r`n")
        }
    })
    $form.Controls.Add($btnTestMAL)
    
    # Export Error Report
    $btnExportErrors = New-Object System.Windows.Forms.Button
    $btnExportErrors.Location = New-Object System.Drawing.Point(120, 660)
    $btnExportErrors.Size = New-Object System.Drawing.Size(110, 35)
    $btnExportErrors.Text = 'Export Errors'
    $btnExportErrors.Add_Click({
        try {
            $reportPath = Export-ErrorReport
            if ($reportPath) {
                [System.Windows.Forms.MessageBox]::Show("Error report exported to:`n$reportPath", 'Success')
                Start-Process notepad.exe -ArgumentList $reportPath
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("No errors to export.", 'Info')
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error exporting report: $_", 'Error')
        }
    })
    $form.Controls.Add($btnExportErrors)
    
    # Get Latest Log Path
    $btnGetLogPath = New-Object System.Windows.Forms.Button
    $btnGetLogPath.Location = New-Object System.Drawing.Point(240, 660)
    $btnGetLogPath.Size = New-Object System.Drawing.Size(110, 35)
    $btnGetLogPath.Text = 'Get Log Path'
    $btnGetLogPath.Add_Click({
        try {
            $logPath = Get-LatestLog -Type Main
            if ($logPath) {
                [System.Windows.Forms.MessageBox]::Show("Latest log path:`n$logPath", 'Log Path')
                [System.Windows.Forms.Clipboard]::SetText($logPath)
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("No log file found.", 'Info')
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error: $_", 'Error')
        }
    })
    $form.Controls.Add($btnGetLogPath)
    
    # Show Error Summary
    $btnErrorSummary = New-Object System.Windows.Forms.Button
    $btnErrorSummary.Location = New-Object System.Drawing.Point(360, 660)
    $btnErrorSummary.Size = New-Object System.Drawing.Size(110, 35)
    $btnErrorSummary.Text = 'Error Summary'
    $btnErrorSummary.Add_Click({
        $txtOutput.Clear()
        try {
            $summary = Get-ErrorSummary
            $txtOutput.AppendText($summary)
        }
        catch {
            $txtOutput.AppendText("Error getting summary: $_`r`n")
        }
    })
    $form.Controls.Add($btnErrorSummary)
    
    # Open Logs Folder
    $btnOpenLogsFolder = New-Object System.Windows.Forms.Button
    $btnOpenLogsFolder.Location = New-Object System.Drawing.Point(480, 660)
    $btnOpenLogsFolder.Size = New-Object System.Drawing.Size(110, 35)
    $btnOpenLogsFolder.Text = 'Open Logs'
    $btnOpenLogsFolder.Add_Click({
        try {
            $logsPath = Join-Path $script:ModuleRoot 'Logs'
            if (Test-Path $logsPath) {
                Start-Process explorer.exe -ArgumentList $logsPath
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Logs folder not found.", 'Error')
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error opening logs folder: $_", 'Error')
        }
    })
    $form.Controls.Add($btnOpenLogsFolder)
    
    # Help/README
    $btnHelp = New-Object System.Windows.Forms.Button
    $btnHelp.Location = New-Object System.Drawing.Point(600, 660)
    $btnHelp.Size = New-Object System.Drawing.Size(100, 35)
    $btnHelp.Text = 'Help/README'
    $btnHelp.Add_Click({
        try {
            $readmePath = Join-Path $script:ModuleRoot "README.md"
            if (Test-Path $readmePath) {
                Start-Process $readmePath
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("README.md not found.", 'Error')
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error opening README: $_", 'Error')
        }
    })
    $form.Controls.Add($btnHelp)
    
    # Close Button
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Location = New-Object System.Drawing.Point(790, 660)
    $btnClose.Size = New-Object System.Drawing.Size(80, 35)
    $btnClose.Text = 'Close'
    $btnClose.BackColor = [System.Drawing.Color]::LightCoral
    $btnClose.Add_Click({ 
        $script:GuiLogBox = $null
        $form.Close() 
    })
    $form.Controls.Add($btnClose)
    
    # Show Form
    $form.Add_FormClosing({
        $script:GuiLogBox = $null
    })
    
    $form.ShowDialog() | Out-Null
}

Export-ModuleMember -Function Start-PlexGUI