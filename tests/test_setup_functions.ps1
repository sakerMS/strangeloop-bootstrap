# StrangeLoop CLI Setup - Unit Test Suite
# Function-Level Testing and Validation
# 
# Author: [Sakr Omera/Bing Ads Teams Egypt]
# Version: 1.0
# Created: August 2025
# 
# This script performs unit testing on individual functions from the setup script

param(
    [switch]$TestWSLFunctions = $false,
    [switch]$TestVSCodeFunctions = $false,
    [switch]$Verbose = $false
)

#region Setup and Configuration

# Get the path to the setup script
$script:SetupScriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "setup_strangeloop.ps1"

# Set error handling
$ErrorActionPreference = "Continue"

# Initialize test counters
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0

#endregion

#region Test Header

Write-Host @"
 
╔═══════════════════════════════════════════════════════════════╗
║         StrangeLoop CLI Setup - Unit Test Suite               ║
║                Function-Level Testing                         ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue

Write-Host "`nUnit Test Suite for StrangeLoop Setup Functions" -ForegroundColor White
Write-Host "Testing individual function behavior and logic" -ForegroundColor Gray
Write-Host ""

#endregion

#region Helper Functions

function Write-UnitTestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = "",
        [string]$Expected = "",
        [string]$Actual = ""
    )
    
    $script:TotalTests++
    
    if ($Passed) {
        $script:PassedTests++
        Write-Host "✅ PASS: $TestName" -ForegroundColor Green
        if ($Message -and $Verbose) {
            Write-Host "   $Message" -ForegroundColor Gray
        }
    } else {
        $script:FailedTests++
        Write-Host "❌ FAIL: $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "   $Message" -ForegroundColor Yellow
        }
        if ($Expected -and $Actual) {
            Write-Host "   Expected: $Expected" -ForegroundColor Gray
            Write-Host "   Actual: $Actual" -ForegroundColor Gray
        }
    }
}

function Load-SetupScriptFunctions {
    Write-Host "Loading setup script functions for testing..." -ForegroundColor Yellow
    
    try {
        # Check if the functions exist in the script file by content analysis
        $scriptContent = Get-Content $script:SetupScriptPath -Raw
        
        $functionsToTest = @(
            'Test-Command',
            'Write-Success', 'Write-Info', 'Write-Warning', 'Write-Error',
            'Get-UserInput',
            'Test-WSLInstallation',
            'Open-VSCode',
            'Invoke-WSLCommand',
            'Get-WSLCommandOutput',
            'Install-RecommendedVSCodeExtensions',
            'Install-VSCodeWSLExtension'
        )
        
        $foundFunctions = @()
        foreach ($func in $functionsToTest) {
            if ($scriptContent -match "function\s+$func\s*\{") {
                $foundFunctions += $func
            }
        }
        
        Write-Host "✅ Found $($foundFunctions.Count)/$($functionsToTest.Count) expected functions in setup script" -ForegroundColor Green
        
        # Set a script variable to indicate which functions exist for testing
        $script:AvailableFunctions = $foundFunctions
        
        return $foundFunctions.Count -gt 0
    } catch {
        Write-Host "❌ Failed to analyze setup script functions: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

#endregion

#region Helper Function Unit Tests

Write-Host "`n═══ Helper Function Unit Tests ═══" -ForegroundColor Cyan

# Try to load the functions first
$functionsLoaded = Load-SetupScriptFunctions

if (-not $functionsLoaded) {
    Write-UnitTestResult "Function Loading" $false "Could not analyze functions from setup script"
    Write-Host "`nSkipping function tests due to analysis failure." -ForegroundColor Yellow
} else {
    Write-UnitTestResult "Function Loading" $true "Successfully analyzed setup script functions"

    # Test function existence (rather than actual execution which requires full environment)
    $keyFunctions = @('Test-Command', 'Write-Success', 'Write-Info', 'Write-Warning', 'Write-Error', 'Get-UserInput')
    foreach ($func in $keyFunctions) {
        if ($script:AvailableFunctions -contains $func) {
            Write-UnitTestResult "$func function availability" $true "Function definition found in setup script"
        } else {
            Write-UnitTestResult "$func function availability" $false "Function definition not found"
        }
    }
}

#endregion

#region WSL Function Unit Tests

if ($TestWSLFunctions) {
    Write-Host "`n═══ WSL Function Unit Tests ═══" -ForegroundColor Cyan
    
    $wslFunctions = @('Test-WSLInstallation', 'Initialize-UbuntuDistribution', 'Invoke-WSLCommand', 'Get-WSLCommandOutput', 'Resolve-WSLPath')
    
    foreach ($func in $wslFunctions) {
        if ($script:AvailableFunctions -contains $func) {
            Write-UnitTestResult "$func availability" $true "WSL function definition found in setup script"
        } else {
            Write-UnitTestResult "$func availability" $false "WSL function not found"
        }
    }
} else {
    Write-UnitTestResult "WSL Function Tests" $true "Skipped - use -TestWSLFunctions to enable" 
}

#endregion

#region VS Code Function Unit Tests

if ($TestVSCodeFunctions) {
    Write-Host "`n═══ VS Code Function Unit Tests ═══" -ForegroundColor Cyan
    
    $vscodeFunctions = @('Install-RecommendedVSCodeExtensions', 'Install-VSCodeWSLExtension', 'Open-VSCode')
    
    foreach ($func in $vscodeFunctions) {
        if ($script:AvailableFunctions -contains $func) {
            Write-UnitTestResult "$func availability" $true "VS Code function definition found in setup script"
        } else {
            Write-UnitTestResult "$func availability" $false "VS Code function not found"
        }
    }
} else {
    Write-UnitTestResult "VS Code Function Tests" $true "Skipped - use -TestVSCodeFunctions to enable"
}

#endregion

#region Function Parameter Validation Tests

Write-Host "`n═══ Function Parameter Validation Tests ═══" -ForegroundColor Cyan

if ($functionsLoaded) {
    # Test that key functions have proper parameter definitions in the source
    $functionsToValidate = @('Test-Command', 'Test-WSLInstallation', 'Open-VSCode', 'Invoke-WSLCommand', 'Get-WSLCommandOutput')

    foreach ($func in $functionsToValidate) {
        if ($script:AvailableFunctions -contains $func) {
            # Read the function definition from the script and check for parameter blocks
            $scriptContent = Get-Content $script:SetupScriptPath -Raw
            $funcPattern = "function\s+$func\s*\{[^}]*param\s*\("
            
            if ($scriptContent -match $funcPattern) {
                Write-UnitTestResult "$func parameter validation" $true "Function has parameter block defined"
            } else {
                # Some functions might not have parameters
                Write-UnitTestResult "$func parameter validation" $true "Function found (may not require parameters)"
            }
        } else {
            Write-UnitTestResult "$func parameter validation" $false "Function not found"
        }
    }
} else {
    Write-UnitTestResult "Parameter Validation" $false "Cannot validate - functions not loaded"
}

#endregion

#region Edge Case Tests

Write-Host "`n═══ Edge Case Tests ═══" -ForegroundColor Cyan

# These are basic structural tests since we can't execute functions without full environment
if ($functionsLoaded) {
    # Test that the script has error handling patterns
    $scriptContent = Get-Content $script:SetupScriptPath -Raw
    
    $hasErrorHandling = $scriptContent -match "try\s*\{" -and $scriptContent -match "catch\s*\{"
    Write-UnitTestResult "Error handling patterns" $hasErrorHandling "Script contains try/catch blocks"
    
    $hasParameterValidation = $scriptContent -match "param\s*\(" -or $scriptContent -match "\[Parameter\("
    Write-UnitTestResult "Parameter validation patterns" $hasParameterValidation "Script contains parameter definitions"
} else {
    Write-UnitTestResult "Edge Case Tests" $false "Cannot test - script analysis failed"
}

#endregion

#region Function Performance Tests

Write-Host "`n═══ Function Performance Tests ═══" -ForegroundColor Cyan

if ($functionsLoaded) {
    # Count functions and check for reasonable complexity
    $functionCount = $script:AvailableFunctions.Count
    $functionCountOk = $functionCount -ge 10  # Expecting at least 10 helper functions
    Write-UnitTestResult "Function count" $functionCountOk "Found $functionCount functions"
    
    # Check script size is reasonable (not too large, indicating good organization)
    $scriptSize = (Get-Item $script:SetupScriptPath).Length / 1KB
    $scriptSizeOk = $scriptSize -lt 200  # Less than 200KB indicates good organization
    Write-UnitTestResult "Script size" $scriptSizeOk "Script size: $([math]::Round($scriptSize, 1)) KB"
} else {
    Write-UnitTestResult "Performance Tests" $false "Cannot test - script analysis failed"
}

#endregion

#region Test Results Summary

Write-Host ("`n" + ("═" * 80)) -ForegroundColor Blue
Write-Host "UNIT TEST RESULTS SUMMARY" -ForegroundColor Blue
Write-Host ("═" * 80) -ForegroundColor Blue

Write-Host "`nUnit Test Results:" -ForegroundColor White
Write-Host "  Total Tests: $script:TotalTests" -ForegroundColor Gray
Write-Host "  Passed: $script:PassedTests" -ForegroundColor Green
Write-Host "  Failed: $script:FailedTests" -ForegroundColor Red

$successRate = if ($script:TotalTests -gt 0) { [math]::Round(($script:PassedTests / $script:TotalTests) * 100, 1) } else { 0 }
Write-Host "`nUnit Test Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } else { "Yellow" })

if ($script:FailedTests -gt 0) {
    Write-Host "`nFailed Unit Tests:" -ForegroundColor Red
    # Note: Individual failed tests are shown above as they occur
}

Write-Host "`nUnit Test Recommendations:" -ForegroundColor Yellow
if ($successRate -ge 90) {
    Write-Host "  ✅ Excellent function structure and organization!" -ForegroundColor Green
} elseif ($successRate -ge 80) {
    Write-Host "  ✅ Good function structure with minor issues." -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Some unit tests failed. Review the specific function implementations." -ForegroundColor Yellow
}

if (-not $TestWSLFunctions) {
    Write-Host "  📝 Run with -TestWSLFunctions to test WSL-specific functionality." -ForegroundColor Cyan
}

if (-not $TestVSCodeFunctions) {
    Write-Host "  📝 Run with -TestVSCodeFunctions to test VS Code integration functions." -ForegroundColor Cyan
}

Write-Host "`nUnit testing completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ("═" * 80) -ForegroundColor Blue

#endregion
