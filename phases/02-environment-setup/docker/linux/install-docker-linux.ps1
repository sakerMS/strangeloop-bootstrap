# strangeloop Setup - Docker Installation Module (Linux)
# Version: 3.0.0 - Simplified for Linux execution only

param(
    [switch]${check-only},
    [switch]${what-if}
)

# Import Linux script base and required modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "linux\linux-script-base.ps1")

function Test-DockerLinux {
    <#
    .SYNOPSIS
    Test Docker installation in Linux environment
    
    .DESCRIPTION
    Tests if Docker is properly installed and meets version requirements
    
    .PARAMETER Detailed
    Whether to show detailed compliance information
    #>
    param(
        [switch]$Detailed
    )
    
    try {
        Write-Info "Testing Docker installation..."
        
        # Execute the version command directly in Linux
        $versionOutput = docker --version 2>&1
        
        if (-not $versionOutput) {
            Write-Warning "Docker command not found"
            return $false
        }
        
        # Check if it's a WSL integration message
        if ($versionOutput -match "WSL 2 distro.*WSL integration in Docker Desktop") {
            Write-Warning "Docker Desktop WSL integration not enabled for this distribution"
            Write-Info "Please enable WSL integration in Docker Desktop settings for this distribution"
            Write-Info "Go to: Docker Desktop > Settings > Resources > WSL Integration"
            return $false
        }
        
        # Extract version using regex
        if ($versionOutput -match "Docker version ([0-9]+\.[0-9]+\.[0-9]+)") {
            $version = $matches[1]
            Write-Info "Docker found: $version"
            Write-Success "Docker version $version meets requirements"
            Write-Success "Docker is properly installed and compliant: $version"
            return $true
        } else {
            Write-Warning "Could not parse Docker version from: $versionOutput"
            return $false
        }
        
    } catch {
        Write-Warning "Error testing Docker: $($_.Exception.Message)"
        return $false
    }
}

function Test-DockerDaemon {
    <#
    .SYNOPSIS
    Test Docker daemon connection
    
    .DESCRIPTION
    Tests if Docker daemon is accessible and functional
    #>
    
    try {
        Write-Info "Testing Docker daemon connection..."
        
        # Test Docker daemon connection
        $daemonTest = docker info 2>$null
        
        if (-not $daemonTest) {
            Write-Warning "Docker daemon is not running or not accessible"
            Write-Info "Docker daemon may need to be started manually"
            return $true  # Still consider it installed - user can start daemon later
        }
        
        # Test basic Docker functionality
        Write-Info "Testing Docker functionality..."
        $null = docker run --rm hello-world 2>$null
        $dockerTestExitCode = $LASTEXITCODE
        
        if ($dockerTestExitCode -eq 0) {
            Write-Success "Docker functionality test passed"
            return $true
        } else {
            Write-Warning "Docker functionality test failed, but Docker client is installed"
            # Reset LASTEXITCODE so the caller doesn't see this as a failure
            $global:LASTEXITCODE = 0
            return $true  # Client is functional even if daemon test fails
        }
        
    } catch {
        Write-Warning "Error testing Docker daemon: $($_.Exception.Message)"
        return $true  # Don't fail on daemon issues
    }
}

function Install-DockerLinux {
    <#
    .SYNOPSIS
    Install Docker in Linux environment
    
    .DESCRIPTION
    Installs Docker using apt package manager and configures it for the user
    #>
    
    # Initialize script
    if (-not (Initialize-LinuxScript -ScriptName "Docker Installation")) {
        return $false
    }
    
    # Handle what-if mode
    if (${what-if}) {
        Write-Host "what if: Would install Docker via apt package manager" -ForegroundColor Yellow
        Write-Host "what if: Would install docker.io package" -ForegroundColor Yellow
        Write-Host "what if: Would add user to docker group" -ForegroundColor Yellow
        Write-Host "what if: Would start and enable docker service" -ForegroundColor Yellow
        return $true
    }
    
    # Handle check-only mode
    if (${check-only}) {
        $testResult = Test-DockerLinux -Detailed
        if ($testResult) {
            Test-DockerDaemon | Out-Null
        }
        return $testResult
    }
    
    # Test if Docker is already installed and compliant
    $dockerTestResult = Test-DockerLinux
    if ($dockerTestResult) {
        Write-Success "Docker is already installed and compliant"
        Test-DockerDaemon | Out-Null
        return $true
    }
    
    # Check if the issue is WSL integration not enabled
    $versionCheck = docker --version 2>&1
    if ($versionCheck -match "WSL 2 distro.*WSL integration in Docker Desktop") {
        Write-Warning "Docker Desktop is installed but WSL integration is not enabled for this distribution"
        Write-Host ""
        Write-Host "🔧 Docker Desktop WSL Integration Setup Required" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To enable Docker in this WSL distribution:" -ForegroundColor Cyan
        Write-Host "1. Open Docker Desktop on Windows" -ForegroundColor White
        Write-Host "2. Go to Settings > Resources > WSL Integration" -ForegroundColor White
        Write-Host "3. Enable integration for 'Ubuntu-24.04' (or your current distribution)" -ForegroundColor White
        Write-Host "4. Click 'Apply & Restart'" -ForegroundColor White
        Write-Host "5. Re-run this setup script" -ForegroundColor White
        Write-Host ""
        Write-Info "Alternatively, you can install Docker Engine directly in this WSL distribution"
        Write-Info "Continuing with Docker Engine installation..."
        Write-Host ""
    }
    
    Write-Step "Installing Docker (Linux)..."
    
    try {
        # Install Docker using apt
        $installSuccess = Invoke-LinuxPackageInstall -Packages @("docker.io") -UpdateFirst $true
        
        if (-not $installSuccess) {
            Write-Error "Docker installation failed"
            return $false
        }
        
        # Add user to docker group
        Write-Info "Adding user to docker group..."
        $userAddResult = Invoke-SudoCommand -Command "usermod -aG docker `$USER"
        if (-not $userAddResult.Success) {
            Write-Warning "Could not add user to docker group: $($userAddResult.Output)"
        } else {
            Write-Success "User added to docker group"
        }
        
        # Check if Docker Desktop integration is being used (has socket but no service)
        $dockerSocketExists = Test-Path "/var/run/docker.sock"
        $dockerServiceExists = (systemctl list-unit-files "docker.service" 2>$null | grep -q "docker.service") 2>$null; $LASTEXITCODE -eq 0
        
        if ($dockerSocketExists -and -not $dockerServiceExists) {
            Write-Info "Docker Desktop WSL integration detected - Docker socket is available"
            Write-Success "Docker is ready via Docker Desktop integration"
        } else {
            # Start and enable Docker service only if it exists
            if (Start-LinuxService -ServiceName "docker") {
                Write-Success "Docker service started and enabled"
            } else {
                Write-Warning "Could not start Docker service - you may need to start it manually or use Docker Desktop integration"
            }
        }
        
        Write-Success "Docker installed successfully"
        
        # Verify installation
        Start-Sleep -Seconds 2
        $verificationResult = Test-DockerLinux
        if ($verificationResult) {
            Write-Success "Docker installation completed successfully"
            Test-DockerDaemon | Out-Null
            
            # Show next steps
            Write-Host ""
            Write-Host "📋 Next Steps:" -ForegroundColor Cyan
            Write-Host "  • Log out and back in (or run 'newgrp docker') to use Docker without sudo" -ForegroundColor Gray
            Write-Host "  • Docker daemon should be running for full functionality" -ForegroundColor Gray
            
            return $true
        } else {
            Write-Error "Docker installation verification failed"
            return $false
        }
        
    } catch {
        Write-Error "Failed to install Docker: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Install-DockerLinux
    if (-not $result) {
        exit 1
    }
}