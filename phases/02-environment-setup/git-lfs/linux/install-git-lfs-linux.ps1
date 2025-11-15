# strangeloop Setup - Git LFS Installation Module (Linux)
# Version: 3.0.0 - Simplified for Linux execution only

param(
    [switch]${check-only},
    [switch]${what-if}
)

# Import Linux script base and required modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "linux\linux-script-base.ps1")

function Test-GitLFSLinux {
    <#
    .SYNOPSIS
    Test Git LFS installation in Linux environment
    
    .DESCRIPTION
    Tests if Git LFS is properly installed and meets version requirements
    
    .PARAMETER Detailed
    Whether to show detailed compliance information
    #>
    param(
        [switch]$Detailed
    )
    
    return Test-LinuxToolVersion -ToolName "Git LFS" -VersionCommand "git lfs version" -VersionRegex "git-lfs/([0-9]+\.[0-9]+\.[0-9]+)" -Detailed:$Detailed
}

function Install-GitLFSLinux {
    <#
    .SYNOPSIS
    Install Git LFS in Linux environment
    
    .DESCRIPTION
    Installs Git LFS using apt package manager and initializes it
    #>
    
    # Initialize script
    if (-not (Initialize-LinuxScript -ScriptName "Git LFS Installation")) {
        return $false
    }
    
    # Handle what-if mode
    if (${what-if}) {
        Write-Host "what if: Would install Git LFS via apt package manager" -ForegroundColor Yellow
        Write-Host "what if: Would install git-lfs package" -ForegroundColor Yellow
        Write-Host "what if: Would initialize Git LFS globally" -ForegroundColor Yellow
        return $true
    }
    
    # Handle check-only mode
    if (${check-only}) {
        return Test-GitLFSLinux -Detailed
    }
    
    # Test if Git LFS is already installed and compliant
    if (Test-GitLFSLinux) {
        Write-Success "Git LFS is already installed and compliant"
        return $true
    }
    
    Write-Step "Installing Git LFS (Linux/WSL)..."
    
    try {
        # Install Git LFS using apt
        $installSuccess = Invoke-LinuxPackageInstall -Packages @("git-lfs") -UpdateFirst $true
        
        if (-not $installSuccess) {
            Write-Error "Git LFS installation failed"
            return $false
        }
        
        # Initialize Git LFS globally with hook conflict handling
        Write-Host "Initializing Git LFS..." -ForegroundColor Gray
        $initResult = & git lfs install 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            # Check if it's a hook conflict issue
            if ($initResult -match "Hook already exists") {
                Write-Info "Git LFS hook already exists, attempting to update..."
                # Try to update hooks with force to resolve conflicts
                $forceResult = & git lfs install --force 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Git LFS hooks updated successfully"
                } else {
                    Write-Warning "Git LFS hook update failed: $forceResult"
                    # Continue anyway as LFS might still work
                }
            } else {
                Write-Warning "Git LFS initialization had issues: $initResult"
            }
        } else {
            Write-Success "Git LFS initialized successfully"
        }
        
        Write-Success "Git LFS installed successfully"
        
        # Verify installation
        Start-Sleep -Seconds 2
        $verificationResult = Test-GitLFSLinux
        if ($verificationResult) {
            Write-Success "Git LFS installation completed successfully"
            
            # Show next steps
            Write-Host ""
            Write-Host "📋 Next Steps:" -ForegroundColor Cyan
            Write-Host "  • Git LFS is initialized globally for this user" -ForegroundColor Gray
            Write-Host "  • Use 'git lfs track \"*.large-file\"' to track large files" -ForegroundColor Gray
            Write-Host "  • Large files will be handled automatically on push/pull" -ForegroundColor Gray
            
            return $true
        } else {
            Write-Error "Git LFS installation verification failed"
            return $false
        }
        
    } catch {
        Write-Error "Failed to install Git LFS: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Install-GitLFSLinux
    if (-not $result) {
        exit 1
    }
}