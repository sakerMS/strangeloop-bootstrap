# StrangeLoop CLI Setup Script - Test Framework Documentation

## Overview

This comprehensive test framework validates all aspects of the StrangeLoop CLI setup script (`setup_strangeloop.ps1`). The test suite includes multiple test scripts that cover integration testing, unit testing, and comprehensive reporting.

## Test Scripts

### 1. `test_setup_strangeloop.ps1` - Integration Tests
**Purpose**: Validates system compatibility, prerequisites, and overall functionality.

**Key Features**:
- System requirements validation
- Command availability testing
- WSL integration testing
- VS Code integration testing
- Network connectivity testing
- File system permissions testing
- Performance benchmarking
- Security validation

**Usage**:
```powershell
# Basic test run
.\test_setup_strangeloop.ps1

# Comprehensive testing with all features
.\test_setup_strangeloop.ps1 -RunFullTests -Verbose

# Skip specific test categories
.\test_setup_strangeloop.ps1 -SkipWSLTests -SkipVSCodeTests
```

### 2. `test_setup_functions.ps1` - Unit Tests
**Purpose**: Tests individual functions and their behavior in isolation.

**Key Features**:
- Function availability validation
- Parameter validation testing
- Edge case handling
- Performance testing
- Error handling validation
- Mock input testing

**Usage**:
```powershell
# Basic function tests
.\test_setup_functions.ps1

# Test specific functionality
.\test_setup_functions.ps1 -TestWSLFunctions -TestVSCodeFunctions -Verbose
```

### 3. `run_all_tests.ps1` - Comprehensive Test Runner
**Purpose**: Orchestrates all test suites and generates detailed reports.

**Key Features**:
- Runs all test suites in sequence
- Aggregates results across test suites
- Generates HTML and JSON reports
- Provides comprehensive recommendations
- Supports parallel test execution
- Detailed performance metrics

**Usage**:
```powershell
# Run all tests
.\run_all_tests.ps1

# Full testing with reports
.\run_all_tests.ps1 -FullTest -GenerateReport -OutputPath "test_results"
```

### 4. `test_usage_guide.ps1` - Documentation and Reference
**Purpose**: Interactive guide for using the test framework.

## Test Categories

### 🔧 System Requirements Tests
- **PowerShell Version**: Validates PowerShell 5.1+ compatibility
- **Windows Version**: Ensures Windows 10/11 compatibility
- **Execution Policy**: Checks and validates execution policies
- **Administrator Privileges**: Verifies required permissions
- **File System Access**: Tests read/write permissions

### 📜 Script Validation Tests  
- **Syntax Validation**: PowerShell syntax checking
- **Function Existence**: Validates all required functions are defined
- **Parameter Validation**: Tests function parameter definitions
- **Load Testing**: Tests script loading without execution
- **Structure Validation**: Validates script organization

### 🐧 WSL Integration Tests
- **WSL Installation**: Checks WSL availability and version
- **Distribution Management**: Tests Ubuntu distribution setup
- **Command Execution**: Validates WSL command execution
- **Path Resolution**: Tests Windows/Linux path conversion
- **Error Handling**: Tests WSL error scenarios

### 💻 VS Code Integration Tests
- **CLI Availability**: Checks VS Code command line interface
- **Extension Management**: Tests extension installation/detection
- **WSL Extension**: Validates WSL extension functionality
- **Project Opening**: Tests VS Code project launching
- **Configuration**: Validates VS Code settings

### 🌐 Network Connectivity Tests
- **GitHub Access**: Tests GitHub connectivity
- **Marketplace Access**: Validates VS Code Marketplace access
- **Microsoft Resources**: Tests Microsoft download endpoints
- **Proxy Handling**: Validates proxy configuration
- **Firewall Compatibility**: Tests firewall scenarios

### ⚡ Performance Tests
- **Script Load Time**: Measures script parsing time
- **Function Execution**: Tests function performance
- **Memory Usage**: Validates resource consumption
- **Concurrency**: Tests parallel execution capabilities
- **Scalability**: Validates performance under load

### 🔒 Security Tests
- **Code Signing**: Validates script signatures (if applicable)
- **Dangerous Patterns**: Scans for potentially harmful commands
- **Input Validation**: Tests input sanitization
- **Privilege Escalation**: Validates security context
- **Data Protection**: Tests sensitive data handling

## Test Results and Reporting

### Success Metrics
- **Overall Success Rate**: Percentage of passed tests
- **Category Success Rates**: Success rate per test category
- **Performance Benchmarks**: Timing and resource usage metrics
- **Coverage Analysis**: Function and feature coverage statistics

### Report Formats

#### JSON Report
- Machine-readable test results
- Detailed test metadata
- Performance metrics
- Suitable for CI/CD integration
- Historical trend analysis

#### HTML Report
- Human-readable executive summary
- Visual charts and graphs
- Detailed test breakdowns
- Recommendations and next steps
- Professional presentation format

### Exit Codes
- **0**: All tests passed successfully
- **1**: Some tests failed, review required
- **2**: Critical failures, script unusable

## Usage Workflows

### 🚀 Development Workflow
```powershell
# Quick validation during development
.\test_setup_strangeloop.ps1

# Test specific functionality
.\test_setup_functions.ps1 -TestWSLFunctions -Verbose
```

### 🔍 Pre-Release Workflow
```powershell
# Comprehensive testing before release
.\run_all_tests.ps1 -FullTest -GenerateReport -OutputPath "release_validation"
```

### 🎯 Debugging Workflow
```powershell
# Targeted testing for specific issues
.\test_setup_functions.ps1 -TestFunction "Test-WSLInstallation" -Verbose
.\test_setup_strangeloop.ps1 -SkipNetworkTests -Verbose
```

### 🌐 Production Workflow
```powershell
# Production environment validation
.\run_all_tests.ps1 -SkipNetworkTests -GenerateReport
```

## Troubleshooting

### Common Issues and Solutions

#### WSL Test Failures
- Enable WSL in Windows Features
- Install WSL 2 kernel update
- Verify Ubuntu distribution availability
- Check Windows version compatibility

#### VS Code Test Failures
- Install VS Code with CLI tools
- Add 'code' command to PATH
- Restart terminal after installation
- Verify VS Code permissions

#### Network Test Failures
- Check internet connectivity
- Verify proxy settings
- Review firewall configuration
- Use `-SkipNetworkTests` if necessary

#### Permission Issues
- Run PowerShell as Administrator
- Check execution policy settings
- Verify file system permissions
- Use appropriate security context

## Extending the Test Framework

### Adding New Tests
1. Identify the test category
2. Add test function to appropriate script
3. Follow naming conventions (`Test-*`)
4. Include proper error handling
5. Update documentation

### Custom Test Suites
1. Create new test script following template
2. Implement test framework functions
3. Add to `run_all_tests.ps1` suite list
4. Document usage and purpose

### Integration with CI/CD
1. Use JSON output for automation
2. Set up proper exit codes
3. Configure environment-specific parameters
4. Implement result archiving

## Best Practices

### Test Development
- Write tests before implementing features
- Use descriptive test names
- Include both positive and negative tests
- Test edge cases and error conditions
- Maintain test independence

### Test Execution
- Run tests in clean environments
- Use appropriate test parameters
- Review all test output
- Address failures promptly
- Document test results

### Maintenance
- Update tests when functionality changes
- Review test coverage regularly
- Archive test results for trends
- Update documentation as needed
- Validate test effectiveness

## Conclusion

This comprehensive test framework ensures the StrangeLoop CLI setup script is robust, reliable, and ready for production use. The multi-layered testing approach catches issues early and provides confidence in the script's functionality across diverse environments.

For questions or support, refer to the test usage guide (`.\test_usage_guide.ps1`) or review the detailed test output and reports generated by the test runner.
