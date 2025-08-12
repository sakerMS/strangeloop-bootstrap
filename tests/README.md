# StrangeLoop CLI Setup - Test Suite

This folder contains the comprehensive test suite for the StrangeLoop CLI setup script.

## Quick Start

```powershell
# Navigate to the tests folder
cd tests

# Run basic integration tests
.\test_setup_strangeloop.ps1

# Run all tests with reports
.\run_all_tests.ps1 -FullTest -GenerateReport

# View usage guide
.\test_usage_guide.ps1
```

## Test Scripts

| Script | Purpose | Description |
|--------|---------|-------------|
| `test_setup_strangeloop.ps1` | Integration Tests | System compatibility and setup requirements |
| `test_setup_functions.ps1` | Unit Tests | Individual function validation |
| `test_ubuntu_detection.ps1` | Ubuntu Detection | Standalone Ubuntu 24.04 detection testing |
| `test_git_config.ps1` | Git Configuration | Git configuration detection and setting tests |
| `test_runner.ps1` | Convenience Runner | Root directory test launcher with options |
| `run_all_tests.ps1` | Test Runner | Orchestrates all tests with reporting |
| `test_usage_guide.ps1` | Documentation | Interactive usage guide |

## Test Categories

- **System Requirements**: PowerShell, Windows, execution policies
- **Script Validation**: Syntax, functions, structure
- **WSL Integration**: Installation, distributions, commands
- **VS Code Integration**: CLI, extensions, project opening
- **Network Connectivity**: GitHub, VS Code Marketplace, downloads
- **Performance**: Load times, execution speed, resources
- **Security**: Code patterns, input validation, privileges

## Common Usage Patterns

### Development Testing
```powershell
# Quick validation during development
.\test_setup_strangeloop.ps1

# Test specific functionality
.\test_setup_functions.ps1 -TestWSLFunctions -Verbose
```

### Pre-Release Testing
```powershell
# Comprehensive testing before release
.\run_all_tests.ps1 -FullTest -GenerateReport
```

### Production Environment Testing
```powershell
# Testing in restricted environments
.\run_all_tests.ps1 -SkipNetworkTests -GenerateReport
```

### Debugging Specific Issues
```powershell
# Skip problematic test categories
.\test_setup_strangeloop.ps1 -SkipWSLTests -SkipVSCodeTests -Verbose
```

## Output

- **Console Output**: Real-time test progress and results
- **JSON Reports**: Machine-readable results in `test_results/`
- **HTML Reports**: Human-readable reports with charts
- **Exit Codes**: 0 = success, 1 = failures detected

## Requirements

- PowerShell 5.1+ (same as main setup script)
- Internet connection (for network tests, unless skipped)
- Optional: WSL installation (for WSL tests)
- Optional: VS Code installation (for VS Code tests)

## Documentation

This README contains all the test documentation you need. For additional guidance on the StrangeLoop CLI setup, see the main repository README.md and the docs/ folder.
