# StrangeLoop CLI Setup Script - Test Usage Guide
# Quick reference for running comprehensive tests
# 
# Author: [Sakr Omera/Bing Ads Teams Egypt]
# Version: 1.0
# Created: August 2025

Write-Host @"
 
╔═══════════════════════════════════════════════════════════════╗
║        StrangeLoop CLI Setup - Test Usage Guide               ║
║              Comprehensive Testing Reference                  ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host "`nStrangeLoop CLI Setup Test Suite - Usage Guide" -ForegroundColor White
Write-Host "This guide explains how to run comprehensive tests for the setup script" -ForegroundColor Gray

Write-Host "`n═══ Available Test Scripts ═══" -ForegroundColor Cyan

Write-Host "`n1. test_setup_strangeloop.ps1 - Integration Tests" -ForegroundColor Yellow
Write-Host "   Purpose: Tests overall system compatibility and setup requirements" -ForegroundColor Gray
Write-Host "   Usage Examples:" -ForegroundColor White
Write-Host "     .\test_setup_strangeloop.ps1                    # Basic test run" -ForegroundColor Cyan
Write-Host "     .\test_setup_strangeloop.ps1 -RunFullTests      # Comprehensive testing" -ForegroundColor Cyan
Write-Host "     .\test_setup_strangeloop.ps1 -SkipWSLTests      # Skip WSL-related tests" -ForegroundColor Cyan
Write-Host "     .\test_setup_strangeloop.ps1 -SkipVSCodeTests   # Skip VS Code tests" -ForegroundColor Cyan
Write-Host "     .\test_setup_strangeloop.ps1 -SkipNetworkTests  # Skip network tests" -ForegroundColor Cyan
Write-Host "     .\test_setup_strangeloop.ps1 -Verbose           # Detailed output" -ForegroundColor Cyan

Write-Host "`n2. test_setup_functions.ps1 - Unit Tests" -ForegroundColor Yellow
Write-Host "   Purpose: Tests individual functions and their behavior" -ForegroundColor Gray
Write-Host "   Usage Examples:" -ForegroundColor White
Write-Host "     .\test_setup_functions.ps1                      # Basic function tests" -ForegroundColor Cyan
Write-Host "     .\test_setup_functions.ps1 -TestWSLFunctions    # Test WSL-specific functions" -ForegroundColor Cyan
Write-Host "     .\test_setup_functions.ps1 -TestVSCodeFunctions # Test VS Code functions" -ForegroundColor Cyan
Write-Host "     .\test_setup_functions.ps1 -Verbose             # Detailed function testing" -ForegroundColor Cyan

Write-Host "`n3. run_all_tests.ps1 - Comprehensive Test Runner" -ForegroundColor Yellow
Write-Host "   Purpose: Runs all test suites and generates reports" -ForegroundColor Gray
Write-Host "   Usage Examples:" -ForegroundColor White
Write-Host "     .\run_all_tests.ps1                             # Run all test suites" -ForegroundColor Cyan
Write-Host "     .\run_all_tests.ps1 -FullTest                   # Full comprehensive testing" -ForegroundColor Cyan
Write-Host "     .\run_all_tests.ps1 -GenerateReport             # Generate HTML/JSON reports" -ForegroundColor Cyan
Write-Host "     .\run_all_tests.ps1 -OutputPath 'results'       # Custom output directory" -ForegroundColor Cyan
Write-Host "     .\run_all_tests.ps1 -SkipWSL -SkipVSCode        # Skip specific test categories" -ForegroundColor Cyan

Write-Host "`n═══ Test Categories ═══" -ForegroundColor Cyan

Write-Host "`n📋 System Requirements Tests:" -ForegroundColor White
Write-Host "   • PowerShell version compatibility" -ForegroundColor Gray
Write-Host "   • Windows version requirements" -ForegroundColor Gray
Write-Host "   • Execution policy validation" -ForegroundColor Gray
Write-Host "   • Administrator privileges check" -ForegroundColor Gray

Write-Host "`n📋 Script Validation Tests:" -ForegroundColor White
Write-Host "   • PowerShell syntax validation" -ForegroundColor Gray
Write-Host "   • Function existence verification" -ForegroundColor Gray
Write-Host "   • Parameter validation" -ForegroundColor Gray
Write-Host "   • Error handling tests" -ForegroundColor Gray

Write-Host "`n📋 WSL Integration Tests:" -ForegroundColor White
Write-Host "   • WSL installation and availability" -ForegroundColor Gray
Write-Host "   • Ubuntu distribution management" -ForegroundColor Gray
Write-Host "   • WSL command execution" -ForegroundColor Gray
Write-Host "   • Path resolution and conversion" -ForegroundColor Gray

Write-Host "`n📋 VS Code Integration Tests:" -ForegroundColor White
Write-Host "   • VS Code CLI availability" -ForegroundColor Gray
Write-Host "   • Extension installation testing" -ForegroundColor Gray
Write-Host "   • WSL extension validation" -ForegroundColor Gray
Write-Host "   • Project opening functionality" -ForegroundColor Gray

Write-Host "`n📋 Network Connectivity Tests:" -ForegroundColor White
Write-Host "   • GitHub accessibility" -ForegroundColor Gray
Write-Host "   • VS Code Marketplace connectivity" -ForegroundColor Gray
Write-Host "   • Microsoft WSL resources" -ForegroundColor Gray
Write-Host "   • Download capability validation" -ForegroundColor Gray

Write-Host "`n📋 Performance Tests:" -ForegroundColor White
Write-Host "   • Script loading time" -ForegroundColor Gray
Write-Host "   • Function execution performance" -ForegroundColor Gray
Write-Host "   • Memory usage validation" -ForegroundColor Gray
Write-Host "   • Resource efficiency checks" -ForegroundColor Gray

Write-Host "`n═══ Recommended Test Workflows ═══" -ForegroundColor Cyan

Write-Host "`n🚀 Quick Validation (Development):" -ForegroundColor Green
Write-Host "   .\test_setup_strangeloop.ps1" -ForegroundColor Cyan
Write-Host "   Purpose: Fast validation during development" -ForegroundColor Gray

Write-Host "`n🔍 Comprehensive Testing (Pre-release):" -ForegroundColor Green
Write-Host "   .\run_all_tests.ps1 -FullTest -GenerateReport" -ForegroundColor Cyan
Write-Host "   Purpose: Complete validation before release" -ForegroundColor Gray

Write-Host "`n🎯 Targeted Testing (Specific Issues):" -ForegroundColor Green
Write-Host "   .\test_setup_functions.ps1 -TestWSLFunctions -Verbose" -ForegroundColor Cyan
Write-Host "   Purpose: Debug specific functionality" -ForegroundColor Gray

Write-Host "`n🌐 Production Environment Testing:" -ForegroundColor Green
Write-Host "   .\run_all_tests.ps1 -SkipNetworkTests -GenerateReport" -ForegroundColor Cyan
Write-Host "   Purpose: Validate in restricted environments" -ForegroundColor Gray

Write-Host "`n═══ Understanding Test Results ═══" -ForegroundColor Cyan

Write-Host "`n✅ Success Indicators:" -ForegroundColor Green
Write-Host "   • Exit code 0" -ForegroundColor Gray
Write-Host "   • Success rate ≥ 90%" -ForegroundColor Gray
Write-Host "   • All critical tests passed" -ForegroundColor Gray
Write-Host "   • No unexpected failures" -ForegroundColor Gray

Write-Host "`n⚠️ Warning Indicators:" -ForegroundColor Yellow
Write-Host "   • Success rate 70-89%" -ForegroundColor Gray
Write-Host "   • Optional features failed" -ForegroundColor Gray
Write-Host "   • High number of skipped tests" -ForegroundColor Gray
Write-Host "   • Performance degradation" -ForegroundColor Gray

Write-Host "`n❌ Failure Indicators:" -ForegroundColor Red
Write-Host "   • Exit code non-zero" -ForegroundColor Gray
Write-Host "   • Success rate < 70%" -ForegroundColor Gray
Write-Host "   • Critical functionality failed" -ForegroundColor Gray
Write-Host "   • Script syntax errors" -ForegroundColor Gray

Write-Host "`n═══ Troubleshooting Common Issues ═══" -ForegroundColor Cyan

Write-Host "`n🔧 WSL Test Failures:" -ForegroundColor Yellow
Write-Host "   • Ensure WSL is enabled in Windows Features" -ForegroundColor Gray
Write-Host "   • Install WSL 2 kernel update" -ForegroundColor Gray
Write-Host "   • Verify Ubuntu distribution is available" -ForegroundColor Gray
Write-Host "   • Check Windows version compatibility" -ForegroundColor Gray

Write-Host "`n🔧 VS Code Test Failures:" -ForegroundColor Yellow
Write-Host "   • Install VS Code with CLI tools" -ForegroundColor Gray
Write-Host "   • Add 'code' command to PATH" -ForegroundColor Gray
Write-Host "   • Restart terminal after VS Code installation" -ForegroundColor Gray
Write-Host "   • Check VS Code permissions" -ForegroundColor Gray

Write-Host "`n🔧 Network Test Failures:" -ForegroundColor Yellow
Write-Host "   • Check internet connectivity" -ForegroundColor Gray
Write-Host "   • Verify proxy settings" -ForegroundColor Gray
Write-Host "   • Check firewall restrictions" -ForegroundColor Gray
Write-Host "   • Use -SkipNetworkTests if necessary" -ForegroundColor Gray

Write-Host "`n🔧 Permission Issues:" -ForegroundColor Yellow
Write-Host "   • Run PowerShell as Administrator" -ForegroundColor Gray
Write-Host "   • Check execution policy settings" -ForegroundColor Gray
Write-Host "   • Verify file system permissions" -ForegroundColor Gray
Write-Host "   • Use appropriate security context" -ForegroundColor Gray

Write-Host "`n═══ Report Analysis ═══" -ForegroundColor Cyan

Write-Host "`n📊 HTML Report Contents:" -ForegroundColor White
Write-Host "   • Executive summary with success rates" -ForegroundColor Gray
Write-Host "   • Detailed test breakdown by category" -ForegroundColor Gray
Write-Host "   • Performance metrics and timing" -ForegroundColor Gray
Write-Host "   • Specific recommendations for failures" -ForegroundColor Gray

Write-Host "`n📊 JSON Report Usage:" -ForegroundColor White
Write-Host "   • Machine-readable test results" -ForegroundColor Gray
Write-Host "   • Integration with CI/CD pipelines" -ForegroundColor Gray
Write-Host "   • Historical trend analysis" -ForegroundColor Gray
Write-Host "   • Automated quality gates" -ForegroundColor Gray

Write-Host "`n═══ Next Steps ═══" -ForegroundColor Cyan

Write-Host "`n1. Run basic tests first:" -ForegroundColor White
Write-Host "   .\test_setup_strangeloop.ps1" -ForegroundColor Cyan

Write-Host "`n2. If issues found, run targeted tests:" -ForegroundColor White
Write-Host "   .\test_setup_functions.ps1 -Verbose" -ForegroundColor Cyan

Write-Host "`n3. For complete validation:" -ForegroundColor White
Write-Host "   .\run_all_tests.ps1 -FullTest -GenerateReport" -ForegroundColor Cyan

Write-Host "`n4. Review reports and address any failures" -ForegroundColor White

Write-Host "`n5. Re-run tests after fixes to confirm resolution" -ForegroundColor White

Write-Host "`n═══════════════════════════════════════════════" -ForegroundColor Green
Write-Host "Happy Testing! 🧪" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Green
