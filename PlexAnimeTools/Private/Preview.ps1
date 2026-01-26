# =============================================================================
# Show-WhatIfPreview Function
# Displays preview window with planned changes
# =============================================================================

function Show-WhatIfPreview {
    <#
    .SYNOPSIS
        Shows a preview window of planned changes with option to proceed
    
    .PARAMETER Changes
        Array of change objects to display
    
    .PARAMETER Parameters
        Original parameters to pass to actual execution
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Changes,
        
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    # Create form
    $previewForm = New-Object System.Windows.Forms.Form
    $previewForm.Text = 'PlexAnimeTools - Preview Changes'
    $previewForm.Size = New-Object System.Drawing.Size(1000, 700)
    $previewForm.MinimumSize = New-Object System.Drawing.Size(800, 600)
    $previewForm.StartPosition = 'CenterScreen'
    $previewForm.FormBorderStyle = 'Sizable'
    $previewForm.MaximizeBox = $true
    $previewForm.MinimizeBox = $true
    
    # Summary Panel - anchored to top, stretches width
    $summaryPanel = New-Object System.Windows.Forms.Panel
    $summaryPanel.Location = New-Object System.Drawing.Point(10, 10)
    $summaryPanel.Size = New-Object System.Drawing.Size(($previewForm.ClientSize.Width - 20), 80)
    $summaryPanel.Anchor = 'Top,Left,Right'
    $summaryPanel.BorderStyle = 'FixedSingle'
    $previewForm.Controls.Add($summaryPanel)
    
    # Summary Labels
    $lblSummaryTitle = New-Object System.Windows.Forms.Label
    $lblSummaryTitle.Location = New-Object System.Drawing.Point(10, 10)
    $lblSummaryTitle.Size = New-Object System.Drawing.Size(940, 20)
    $lblSummaryTitle.Text = 'PREVIEW: Changes that will be made'
    $lblSummaryTitle.Font = New-Object System.Drawing.Font('Arial', 12, [System.Drawing.FontStyle]::Bold)
    $lblSummaryTitle.ForeColor = [System.Drawing.Color]::DarkBlue
    $summaryPanel.Controls.Add($lblSummaryTitle)
    
    $lblStats = New-Object System.Windows.Forms.Label
    $lblStats.Location = New-Object System.Drawing.Point(10, 35)
    $lblStats.Size = New-Object System.Drawing.Size(940, 20)
    $lblStats.Font = New-Object System.Drawing.Font('Arial', 10)
    
    $totalFiles = ($Changes | Where-Object { $_.Type -eq 'File' }).Count
    $totalShows = ($Changes | Select-Object ShowTitle -Unique).Count
    $totalFolders = ($Changes | Where-Object { $_.Type -eq 'Folder' }).Count
    
    $lblStats.Text = "Total Shows: $totalShows | Files to Rename/Move: $totalFiles | Folders to Create: $totalFolders"
    $summaryPanel.Controls.Add($lblStats)
    
    # Add instruction label
    $lblInstructions = New-Object System.Windows.Forms.Label
    $lblInstructions.Location = New-Object System.Drawing.Point(10, 55)
    $lblInstructions.Size = New-Object System.Drawing.Size(940, 20)
    $lblInstructions.Font = New-Object System.Drawing.Font('Arial', 9, [System.Drawing.FontStyle]::Italic)
    $lblInstructions.ForeColor = [System.Drawing.Color]::DarkGreen
    $lblInstructions.Text = 'Tip: Drag column borders to resize | Scroll horizontally to see full paths | Hover over cells for tooltips'
    $summaryPanel.Controls.Add($lblInstructions)
    
    # DataGridView for changes - fills available space, resizes with form
    $dgvChanges = New-Object System.Windows.Forms.DataGridView
    $dgvChanges.Location = New-Object System.Drawing.Point(10, 100)
    $dgvChanges.Size = New-Object System.Drawing.Size(($previewForm.ClientSize.Width - 20), ($previewForm.ClientSize.Height - 180))
    $dgvChanges.Anchor = 'Top,Bottom,Left,Right'  # Stretches in all directions
    $dgvChanges.AllowUserToAddRows = $false
    $dgvChanges.AllowUserToDeleteRows = $false
    $dgvChanges.ReadOnly = $true
    $dgvChanges.SelectionMode = 'FullRowSelect'
    $dgvChanges.MultiSelect = $true
    $dgvChanges.RowHeadersVisible = $false
    $dgvChanges.BackgroundColor = [System.Drawing.Color]::White
    
    # Enable horizontal scrolling and column resizing
    $dgvChanges.AutoSizeColumnsMode = 'None'  # Allow manual sizing
    $dgvChanges.ScrollBars = 'Both'            # Enable both scrollbars
    $dgvChanges.AllowUserToResizeColumns = $true
    $dgvChanges.AllowUserToResizeRows = $false
    $dgvChanges.ColumnHeadersHeightSizeMode = 'AutoSize'
    
    # Enable word wrap for long paths
    $dgvChanges.DefaultCellStyle.WrapMode = 'False'  # No wrap for cleaner look
    
    $previewForm.Controls.Add($dgvChanges)
    
    # Add columns with better sizing
    $colType = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colType.Name = 'Type'
    $colType.HeaderText = 'Type'
    $colType.Width = 60
    $colType.MinimumWidth = 50
    $dgvChanges.Columns.Add($colType) | Out-Null
    
    $colShow = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colShow.Name = 'ShowTitle'
    $colShow.HeaderText = 'Show'
    $colShow.Width = 150
    $colShow.MinimumWidth = 100
    $dgvChanges.Columns.Add($colShow) | Out-Null
    
    $colAction = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colAction.Name = 'Action'
    $colAction.HeaderText = 'Action'
    $colAction.Width = 70
    $colAction.MinimumWidth = 60
    $dgvChanges.Columns.Add($colAction) | Out-Null
    
    $colSource = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colSource.Name = 'Source'
    $colSource.HeaderText = 'Source Path / Current Name'
    $colSource.Width = 450
    $colSource.MinimumWidth = 200
    $dgvChanges.Columns.Add($colSource) | Out-Null
    
    $colDest = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colDest.Name = 'Destination'
    $colDest.HeaderText = 'Destination Path / New Name'
    $colDest.Width = 450
    $colDest.MinimumWidth = 200
    $dgvChanges.Columns.Add($colDest) | Out-Null
    
    # Populate data
    foreach ($change in $Changes) {
        $row = $dgvChanges.Rows.Add()
        $dgvChanges.Rows[$row].Cells[0].Value = $change.Type
        $dgvChanges.Rows[$row].Cells[1].Value = $change.ShowTitle
        $dgvChanges.Rows[$row].Cells[2].Value = $change.Action
        $dgvChanges.Rows[$row].Cells[3].Value = $change.Source
        $dgvChanges.Rows[$row].Cells[4].Value = $change.Destination
        
        # Add tooltips with full paths
        $dgvChanges.Rows[$row].Cells[3].ToolTipText = $change.Source
        $dgvChanges.Rows[$row].Cells[4].ToolTipText = $change.Destination
        
        # Color code by type
        if ($change.Type -eq 'Folder') {
            $dgvChanges.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightBlue
        }
        elseif ($change.Action -eq 'Create') {
            $dgvChanges.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGreen
        }
        elseif ($change.Action -eq 'Move') {
            $dgvChanges.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightYellow
        }
    }
    
    # Add double-click event on column headers to auto-fit width
    $dgvChanges.Add_ColumnHeaderMouseDoubleClick({
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $sender.Columns[$e.ColumnIndex].AutoSizeMode = 'AllCells'
            $sender.Columns[$e.ColumnIndex].AutoSizeMode = 'None'
        }
    })
    
    # Button Panel - anchored to bottom, stretches width
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Location = New-Object System.Drawing.Point(10, ($previewForm.ClientSize.Height - 70))
    $buttonPanel.Size = New-Object System.Drawing.Size(($previewForm.ClientSize.Width - 20), 60)
    $buttonPanel.Anchor = 'Bottom,Left,Right'
    $previewForm.Controls.Add($buttonPanel)
    
    # Export Button
    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Location = New-Object System.Drawing.Point(10, 15)
    $btnExport.Size = New-Object System.Drawing.Size(120, 35)
    $btnExport.Text = 'Export to CSV'
    $btnExport.Add_Click({
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = 'CSV files (*.csv)|*.csv'
        $saveDialog.FileName = "PlexAnimeTools_Preview_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $saveDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
        
        if ($saveDialog.ShowDialog() -eq 'OK') {
            try {
                $Changes | Export-Csv -Path $saveDialog.FileName -NoTypeInformation
                [System.Windows.Forms.MessageBox]::Show("Preview exported to:`n$($saveDialog.FileName)", 'Export Successful', 'OK', 'Information')
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to export:`n$_", 'Export Failed', 'OK', 'Error')
            }
        }
    })
    $buttonPanel.Controls.Add($btnExport)
    
    # Status Label
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Location = New-Object System.Drawing.Point(140, 20)
    $lblStatus.Size = New-Object System.Drawing.Size(500, 25)
    $lblStatus.Text = 'Review changes above. Click Proceed to execute or Cancel to abort.'
    $lblStatus.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $buttonPanel.Controls.Add($lblStatus)
    
    # Cancel Button - anchored to bottom right
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Location = New-Object System.Drawing.Point(($buttonPanel.Width - 220), 15)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 35)
    $btnCancel.Text = 'Cancel'
    $btnCancel.Anchor = 'Bottom,Right'
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $buttonPanel.Controls.Add($btnCancel)
    
    # Proceed Button - anchored to bottom right
    $btnProceed = New-Object System.Windows.Forms.Button
    $btnProceed.Location = New-Object System.Drawing.Point(($buttonPanel.Width - 110), 15)
    $btnProceed.Size = New-Object System.Drawing.Size(100, 35)
    $btnProceed.Text = 'Proceed'
    $btnProceed.BackColor = [System.Drawing.Color]::LightGreen
    $btnProceed.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $btnProceed.Anchor = 'Bottom,Right'
    $btnProceed.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $buttonPanel.Controls.Add($btnProceed)
    
    # Set form properties
    $previewForm.AcceptButton = $btnProceed
    $previewForm.CancelButton = $btnCancel
    
    # Add cleanup handler
    $previewForm.Add_FormClosing({
        # Force UI update
        [System.Windows.Forms.Application]::DoEvents()
    })
    
    # Show form and get result
    try {
        $result = $previewForm.ShowDialog()
        
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            Write-Host ""
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "User approved changes. Executing now..." -ForegroundColor Green
            Write-Host "============================================" -ForegroundColor Green
            Write-Host ""
            
            # Create new parameters without WhatIf
            $executeParams = @{}
            foreach ($key in $Parameters.Keys) {
                if ($key -ne 'WhatIf') {
                    $executeParams[$key] = $Parameters[$key]
                }
            }
            
            # Force WhatIf to false
            $executeParams['WhatIf'] = $false
            
            # Clear the planned changes
            $script:PlannedChanges = @()
            $script:IsWhatIfMode = $false
            
            Write-Host "Executing with parameters:"
            $executeParams.GetEnumerator() | ForEach-Object {
                Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Cyan
            }
            Write-Host ""
            
            # Execute actual operation
            try {
                Invoke-AnimeOrganize @executeParams
                Write-Host ""
                Write-Host "============================================" -ForegroundColor Green
                Write-Host "Execution completed!" -ForegroundColor Green
                Write-Host "============================================" -ForegroundColor Green
            }
            catch {
                Write-Host ""
                Write-Host "============================================" -ForegroundColor Red
                Write-Host "Error during execution: $_" -ForegroundColor Red
                Write-Host "============================================" -ForegroundColor Red
            }
            
            return $true
        }
        else {
            Write-Host ""
            Write-Host "User cancelled operation. No changes made." -ForegroundColor Yellow
            Write-Host ""
            return $false
        }
    }
    finally {
        # Ensure form is disposed
        if ($previewForm) {
            $previewForm.Dispose()
        }
        
        # Force garbage collection
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}