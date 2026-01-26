# =============================================================================
# Start-PlexGUI - ASCII ONLY VERSION (No Unicode)
# Uses Invoke-SourceFirstOrganize - reads YOUR files first!
# =============================================================================

function Start-PlexGUI {
    [CmdletBinding()]
    param()
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    # Main Form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'PlexAnimeTools - Source-First Organize'
    $form.Size = New-Object System.Drawing.Size(700, 600)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    
    # Title Label
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
    $lblTitle.Size = New-Object System.Drawing.Size(660, 30)
    $lblTitle.Text = 'PlexAnimeTools - YOUR Files Control Everything!'
    $lblTitle.Font = New-Object System.Drawing.Font('Arial', 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 122, 204)
    $form.Controls.Add($lblTitle)
    
    # Info Label
    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Location = New-Object System.Drawing.Point(20, 50)
    $lblInfo.Size = New-Object System.Drawing.Size(660, 30)
    $lblInfo.Text = 'Priority: YOUR filenames > Wikipedia > Jikan > MAL (APIs only add episode titles)'
    $lblInfo.Font = New-Object System.Drawing.Font('Arial', 9, [System.Drawing.FontStyle]::Italic)
    $lblInfo.ForeColor = [System.Drawing.Color]::DarkGreen
    $form.Controls.Add($lblInfo)
    
    # Source Panel
    $grpSource = New-Object System.Windows.Forms.GroupBox
    $grpSource.Location = New-Object System.Drawing.Point(20, 90)
    $grpSource.Size = New-Object System.Drawing.Size(660, 80)
    $grpSource.Text = 'Source (Your Media Files)'
    $form.Controls.Add($grpSource)
    
    $txtSource = New-Object System.Windows.Forms.TextBox
    $txtSource.Location = New-Object System.Drawing.Point(15, 30)
    $txtSource.Size = New-Object System.Drawing.Size(530, 25)
    $txtSource.Font = New-Object System.Drawing.Font('Consolas', 10)
    $grpSource.Controls.Add($txtSource)
    
    $btnBrowseSource = New-Object System.Windows.Forms.Button
    $btnBrowseSource.Location = New-Object System.Drawing.Point(555, 28)
    $btnBrowseSource.Size = New-Object System.Drawing.Size(90, 28)
    $btnBrowseSource.Text = 'Browse...'
    $btnBrowseSource.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = 'Select folder with media files'
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $txtSource.Text = $folderBrowser.SelectedPath
            # Auto-fill destination if empty
            if ([string]::IsNullOrWhiteSpace($txtDest.Text)) {
                $txtDest.Text = $folderBrowser.SelectedPath
            }
        }
    })
    $grpSource.Controls.Add($btnBrowseSource)
    
    # Destination Panel
    $grpDest = New-Object System.Windows.Forms.GroupBox
    $grpDest.Location = New-Object System.Drawing.Point(20, 180)
    $grpDest.Size = New-Object System.Drawing.Size(660, 80)
    $grpDest.Text = 'Destination (Your Plex Library)'
    $form.Controls.Add($grpDest)
    
    $txtDest = New-Object System.Windows.Forms.TextBox
    $txtDest.Location = New-Object System.Drawing.Point(15, 30)
    $txtDest.Size = New-Object System.Drawing.Size(530, 25)
    $txtDest.Font = New-Object System.Drawing.Font('Consolas', 10)
    $grpDest.Controls.Add($txtDest)
    
    $btnBrowseDest = New-Object System.Windows.Forms.Button
    $btnBrowseDest.Location = New-Object System.Drawing.Point(555, 28)
    $btnBrowseDest.Size = New-Object System.Drawing.Size(90, 28)
    $btnBrowseDest.Text = 'Browse...'
    $btnBrowseDest.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = 'Select Plex library folder'
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $txtDest.Text = $folderBrowser.SelectedPath
        }
    })
    $grpDest.Controls.Add($btnBrowseDest)
    
    # Options Panel
    $grpOptions = New-Object System.Windows.Forms.GroupBox
    $grpOptions.Location = New-Object System.Drawing.Point(20, 270)
    $grpOptions.Size = New-Object System.Drawing.Size(660, 80)
    $grpOptions.Text = 'Options'
    $form.Controls.Add($grpOptions)
    
    $chkWhatIf = New-Object System.Windows.Forms.CheckBox
    $chkWhatIf.Location = New-Object System.Drawing.Point(15, 30)
    $chkWhatIf.Size = New-Object System.Drawing.Size(200, 20)
    $chkWhatIf.Text = 'Preview Mode (WhatIf)'
    $chkWhatIf.Checked = $true
    $grpOptions.Controls.Add($chkWhatIf)
    
    $chkRecursive = New-Object System.Windows.Forms.CheckBox
    $chkRecursive.Location = New-Object System.Drawing.Point(230, 30)
    $chkRecursive.Size = New-Object System.Drawing.Size(200, 20)
    $chkRecursive.Text = 'Process Subfolders'
    $chkRecursive.Checked = $false
    $grpOptions.Controls.Add($chkRecursive)
    
    # Output Box
    $txtOutput = New-Object System.Windows.Forms.TextBox
    $txtOutput.Location = New-Object System.Drawing.Point(20, 360)
    $txtOutput.Size = New-Object System.Drawing.Size(660, 130)
    $txtOutput.Multiline = $true
    $txtOutput.ScrollBars = 'Vertical'
    $txtOutput.Font = New-Object System.Drawing.Font('Consolas', 9)
    $txtOutput.ReadOnly = $true
    $txtOutput.BackColor = [System.Drawing.Color]::Black
    $txtOutput.ForeColor = [System.Drawing.Color]::LightGreen
    $form.Controls.Add($txtOutput)
    
    $script:GuiLogBox = $txtOutput
    
    # Big Organize Button
    $btnGo = New-Object System.Windows.Forms.Button
    $btnGo.Location = New-Object System.Drawing.Point(20, 500)
    $btnGo.Size = New-Object System.Drawing.Size(500, 50)
    $btnGo.Text = 'PREVIEW CHANGES'  # Default when WhatIf is checked
    $btnGo.Font = New-Object System.Drawing.Font('Arial', 12, [System.Drawing.FontStyle]::Bold)
    $btnGo.BackColor = [System.Drawing.Color]::FromArgb(0, 200, 81)
    $btnGo.ForeColor = [System.Drawing.Color]::White
    $btnGo.FlatStyle = 'Flat'
    
    # Update button text dynamically when WhatIf checkbox changes
    $chkWhatIf.Add_CheckedChanged({
        if ($chkWhatIf.Checked) {
            $btnGo.Text = 'PREVIEW CHANGES'
            $btnGo.BackColor = [System.Drawing.Color]::FromArgb(255, 165, 0)  # Orange for preview
        } else {
            $btnGo.Text = 'ORGANIZE LIBRARY'
            $btnGo.BackColor = [System.Drawing.Color]::FromArgb(0, 200, 81)  # Green for action
        }
    })
    
    $btnGo.Add_Click({
        if (-not $txtSource.Text) {
            [System.Windows.Forms.MessageBox]::Show('Please select a source folder!', 'Missing Source', 'OK', 'Warning')
            return
        }
        
        if (-not $txtDest.Text) {
            [System.Windows.Forms.MessageBox]::Show('Please select a destination folder!', 'Missing Destination', 'OK', 'Warning')
            return
        }
        
        $btnGo.Enabled = $false
        $txtOutput.Clear()
        $txtOutput.AppendText("SOURCE-FIRST ORGANIZE`r`n")
        $txtOutput.AppendText("Priority: YOUR files > Wikipedia > Jikan > MAL`r`n")
        $txtOutput.AppendText("========================================`r`n`r`n")
        [System.Windows.Forms.Application]::DoEvents()
        
        try {
            # Build parameters
            $params = @{
                Path = $txtSource.Text
                OutputPath = $txtDest.Text
            }
            
            # Add WhatIf if checked
            if ($chkWhatIf.Checked) {
                $params.WhatIf = $true
            }
            
            # Always start with root folder (to handle loose files)
            $pathsToProcess = @($txtSource.Text)
            
            # Add subfolders if recursive is checked
            if ($chkRecursive.Checked) {
                $folders = Get-ChildItem -Path $txtSource.Text -Directory -Recurse -ErrorAction SilentlyContinue
                if ($folders) {
                    $pathsToProcess += $folders.FullName
                }
            }
            
            $params.Path = $pathsToProcess
            
            # Call SOURCE-FIRST function
            $txtOutput.AppendText("Step 1: Reading YOUR source files...`r`n")
            $txtOutput.AppendText("Step 2: Extracting YOUR metadata...`r`n")
            $txtOutput.AppendText("Step 3: Fetching episode titles from APIs...`r`n")
            $txtOutput.AppendText("Step 4: Organizing using YOUR data...`r`n`r`n")
            [System.Windows.Forms.Application]::DoEvents()
            
            $result = Invoke-SourceFirstOrganize @params
            
            $txtOutput.AppendText("`r`n========================================`r`n")
            
            if ($result) {
                $txtOutput.AppendText("[DONE] Source-first organization complete!`r`n")
                $txtOutput.AppendText("Processed: $($result.TotalProcessed)`r`n")
                $txtOutput.AppendText("Success: $($result.Success) | Failed: $($result.Failed)`r`n")
            } else {
                $txtOutput.AppendText("[INFO] No results returned`r`n")
            }
            
        }
        catch {
            $txtOutput.AppendText("`r`n[ERROR] $_`r`n")
            $txtOutput.AppendText("$($_.ScriptStackTrace)`r`n")
            [System.Windows.Forms.MessageBox]::Show("Error: $_", 'Error', 'OK', 'Error')
        }
        finally {
            $btnGo.Enabled = $true
        }
    })
    $form.Controls.Add($btnGo)
    
    # Close Button
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Location = New-Object System.Drawing.Point(530, 500)
    $btnClose.Size = New-Object System.Drawing.Size(150, 50)
    $btnClose.Text = 'Close'
    $btnClose.Font = New-Object System.Drawing.Font('Arial', 12)
    $btnClose.BackColor = [System.Drawing.Color]::LightGray
    $btnClose.Add_Click({ 
        $script:GuiLogBox = $null
        $form.Close() 
    })
    $form.Controls.Add($btnClose)
    
    # Show form
    $form.Add_FormClosing({
        $script:GuiLogBox = $null
        [System.GC]::Collect()
    })
    
    try {
        $form.ShowDialog() | Out-Null
    }
    finally {
        $script:GuiLogBox = $null
        if ($form) { $form.Dispose() }
        [System.GC]::Collect()
    }
}

Export-ModuleMember -Function Start-PlexGUI
