# ===============================================================================
# Renamer.ps1 - Rename / Copy / Move Files with Conflict Handling
# ===============================================================================

function Invoke-RenameFiles {
    param(
        [array]$Files,
        [string]$Mode = "Rename",       # "Rename", "Copy", "Move"
        [string]$DestinationFolder = "", # For Copy/Move modes
        [string]$ConflictAction = "Ask", # "Ask", "Skip", "Suffix"
        [scriptblock]$OnProgress = $null,
        [scriptblock]$OnConflict = $null  # Returns "Overwrite","Skip","Suffix" for each conflict
    )

    $results = @{
        Success   = 0
        Skipped   = 0
        Errors    = 0
        Total     = ($Files | Where-Object { -not $_.Excluded -and $_.Status -eq "Will Rename" }).Count
        RollbackData = @()
    }

    $count = 0
    foreach ($file in $Files) {
        if ($file.Excluded -or $file.Status -ne "Will Rename") { continue }

        $count++
        if ($OnProgress) { & $OnProgress $count $results.Total $file.OriginalName }

        $sourcePath = $file.FullPath
        $targetDir = if ($Mode -eq "Rename") { $file.Directory } else { $DestinationFolder }
        $targetPath = Join-Path $targetDir $file.NewName

        try {
            # Check for conflict
            if (Test-Path $targetPath) {
                $action = $ConflictAction
                if ($action -eq "Ask" -and $OnConflict) {
                    $action = & $OnConflict $file.OriginalName $file.NewName $targetPath
                }

                switch ($action) {
                    "Skip" {
                        $file.Status = "Skipped (conflict)"
                        $results.Skipped++
                        continue
                    }
                    "Suffix" {
                        $base = [System.IO.Path]::GetFileNameWithoutExtension($file.NewName)
                        $ext = [System.IO.Path]::GetExtension($file.NewName)
                        $suffix = 2
                        do {
                            $newTarget = Join-Path $targetDir "${base}_${suffix}${ext}"
                            $suffix++
                        } while (Test-Path $newTarget)
                        $targetPath = $newTarget
                        $file.NewName = Split-Path $newTarget -Leaf
                    }
                    "Cancel" {
                        return $results
                    }
                }
            }

            # Ensure target directory exists
            if (-not (Test-Path $targetDir)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }

            # Perform the operation
            switch ($Mode) {
                "Rename" {
                    Rename-Item -Path $sourcePath -NewName $file.NewName -ErrorAction Stop
                    $results.RollbackData += [PSCustomObject]@{
                        OldPath = $sourcePath
                        NewPath = $targetPath
                        OldName = $file.OriginalName
                        NewName = $file.NewName
                        Mode    = "Rename"
                    }
                }
                "Copy" {
                    Copy-Item -Path $sourcePath -Destination $targetPath -ErrorAction Stop
                    $results.RollbackData += [PSCustomObject]@{
                        OldPath = $sourcePath
                        NewPath = $targetPath
                        OldName = $file.OriginalName
                        NewName = $file.NewName
                        Mode    = "Copy"
                    }
                }
                "Move" {
                    Move-Item -Path $sourcePath -Destination $targetPath -ErrorAction Stop
                    $results.RollbackData += [PSCustomObject]@{
                        OldPath = $sourcePath
                        NewPath = $targetPath
                        OldName = $file.OriginalName
                        NewName = $file.NewName
                        Mode    = "Move"
                    }
                }
            }

            $file.Status = "Done"
            $file.FullPath = $targetPath
            $file.OriginalName = $file.NewName
            $results.Success++

        } catch {
            $file.Status = "Error: $($_.Exception.Message)"
            $results.Errors++
        }
    }

    return $results
}

function Invoke-Undo {
    param([array]$RollbackData)

    $undone = 0
    $errors = 0

    # Reverse order for undo
    $reversed = @($RollbackData)
    [array]::Reverse($reversed)

    foreach ($entry in $reversed) {
        try {
            switch ($entry.Mode) {
                "Rename" {
                    Rename-Item -Path $entry.NewPath -NewName $entry.OldName -ErrorAction Stop
                }
                "Move" {
                    Move-Item -Path $entry.NewPath -Destination $entry.OldPath -ErrorAction Stop
                }
                "Copy" {
                    Remove-Item -Path $entry.NewPath -ErrorAction Stop
                }
            }
            $undone++
        } catch {
            $errors++
        }
    }

    return @{ Undone = $undone; Errors = $errors }
}

function Export-RollbackScript {
    param(
        [array]$RollbackData,
        [string]$OutputPath
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# ===========================================================")
    [void]$sb.AppendLine("# Rollback Script - Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("# Run this script to undo the rename operation")
    [void]$sb.AppendLine("# ===========================================================")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('$ErrorActionPreference = "Stop"')
    [void]$sb.AppendLine('$undone = 0; $errors = 0')
    [void]$sb.AppendLine("")

    $reversed = $RollbackData | Sort-Object { [array]::IndexOf($RollbackData, $_) } -Descending

    foreach ($entry in $reversed) {
        $escapedNew = $entry.NewPath -replace "'", "''"
        $escapedOld = $entry.OldName -replace "'", "''"
        $escapedOldPath = $entry.OldPath -replace "'", "''"

        switch ($entry.Mode) {
            "Rename" {
                [void]$sb.AppendLine("try {")
                [void]$sb.AppendLine("    Rename-Item -Path '$escapedNew' -NewName '$escapedOld' -ErrorAction Stop")
                [void]$sb.AppendLine("    `$undone++; Write-Host 'Restored: $escapedOld' -ForegroundColor Green")
                [void]$sb.AppendLine("} catch { `$errors++; Write-Host `"Error restoring: $escapedOld - `$(`$_.Exception.Message)`" -ForegroundColor Red }")
            }
            "Move" {
                [void]$sb.AppendLine("try {")
                [void]$sb.AppendLine("    Move-Item -Path '$escapedNew' -Destination '$escapedOldPath' -ErrorAction Stop")
                [void]$sb.AppendLine("    `$undone++; Write-Host 'Restored: $escapedOld' -ForegroundColor Green")
                [void]$sb.AppendLine("} catch { `$errors++; Write-Host `"Error restoring: $escapedOld - `$(`$_.Exception.Message)`" -ForegroundColor Red }")
            }
            "Copy" {
                [void]$sb.AppendLine("try {")
                [void]$sb.AppendLine("    Remove-Item -Path '$escapedNew' -ErrorAction Stop")
                [void]$sb.AppendLine("    `$undone++; Write-Host 'Removed copy: $($entry.NewName)' -ForegroundColor Green")
                [void]$sb.AppendLine("} catch { `$errors++; Write-Host `"Error removing: $($entry.NewName) - `$(`$_.Exception.Message)`" -ForegroundColor Red }")
            }
        }
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("Write-Host `"`nRollback complete: `$undone restored, `$errors errors`" -ForegroundColor Cyan")
    [void]$sb.AppendLine("pause")

    Set-Content -Path $OutputPath -Value $sb.ToString() -Encoding UTF8
    return $OutputPath
}
