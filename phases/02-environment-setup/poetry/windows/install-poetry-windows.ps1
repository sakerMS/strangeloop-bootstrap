# strangeloop Setup - Poetry Installation Module (Windows)
# Version: 1.3.0 - Simplified

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

function Test-PoetryWindows {
    param(
        [switch]$Detailed
    )
    
    try {
        Write-Info "Testing Poetry installation (Windows)..."
        
        # Simple PATH check using Get-Command
        try {
            $poetryCommand = Get-Command "poetry" -ErrorAction Stop
            $versionOutput = poetry --version 2>&1
            if ($versionOutput -match "Poetry.*?(\d+\.\d+\.\d+)") {
                $poetryVersion = $matches[1]
                Write-Success "Found Poetry $poetryVersion in PATH"
                
                # Check version compliance
                $compliance = Test-ToolVersionCompliance -ToolName "poetry" -InstalledVersion $poetryVersion
                Write-VersionComplianceReport -ToolName "Poetry" -ComplianceResult $compliance
                
                if (-not $compliance.IsCompliant) {
                    Write-Warning "Poetry version $poetryVersion does not meet minimum requirements"
                    return $false
                }
                
                Write-Success "Poetry is properly installed and compliant: $poetryVersion"
                return $true
            }
        } catch {
            Write-Warning "Poetry command not found in PATH"
            return $false
        }
        
        Write-Warning "Poetry command not found"
        return $false
        
    } catch {
        Write-Warning "Error testing Poetry: $($_.Exception.Message)"
        return $false
    }
}

function Install-Poetry {
    if (${what-if}) {
        Write-Host "what if: Would check for Poetry installation" -ForegroundColor Yellow
        Write-Host "what if: Would install Poetry using official installer if not found" -ForegroundColor Yellow
        Write-Host "what if: Would configure Poetry with recommended settings" -ForegroundColor Yellow
        return $true
    }
    
    if (${check-only}) {
        return Test-PoetryWindows -Detailed
    }
    
    if (Test-PoetryWindows) {
        Write-Success "Poetry is already installed and working"
        return $true
    }
    
    return Install-PoetryWindows
}

function Install-PoetryWindows {
    Write-Step "Installing Poetry (Windows)..."
    
    try {
        # Validate prerequisites before installation
        Write-Info "Validating installation prerequisites..."
        $prereqResult = Test-InstallationPrerequisites -RequireWinget $false -RequirePython $true
        
        if (-not $prereqResult.Success) {
            Write-Error "Prerequisites validation failed. Cannot proceed with Poetry installation."
            Write-Info "Poetry requires Python and pip to be installed first."
            return $false
        }
        
        # Install Poetry using pip (reliable method)
        Write-Info "Installing Poetry via pip..."
        try {
            $pipResult = pip install poetry 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Poetry installed successfully via pip"
                if (Test-PoetryAfterInstall) {
                    return $true
                }
            } else {
                Write-Error "pip installation failed with exit code: $LASTEXITCODE"
                Write-Info "pip output: $pipResult"
            }
        } catch {
            Write-Error "pip installation failed: $($_.Exception.Message)"
        }

        Write-Error "Poetry installation failed"
        Write-Info "Please install Poetry manually using one of these methods:"
        Write-Info "  • pip install poetry"
        Write-Info "  • Visit https://python-poetry.org/docs/#installation for official installer"
        return $false

    } catch {
        Write-Error "Failed to install Poetry: $($_.Exception.Message)"
        return $false
    }
}

function Test-PoetryAfterInstall {
    # Refresh PATH environment variable
    Write-Info "Refreshing PATH environment..."
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    # Wait for installation to complete
    Write-Info "Waiting for installation to complete..."
    Start-Sleep -Seconds 3
    
    if (Test-PoetryWindows) {
        Write-Success "Poetry installation completed successfully"
        
        # Configure Poetry with recommended settings
        try {
            & poetry config virtualenvs.create true 2>$null
            & poetry config virtualenvs.in-project true 2>$null
            Write-Info "Poetry configured with recommended settings"
        } catch {
            Write-Info "Poetry installed but configuration may need manual setup"
        }
        
        return $true
    } else {
        Write-Warning "Poetry installation completed but verification failed"
        Write-Info "Poetry may not have been added to PATH properly by the installer"
        Write-Info "Please restart your terminal and verify manually with: poetry --version"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Install-Poetry
    if (-not $result) {
        exit 1
    }
}
