# strangeloop Setup - Docker Installation Module (Windows)
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

function Test-DockerWindows {
    param(
        [switch]$Detailed
    )
    
    try {
        Write-Info "Testing Docker installation (Windows)..."
        
        # Check if Docker command is available
        try {
            $null = Get-Command "docker" -ErrorAction Stop
            $versionOutput = docker --version 2>&1
            if ($versionOutput -match "Docker version (\d+\.\d+\.\d+)") {
                $dockerVersion = $matches[1]
                Write-Success "Found Docker $dockerVersion in PATH"
                
                # Check version compliance
                $compliance = Test-ToolVersionCompliance -ToolName "docker" -InstalledVersion $dockerVersion
                Write-VersionComplianceReport -ToolName "Docker" -ComplianceResult $compliance
                
                if (-not $compliance.IsCompliant) {
                    Write-Warning "Docker version $dockerVersion does not meet minimum requirements"
                    return $false
                }
                
                # Test Docker daemon connection
                try {
                    Write-Info "Testing Docker daemon connection..."
                    $null = docker info 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Docker daemon is running and accessible"
                        Write-Success "Docker is properly installed and running: $dockerVersion"
                        return $true
                    } else {
                        Write-Warning "Docker daemon is not running or not accessible"
                        Write-Info "Attempting to start Docker Desktop..."
                        return Start-DockerDesktop
                    }
                } catch {
                    Write-Warning "Cannot connect to Docker daemon"
                    Write-Info "Attempting to start Docker Desktop..."
                    return Start-DockerDesktop
                }
            }
        } catch {
            Write-Warning "Docker command not found in PATH"
            return $false
        }
        
        Write-Warning "Docker command not found"
        return $false
        
    } catch {
        Write-Warning "Error testing Docker: $($_.Exception.Message)"
        return $false
    }
}

function Start-DockerDesktop {
    try {
        $dockerDesktopPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
        if (-not (Test-Path $dockerDesktopPath)) {
            Write-Warning "Docker Desktop executable not found at: $dockerDesktopPath"
            return $false
        }
        
        Write-Info "Starting Docker Desktop..."
        Start-Process $dockerDesktopPath -WindowStyle Hidden
        Write-Info "Docker Desktop startup initiated. Waiting for daemon to start..."
        
        # Wait for Docker daemon to start with proper verification
        $timeout = 120  # 2 minutes timeout
        $elapsed = 0
        $interval = 5
        $daemonReady = $false
        
        while ($elapsed -lt $timeout) {
            Start-Sleep -Seconds $interval
            $elapsed += $interval
            
            Write-Info "Checking Docker daemon status... ($elapsed/$timeout seconds)"
            
            try {
                $null = docker info 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Docker daemon started successfully"
                    
                    # Verify functionality with hello-world test
                    Write-Info "Verifying Docker functionality..."
                    $null = docker run --rm hello-world 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Docker functionality test passed"
                        $daemonReady = $true
                        break
                    } else {
                        Write-Info "Docker daemon running but functionality test failed. Continuing to wait..."
                    }
                }
            } catch {
                # Continue waiting
            }
            
            if ($elapsed -lt $timeout) {
                Write-Info "Docker daemon not ready yet. Waiting $interval more seconds..."
            }
        }
        
        if ($daemonReady) {
            Write-Success "Docker is fully functional"
            return $true
        } else {
            Write-Warning "Docker daemon did not start properly within $timeout seconds"
            Write-Info "Docker Desktop may still be starting. Please wait a few more minutes."
            return $false
        }
        
    } catch {
        Write-Warning "Failed to start Docker Desktop: $($_.Exception.Message)"
        return $false
    }
}

function Install-Docker {
    if (${what-if}) {
        Write-Host "what if: Would check for Docker installation" -ForegroundColor Yellow
        Write-Host "what if: Would install Docker Desktop using winget if not found" -ForegroundColor Yellow
        return $true
    }
    
    if (${check-only}) {
        return Test-DockerWindows -Detailed
    }
    
    if (Test-DockerWindows) {
        Write-Success "Docker is already installed and working"
        return $true
    }
    
    return Install-DockerWindows
}

function Install-DockerWindows {
    Write-Step "Installing Docker Desktop (Windows)..."
    
    try {
        # Validate prerequisites before installation
        Write-Info "Validating installation prerequisites..."
        $prereqResult = Test-InstallationPrerequisites -RequireWinget $true -RequirePython $false
        
        if (-not $prereqResult.Success) {
            Write-Error "Prerequisites validation failed. Cannot proceed with Docker installation."
            return $false
        }
        
        # Install Docker Desktop using winget (reliable method)
        Write-Info "Installing Docker Desktop via winget..."
        Write-Info "This may take several minutes. Please wait..."
        
        try {
            $wingetResult = winget install Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Docker Desktop installed successfully via winget"
                if (Test-DockerAfterInstall) {
                    return $true
                }
            } else {
                Write-Error "winget installation failed with exit code: $LASTEXITCODE"
                Write-Info "winget output: $wingetResult"
            }
        } catch {
            Write-Error "winget installation failed: $($_.Exception.Message)"
        }

        Write-Error "Docker Desktop installation failed"
        Write-Info "Please install Docker Desktop manually using one of these methods:"
        Write-Info "  • winget install Docker.DockerDesktop"
        Write-Info "  • Download from https://www.docker.com/products/docker-desktop/"
        return $false

    } catch {
        Write-Error "Failed to install Docker Desktop: $($_.Exception.Message)"
        return $false
    }
}

function Test-DockerAfterInstall {
    # Refresh PATH environment variable
    Write-Info "Refreshing PATH environment..."
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    # Wait for installation to complete
    Write-Info "Waiting for installation to complete..."
    Start-Sleep -Seconds 5
    
    # Test if Docker command is available first
    try {
        $null = Get-Command "docker" -ErrorAction Stop
        Write-Success "Docker command is available in PATH"
    } catch {
        Write-Warning "Docker command not found in PATH after installation"
        return $false
    }
    
    # Now test if Docker daemon is running, and start it if needed
    Write-Info "Testing Docker daemon connection..."
    $null = docker info 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker daemon is already running"
        return $true
    } else {
        Write-Info "Docker daemon is not running. Starting Docker Desktop..."
        return Start-DockerDesktop
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Install-Docker
    if (-not $result) {
        exit 1
    }
}