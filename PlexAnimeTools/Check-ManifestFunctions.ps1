# Check-ManifestFunctions.ps1
# Diagnoses FunctionsToExport parsing issue

$manifestPath = ".\PlexAnimeTools.psd1"

if (-not (Test-Path $manifestPath)) {
    Write-Host "ERROR: Manifest not found" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Manifest Functions Analysis" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Read the raw content
$content = Get-Content $manifestPath -Raw

Write-Host "Step 1: Finding FunctionsToExport section..." -ForegroundColor Yellow
if ($content -match 'FunctionsToExport') {
    Write-Host "  Found FunctionsToExport keyword" -ForegroundColor Green
    
    # Extract the entire FunctionsToExport section
    $startIdx = $content.IndexOf('FunctionsToExport')
    $snippet = $content.Substring($startIdx, [Math]::Min(500, $content.Length - $startIdx))
    
    Write-Host ""
    Write-Host "Raw content around FunctionsToExport:" -ForegroundColor Cyan
    Write-Host "---" -ForegroundColor Gray
    Write-Host $snippet -ForegroundColor White
    Write-Host "---" -ForegroundColor Gray
}
else {
    Write-Host "  FunctionsToExport NOT FOUND" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Using Test-ModuleManifest..." -ForegroundColor Yellow
try {
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    $exportedFuncs = $manifest.ExportedFunctions.Keys
    
    Write-Host "  Functions found via Test-ModuleManifest:" -ForegroundColor Green
    foreach ($func in $exportedFuncs) {
        Write-Host "    - $func" -ForegroundColor White
    }
    Write-Host "  Total: $($exportedFuncs.Count)" -ForegroundColor Cyan
}
catch {
    Write-Host "  ERROR: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 3: Manual string extraction..." -ForegroundColor Yellow

# Try multiple extraction methods
$methods = @{
    "Method 1: Simple regex" = { 
        if ($content -match "FunctionsToExport\s*=\s*@\(([^)]+)\)") {
            $matches[1] -split ',' | ForEach-Object { 
                $_.Trim().Trim("'").Trim('"').Trim() 
            } | Where-Object { $_ }
        }
    }
    "Method 2: Multi-line regex" = {
        if ($content -match "(?s)FunctionsToExport\s*=\s*@\((.*?)\)") {
            $matches[1] -split "[,`n`r]" | ForEach-Object {
                $_.Trim().Trim("'").Trim('"').Trim()
            } | Where-Object { $_ }
        }
    }
    "Method 3: IndexOf parsing" = {
        $start = $content.IndexOf('FunctionsToExport')
        if ($start -gt 0) {
            $arrayStart = $content.IndexOf('@(', $start)
            $arrayEnd = $content.IndexOf(')', $arrayStart)
            if ($arrayStart -gt 0 -and $arrayEnd -gt $arrayStart) {
                $block = $content.Substring($arrayStart + 2, $arrayEnd - $arrayStart - 2)
                $block -split ',' | ForEach-Object {
                    $_.Trim().Trim("'").Trim('"').Trim() -replace '\s+', ''
                } | Where-Object { $_ }
            }
        }
    }
}

foreach ($methodName in $methods.Keys) {
    Write-Host "  $methodName" -ForegroundColor Cyan
    try {
        $result = & $methods[$methodName]
        if ($result) {
            foreach ($func in $result) {
                Write-Host "    - $func" -ForegroundColor White
            }
            Write-Host "    Total: $($result.Count)" -ForegroundColor Green
        }
        else {
            Write-Host "    No results" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "    ERROR: $_" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Recommendation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Use Test-ModuleManifest for accurate parsing" -ForegroundColor Green
Write-Host "This is the most reliable method" -ForegroundColor Gray
Write-Host ""
