# strangeloop Setup - Git Installation Module (Windows)
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

function Test-GitWindows {
    param(
        [switch]$Detailed
    )
    
    try {
        Write-Info "Testing Git installation (Windows)..."
        
        # Simple PATH check using Get-Command
        try {
            $null = Get-Command "git" -ErrorAction Stop
            $versionOutput = git --version 2>&1
            if ($versionOutput -match "git version (\d+\.\d+\.\d+)") {
                $gitVersion = $matches[1]
                Write-Success "Found Git $gitVersion in PATH"
                
                # Check version compliance
                $compliance = Test-ToolVersionCompliance -ToolName "git" -InstalledVersion $gitVersion
                Write-VersionComplianceReport -ToolName "Git" -ComplianceResult $compliance
                
                if (-not $compliance.IsCompliant) {
                    Write-Warning "Git version $gitVersion does not meet minimum requirements"
                    return $false
                }
                
                Write-Success "Git is properly installed and compliant: $gitVersion"
                return $true
            }
        } catch {
            Write-Warning "Git command not found in PATH"
            return $false
        }
        
        Write-Warning "Git command not found"
        return $false
        
    } catch {
        Write-Warning "Error testing Git: $($_.Exception.Message)"
        return $false
    }
}

function Install-Git {
    if (${what-if}) {
        Write-Host "what if: Would check for Git installation" -ForegroundColor Yellow
        Write-Host "what if: Would install Git using winget if not found" -ForegroundColor Yellow
        return $true
    }
    
    if (${check-only}) {
        return Test-GitWindows -Detailed
    }
    
    if (Test-GitWindows) {
        Write-Success "Git is already installed and working"
        return $true
    }
    
    return Install-GitWindows
}

function Install-GitWindows {
    Write-Step "Installing Git (Windows)..."
    
    try {
        # Validate prerequisites before installation
        Write-Info "Validating installation prerequisites..."
        $prereqResult = Test-InstallationPrerequisites -RequireWinget $true -RequirePython $false
        
        if (-not $prereqResult.Success) {
            Write-Error "Prerequisites validation failed. Cannot proceed with Git installation."
            return $false
        }
        
        # Install Git using winget (reliable method)
        Write-Info "Installing Git via winget..."
        try {
            $wingetResult = winget install Git.Git --silent 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Git installed successfully via winget"
                if (Test-GitAfterInstall) {
                    return $true
                }
            } else {
                Write-Error "winget installation failed with exit code: $LASTEXITCODE"
                Write-Info "winget output: $wingetResult"
            }
        } catch {
            Write-Error "winget installation failed: $($_.Exception.Message)"
        }

        Write-Error "Git installation failed"
        Write-Info "Please install Git manually using one of these methods:"
        Write-Info "  • winget install Git.Git"
        Write-Info "  • Download from https://git-scm.com/download/win"
        return $false

    } catch {
        Write-Error "Failed to install Git: $($_.Exception.Message)"
        return $false
    }
}

function Test-GitAfterInstall {
    # Refresh PATH environment variable
    Write-Info "Refreshing PATH environment..."
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    # Wait for installation to complete
    Write-Info "Waiting for installation to complete..."
    Start-Sleep -Seconds 3
    
    if (Test-GitWindows) {
        Write-Success "Git installation completed successfully"
        return $true
    } else {
        Write-Warning "Git installation completed but verification failed"
        Write-Info "Git may not have been added to PATH properly by the installer"
        Write-Info "Please restart your terminal and verify manually with: git --version"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Install-Git
    if (-not $result) {
        exit 1
    }
}