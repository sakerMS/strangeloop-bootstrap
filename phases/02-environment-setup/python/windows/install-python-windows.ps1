# strangeloop Setup - Python Installation Module (Windows)
# Version: 2.0.0 - Simplified

param(
    [switch]${check-only},
    [switch]${what-if}
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "version\version-functions.ps1")

function Test-PythonWindows {
    param(
        [switch]$Detailed
    )
    
    try {
        Write-Info "Testing Python installation (Windows)..."
        
        # Check if Python command is available (skip MS Store alias)
        try {
            $pythonCommand = Get-Command "python" -ErrorAction Stop
            if ($pythonCommand.Source -like "*WindowsApps*") {
                Write-Warning "Found Windows Store Python alias, not a real installation"
                return $false
            }
            
            $versionOutput = python --version 2>&1
            if ($versionOutput -match "Python (\d+\.\d+\.\d+)") {
                $pythonVersion = $matches[1]
                Write-Success "Found Python $pythonVersion in PATH"
                
                # Check version compliance
                $compliance = Test-ToolVersionCompliance -ToolName "python" -InstalledVersion $pythonVersion
                Write-VersionComplianceReport -ToolName "Python" -ComplianceResult $compliance
                
                if (-not $compliance.IsCompliant) {
                    Write-Warning "Python version $pythonVersion does not meet minimum requirements"
                    return $false
                }
                
                # Verify pip is available
                $null = python -m pip --version 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "pip is not available or not working"
                    return $false
                }
                
                Write-Success "Python is properly installed and compliant: $pythonVersion"
                return $true
            }
        } catch {
            Write-Warning "Python command not found in PATH"
            return $false
        }
        
        Write-Warning "Python command not found"
        return $false
        
    } catch {
        Write-Warning "Error testing Python: $($_.Exception.Message)"
        return $false
    }
}

function Install-Python {
    if (${what-if}) {
        Write-Host "what if: Would check for Python installation" -ForegroundColor Yellow
        Write-Host "what if: Would install Python 3.12 using winget if not found" -ForegroundColor Yellow
        return $true
    }
    
    if (${check-only}) {
        return Test-PythonWindows -Detailed
    }
    
    if (Test-PythonWindows) {
        Write-Success "Python is already installed and working"
        return $true
    }
    
    return Install-PythonWindows
}

function Install-PythonWindows {
    Write-Step "Installing Python (Windows)..."
    
    try {
        # Validate prerequisites before installation
        Write-Info "Validating installation prerequisites..."
        $prereqResult = Test-InstallationPrerequisites -RequireWinget $true -RequirePython $false
        
        if (-not $prereqResult.Success) {
            Write-Error "Prerequisites validation failed. Cannot proceed with Python installation."
            return $false
        }
        
        # Install Python using winget (reliable method)
        Write-Info "Installing Python 3.12 via winget..."
        Write-Info "This may take several minutes. Please wait..."
        
        try {
            $wingetResult = winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements --silent 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Python installed successfully via winget"
                if (Test-PythonAfterInstall) {
                    return $true
                }
            } elseif ($LASTEXITCODE -eq -1978335189) {
                Write-Info "Python may already be installed (winget indicates existing installation)"
                if (Test-PythonAfterInstall) {
                    return $true
                }
            } else {
                Write-Error "winget installation failed with exit code: $LASTEXITCODE"
                Write-Info "winget output: $wingetResult"
            }
        } catch {
            Write-Error "winget installation failed: $($_.Exception.Message)"
        }

        Write-Error "Python installation failed"
        Write-Info "Please install Python manually using one of these methods:"
        Write-Info "  • winget install Python.Python.3.12"
        Write-Info "  • Download from https://www.python.org/downloads/"
        return $false

    } catch {
        Write-Error "Failed to install Python: $($_.Exception.Message)"
        return $false
    }
}

function Test-PythonAfterInstall {
    # Refresh PATH environment variable
    Write-Info "Refreshing PATH environment..."
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    # Wait for installation to complete
    Write-Info "Waiting for installation to complete..."
    Start-Sleep -Seconds 5
    
    # Test if Python command is available
    if (Test-PythonWindows) {
        Write-Success "Python installation completed successfully"
        return $true
    } else {
        Write-Warning "Python installation completed but verification failed"
        Write-Info "Please restart your terminal and verify with: python --version"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Install-Python
    if (-not $result) {
        exit 1
    }
}
