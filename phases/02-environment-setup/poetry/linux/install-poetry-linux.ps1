# strangeloop Setup - Poetry Installation Module (Linux)
# Version: 3.0.0 - Simplified for Linux execution only

param(
    [switch]${check-only},
    [switch]${what-if},
    [switch]$WSLMode
)

# Import Linux script base and required modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "linux\linux-script-base.ps1")

function Test-PoetryLinux {
    <#
    .SYNOPSIS
    Test Poetry installation in Linux environment
    
    .DESCRIPTION
    Tests if Poetry is properly installed and meets version requirements
    
    .PARAMETER Detailed
    Whether to show detailed compliance information
    
    .PARAMETER Quiet
    Whether to suppress warning messages for missing tools
    #>
    param(
        [switch]$Detailed,
        [switch]$Quiet
    )
    
    try {
        # Try multiple ways to find and test Poetry
        $versionOutput = $null
        $poetryFound = $false
        
        # Method 1: Try poetry command in PATH
        if (-not $poetryFound) {
            try {
                $versionOutput = poetry --version 2>$null
                if ($versionOutput) {
                    $poetryFound = $true
                }
            } catch {
                # Poetry not in PATH, continue to next method
            }
        }
        
        # Method 2: Try direct pipx binary location
        if (-not $poetryFound) {
            try {
                $pipxPoetryPath = "$env:HOME/.local/share/pipx/venvs/poetry/bin/poetry"
                if (Test-Path $pipxPoetryPath) {
                    $versionOutput = & $pipxPoetryPath --version 2>$null
                    if ($versionOutput) {
                        $poetryFound = $true
                    }
                }
            } catch {
                # Direct path failed, continue to next method
            }
        }
        
        # Method 3: Try symlink location
        if (-not $poetryFound) {
            try {
                $binPoetryPath = "$env:HOME/.local/bin/poetry"
                if (Test-Path $binPoetryPath) {
                    $versionOutput = & $binPoetryPath --version 2>$null
                    if ($versionOutput) {
                        $poetryFound = $true
                    }
                }
            } catch {
                # Symlink failed
            }
        }
        
        if (-not $poetryFound -or -not $versionOutput) {
            if (-not $Quiet) {
                Write-Warning "Poetry command not found or not working"
            }
            return $false
        }
        
        # Extract version
        if ($versionOutput -match "Poetry.*?([0-9]+\.[0-9]+\.[0-9]+)") {
            $version = $matches[1]
            if ($Detailed -or -not $Quiet) {
                Write-Info "Poetry found: $version"
                Write-Success "Poetry version $version meets requirements"
                Write-Success "Poetry is properly installed and compliant: $version"
            }
            return $true
        } else {
            if (-not $Quiet) {
                Write-Warning "Could not parse Poetry version from: $versionOutput"
            }
            return $false
        }
        
    } catch {
        if (-not $Quiet) {
            Write-Warning "Error testing Poetry: $($_.Exception.Message)"
        }
        return $false
    }
}

function Install-PoetryLinux {
    <#
    .SYNOPSIS
    Install Poetry in Linux environment
    
    .DESCRIPTION
    Installs Poetry using pipx for isolated installation
    #>
    
    # Initialize script
    if (-not (Initialize-LinuxScript -ScriptName "Poetry Installation")) {
        return $false
    }
    
    # Handle what-if mode
    if (${what-if}) {
        Write-Host "what if: Would install pipx via apt package manager" -ForegroundColor Yellow
        Write-Host "what if: Would install poetry via pipx" -ForegroundColor Yellow
        Write-Host "what if: Would add poetry to PATH" -ForegroundColor Yellow
        return $true
    }
    
    # Handle check-only mode
    if (${check-only}) {
        return Test-PoetryLinux -Detailed
    }
    
    # Test if Poetry is already installed and compliant (quietly, without warnings)
    if (Test-PoetryLinux -Quiet) {
        # If found quietly, run detailed test to show proper messages
        Test-PoetryLinux -Detailed | Out-Null
        Write-Success "Poetry is already installed and compliant"
        return $true
    }
    
    Write-Step "Installing Poetry (Linux/WSL)..."
    
    try {
        # Check if we're in WSL mode called from Windows
        if ($WSLMode) {
            Write-Info "WSL mode detected - checking for pipx availability..."
            
            # In WSL mode, try to use pipx if available, otherwise use pip install --user
            if (Get-Command pipx -ErrorAction SilentlyContinue) {
                Write-Info "pipx is available, using for Poetry installation..."
                $installMethod = "pipx"
            } else {
                Write-Info "pipx not available, using pip install --user method..."
                $installMethod = "pip"
            }
        } else {
            # Direct Linux execution - install pipx via package manager
            Write-Step "Installing pipx..."
            $pipxInstallSuccess = Invoke-LinuxPackageInstall -Packages @("pipx") -UpdateFirst $false
            
            if (-not $pipxInstallSuccess) {
                Write-Error "pipx installation failed"
                return $false
            }
            $installMethod = "pipx"
        }
        
        if ($installMethod -eq "pipx") {
            # Ensure pipx path is available
            Write-Host "Ensuring pipx path is configured..." -ForegroundColor Gray
            & pipx ensurepath 2>&1 | Out-Null
            
            # Install Poetry via pipx
            Write-Step "Installing Poetry via pipx..."
            $poetryInstallResult = & pipx install poetry 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Poetry installation via pipx failed: $poetryInstallResult"
                return $false
            }
            
            Write-Success "Poetry installed successfully via pipx"
            
            # Immediately add pipx binary path to current session
            $pipxBinPath = "$env:HOME/.local/bin"
            if ($env:PATH -notlike "*$pipxBinPath*") {
                $env:PATH = "$pipxBinPath" + ":" + "$env:PATH"
            }
        } else {
            # Install Poetry via pip install --user (no sudo required)
            Write-Step "Installing Poetry via pip install --user..."
            $poetryInstallResult = & python3 -m pip install --user poetry 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Poetry installation via pip failed: $poetryInstallResult"
                return $false
            }
            
            Write-Success "Poetry installed successfully via pip install --user"
            
            # Add pip user binary path to current session
            $pipUserBinPath = "$env:HOME/.local/bin"
            if ($env:PATH -notlike "*$pipUserBinPath*") {
                $env:PATH = "$pipUserBinPath" + ":" + "$env:PATH"
            }
        }
        
        # Ensure Poetry is in PATH for verification (PATH was already updated during installation)
        # No additional PATH changes needed here
        
        # Verify installation with detailed output
        Start-Sleep -Seconds 2
        $verificationResult = Test-PoetryLinux -Detailed
        if ($verificationResult) {
            Write-Success "Poetry installation completed successfully"
            
            # Show next steps
            Write-Host ""
            Write-Host "📋 Next Steps:" -ForegroundColor Cyan
            Write-Host "  • Poetry is installed and ready to use" -ForegroundColor Gray
            Write-Host "  • Use 'poetry new project-name' to create new projects" -ForegroundColor Gray
            Write-Host "  • Use 'poetry init' in existing projects" -ForegroundColor Gray
            Write-Host "  • PATH updated for current session" -ForegroundColor Gray
            
            return $true
        } else {
            Write-Error "Poetry installation verification failed"
            return $false
        }
        
    } catch {
        Write-Error "Failed to install Poetry: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Install-PoetryLinux
    if (-not $result) {
        exit 1
    }
}