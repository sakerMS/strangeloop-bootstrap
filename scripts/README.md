# Scripts Directory

This directory contains utility scripts that support the StrangeLoop CLI setup process.

## Files

### test_ubuntu_detection.ps1
A standalone Ubuntu detection testing script that validates the Ubuntu 24.04 detection logic used in the main setup script.

**Purpose**: Test and validate Ubuntu distribution detection across different WSL configurations.

**Usage**:
```powershell
.\scripts\test_ubuntu_detection.ps1
```

**Features**:
- Tests WSL status detection for default distribution
- Validates distribution list parsing
- Checks for Ubuntu 24.04, 22.04, 20.04, and generic Ubuntu
- Provides detailed output for debugging detection issues

**Integration**: The core logic from this script has been integrated into the main test suite (`tests/test_setup_strangeloop.ps1`) as the `Test-Ubuntu24Detection` function.

## Note

These scripts are part of the StrangeLoop CLI bootstrap process and support the main `setup_strangeloop.ps1` script functionality.
