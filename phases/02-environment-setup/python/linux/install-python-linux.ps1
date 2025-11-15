# strangeloop Setup - Python Installation Module (Linux/WSL)
# Version: 3.0.0 - Simplified for Linux/WSL execution only

param(
    [switch]${check-only},
    [switch]${what-if}
)

# Import Linux script base and required modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "linux\linux-script-base.ps1")

function Test-PythonLinux {
    <#
    .SYNOPSIS
    Test Python installation in Linux environment
    
    .DESCRIPTION
    Tests if Python 3 is properly installed and meets version requirements
    
    .PARAMETER Detailed
    Whether to show detailed compliance information
    #>
    param(
        [switch]$Detailed
    )
    
    return Test-LinuxToolVersion -ToolName "Python" -VersionCommand "python3 --version" -VersionRegex "Python ([0-9]+\.[0-9]+\.[0-9]+)" -Detailed:$Detailed
}

function Test-PipLinux {
    <#
    .SYNOPSIS
    Test pip installation in Linux environment
    
    .DESCRIPTION
    Tests if pip is available for Python 3
    #>
    
    try {
        Write-Info "Testing pip availability..."
        
        # Test pip via python3 -m pip
        $pipTest = python3 -m pip --version 2>$null
        
        if (-not $pipTest) {
            Write-Warning "pip not found"
            return $false
        }
        
        Write-Success "pip is available: $pipTest"
        return $true
        
    } catch {
        Write-Warning "Error testing pip: $($_.Exception.Message)"
        return $false
    }
}

function Install-PipLinux {
    <#
    .SYNOPSIS
    Install pip for Python in Linux environment
    
    .DESCRIPTION
    Installs pip using various methods (apt packages or ensurepip)
    #>
    
    try {
        Write-Info "Installing pip for Python..."
        
        # Try installing python3-pip via apt first
        Write-Info "Attempting to install python3-pip via apt..."
        $pipInstallResult = Invoke-LinuxPackageInstall -Packages @("python3-pip") -UpdateFirst $false
        
        if (-not $pipInstallResult) {
            Write-Warning "python3-pip package not available via apt, trying python3-full package..."
            
            # Fallback: Try installing python3-full which includes pip in newer Ubuntu versions
            $fullInstallResult = Invoke-LinuxPackageInstall -Packages @("python3-full") -UpdateFirst $false
            
            if (-not $fullInstallResult) {
                Write-Info "Trying to install pip via ensurepip..."
                
                # Final fallback: try using ensurepip if available
                $ensurepipResult = python3 -m ensurepip --default-pip --user 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "All pip installation methods failed. Python will work but pip may not be available."
                    return $false
                }
            }
        }
        
        # Upgrade pip to latest version
        Write-Info "Upgrading pip to latest version..."
        $pipUpgradeResult = python3 -m pip install --user --upgrade pip 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "pip upgrade failed: $pipUpgradeResult"
        }
        
        # Verify pip installation
        Start-Sleep -Seconds 2
        if (Test-PipLinux) {
            Write-Success "pip installed and configured successfully"
            return $true
        } else {
            Write-Warning "pip installation verification failed"
            return $false
        }
        
    } catch {
        Write-Warning "Error installing pip: $($_.Exception.Message)"
        return $false
    }
}

function Install-PythonLinux {
    <#
    .SYNOPSIS
    Install Python in Linux environment
    
    .DESCRIPTION
    Installs Python 3 and related packages using apt package manager
    #>
    
    # Initialize script
    if (-not (Initialize-LinuxScript -ScriptName "Python Installation")) {
        return $false
    }
    
    # Handle what-if mode
    if (${what-if}) {
        Write-Host "what if: Would install Python 3 via apt package manager" -ForegroundColor Yellow
        Write-Host "what if: Would install python3, python3-full, python3-venv, python3-dev packages" -ForegroundColor Yellow
        Write-Host "what if: Would create python symlink" -ForegroundColor Yellow
        Write-Host "what if: Would install and upgrade pip" -ForegroundColor Yellow
        return $true
    }
    
    # Handle check-only mode
    if (${check-only}) {
        $testResult = Test-PythonLinux -Detailed
        if ($testResult) {
            # Test pip but don't fail if it's missing in check-only mode
            $pipResult = Test-PipLinux
            if (-not $pipResult) {
                Write-Info "Python is installed but pip needs to be configured"
            }
        }
        return $testResult
    }
    
    # Test if Python is already installed and compliant
    if (Test-PythonLinux) {
        Write-Success "Python is already installed and compliant"
        
        # Check and install pip if needed
        if (-not (Test-PipLinux)) {
            Write-Info "Installing pip for existing Python installation..."
            Install-PipLinux | Out-Null
        }
        
        return $true
    }
    
    Write-Step "Installing Python (Linux/WSL)..."
    
    try {
        # Install Python packages using apt
        Write-Info "Installing Python packages via apt..."
        $pythonPackages = @("python3", "python3-full", "python3-venv", "python3-dev")
        $installSuccess = Invoke-LinuxPackageInstall -Packages $pythonPackages -UpdateFirst $true
        
        if (-not $installSuccess) {
            Write-Error "Python installation failed"
            return $false
        }
        
        # Create python symlink if it doesn't exist
        Write-Info "Setting up Python symlink..."
        $symlinkResult = Invoke-SudoCommand -Command "bash -c 'if [ ! -f /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi'"
        
        if (-not $symlinkResult.Success) {
            Write-Warning "Could not create python symlink: $($symlinkResult.Output)"
        } else {
            Write-Success "Python symlink created"
        }
        
        Write-Success "Python installed successfully"
        
        # Install pip
        Write-Info "Installing pip..."
        if (Install-PipLinux) {
            Write-Success "pip installation completed"
        } else {
            Write-Warning "pip installation had issues, but Python is functional"
        }
        
        # Verify installation
        Start-Sleep -Seconds 2
        $verificationResult = Test-PythonLinux
        if ($verificationResult) {
            Write-Success "Python installation completed successfully"
            
            # Show next steps
            Write-Host ""
            Write-Host "📋 Next Steps:" -ForegroundColor Cyan
            Write-Host "  • Python 3 is available as 'python3' and 'python'" -ForegroundColor Gray
            Write-Host "  • pip is available via 'python3 -m pip'" -ForegroundColor Gray
            Write-Host "  • Use 'python3 -m venv' to create virtual environments" -ForegroundColor Gray
            
            return $true
        } else {
            Write-Error "Python installation verification failed"
            return $false
        }
        
    } catch {
        Write-Error "Failed to install Python: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Install-PythonLinux
    if (-not $result) {
        exit 1
    }
}
