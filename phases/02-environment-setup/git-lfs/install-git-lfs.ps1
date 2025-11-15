# strangeloop Setup - Git LFS Installation Router
# Version: 2.0.0
# Routes to platform-specific Git LFS installation implementation

param(
    [switch]${check-only},
    [switch]${what-if},
    [switch]$WSLMode = $false
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")

try {
    Write-Info "Git LFS Installation Router - detecting platform..."
    
    # Detect current platform
    $currentPlatform = Get-CurrentPlatform
    $platformIsWindows = $currentPlatform -eq "Windows"
    $platformIsWSL = $currentPlatform -eq "WSL" 
    $platformIsLinux = $currentPlatform -eq "Linux"
    
    Write-Info "Detected platform: $currentPlatform"
    
    # Override platform detection if WSLMode is explicitly set
    if ($WSLMode -and $platformIsWindows) {
        Write-Info "WSLMode override: routing to Linux implementation from Windows"
        $platformIsLinux = $true
        $platformIsWindows = $false
    }
    
    # Route to appropriate platform-specific script
    if ($platformIsWindows) {
        $targetScript = Join-Path $PSScriptRoot "windows\install-git-lfs-windows.ps1"
        Write-Info "Routing to Windows Git LFS installation"
    } elseif ($platformIsWSL -or $platformIsLinux) {
        $targetScript = Join-Path $PSScriptRoot "linux\install-git-lfs-linux.ps1"
        Write-Info "Routing to Linux Git LFS installation"
    } else {
        Write-Error "Unsupported platform: $currentPlatform"
        exit 1
    }
    
    # Verify target script exists
    if (-not (Test-Path $targetScript)) {
        Write-Error "Platform-specific script not found: $targetScript"
        exit 1
    }
    
    # Build parameters to forward
    $forwardParams = @{}
    if (${check-only}) { $forwardParams['check-only'] = $true }
    if (${what-if}) { $forwardParams['what-if'] = $true }
    
    # Forward WSLMode parameter when routing from Windows to Linux
    if ($WSLMode -or ($platformIsWindows -and ($platformIsWSL -or $platformIsLinux))) {
        $forwardParams['WSLMode'] = $true
    }
    
    # Execute platform-specific script
    Write-Info "Executing: $targetScript"
    $result = & $targetScript @forwardParams
    $exitCode = $LASTEXITCODE
    
    # Return the result
    if ($exitCode -eq 0) {
        Write-Success "Git LFS installation routing completed successfully"
        exit 0
    } else {
        Write-Error "Git LFS installation failed with exit code: $exitCode"
        exit $exitCode
    }
    
} catch {
    Write-Error "Git LFS installation router failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

function Test-GitLFS {
    param(
        [switch]$Detailed
    )
    
    try {
        Write-Info "Testing Git LFS installation..."
        
        # Check if Git LFS command is available
        if (-not (Test-Command "git-lfs")) {
            Write-Warning "Git LFS command not found"
            return $false
        }
        
        # Check Git LFS version
        $lfsVersion = Get-ToolVersion "git-lfs"
        if (-not $lfsVersion) {
            Write-Warning "Could not get Git LFS version"
            return $false
        }
        
        # Test version compliance
        $compliance = Test-ToolVersionCompliance -ToolName "git_lfs" -InstalledVersion $lfsVersion
        Write-VersionComplianceReport -ToolName "Git LFS" -ComplianceResult $compliance
        
        if (-not $compliance.IsCompliant) {
            Write-Warning "Git LFS version $lfsVersion does not meet minimum requirements"
            if ($Detailed) {
                Write-Info "Action required: $($compliance.Action)"
            }
            return $false
        }
        
        Write-Success "Git LFS is properly installed and compliant: $lfsVersion"
        return $true
        
    } catch {
        Write-Warning "Error testing Git LFS: $($_.Exception.Message)"
        return $false
    }
}

function Install-GitLFS {
    param(
        [switch]${check-only}
    )
    
    # If check-only mode, just test current installation
    if (${check-only}) {
        return Test-GitLFS
    }
    
    Write-Step "Installing Git LFS..."
    
    try {
        # Check if Git LFS is already installed
        if (Test-Command "git-lfs") {
            $lfsVersion = git lfs version 2>$null
            if ($lfsVersion) {
                Write-Success "Git LFS is already installed: $lfsVersion"
                return $true
            }
        }
        
        $installChoice = Read-UserPrompt -Prompt "Git LFS not found. Install Git LFS?" -ValidValues @("y","n")
        if (-not (Test-YesResponse $installChoice)) {
            Write-Warning "Skipping Git LFS installation"
            return $false
        }
        
        Write-Progress "Installing Git LFS..."
        
        # Try different installation methods
        $installSuccess = $false
        
        # Method 1: Try winget (Windows Package Manager)
        if (Test-Command "winget") {
            try {
                Write-Info "Installing Git LFS via winget..."
                winget install GitHub.GitLFS --accept-package-agreements --accept-source-agreements --silent
                if ($LASTEXITCODE -eq 0) {
                    $installSuccess = $true
                    Write-Success "Git LFS installed via winget"
                }
            } catch {
                Write-Warning "winget installation failed: $($_.Exception.Message)"
            }
        }
        
        # Method 2: Try chocolatey if winget failed
        if (-not $installSuccess -and (Test-Command "choco")) {
            try {
                Write-Info "Installing Git LFS via chocolatey..."
                choco install git-lfs -y
                if ($LASTEXITCODE -eq 0) {
                    $installSuccess = $true
                    Write-Success "Git LFS installed via chocolatey"
                }
            } catch {
                Write-Warning "Chocolatey installation failed: $($_.Exception.Message)"
            }
        }
        
        # Method 3: Direct download if package managers failed
        if (-not $installSuccess) {
            try {
                Write-Info "Downloading Git LFS installer..."
                
                # Get the latest release from GitHub API
                $apiUrl = "https://api.github.com/repos/git-lfs/git-lfs/releases/latest"
                $response = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "strangeloop-Setup" }
                
                # Find Windows installer
                $windowsAsset = $response.assets | Where-Object { $_.name -like "*windows-amd64.exe" } | Select-Object -First 1
                
                if ($windowsAsset) {
                    $installerPath = Join-Path $env:TEMP "git-lfs-installer.exe"
                    
                    # Download installer
                    Write-Progress "Downloading Git LFS v$($response.tag_name)..."
                    Invoke-WebRequest -Uri $windowsAsset.browser_download_url -OutFile $installerPath
                    
                    Write-Info "Running Git LFS installer..."
                    $process = Start-Process -FilePath $installerPath -ArgumentList "/SILENT" -Wait -PassThru
                    
                    if ($process.ExitCode -eq 0) {
                        $installSuccess = $true
                        Write-Success "Git LFS installed via direct download"
                    } else {
                        Write-Warning "Git LFS installer returned exit code: $($process.ExitCode)"
                    }
                    
                    # Cleanup
                    if (Test-Path $installerPath) {
                        Remove-Item $installerPath -Force
                    }
                } else {
                    Write-Warning "Could not find Windows installer for Git LFS"
                }
            } catch {
                Write-Warning "Direct download installation failed: $($_.Exception.Message)"
            }
        }
        
        if ($installSuccess) {
            # Initialize Git LFS
            try {
                Write-Info "Initializing Git LFS..."
                git lfs install --skip-smudge
                Write-Success "Git LFS initialized successfully"
            } catch {
                Write-Warning "Git LFS initialization failed: $($_.Exception.Message)"
            }
            
            Write-Success "Git LFS installation completed"
            return $true
        } else {
            Write-Error "Failed to install Git LFS"
            Write-Info "Please install Git LFS manually from: https://git-lfs.github.io/"
            return $false
        }
        
    } catch {
        Write-Error "Git LFS installation failed: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    # Build parameters dynamically to avoid syntax errors
    $params = @{}
    if (${check-only}) { $params['check-only'] = $true }
    
    $result = Install-GitLFS @params
    
    if ($result) {
        if (${check-only}) {
            Write-Success "Git LFS test completed successfully"
        } else {
            Write-Success "Git LFS installation completed successfully"
        }
        exit 0
    } else {
        if (${check-only}) {
            Write-Error "Git LFS test failed"
        } else {
            Write-Error "Git LFS installation failed"
        }
        exit 1
    }
}

# Export functions for module usage
if ($MyInvocation.MyCommand.ModuleName) {
    Export-ModuleMember -Function @(
        'Install-GitLFS'
    )
}

