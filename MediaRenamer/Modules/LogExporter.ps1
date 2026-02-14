# ===============================================================================
# LogExporter.ps1 - Export Rename Log to Text File
# ===============================================================================

function Export-RenameLog {
    param(
        [array]$Files,
        [string]$OutputPath,
        [hashtable]$RenameResults = @{},
        [string]$ShowName = "",
        [int]$Season = 0,
        [string]$Mode = "Rename"
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("================================================================")
    [void]$sb.AppendLine("  Media File Renamer - Operation Log")
    [void]$sb.AppendLine("  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("================================================================")
    [void]$sb.AppendLine("")

    if ($ShowName) { [void]$sb.AppendLine("  Show:     $ShowName") }
    if ($Season -gt 0) { [void]$sb.AppendLine("  Season:   $Season") }
    [void]$sb.AppendLine("  Mode:     $Mode")
    [void]$sb.AppendLine("  Files:    $($Files.Count)")
    [void]$sb.AppendLine("")

    if ($RenameResults.Count -gt 0) {
        [void]$sb.AppendLine("  Results:  $($RenameResults.Success) succeeded, $($RenameResults.Skipped) skipped, $($RenameResults.Errors) errors")
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("----------------------------------------------------------------")
    [void]$sb.AppendLine(("{0,-5} {1,-45} {2,-45} {3}" -f "#", "Original Name", "New Name", "Status"))
    [void]$sb.AppendLine("----------------------------------------------------------------")

    $num = 0
    foreach ($file in $Files) {
        $num++
        $orig = if ($file.OriginalName.Length -gt 43) { $file.OriginalName.Substring(0,40) + "..." } else { $file.OriginalName }
        $new = if ($file.NewName.Length -gt 43) { $file.NewName.Substring(0,40) + "..." } else { $file.NewName }
        $status = if ($file.Excluded) { "Excluded" } else { $file.Status }
        [void]$sb.AppendLine(("{0,-5} {1,-45} {2,-45} {3}" -f $num, $orig, $new, $status))
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("================================================================")
    [void]$sb.AppendLine("  End of Log")
    [void]$sb.AppendLine("================================================================")

    try {
        Set-Content -Path $OutputPath -Value $sb.ToString() -Encoding UTF8
        return $true
    } catch {
        return $false
    }
}

function Export-CsvLog {
    param(
        [array]$Files,
        [string]$OutputPath
    )

    $csvData = @()
    $num = 0
    foreach ($file in $Files) {
        $num++
        $csvData += [PSCustomObject]@{
            Number       = $num
            OriginalName = $file.OriginalName
            NewName      = $file.NewName
            Status       = if ($file.Excluded) { "Excluded" } else { $file.Status }
            FileSize     = $file.FileSizeText
            Duration     = $file.DurationText
            Path         = $file.FullPath
        }
    }

    try {
        $csvData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        return $true
    } catch {
        return $false
    }
}
