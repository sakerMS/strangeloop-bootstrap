# strangeloop Setup - Git Installation Router
# Version: 2.0.0
# Routes to platform-specific Git installation implementation

param(
    [string]$Version = "latest",
    [string]$InstallPath = $null,
    [switch]${check-only},
    [switch]$Detailed,
    [switch]${what-if},
    [switch]$WSLMode = $false
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")

try {
    Write-Info "Git Installation Router - detecting platform..."
    
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
        $targetScript = Join-Path $PSScriptRoot "windows\install-git-windows.ps1"
        Write-Info "Routing to Windows Git for Windows installation"
    } elseif ($platformIsWSL -or $platformIsLinux) {
        $targetScript = Join-Path $PSScriptRoot "linux\install-git-linux.ps1"
        Write-Info "Routing to Linux Git via package manager installation"
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
    if ($Version) { $forwardParams['Version'] = $Version }
    if ($InstallPath) { $forwardParams['InstallPath'] = $InstallPath }
    if (${check-only}) { $forwardParams['check-only'] = $true }
    if ($Detailed) { $forwardParams['Detailed'] = $true }
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
        Write-Success "Git installation routing completed successfully"
        exit 0
    } else {
        Write-Error "Git installation failed with exit code: $exitCode"
        exit $exitCode
    }
    
} catch {
    Write-Error "Git installation router failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

function Test-Git {
    param(
        [switch]$Detailed
    )
    
    try {
        Write-Info "Testing Git installation..."
        
        # Check if Git command is available
        if (-not (Test-Command "git")) {
            Write-Warning "Git command 'git' not found"
            return $false
        }
        
        # Check Git version
        $gitVersion = Get-ToolVersion "git"
        if (-not $gitVersion) {
            Write-Warning "Could not get Git version"
            return $false
        }
        
        # Test version compliance
        $compliance = Test-ToolVersionCompliance -ToolName "git" -InstalledVersion $gitVersion
        Write-VersionComplianceReport -ToolName "Git" -ComplianceResult $compliance
        
        if (-not $compliance.IsCompliant) {
            Write-Warning "Git version $gitVersion does not meet minimum requirements"
            if ($Detailed) {
                Write-Info "Action required: $($compliance.Action)"
            }
            return $false
        }
        
        # Test basic functionality
        $versionOutput = git --version 2>$null
        if (-not $versionOutput) {
            Write-Warning "Git functionality test failed"
            return $false
        }
        
        Write-Success "Git is properly installed and compliant: $gitVersion"
        return $true
        
    } catch {
        Write-Warning "Error testing Git: $($_.Exception.Message)"
        return $false
    }
}

function Install-Git {
    param(
        [string]$Version = "latest",
        [string]$InstallPath = $null,
        [switch]${check-only},
        [switch]${what-if}
    )
    
    # If check-only mode, just test current installation
    if (${check-only}) {
        return Test-Git -Detailed
    }
    
    # If what-if mode, show what would be done
    if (${what-if}) {
        Write-Host "what if: Would test if Git is already installed" -ForegroundColor Yellow
        Write-Host "what if: Would check Git version compliance against requirements" -ForegroundColor Yellow
        Write-Host "what if: Would check internet connection" -ForegroundColor Yellow
        Write-Host "what if: Would determine Git download URL for version '$Version'" -ForegroundColor Yellow
        Write-Host "what if: Would download Git installer to temporary directory" -ForegroundColor Yellow
        Write-Host "what if: Would install Git with silent installation arguments" -ForegroundColor Yellow
        Write-Host "what if: Would refresh PATH environment variables" -ForegroundColor Yellow
        Write-Host "what if: Would configure Git with safe defaults" -ForegroundColor Yellow
        return $true
    }
    
    Write-Step "Installing Git..."
    
    try {
        # Check if Git is already installed and compliant
        if (Test-Command "git") {
            $currentVersion = Get-ToolVersion "git"
            if ($currentVersion) {
                Write-Info "Git $currentVersion is already installed"
                
                # Check version compliance
                $compliance = Test-ToolVersionCompliance -ToolName "git" -InstalledVersion $currentVersion
                if ($compliance.IsCompliant) {
                    if ($Version -eq "latest" -or $compliance.Status -eq "Optimal") {
                        Write-Success "Git installation confirmed and compliant"
                        return $true
                    } else {
                        Write-Info "Git meets minimum requirements but newer version requested"
                        # Continue with installation
                    }
                } else {
                    Write-Warning "Git version $currentVersion does not meet requirements"
                    Write-Info "Required action: $($compliance.Action)"
                    # Continue with installation
                }
            }
        }
        
        # Check internet connection
        if (-not (Test-InternetConnection)) {
            Write-Error "Internet connection required for Git installation"
            return $false
        }
        
        Write-Progress "Determining Git download URL..."
        
        # Get target version based on requirements
        $targetVersion = $Version
        if ($Version -eq "latest") {
            $requirements = Get-ToolVersionRequirement -ToolName "git"
            if ($requirements -and $requirements.recommended_version -ne "latest") {
                $targetVersion = $requirements.recommended_version
                Write-Info "Using recommended version: $targetVersion"
            }
        }
        
        # Get download URL
        $downloadUrl = $null
        if ($targetVersion -eq "latest") {
            try {
                $releasesUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
                $releaseInfo = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing
                $asset = $releaseInfo.assets | Where-Object { $_.name -like "*64-bit.exe" } | Select-Object -First 1
                if ($asset) {
                    $downloadUrl = $asset.browser_download_url
                    $targetVersion = $releaseInfo.tag_name -replace '^v', ''
                    Write-Info "Latest version found: $targetVersion"
                }
            } catch {
                Write-Warning "Could not get latest Git version from GitHub API, using fallback URL"
                $downloadUrl = "https://github.com/git-for-windows/git/releases/latest/download/Git-2.42.0.2-64-bit.exe"
            }
        } else {
            $downloadUrl = "https://github.com/git-for-windows/git/releases/download/v$targetVersion.windows.1/Git-$targetVersion-64-bit.exe"
        }
        
        if (-not $downloadUrl) {
            Write-Error "Could not determine Git download URL"
            return $false
        }
        
        Write-Progress "Downloading Git installer..."
        
        # Download Git installer
        $tempDir = Join-Path $env:TEMP "Git-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        if (-not (Test-Path $tempDir)) {
            Write-Error "Could not create temporary directory"
            return $false
        }
        
        $installerPath = Join-Path $tempDir "git-installer.exe"
        
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            Write-Success "Git installer downloaded successfully"
        } catch {
            Write-Error "Failed to download Git installer: $($_.Exception.Message)"
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }
        
        # Verify download
        if (-not (Test-Path $installerPath)) {
            Write-Error "Git installer not found after download"
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }
        
        Write-Progress "Installing Git..."
        
        # Prepare installation arguments
        $installArgs = @(
            "/VERYSILENT",
            "/NORESTART",
            "/NOCANCEL",
            "/SP-",
            "/CLOSEAPPLICATIONS",
            "/RESTARTAPPLICATIONS",
            "/COMPONENTS=icons,ext\reg\shellhere,assoc,assoc_sh"
        )
        
        if ($InstallPath) {
            $installArgs += "/DIR=`"$InstallPath`""
        }
        
        # Install Git
        $installResult = Invoke-CommandWithTimeout -ScriptBlock {
            Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -NoNewWindow -PassThru
        } -TimeoutSeconds 600 -Description "Git installation"
        
        # Clean up installer
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        if (-not $installResult.Success) {
            Write-Error "Git installation failed: $($installResult.Error)"
            return $false
        }
        
        $exitCode = $installResult.Output.ExitCode
        if ($exitCode -ne 0) {
            Write-Error "Git installation failed with exit code: $exitCode"
            return $false
        }
        
        Write-Success "Git installed successfully"
        
        # Update PATH and verify installation
        Write-Progress "Verifying Git installation..."
        
        # Comprehensive PATH refresh
        Write-Info "Refreshing environment variables..."
        $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + 
                   ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Also refresh from registry for completeness
        try {
            $machinePath = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $userPath = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $env:PATH = $machinePath + ";" + $userPath
            Write-Info "PATH refreshed from registry"
        } catch {
            Write-Warning "Could not refresh PATH from registry: $($_.Exception.Message)"
        }
        
        # Wait for installation to fully complete
        Start-Sleep -Seconds 5
        
        # Verify installation with comprehensive test
        if (Test-Git -Detailed) {
            Write-Success "Git installation verified and compliant"
            
            # Configure Git with safe defaults if not already configured
            Write-Progress "Configuring Git defaults..."
            Set-GitDefaults
            
            return $true
        } else {
            Write-Error "Git installation completed but verification failed"
            Write-Info "You may need to restart your terminal or reboot your system"
            Write-Info "Try running: refreshenv (if using Chocolatey) or restart your terminal"
            return $false
        }
        
    } catch {
        Write-Error "Git installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Set-GitDefaults {
    Write-Step "Configuring Git defaults..."
    
    try {
        # Check if global user.name is set
        $userName = git config --global user.name 2>$null
        if (-not $userName) {
            Write-Host ""
            Write-Host "🔧 Git Configuration Required" -ForegroundColor Yellow
            Write-Host "Git needs to be configured with your name and email for commits." -ForegroundColor Gray
            Write-Host ""
            $userName = Read-Host "Enter your Git user.name (required)"
            while ([string]::IsNullOrWhiteSpace($userName)) {
                $userName = Read-Host "Git user.name cannot be empty. Please enter your name"
            }
            git config --global user.name "$userName"
            Write-Success "Set Git user.name to '$userName'"
        } else {
            Write-Success "Git user.name is already configured: $userName"
        }

        # Check if global user.email is set
        $userEmail = git config --global user.email 2>$null
        if (-not $userEmail) {
            $userEmail = Read-Host "Enter your Git user.email (required)"
            while ([string]::IsNullOrWhiteSpace($userEmail)) {
                $userEmail = Read-Host "Git user.email cannot be empty. Please enter your email"
            }
            git config --global user.email "$userEmail"
            Write-Success "Set Git user.email to '$userEmail'"
        } else {
            Write-Success "Git user.email is already configured: $userEmail"
        }

        # Set safe directory configuration for Linux compatibility
        git config --global --add safe.directory '*'
        Write-Info "Configured Git safe.directory for Linux compatibility"

        # Set default branch name
        git config --global init.defaultBranch main
        Write-Info "Set default branch name to 'main'"

        # Set pull behavior
        git config --global pull.rebase false
        Write-Info "Set Git pull behavior to merge"

        # Set core autocrlf for Windows
        git config --global core.autocrlf true
        Write-Info "Set Git core.autocrlf to true for Windows"

        Write-Success "Git default configuration completed"

    } catch {
        Write-Warning "Could not configure Git defaults: $($_.Exception.Message)"
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    # Build parameters dynamically to avoid syntax errors
    $params = @{
        'Version' = $Version
        'InstallPath' = $InstallPath
    }
    if (${check-only}) { $params['check-only'] = $true }
    if (${what-if}) { $params['what-if'] = $true }
    
    $result = Install-Git @params
    
    if ($result) {
        if (${check-only}) {
            Write-Success "Git test completed successfully"
        } else {
            Write-CompletionSummary @{
                'Git Installation' = 'Completed Successfully'
                'Version' = (Get-ToolVersion "git")
                'Command Available' = if (Test-Command "git") { "Yes" } else { "No" }
            } -Title "Git Installation Summary"
        }
        exit 0
    } else {
        if (${check-only}) {
            Write-Error "Git test failed"
        } else {
            Write-Error "Git installation failed"
        }
        exit 1
    }
}

# Export functions for module usage
Export-ModuleMember -Function @(
    'Install-Git',
    'Set-GitDefaults'
)

