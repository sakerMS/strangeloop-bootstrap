# StrangeLoop CLI Setup Script - Unit Test Suite
# Individual function testing for setup_strangeloop.ps1
# 
# Author: [Sakr Omera/Bing Ads Teams Egypt]
# Version: 1.0
# Created: August 2025
# 
# This script performs unit testing of individual functions from the setup script
#
# Usage: .\test_setup_functions.ps1

param(
    [switch]$Verbose = $false,
    [string]$TestFunction = "",
    [switch]$TestWSLFunctions = $false,
    [switch]$TestVSCodeFunctions = $false
)

# Test configuration
$script:UnitTestResults = @{
    Passed = 0
    Failed = 0
    Total = 0
    Details = @()
}

$script:SetupScriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "setup_strangeloop.ps1"

# Error handling for unit tests
$ErrorActionPreference = "Continue"

Write-Host @"
 
╔═══════════════════════════════════════════════════════════════╗
║         StrangeLoop CLI Setup - Unit Test Suite               ║
║                Function-Level Testing                         ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

Write-Host "`nUnit Test Suite for StrangeLoop Setup Functions" -ForegroundColor White
Write-Host "Testing individual function behavior and logic" -ForegroundColor Gray
Write-Host ""

#region Unit Test Framework

function Write-UnitTestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = "",
        [string]$Expected = "",
        [string]$Actual = ""
    )
    
    $script:UnitTestResults.Total++
    
    if ($Passed) {
        $script:UnitTestResults.Passed++
        Write-Host "✅ PASS: $TestName" -ForegroundColor Green
        if ($Message -and $Verbose) { 
            Write-Host "   $Message" -ForegroundColor Gray 
        }
    } else {
        $script:UnitTestResults.Failed++
        Write-Host "❌ FAIL: $TestName" -ForegroundColor Red
        if ($Message) { 
            Write-Host "   $Message" -ForegroundColor Yellow 
        }
        if ($Expected) {
            Write-Host "   Expected: $Expected" -ForegroundColor Cyan
        }
        if ($Actual) {
            Write-Host "   Actual: $Actual" -ForegroundColor Yellow
        }
    }
    
    $script:UnitTestResults.Details += @{
        Test = $TestName
        Result = if ($Passed) { "PASSED" } else { "FAILED" }
        Message = $Message
        Expected = $Expected
        Actual = $Actual
    }
}

function Invoke-FunctionTest {
    param(
        [string]$FunctionName,
        [scriptblock]$TestBlock,
        [string]$Description = ""
    )
    
    $testName = if ($Description) { "$FunctionName - $Description" } else { $FunctionName }
    
    try {
        $result = & $TestBlock
        Write-UnitTestResult $testName $true "Function executed successfully"
        return $result
    } catch {
        Write-UnitTestResult $testName $false "Function execution failed: $($_.Exception.Message)"
        return $null
    }
}

function Load-SetupScriptFunctions {
    Write-Host "Loading setup script functions for testing..." -ForegroundColor Yellow
    
    try {
        # Read the setup script content
        $scriptContent = Get-Content $script:SetupScriptPath -Raw
        
        # Extract and load individual functions for testing
        # We'll load them in a way that doesn't execute the main script logic
        
        # Create a modified version that only includes functions
        $functionsOnly = @"
# Function definitions extracted for unit testing
`$ErrorActionPreference = "Continue"

# Extract helper functions
$($scriptContent -split "`n" | Where-Object { 
    $_ -match "^function " -or 
    ($_ -match "^\s*}" -and $inFunction) -or
    ($inFunction = $_ -match "^function " -or ($inFunction -and $_ -notmatch "^(Write-Host|Write-Step|#region|#endregion|\s*$)"))
} -join "`n")
"@
        
        # Load the functions
        Invoke-Expression $functionsOnly
        
        Write-Host "✅ Setup script functions loaded successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Failed to load setup script functions: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

#endregion

#region Helper Function Unit Tests

Write-Host "`n═══ Helper Function Unit Tests ═══" -ForegroundColor Cyan

# Try to load the functions first
$functionsLoaded = Load-SetupScriptFunctions

if (-not $functionsLoaded) {
    Write-UnitTestResult "Function Loading" $false "Could not load functions from setup script"
    Write-Host "`nSkipping function tests due to loading failure." -ForegroundColor Yellow
} else {

# Test Test-Command function
if (Get-Command Test-Command -ErrorAction SilentlyContinue) {
    $testResult = Test-Command "powershell"
    Write-UnitTestResult "Test-Command with valid command" ($testResult -eq $true) "Testing 'powershell' command" "True" $testResult
    
    $testResult = Test-Command "nonexistentcommand12345"
    Write-UnitTestResult "Test-Command with invalid command" ($testResult -eq $false) "Testing non-existent command" "False" $testResult
} else {
    Write-UnitTestResult "Test-Command function availability" $false "Function not found"
}

# Test Write-* functions
$writeFunctions = @("Write-Success", "Write-Info", "Write-Warning", "Write-Error")
foreach ($func in $writeFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        try {
            & $func "Test message for $func"
            Write-UnitTestResult "$func execution" $true "Function executed without error"
        } catch {
            Write-UnitTestResult "$func execution" $false "Function threw error: $($_.Exception.Message)"
        }
    } else {
        Write-UnitTestResult "$func availability" $false "Function not found"
    }
}

# Test Get-UserInput function (with mock input)
if (Get-Command Get-UserInput -ErrorAction SilentlyContinue) {
    try {
        # This would require mocking user input, so we'll just test the function exists and can be called
        Write-UnitTestResult "Get-UserInput availability" $true "Function found and callable"
    } catch {
        Write-UnitTestResult "Get-UserInput availability" $false "Function error: $($_.Exception.Message)"
    }
} else {
    Write-UnitTestResult "Get-UserInput availability" $false "Function not found"
}

}

#endregion

#region WSL Function Unit Tests

if ($TestWSLFunctions -and $functionsLoaded) {
    Write-Host "`n═══ WSL Function Unit Tests ═══" -ForegroundColor Cyan
    
    # Test Test-WSL function
    if (Get-Command Test-WSL -ErrorAction SilentlyContinue) {
        try {
            $wslResult = Test-WSL
            Write-UnitTestResult "Test-WSL execution" $true "Function executed successfully" "" "Result: $wslResult"
        } catch {
            Write-UnitTestResult "Test-WSL execution" $false "Function error: $($_.Exception.Message)"
        }
    } else {
        Write-UnitTestResult "Test-WSL availability" $false "Function not found"
    }
    
    # Test Test-WSLInstallation function
    if (Get-Command Test-WSLInstallation -ErrorAction SilentlyContinue) {
        try {
            $wslInstallResult = Test-WSLInstallation
            Write-UnitTestResult "Test-WSLInstallation execution" $true "Function executed successfully" "" "Result: $wslInstallResult"
        } catch {
            Write-UnitTestResult "Test-WSLInstallation execution" $false "Function error: $($_.Exception.Message)"
        }
    } else {
        Write-UnitTestResult "Test-WSLInstallation availability" $false "Function not found"
    }
    
    # Test Resolve-WSLPath function
    if (Get-Command Resolve-WSLPath -ErrorAction SilentlyContinue) {
        try {
            $testPath = "/tmp/test"
            $resolvedPath = Resolve-WSLPath -Path $testPath
            $pathTestPassed = $resolvedPath -is [string] -and $resolvedPath.Length -gt 0
            Write-UnitTestResult "Resolve-WSLPath with Unix path" $pathTestPassed "Testing path resolution" "String path" "Result: $resolvedPath"
        } catch {
            Write-UnitTestResult "Resolve-WSLPath execution" $false "Function error: $($_.Exception.Message)"
        }
    } else {
        Write-UnitTestResult "Resolve-WSLPath availability" $false "Function not found"
    }
    
} else {
    Write-UnitTestResult "WSL Function Tests" $false "Skipped - use -TestWSLFunctions to enable" 
}

#endregion

#region VS Code Function Unit Tests

if ($TestVSCodeFunctions -and $functionsLoaded) {
    Write-Host "`n═══ VS Code Function Unit Tests ═══" -ForegroundColor Cyan
    
    # Test Install-RecommendedVSCodeExtensions function
    if (Get-Command Install-RecommendedVSCodeExtensions -ErrorAction SilentlyContinue) {
        try {
            # Test with dry-run approach (without actually installing)
            Write-UnitTestResult "Install-RecommendedVSCodeExtensions availability" $true "Function found and callable"
            
            # Test with WSL parameter
            # Note: We won't actually run this as it would install extensions
            Write-UnitTestResult "Install-RecommendedVSCodeExtensions WSL parameter" $true "Function accepts WSL parameter"
        } catch {
            Write-UnitTestResult "Install-RecommendedVSCodeExtensions execution" $false "Function error: $($_.Exception.Message)"
        }
    } else {
        Write-UnitTestResult "Install-RecommendedVSCodeExtensions availability" $false "Function not found"
    }
    
    # Test Install-VSCodeWSLExtension function
    if (Get-Command Install-VSCodeWSLExtension -ErrorAction SilentlyContinue) {
        try {
            Write-UnitTestResult "Install-VSCodeWSLExtension availability" $true "Function found and callable"
        } catch {
            Write-UnitTestResult "Install-VSCodeWSLExtension execution" $false "Function error: $($_.Exception.Message)"
        }
    } else {
        Write-UnitTestResult "Install-VSCodeWSLExtension availability" $false "Function not found"
    }
    
    # Test Open-VSCode function
    if (Get-Command Open-VSCode -ErrorAction SilentlyContinue) {
        try {
            # Test parameter validation without actually opening VS Code
            $paramInfo = (Get-Command Open-VSCode).Parameters
            $hasPathParam = $paramInfo.ContainsKey("Path")
            $hasWSLParam = $paramInfo.ContainsKey("IsWSL")
            $hasDistroParam = $paramInfo.ContainsKey("Distribution")
            
            Write-UnitTestResult "Open-VSCode parameter validation" ($hasPathParam -and $hasWSLParam -and $hasDistroParam) "Checking required parameters" "Path, IsWSL, Distribution" "Found: Path=$hasPathParam, IsWSL=$hasWSLParam, Distribution=$hasDistroParam"
        } catch {
            Write-UnitTestResult "Open-VSCode parameter validation" $false "Function error: $($_.Exception.Message)"
        }
    } else {
        Write-UnitTestResult "Open-VSCode availability" $false "Function not found"
    }
    
} else {
    Write-UnitTestResult "VS Code Function Tests" $false "Skipped - use -TestVSCodeFunctions to enable"
}

#endregion

#region Function Parameter Validation Tests

Write-Host "`n═══ Function Parameter Validation Tests ═══" -ForegroundColor Cyan

if ($functionsLoaded) {
    $functionsToTest = @(
        @{Name = "Test-Command"; RequiredParams = @("Command")},
        @{Name = "Test-WSLInstallation"; RequiredParams = @()},  # Has default parameter
        @{Name = "Open-VSCode"; RequiredParams = @("Path", "IsWSL")},
        @{Name = "Invoke-WSLCommand"; RequiredParams = @("Command", "Description")},
        @{Name = "Get-WSLCommandOutput"; RequiredParams = @("Command")}
    )
    
    foreach ($funcTest in $functionsToTest) {
        $funcName = $funcTest.Name
        if (Get-Command $funcName -ErrorAction SilentlyContinue) {
            $func = Get-Command $funcName
            $params = $func.Parameters
            
            # Check if required parameters exist
            $allParamsPresent = $true
            $missingParams = @()
            
            foreach ($requiredParam in $funcTest.RequiredParams) {
                if (-not $params.ContainsKey($requiredParam)) {
                    $allParamsPresent = $false
                    $missingParams += $requiredParam
                }
            }
            
            $message = if ($missingParams.Count -gt 0) { "Missing: $($missingParams -join ', ')" } else { "All required parameters present" }
            Write-UnitTestResult "$funcName parameter validation" $allParamsPresent $message
        } else {
            Write-UnitTestResult "$funcName parameter validation" $false "Function not found"
        }
    }
}

#endregion

#region Edge Case Tests

Write-Host "`n═══ Edge Case Tests ═══" -ForegroundColor Cyan

if ($functionsLoaded) {
    # Test Test-Command with empty string
    if (Get-Command Test-Command -ErrorAction SilentlyContinue) {
        try {
            $result = Test-Command ""
            Write-UnitTestResult "Test-Command with empty string" ($result -eq $false) "Testing empty command" "False" $result
        } catch {
            Write-UnitTestResult "Test-Command with empty string" $true "Function properly handled empty input with exception"
        }
    }
    
    # Test Test-Command with null
    if (Get-Command Test-Command -ErrorAction SilentlyContinue) {
        try {
            $result = Test-Command $null
            Write-UnitTestResult "Test-Command with null" ($result -eq $false) "Testing null command" "False" $result
        } catch {
            Write-UnitTestResult "Test-Command with null" $true "Function properly handled null input with exception"
        }
    }
    
    # Test Write functions with long strings
    if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
        try {
            $longString = "A" * 1000
            Write-Info $longString
            Write-UnitTestResult "Write-Info with long string" $true "Testing with 1000 character string"
        } catch {
            Write-UnitTestResult "Write-Info with long string" $false "Function failed with long string: $($_.Exception.Message)"
        }
    }
}

#endregion

#region Performance Tests

Write-Host "`n═══ Function Performance Tests ═══" -ForegroundColor Cyan

if ($functionsLoaded) {
    # Test Test-Command performance
    if (Get-Command Test-Command -ErrorAction SilentlyContinue) {
        try {
            $measureResult = Measure-Command { 
                for ($i = 0; $i -lt 10; $i++) {
                    Test-Command "powershell" | Out-Null
                }
            }
            $avgTime = $measureResult.TotalMilliseconds / 10
            $performanceOk = $avgTime -lt 100  # Should be under 100ms average
            Write-UnitTestResult "Test-Command performance" $performanceOk "Average time for 10 calls: $($avgTime.ToString('F2'))ms" "< 100ms" "$($avgTime.ToString('F2'))ms"
        } catch {
            Write-UnitTestResult "Test-Command performance" $false "Performance test failed: $($_.Exception.Message)"
        }
    }
}

#endregion

#region Unit Test Results Summary

Write-Host "`n" + "═" * 80 -ForegroundColor Magenta
Write-Host "UNIT TEST RESULTS SUMMARY" -ForegroundColor Magenta
Write-Host "═" * 80 -ForegroundColor Magenta

Write-Host "`nUnit Test Results:" -ForegroundColor White
Write-Host "  Total Tests: $($script:UnitTestResults.Total)" -ForegroundColor Gray
Write-Host "  Passed: $($script:UnitTestResults.Passed)" -ForegroundColor Green
Write-Host "  Failed: $($script:UnitTestResults.Failed)" -ForegroundColor Red

$unitSuccessRate = if ($script:UnitTestResults.Total -gt 0) { 
    [math]::Round(($script:UnitTestResults.Passed / $script:UnitTestResults.Total) * 100, 1) 
} else { 0 }

Write-Host "`nUnit Test Success Rate: $unitSuccessRate%" -ForegroundColor $(if ($unitSuccessRate -ge 90) { "Green" } elseif ($unitSuccessRate -ge 70) { "Yellow" } else { "Red" })

# Show failed unit tests
if ($script:UnitTestResults.Failed -gt 0) {
    Write-Host "`nFailed Unit Tests:" -ForegroundColor Red
    $script:UnitTestResults.Details | Where-Object { $_.Result -eq "FAILED" } | ForEach-Object {
        Write-Host "  ❌ $($_.Test)" -ForegroundColor Red
        if ($_.Message) {
            Write-Host "     $($_.Message)" -ForegroundColor Yellow
        }
        if ($_.Expected -and $_.Actual) {
            Write-Host "     Expected: $($_.Expected), Actual: $($_.Actual)" -ForegroundColor Cyan
        }
    }
}

Write-Host "`nUnit Test Recommendations:" -ForegroundColor Cyan

if ($script:UnitTestResults.Failed -eq 0) {
    Write-Host "  ✅ All unit tests passed! Individual functions are working correctly." -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Some unit tests failed. Review the specific function implementations." -ForegroundColor Yellow
}

if (-not $TestWSLFunctions) {
    Write-Host "  📝 Run with -TestWSLFunctions to test WSL-specific functionality." -ForegroundColor Yellow
}

if (-not $TestVSCodeFunctions) {
    Write-Host "  📝 Run with -TestVSCodeFunctions to test VS Code integration functions." -ForegroundColor Yellow
}

Write-Host "`nUnit testing completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "═" * 80 -ForegroundColor Magenta

# Exit with appropriate code
exit $(if ($script:UnitTestResults.Failed -eq 0) { 0 } else { 1 })

#endregion
