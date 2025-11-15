# strangeloop Setup - Git LFS Installation Module (Windows)
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

function Test-GitLFSWindows {
    param(
        [switch]$Detailed
    )
    
    try {
        Write-Info "Testing Git LFS installation (Windows)..."
        
        # Check if Git LFS command is available
        try {
            $null = Get-Command "git-lfs" -ErrorAction Stop
            $versionOutput = git-lfs --version 2>&1
            if ($versionOutput -match "git-lfs/(\d+\.\d+\.\d+)") {
                $lfsVersion = $matches[1]
                Write-Success "Found Git LFS $lfsVersion in PATH"
                
                # Check version compliance
                $compliance = Test-ToolVersionCompliance -ToolName "git_lfs" -InstalledVersion $lfsVersion
                Write-VersionComplianceReport -ToolName "Git LFS" -ComplianceResult $compliance
                
                if (-not $compliance.IsCompliant) {
                    Write-Warning "Git LFS version $lfsVersion does not meet minimum requirements"
                    return $false
                }
                
                Write-Success "Git LFS is properly installed and compliant: $lfsVersion"
                return $true
            }
        } catch {
            Write-Warning "Git LFS command not found in PATH"
            return $false
        }
        
        Write-Warning "Git LFS command not found"
        return $false
        
    } catch {
        Write-Warning "Error testing Git LFS: $($_.Exception.Message)"
        return $false
    }
}

function Install-GitLFS {
    if (${what-if}) {
        Write-Host "what if: Would check for Git LFS installation" -ForegroundColor Yellow
        Write-Host "what if: Would install Git LFS using winget if not found" -ForegroundColor Yellow
        Write-Host "what if: Would initialize Git LFS after installation" -ForegroundColor Yellow
        return $true
    }
    
    if (${check-only}) {
        return Test-GitLFSWindows -Detailed
    }
    
    if (Test-GitLFSWindows) {
        Write-Success "Git LFS is already installed and working"
        return $true
    }
    
    return Install-GitLFSWindows
}

function Install-GitLFSWindows {
    Write-Step "Installing Git LFS (Windows)..."
    
    try {
        # Validate prerequisites before installation
        Write-Info "Validating installation prerequisites..."
        $prereqResult = Test-InstallationPrerequisites -RequireWinget $true -RequirePython $false
        
        if (-not $prereqResult.Success) {
            Write-Error "Prerequisites validation failed. Cannot proceed with Git LFS installation."
            return $false
        }
        
        # Install Git LFS using winget (reliable method)
        Write-Info "Installing Git LFS via winget..."
        Write-Info "This may take a few minutes. Please wait..."
        
        try {
            $wingetResult = winget install GitHub.GitLFS --accept-package-agreements --accept-source-agreements --silent 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Git LFS installed successfully via winget"
                if (Test-GitLFSAfterInstall) {
                    return $true
                }
            } else {
                Write-Error "winget installation failed with exit code: $LASTEXITCODE"
                Write-Info "winget output: $wingetResult"
            }
        } catch {
            Write-Error "winget installation failed: $($_.Exception.Message)"
        }

        Write-Error "Git LFS installation failed"
        Write-Info "Please install Git LFS manually using one of these methods:"
        Write-Info "  • winget install GitHub.GitLFS"
        Write-Info "  • Download from https://git-lfs.github.io/"
        return $false

    } catch {
        Write-Error "Failed to install Git LFS: $($_.Exception.Message)"
        return $false
    }
}

function Test-GitLFSAfterInstall {
    # Refresh PATH environment variable
    Write-Info "Refreshing PATH environment..."
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    # Wait for installation to complete
    Write-Info "Waiting for installation to complete..."
    Start-Sleep -Seconds 3
    
    # Test if Git LFS command is available
    if (Test-GitLFSWindows) {
        # Initialize Git LFS
        try {
            Write-Info "Initializing Git LFS..."
            git lfs install --skip-smudge 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Git LFS initialized successfully"
            } else {
                Write-Warning "Git LFS initialization may have failed, but installation succeeded"
            }
        } catch {
            Write-Warning "Git LFS initialization failed: $($_.Exception.Message)"
        }
        
        Write-Success "Git LFS installation completed successfully"
        return $true
    } else {
        Write-Warning "Git LFS installation completed but verification failed"
        Write-Info "Please restart your terminal and verify with: git lfs --version"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Install-GitLFS
    if (-not $result) {
        exit 1
    }
}

