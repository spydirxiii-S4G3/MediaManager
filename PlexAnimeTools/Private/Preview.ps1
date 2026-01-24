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
    $previewForm.StartPosition = 'CenterScreen'
    $previewForm.FormBorderStyle = 'Sizable'
    $previewForm.MaximizeBox = $true
    $previewForm.MinimizeBox = $true
    
    # Summary Panel
    $summaryPanel = New-Object System.Windows.Forms.Panel
    $summaryPanel.Location = New-Object System.Drawing.Point(10, 10)
    $summaryPanel.Size = New-Object System.Drawing.Size(960, 80)
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
    $lblStats.Size = New-Object System.Drawing.Size(940, 40)
    $lblStats.Font = New-Object System.Drawing.Font('Arial', 10)
    
    $totalFiles = ($Changes | Where-Object { $_.Type -eq 'File' }).Count
    $totalShows = ($Changes | Select-Object ShowTitle -Unique).Count
    $totalFolders = ($Changes | Where-Object { $_.Type -eq 'Folder' }).Count
    
    $lblStats.Text = "Total Shows: $totalShows | Files to Rename/Move: $totalFiles | Folders to Create: $totalFolders"
    $summaryPanel.Controls.Add($lblStats)
    
    # DataGridView for changes
    $dgvChanges = New-Object System.Windows.Forms.DataGridView
    $dgvChanges.Location = New-Object System.Drawing.Point(10, 100)
    $dgvChanges.Size = New-Object System.Drawing.Size(960, 480)
    $dgvChanges.AllowUserToAddRows = $false
    $dgvChanges.AllowUserToDeleteRows = $false
    $dgvChanges.ReadOnly = $true
    $dgvChanges.SelectionMode = 'FullRowSelect'
    $dgvChanges.MultiSelect = $true
    $dgvChanges.AutoSizeColumnsMode = 'Fill'
    $dgvChanges.RowHeadersVisible = $false
    $dgvChanges.BackgroundColor = [System.Drawing.Color]::White
    $previewForm.Controls.Add($dgvChanges)
    
    # Add columns
    $dgvChanges.Columns.Add('Type', 'Type') | Out-Null
    $dgvChanges.Columns.Add('ShowTitle', 'Show') | Out-Null
    $dgvChanges.Columns.Add('Action', 'Action') | Out-Null
    $dgvChanges.Columns.Add('Source', 'Source Path / Current Name') | Out-Null
    $dgvChanges.Columns.Add('Destination', 'Destination Path / New Name') | Out-Null
    
    # Set column widths
    $dgvChanges.Columns[0].Width = 60   # Type
    $dgvChanges.Columns[1].Width = 120  # Show
    $dgvChanges.Columns[2].Width = 60   # Action
    $dgvChanges.Columns[3].Width = 350  # Source (wider for full paths)
    $dgvChanges.Columns[4].Width = 350  # Destination (wider for full paths)
    
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
    
    # Button Panel
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Location = New-Object System.Drawing.Point(10, 590)
    $buttonPanel.Size = New-Object System.Drawing.Size(960, 60)
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
    
    # Cancel Button
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Location = New-Object System.Drawing.Point(750, 15)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 35)
    $btnCancel.Text = 'Cancel'
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $buttonPanel.Controls.Add($btnCancel)
    
    # Proceed Button
    $btnProceed = New-Object System.Windows.Forms.Button
    $btnProceed.Location = New-Object System.Drawing.Point(860, 15)
    $btnProceed.Size = New-Object System.Drawing.Size(100, 35)
    $btnProceed.Text = 'Proceed'
    $btnProceed.BackColor = [System.Drawing.Color]::LightGreen
    $btnProceed.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $btnProceed.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $buttonPanel.Controls.Add($btnProceed)
    
    # Set form properties
    $previewForm.AcceptButton = $btnProceed
    $previewForm.CancelButton = $btnCancel
    
    # Show form and get result
    $result = $previewForm.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Host ""
        Write-Host "User approved changes. Proceeding with execution..." -ForegroundColor Green
        Write-Host ""
        
        # Remove WhatIf from parameters
        $Parameters.Remove('WhatIf')
        
        # Execute actual operation
        Invoke-AnimeOrganize @Parameters
        
        return $true
    }
    else {
        Write-Host ""
        Write-Host "User cancelled operation. No changes made." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
}