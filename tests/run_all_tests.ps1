# StrangeLoop CLI Setup Script - Test Runner
# Comprehensive test execution and reporting for setup_strangeloop.ps1
# 
# Author: [Sakr Omera/Bing Ads Teams Egypt]
# Version: 1.0
# Created: August 2025
# 
# This script runs all test suites and generates a comprehensive report
#
# Usage: .\run_all_tests.ps1 [-FullTest] [-GenerateReport] [-OutputPath <path>]

param(
    [switch]$FullTest = $false,
    [switch]$GenerateReport = $false,
    [string]$OutputPath = "test_results",
    [switch]$Verbose = $false,
    [switch]$SkipWSL = $false,
    [switch]$SkipVSCode = $false,
    [switch]$SkipNetwork = $false
)

# Configuration
$script:TestSuites = @(
    @{
        Name = "Comprehensive Integration Tests"
        Script = "test_setup_strangeloop.ps1"
        Description = "Full system integration and compatibility tests"
        Color = "Blue"
    },
    @{
        Name = "Unit Function Tests"
        Script = "test_setup_functions.ps1"
        Description = "Individual function validation and unit tests"
        Color = "Magenta"
    }
)

$script:OverallResults = @{
    TestSuites = 0
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    SkippedTests = 0
    StartTime = Get-Date
    EndTime = $null
    Duration = $null
    SuiteResults = @()
}

# Ensure output directory exists
if ($GenerateReport -and -not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

Write-Host @"
 
╔═══════════════════════════════════════════════════════════════╗
║           StrangeLoop CLI Setup - Test Runner                 ║
║                 Comprehensive Test Execution                  ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor White

Write-Host "`nStrangeLoop CLI Setup - Comprehensive Test Runner" -ForegroundColor White
Write-Host "Running all test suites with detailed reporting" -ForegroundColor Gray
Write-Host "`nTest Configuration:" -ForegroundColor Yellow
Write-Host "  Full Testing: $FullTest" -ForegroundColor Gray
Write-Host "  Generate Report: $GenerateReport" -ForegroundColor Gray
Write-Host "  Output Path: $OutputPath" -ForegroundColor Gray
Write-Host "  Skip WSL Tests: $SkipWSL" -ForegroundColor Gray
Write-Host "  Skip VS Code Tests: $SkipVSCode" -ForegroundColor Gray
Write-Host "  Skip Network Tests: $SkipNetwork" -ForegroundColor Gray
Write-Host ""

#region Test Execution Functions

function Write-TestSuiteHeader {
    param([string]$SuiteName, [string]$Color = "White")
    
    $border = "═" * ($SuiteName.Length + 8)
    Write-Host "`n$border" -ForegroundColor $Color
    Write-Host "    $SuiteName" -ForegroundColor $Color
    Write-Host "$border" -ForegroundColor $Color
}

function Execute-TestSuite {
    param(
        [hashtable]$TestSuite,
        [hashtable]$Parameters = @{}
    )
    
    $suiteResult = @{
        Name = $TestSuite.Name
        Script = $TestSuite.Script
        Success = $false
        ExitCode = -1
        Output = ""
        Error = ""
        StartTime = Get-Date
        EndTime = $null
        Duration = $null
        TestCounts = @{
            Total = 0
            Passed = 0
            Failed = 0
            Skipped = 0
        }
    }
    
    Write-TestSuiteHeader $TestSuite.Name $TestSuite.Color
    Write-Host "Description: $($TestSuite.Description)" -ForegroundColor Gray
    Write-Host "Script: $($TestSuite.Script)" -ForegroundColor Gray
    Write-Host ""
    
    try {
        $scriptPath = Join-Path $PSScriptRoot $TestSuite.Script
        
        if (-not (Test-Path $scriptPath)) {
            throw "Test script not found: $scriptPath"
        }
        
        # Build parameter string
        $paramString = ""
        foreach ($key in $Parameters.Keys) {
            if ($Parameters[$key] -is [bool] -and $Parameters[$key]) {
                $paramString += " -$key"
            } elseif ($Parameters[$key] -is [string] -and $Parameters[$key]) {
                $paramString += " -$key '$($Parameters[$key])'"
            }
        }
        
        Write-Host "Executing: powershell -NoProfile -File `"$scriptPath`"$paramString" -ForegroundColor Yellow
        
        # Execute the test script
        $process = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile", "-File", "`"$scriptPath`"$paramString" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "temp_suite_output.txt" -RedirectStandardError "temp_suite_error.txt"
        
        $suiteResult.ExitCode = $process.ExitCode
        $suiteResult.Success = $process.ExitCode -eq 0
        $suiteResult.Output = if (Test-Path "temp_suite_output.txt") { Get-Content "temp_suite_output.txt" -Raw } else { "" }
        $suiteResult.Error = if (Test-Path "temp_suite_error.txt") { Get-Content "temp_suite_error.txt" -Raw } else { "" }
        
        # Parse test results from output
        $output = $suiteResult.Output
        if ($output -match "Total Tests:\s*(\d+)") { $suiteResult.TestCounts.Total = [int]$matches[1] }
        if ($output -match "Passed:\s*(\d+)") { $suiteResult.TestCounts.Passed = [int]$matches[1] }
        if ($output -match "Failed:\s*(\d+)") { $suiteResult.TestCounts.Failed = [int]$matches[1] }
        if ($output -match "Skipped:\s*(\d+)") { $suiteResult.TestCounts.Skipped = [int]$matches[1] }
        
        # Cleanup temp files
        Remove-Item "temp_suite_output.txt" -ErrorAction SilentlyContinue
        Remove-Item "temp_suite_error.txt" -ErrorAction SilentlyContinue
        
    } catch {
        $suiteResult.Error = $_.Exception.Message
        Write-Host "❌ Test suite execution failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $suiteResult.EndTime = Get-Date
    $suiteResult.Duration = $suiteResult.EndTime - $suiteResult.StartTime
    
    # Display suite results
    Write-Host "`nSuite Results:" -ForegroundColor White
    Write-Host "  Status: $(if ($suiteResult.Success) { '✅ PASSED' } else { '❌ FAILED' })" -ForegroundColor $(if ($suiteResult.Success) { "Green" } else { "Red" })
    Write-Host "  Exit Code: $($suiteResult.ExitCode)" -ForegroundColor Gray
    Write-Host "  Duration: $($suiteResult.Duration.TotalSeconds.ToString('F1'))s" -ForegroundColor Gray
    Write-Host "  Test Counts:" -ForegroundColor Gray
    Write-Host "    Total: $($suiteResult.TestCounts.Total)" -ForegroundColor Gray
    Write-Host "    Passed: $($suiteResult.TestCounts.Passed)" -ForegroundColor Green
    Write-Host "    Failed: $($suiteResult.TestCounts.Failed)" -ForegroundColor Red
    Write-Host "    Skipped: $($suiteResult.TestCounts.Skipped)" -ForegroundColor Yellow
    
    if ($Verbose -and $suiteResult.Output) {
        Write-Host "`nDetailed Output:" -ForegroundColor Cyan
        Write-Host $suiteResult.Output -ForegroundColor Gray
    }
    
    if ($suiteResult.Error) {
        Write-Host "`nErrors:" -ForegroundColor Red
        Write-Host $suiteResult.Error -ForegroundColor Yellow
    }
    
    return $suiteResult
}

#endregion

#region Test Suite Execution

Write-Host "Starting comprehensive test execution..." -ForegroundColor Green
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

foreach ($suite in $script:TestSuites) {
    $script:OverallResults.TestSuites++
    
    # Build parameters for each test suite
    $testParams = @{}
    
    if ($suite.Name -eq "Comprehensive Integration Tests") {
        if ($FullTest) { $testParams["RunFullTests"] = $true }
        if ($SkipWSL) { $testParams["SkipWSLTests"] = $true }
        if ($SkipVSCode) { $testParams["SkipVSCodeTests"] = $true }
        if ($SkipNetwork) { $testParams["SkipNetworkTests"] = $true }
        if ($Verbose) { $testParams["Verbose"] = $true }
    } elseif ($suite.Name -eq "Unit Function Tests") {
        if ($Verbose) { $testParams["Verbose"] = $true }
        if (-not $SkipWSL) { $testParams["TestWSLFunctions"] = $true }
        if (-not $SkipVSCode) { $testParams["TestVSCodeFunctions"] = $true }
    }
    
    # Execute test suite
    $suiteResult = Execute-TestSuite -TestSuite $suite -Parameters $testParams
    $script:OverallResults.SuiteResults += $suiteResult
    
    # Aggregate results
    $script:OverallResults.TotalTests += $suiteResult.TestCounts.Total
    $script:OverallResults.PassedTests += $suiteResult.TestCounts.Passed
    $script:OverallResults.FailedTests += $suiteResult.TestCounts.Failed
    $script:OverallResults.SkippedTests += $suiteResult.TestCounts.Skipped
}

$script:OverallResults.EndTime = Get-Date
$script:OverallResults.Duration = $script:OverallResults.EndTime - $script:OverallResults.StartTime

#endregion

#region Results Analysis and Reporting

Write-Host "`n" + "═" * 100 -ForegroundColor White
Write-Host "COMPREHENSIVE TEST RESULTS SUMMARY" -ForegroundColor White
Write-Host "═" * 100 -ForegroundColor White

Write-Host "`nOverall Test Execution Results:" -ForegroundColor White
Write-Host "  Test Suites Executed: $($script:OverallResults.TestSuites)" -ForegroundColor Gray
Write-Host "  Total Test Cases: $($script:OverallResults.TotalTests)" -ForegroundColor Gray
Write-Host "  Passed: $($script:OverallResults.PassedTests)" -ForegroundColor Green
Write-Host "  Failed: $($script:OverallResults.FailedTests)" -ForegroundColor Red
Write-Host "  Skipped: $($script:OverallResults.SkippedTests)" -ForegroundColor Yellow
Write-Host "  Total Duration: $($script:OverallResults.Duration.TotalSeconds.ToString('F1'))s" -ForegroundColor Gray

$overallSuccessRate = if ($script:OverallResults.TotalTests -gt 0) { 
    [math]::Round(($script:OverallResults.PassedTests / $script:OverallResults.TotalTests) * 100, 1) 
} else { 0 }

Write-Host "`nOverall Success Rate: $overallSuccessRate%" -ForegroundColor $(
    if ($overallSuccessRate -ge 90) { "Green" } 
    elseif ($overallSuccessRate -ge 75) { "Yellow" } 
    else { "Red" }
)

# Suite-by-suite breakdown
Write-Host "`nTest Suite Breakdown:" -ForegroundColor Cyan
foreach ($suiteResult in $script:OverallResults.SuiteResults) {
    $suiteSuccess = $suiteResult.Success
    $suiteRate = if ($suiteResult.TestCounts.Total -gt 0) {
        [math]::Round(($suiteResult.TestCounts.Passed / $suiteResult.TestCounts.Total) * 100, 1)
    } else { 0 }
    
    Write-Host "  $($suiteResult.Name):" -ForegroundColor White
    Write-Host "    Status: $(if ($suiteSuccess) { '✅ PASSED' } else { '❌ FAILED' })" -ForegroundColor $(if ($suiteSuccess) { "Green" } else { "Red" })
    Write-Host "    Success Rate: $suiteRate%" -ForegroundColor $(
        if ($suiteRate -ge 90) { "Green" } 
        elseif ($suiteRate -ge 75) { "Yellow" } 
        else { "Red" }
    )
    Write-Host "    Tests: $($suiteResult.TestCounts.Passed)/$($suiteResult.TestCounts.Total) passed" -ForegroundColor Gray
    Write-Host "    Duration: $($suiteResult.Duration.TotalSeconds.ToString('F1'))s" -ForegroundColor Gray
}

# Recommendations
Write-Host "`nRecommendations:" -ForegroundColor Cyan

$allSuitesPass = ($script:OverallResults.SuiteResults | Where-Object { -not $_.Success }).Count -eq 0

if ($allSuitesPass -and $script:OverallResults.FailedTests -eq 0) {
    Write-Host "  🎉 Excellent! All test suites passed successfully." -ForegroundColor Green
    Write-Host "  ✅ The setup script is ready for production use." -ForegroundColor Green
} elseif ($overallSuccessRate -ge 80) {
    Write-Host "  ⚠️  Most tests passed, but some issues were found." -ForegroundColor Yellow
    Write-Host "  📝 Review failed tests and consider fixing before production use." -ForegroundColor Yellow
} else {
    Write-Host "  ❌ Significant test failures detected." -ForegroundColor Red
    Write-Host "  🔧 The setup script requires fixes before use." -ForegroundColor Red
}

# Specific recommendations based on test results
$hasWSLFailures = $script:OverallResults.SuiteResults | ForEach-Object { $_.Output } | Where-Object { $_ -match "WSL.*FAIL" }
$hasVSCodeFailures = $script:OverallResults.SuiteResults | ForEach-Object { $_.Output } | Where-Object { $_ -match "(VS Code|code).*FAIL" }
$hasNetworkFailures = $script:OverallResults.SuiteResults | ForEach-Object { $_.Output } | Where-Object { $_ -match "(Network|connectivity).*FAIL" }

if ($hasWSLFailures) {
    Write-Host "  📋 WSL-related issues detected. Ensure WSL is properly installed and configured." -ForegroundColor Yellow
}

if ($hasVSCodeFailures) {
    Write-Host "  📋 VS Code integration issues detected. Ensure VS Code is installed with CLI support." -ForegroundColor Yellow
}

if ($hasNetworkFailures) {
    Write-Host "  📋 Network connectivity issues detected. Check internet connection and firewall settings." -ForegroundColor Yellow
}

if ($script:OverallResults.SkippedTests -gt 10) {
    Write-Host "  📋 Many tests were skipped. Consider running with -FullTest for complete validation." -ForegroundColor Yellow
}

#endregion

#region Report Generation

if ($GenerateReport) {
    Write-Host "`nGenerating detailed test report..." -ForegroundColor Yellow
    
    $reportData = @{
        ExecutionInfo = @{
            DateTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Machine = $env:COMPUTERNAME
            User = $env:USERNAME
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            OSVersion = [System.Environment]::OSVersion.VersionString
            Parameters = @{
                FullTest = $FullTest
                SkipWSL = $SkipWSL
                SkipVSCode = $SkipVSCode
                SkipNetwork = $SkipNetwork
                Verbose = $Verbose
            }
        }
        Summary = $script:OverallResults
        Recommendations = @()
    }
    
    # Add recommendations to report
    if ($allSuitesPass -and $script:OverallResults.FailedTests -eq 0) {
        $reportData.Recommendations += "All tests passed - script ready for production"
    } else {
        $reportData.Recommendations += "Review failed tests before production use"
    }
    
    if ($hasWSLFailures) { $reportData.Recommendations += "Address WSL configuration issues" }
    if ($hasVSCodeFailures) { $reportData.Recommendations += "Fix VS Code integration problems" }
    if ($hasNetworkFailures) { $reportData.Recommendations += "Resolve network connectivity issues" }
    
    # Generate JSON report
    $jsonReportPath = Join-Path $OutputPath "test_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonReportPath -Encoding UTF8
    
    # Generate HTML report
    $htmlReportPath = Join-Path $OutputPath "test_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>StrangeLoop CLI Setup - Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { background-color: #e8f5e8; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .failed { background-color: #ffe8e8; }
        .warning { background-color: #fff8e1; }
        .suite { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .pass { color: green; }
        .fail { color: red; }
        .skip { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>StrangeLoop CLI Setup - Test Results</h1>
        <p><strong>Execution Time:</strong> $($reportData.ExecutionInfo.DateTime)</p>
        <p><strong>Machine:</strong> $($reportData.ExecutionInfo.Machine)</p>
        <p><strong>User:</strong> $($reportData.ExecutionInfo.User)</p>
        <p><strong>PowerShell Version:</strong> $($reportData.ExecutionInfo.PowerShellVersion)</p>
    </div>
    
    <div class="summary $(if ($overallSuccessRate -lt 80) { 'failed' } elseif ($overallSuccessRate -lt 90) { 'warning' })">
        <h2>Summary</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Overall Success Rate</td><td class="$(if ($overallSuccessRate -ge 80) { 'pass' } else { 'fail' })">$overallSuccessRate%</td></tr>
            <tr><td>Total Tests</td><td>$($script:OverallResults.TotalTests)</td></tr>
            <tr><td>Passed Tests</td><td class="pass">$($script:OverallResults.PassedTests)</td></tr>
            <tr><td>Failed Tests</td><td class="fail">$($script:OverallResults.FailedTests)</td></tr>
            <tr><td>Skipped Tests</td><td class="skip">$($script:OverallResults.SkippedTests)</td></tr>
            <tr><td>Total Duration</td><td>$($script:OverallResults.Duration.TotalSeconds.ToString('F1'))s</td></tr>
        </table>
    </div>
    
    <h2>Test Suite Results</h2>
"@
    
    foreach ($suiteResult in $script:OverallResults.SuiteResults) {
        $suiteRate = if ($suiteResult.TestCounts.Total -gt 0) {
            [math]::Round(($suiteResult.TestCounts.Passed / $suiteResult.TestCounts.Total) * 100, 1)
        } else { 0 }
        
        $htmlContent += @"
    <div class="suite">
        <h3>$($suiteResult.Name) - <span class="$(if ($suiteResult.Success) { 'pass' } else { 'fail' })">$(if ($suiteResult.Success) { 'PASSED' } else { 'FAILED' })</span></h3>
        <p><strong>Success Rate:</strong> $suiteRate%</p>
        <p><strong>Duration:</strong> $($suiteResult.Duration.TotalSeconds.ToString('F1'))s</p>
        <table>
            <tr><th>Status</th><th>Count</th></tr>
            <tr><td>Passed</td><td class="pass">$($suiteResult.TestCounts.Passed)</td></tr>
            <tr><td>Failed</td><td class="fail">$($suiteResult.TestCounts.Failed)</td></tr>
            <tr><td>Skipped</td><td class="skip">$($suiteResult.TestCounts.Skipped)</td></tr>
            <tr><td>Total</td><td>$($suiteResult.TestCounts.Total)</td></tr>
        </table>
    </div>
"@
    }
    
    $htmlContent += @"
    <h2>Recommendations</h2>
    <ul>
"@
    
    foreach ($rec in $reportData.Recommendations) {
        $htmlContent += "<li>$rec</li>"
    }
    
    $htmlContent += @"
    </ul>
    
    <footer>
        <p><em>Generated on $($reportData.ExecutionInfo.DateTime) by StrangeLoop CLI Test Runner</em></p>
    </footer>
</body>
</html>
"@
    
    $htmlContent | Out-File -FilePath $htmlReportPath -Encoding UTF8
    
    Write-Host "✅ Reports generated:" -ForegroundColor Green
    Write-Host "  JSON: $jsonReportPath" -ForegroundColor Cyan
    Write-Host "  HTML: $htmlReportPath" -ForegroundColor Cyan
}

#endregion

Write-Host "`nTest execution completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "═" * 100 -ForegroundColor White

# Exit with appropriate code
$hasFailures = $script:OverallResults.FailedTests -gt 0 -or ($script:OverallResults.SuiteResults | Where-Object { -not $_.Success }).Count -gt 0
exit $(if ($hasFailures) { 1 } else { 0 })
