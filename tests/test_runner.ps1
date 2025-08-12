# StrangeLoop CLI Setup - Test Runner
# Professional test execution interface for the StrangeLoop CLI setup system
# 
# Author: [Sakr Omera/Bing Ads Teams Egypt]
# Version: 1.0
# Created: August 2025
# 
# This test runner provides a convenient interface for executing various test types

param(
    [ValidateSet("basic", "full", "functions", "guide", "help")]
    [string]$TestType = "basic",
    [switch]$GenerateReport = $false,
    [switch]$Verbose = $false,
    [switch]$SkipWSL = $false,
    [switch]$SkipVSCode = $false,
    [switch]$SkipNetwork = $false
)

$testsPath = $PSScriptRoot

if (-not (Test-Path $testsPath)) {
    Write-Host "❌ Tests folder not found at: $testsPath" -ForegroundColor Red
    Write-Host "Please ensure the tests folder exists with the test scripts." -ForegroundColor Yellow
    exit 1
}

Write-Host @"
 
╔═══════════════════════════════════════════════════════════════╗
║            StrangeLoop CLI Setup - Test Runner                ║
║                Professional Test Interface                    ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue

Write-Host "`nStrangeLoop CLI Setup Test Runner" -ForegroundColor White
Write-Host "Professional testing interface for development and validation" -ForegroundColor Gray
Write-Host ""

switch ($TestType) {
    "basic" {
        Write-Host "Running basic integration tests..." -ForegroundColor Yellow
        $scriptPath = Join-Path $testsPath "test_setup_strangeloop.ps1"
        $arguments = @()
        if ($SkipWSL) { $arguments += "-SkipWSLTests" }
        if ($SkipVSCode) { $arguments += "-SkipVSCodeTests" }
        if ($SkipNetwork) { $arguments += "-SkipNetworkTests" }
        if ($Verbose) { $arguments += "-Verbose" }
        
        & $scriptPath @arguments
    }
    
    "full" {
        Write-Host "Running comprehensive test suite..." -ForegroundColor Yellow
        $scriptPath = Join-Path $testsPath "run_all_tests.ps1"
        $arguments = @("-FullTest")
        if ($GenerateReport) { $arguments += "-GenerateReport" }
        if ($SkipWSL) { $arguments += "-SkipWSL" }
        if ($SkipVSCode) { $arguments += "-SkipVSCode" }
        if ($SkipNetwork) { $arguments += "-SkipNetwork" }
        if ($Verbose) { $arguments += "-Verbose" }
        
        & $scriptPath @arguments
    }
    
    "functions" {
        Write-Host "Running unit function tests..." -ForegroundColor Yellow
        
        # Run main function tests
        $scriptPath = Join-Path $testsPath "test_setup_functions.ps1"
        $arguments = @()
        if (-not $SkipWSL) { $arguments += "-TestWSLFunctions" }
        if (-not $SkipVSCode) { $arguments += "-TestVSCodeFunctions" }
        if ($Verbose) { $arguments += "-Verbose" }
        
        & $scriptPath @arguments
        
        # Run Git configuration tests
        if (-not $SkipWSL) {
            Write-Host "`nRunning Git configuration tests..." -ForegroundColor Yellow
            $gitTestPath = Join-Path $testsPath "test_git_config.ps1"
            if (Test-Path $gitTestPath) {
                & $gitTestPath
            } else {
                Write-Warning "Git configuration test not found: $gitTestPath"
            }
        } else {
            Write-Host "`nSkipping Git configuration tests (WSL disabled)" -ForegroundColor Gray
        }
    }
    
    "guide" {
        Write-Host "Displaying test usage guide..." -ForegroundColor Yellow
        $scriptPath = Join-Path $testsPath "test_usage_guide.ps1"
        & $scriptPath
    }
    
    "help" {
        Write-Host "StrangeLoop CLI Setup Test Runner - Usage Help" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor White
        Write-Host "  .\tests\test_runner.ps1 [-TestType <type>] [options]" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Test Types:" -ForegroundColor Yellow
        Write-Host "  basic      - Run basic integration tests (default)" -ForegroundColor Gray
        Write-Host "  full       - Run comprehensive test suite with reports" -ForegroundColor Gray
        Write-Host "  functions  - Run unit function tests" -ForegroundColor Gray
        Write-Host "  guide      - Display interactive test usage guide" -ForegroundColor Gray
        Write-Host "  help       - Show this help message" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  -GenerateReport  - Generate HTML/JSON reports (for full tests)" -ForegroundColor Gray
        Write-Host "  -Verbose         - Show detailed output" -ForegroundColor Gray
        Write-Host "  -SkipWSL         - Skip WSL-related tests" -ForegroundColor Gray
        Write-Host "  -SkipVSCode      - Skip VS Code integration tests" -ForegroundColor Gray
        Write-Host "  -SkipNetwork     - Skip network connectivity tests" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Cyan
        Write-Host "  .\tests\test_runner.ps1                                    # Basic tests" -ForegroundColor White
        Write-Host "  .\tests\test_runner.ps1 -TestType full -GenerateReport    # Full tests with reports" -ForegroundColor White
        Write-Host "  .\tests\test_runner.ps1 -TestType functions -Verbose      # Detailed function tests" -ForegroundColor White
        Write-Host "  .\tests\test_runner.ps1 -SkipWSL -SkipVSCode              # Skip optional components" -ForegroundColor White
        Write-Host ""
        Write-Host "For detailed documentation, run:" -ForegroundColor Green
        Write-Host "  .\tests\test_runner.ps1 -TestType guide" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Test files are located in the 'tests' folder." -ForegroundColor Gray
    }
    
    default {
        Write-Host "❌ Unknown test type: $TestType" -ForegroundColor Red
        Write-Host "Run '.\test.ps1 -TestType help' for usage information." -ForegroundColor Yellow
        exit 1
    }
}
