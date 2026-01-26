# =============================================================================
# Test-ModuleCorrections.ps1 - FIXED VERSION
# Validates all corrections made to PlexAnimeTools module
# Run this after applying fixes to verify everything works
# =============================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PlexAnimeTools Module Validation Test" -ForegroundColor Cyan
Write-Host "Testing Corrections Applied" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true
$testResults = @()

# Test 1: Module Manifest Validation
Write-Host "[Test 1] Validating Module Manifest..." -ForegroundColor Yellow
try {
    $manifest = Test-ModuleManifest -Path "$PSScriptRoot\PlexAnimeTools.psd1" -ErrorAction Stop
    
    Write-Host "  ✓ Manifest is valid" -ForegroundColor Green
    Write-Host "    Version: $($manifest.Version)" -ForegroundColor Gray
    Write-Host "    ModuleVersion: $($manifest.ModuleVersion)" -ForegroundColor Gray
    
    $testResults += [PSCustomObject]@{
        Test = "Manifest Validation"
        Status = "PASS"
        Details = "Valid manifest structure"
    }
}
catch {
    Write-Host "  ✗ Manifest validation failed: $_" -ForegroundColor Red
    $allPassed = $false
    $testResults += [PSCustomObject]@{
        Test = "Manifest Validation"
        Status = "FAIL"
        Details = $_.Exception.Message
    }
}

# Test 2: Check FunctionsToExport
Write-Host ""
Write-Host "[Test 2] Checking FunctionsToExport..." -ForegroundColor Yellow
$expectedFunctions = @(
    'Invoke-AnimeOrganize',
    'Test-PlexScan',
    'Get-AnimeInfo',
    'Start-PlexGUI',
    'Start-TestingGUI',
    'Start-SmartOrganize'
)

$manifestContent = Get-Content "$PSScriptRoot\PlexAnimeTools.psd1" -Raw
$exportedFunctions = @()

# Use Test-ModuleManifest for reliable parsing
try {
    $manifest = Test-ModuleManifest -Path "$PSScriptRoot\PlexAnimeTools.psd1" -ErrorAction Stop -WarningAction SilentlyContinue
    $exportedFunctions = @($manifest.ExportedFunctions.Keys)
}
catch {
    $exportedFunctions = @()
}

$missingFunctions = $expectedFunctions | Where-Object { $exportedFunctions -notcontains $_ }
$extraFunctions = $exportedFunctions | Where-Object { $expectedFunctions -notcontains $_ }

if ($missingFunctions.Count -eq 0 -and $extraFunctions.Count -eq 0) {
    Write-Host "  ✓ All 6 required functions are exported" -ForegroundColor Green
    foreach ($func in $exportedFunctions) {
        Write-Host "    - $func" -ForegroundColor Gray
    }
    $testResults += [PSCustomObject]@{
        Test = "FunctionsToExport"
        Status = "PASS"
        Details = "All 6 functions present"
    }
}
else {
    $allPassed = $false
    if ($missingFunctions) {
        Write-Host "  ✗ Missing functions:" -ForegroundColor Red
        $missingFunctions | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    }
    if ($extraFunctions) {
        Write-Host "  ⚠ Extra functions:" -ForegroundColor Yellow
        $extraFunctions | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    }
    $testResults += [PSCustomObject]@{
        Test = "FunctionsToExport"
        Status = "FAIL"
        Details = "Missing: $($missingFunctions -join ', ')"
    }
}

# Test 3: Check RequiredAssemblies
Write-Host ""
Write-Host "[Test 3] Checking RequiredAssemblies..." -ForegroundColor Yellow
if ($manifestContent -match 'RequiredAssemblies\s*=\s*@\(') {
    $assemblyStart = $manifestContent.IndexOf('RequiredAssemblies')
    $arrayStart = $manifestContent.IndexOf('@(', $assemblyStart)
    $arrayEnd = $manifestContent.IndexOf(')', $arrayStart)
    
    $assembliesBlock = $manifestContent.Substring($arrayStart + 2, $arrayEnd - $arrayStart - 2).Trim()
    
    if ($assembliesBlock -eq '' -or $assembliesBlock -eq '@()') {
        Write-Host "  ✓ RequiredAssemblies is empty (correct)" -ForegroundColor Green
        Write-Host "    Assemblies loaded via Add-Type instead" -ForegroundColor Gray
        $testResults += [PSCustomObject]@{
            Test = "RequiredAssemblies"
            Status = "PASS"
            Details = "Empty array (assemblies loaded via Add-Type)"
        }
    }
    else {
        Write-Host "  ⚠ RequiredAssemblies should be empty" -ForegroundColor Yellow
        Write-Host "    Current: $assembliesBlock" -ForegroundColor Yellow
        Write-Host "    Recommendation: Use @() instead" -ForegroundColor Yellow
        $testResults += [PSCustomObject]@{
            Test = "RequiredAssemblies"
            Status = "WARNING"
            Details = "Should be empty array"
        }
    }
}

# Test 4: Import Module
Write-Host ""
Write-Host "[Test 4] Importing Module..." -ForegroundColor Yellow
try {
    Import-Module "$PSScriptRoot\PlexAnimeTools.psd1" -Force -ErrorAction Stop
    Write-Host "  ✓ Module imported successfully" -ForegroundColor Green
    $testResults += [PSCustomObject]@{
        Test = "Module Import"
        Status = "PASS"
        Details = "Module loads without errors"
    }
}
catch {
    Write-Host "  ✗ Module import failed: $_" -ForegroundColor Red
    $allPassed = $false
    $testResults += [PSCustomObject]@{
        Test = "Module Import"
        Status = "FAIL"
        Details = $_.Exception.Message
    }
}

# Test 5: Verify All Functions Available
Write-Host ""
Write-Host "[Test 5] Verifying Function Availability..." -ForegroundColor Yellow
$availableFunctions = Get-Command -Module PlexAnimeTools -ErrorAction SilentlyContinue

if ($availableFunctions) {
    Write-Host "  ✓ Found $($availableFunctions.Count) exported function(s)" -ForegroundColor Green
    
    foreach ($func in $expectedFunctions) {
        $cmd = Get-Command $func -ErrorAction SilentlyContinue
        if ($cmd) {
            Write-Host "    ✓ $func" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ $func (NOT AVAILABLE)" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    $testResults += [PSCustomObject]@{
        Test = "Function Availability"
        Status = if ($availableFunctions.Count -eq 6) { "PASS" } else { "FAIL" }
        Details = "$($availableFunctions.Count) of 6 functions available"
    }
}
else {
    Write-Host "  ✗ No functions available after import" -ForegroundColor Red
    $allPassed = $false
    $testResults += [PSCustomObject]@{
        Test = "Function Availability"
        Status = "FAIL"
        Details = "No functions exported"
    }
}

# Test 6: Test Start-SmartOrganize Specifically
Write-Host ""
Write-Host "[Test 6] Testing Start-SmartOrganize (Critical Fix)..." -ForegroundColor Yellow
try {
    $cmd = Get-Command Start-SmartOrganize -ErrorAction Stop
    Write-Host "  ✓ Start-SmartOrganize is available" -ForegroundColor Green
    Write-Host "    Source: $($cmd.Source)" -ForegroundColor Gray
    Write-Host "    Module: $($cmd.ModuleName)" -ForegroundColor Gray
    $testResults += [PSCustomObject]@{
        Test = "Start-SmartOrganize"
        Status = "PASS"
        Details = "Function exported and available"
    }
}
catch {
    Write-Host "  ✗ Start-SmartOrganize not available!" -ForegroundColor Red
    Write-Host "    This was the critical fix - check manifest" -ForegroundColor Red
    $allPassed = $false
    $testResults += [PSCustomObject]@{
        Test = "Start-SmartOrganize"
        Status = "FAIL"
        Details = "Function not available - check FunctionsToExport"
    }
}

# Test 7: Check for Movie Regex Fix
Write-Host ""
Write-Host "[Test 7] Checking Movie Detection Regex..." -ForegroundColor Yellow
$detectionFile = Join-Path $PSScriptRoot "Private\Detection.ps1"
if (Test-Path $detectionFile) {
    $content = Get-Content $detectionFile -Raw
    
    # Check for the fixed pattern (using simpler string check)
    if ($content.Contains('Movie') -and $content.Contains('(?!s)')) {
        Write-Host "  ✓ Movie regex uses negative lookahead (?!s)" -ForegroundColor Green
        Write-Host "    Won't match 'Movies' plural" -ForegroundColor Gray
        $testResults += [PSCustomObject]@{
            Test = "Movie Regex Fix"
            Status = "PASS"
            Details = "Uses negative lookahead pattern"
        }
    }
    else {
        Write-Host "  ⚠ Movie regex may still match 'Movies' plural" -ForegroundColor Yellow
        Write-Host "    Recommendation: Use negative lookahead (?!s)" -ForegroundColor Yellow
        $testResults += [PSCustomObject]@{
            Test = "Movie Regex Fix"
            Status = "WARNING"
            Details = "Pattern may need negative lookahead"
        }
    }
}
else {
    Write-Host "  ⚠ Detection.ps1 not found at expected location" -ForegroundColor Yellow
}

# Test 8: Check Session GUID in Logging
Write-Host ""
Write-Host "[Test 8] Checking Logging Session GUID..." -ForegroundColor Yellow
$threadingFile = Join-Path $PSScriptRoot "Private\Threading.ps1"
if (Test-Path $threadingFile) {
    $content = Get-Content $threadingFile -Raw
    
    if ($content.Contains('SessionGuid')) {
        Write-Host "  ✓ Session GUID variable found" -ForegroundColor Green
        
        if ($content.Contains('Events_') -and $content.Contains('SessionGuid')) {
            Write-Host "  ✓ Session GUID used in log filenames" -ForegroundColor Green
            Write-Host "    Prevents timestamp collisions" -ForegroundColor Gray
            $testResults += [PSCustomObject]@{
                Test = "Session GUID"
                Status = "PASS"
                Details = "GUID prevents log file collisions"
            }
        }
        else {
            Write-Host "  ⚠ Session GUID not used in filenames" -ForegroundColor Yellow
            $testResults += [PSCustomObject]@{
                Test = "Session GUID"
                Status = "WARNING"
                Details = "GUID variable exists but not used"
            }
        }
    }
    else {
        Write-Host "  ⚠ Session GUID not found in Threading.ps1" -ForegroundColor Yellow
        $testResults += [PSCustomObject]@{
            Test = "Session GUID"
            Status = "WARNING"
            Details = "No session GUID for log file uniqueness"
        }
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$passed = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$warnings = ($testResults | Where-Object { $_.Status -eq "WARNING" }).Count

Write-Host "Total Tests: $($testResults.Count)" -ForegroundColor White
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "Warnings: $warnings" -ForegroundColor Yellow
Write-Host ""

# Display results table
$testResults | Format-Table -AutoSize

if ($allPassed -and $failed -eq 0) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✓ ALL CRITICAL TESTS PASSED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Module is ready for production use!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Test with sample data: Start-SmartOrganize -InputPath 'test' -OutputPath 'output' -WhatIf" -ForegroundColor White
    Write-Host "  2. Run integration test: .\Test-Integration.ps1" -ForegroundColor White
    Write-Host "  3. Launch GUI: Start-PlexGUI" -ForegroundColor White
}
else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "✗ SOME TESTS FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please review failed tests above and apply fixes." -ForegroundColor Yellow
}

Write-Host ""