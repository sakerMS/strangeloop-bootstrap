# strangeloop Setup - Git Installation Module (Linux/WSL)
# Version: 3.0.0 - Simplified for Linux/WSL execution only

param(
    [switch]${check-only},
    [switch]${what-if}
)

# Import Linux script base and required modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "linux\linux-script-base.ps1")

function Test-GitLinux {
    <#
    .SYNOPSIS
    Test Git installation in Linux environment
    
    .DESCRIPTION
    Tests if Git is properly installed and meets version requirements
    
    .PARAMETER Detailed
    Whether to show detailed compliance information
    #>
    param(
        [switch]$Detailed
    )
    
    return Test-LinuxToolVersion -ToolName "Git" -VersionCommand "git --version" -VersionRegex "git version ([0-9]+\.[0-9]+\.[0-9]+)" -Detailed:$Detailed
}

function Get-WindowsGitConfig {
    <#
    .SYNOPSIS
    Retrieve Git configuration from Windows if available
    
    .DESCRIPTION
    Attempts to retrieve Git user.name and user.email from Windows Git installation
    
    .PARAMETER ConfigKey
    The Git config key to retrieve (e.g., "user.name", "user.email")
    
    .OUTPUTS
    String value from Windows Git config, or $null if not found
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigKey
    )
    
    try {
        # Check if we're in WSL and can access Windows Git
        if (Test-Path "/mnt/c/Program Files/Git/cmd/git.exe") {
            $windowsGitPath = "/mnt/c/Program Files/Git/cmd/git.exe"
        } elseif (Test-Path "/mnt/c/Program Files (x86)/Git/cmd/git.exe") {
            $windowsGitPath = "/mnt/c/Program Files (x86)/Git/cmd/git.exe"
        } else {
            # Try to find git.exe via PATH in Windows
            $gitPath = wsl.exe -e bash -c "which git.exe 2>/dev/null || echo ''"
            if ([string]::IsNullOrWhiteSpace($gitPath)) {
                return $null
            }
            $windowsGitPath = $gitPath.Trim()
        }
        
        if (Test-Path $windowsGitPath) {
            Write-Info "Checking Windows Git configuration for $ConfigKey..."
            $configValue = & "$windowsGitPath" config --global $ConfigKey 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($configValue)) {
                Write-Info "Found Windows Git $ConfigKey`: $configValue"
                return $configValue.Trim()
            }
        }
        
        return $null
        
    } catch {
        Write-Info "Could not retrieve Windows Git config for $ConfigKey`: $($_.Exception.Message)"
        return $null
    }
}

function Set-GitConfiguration {
    <#
    .SYNOPSIS
    Configure Git with default settings
    
    .DESCRIPTION
    Sets up Git with user information and recommended defaults.
    Attempts to retrieve user.name and user.email from Windows Git first.
    #>
    
    Write-Step "Configuring Git defaults..."
    
    try {
        # Check if global user.name is set
        $userName = git config --global user.name 2>$null
        
        if (-not $userName -or $LASTEXITCODE -ne 0) {
            # Try to get user.name from Windows Git first
            $windowsUserName = Get-WindowsGitConfig -ConfigKey "user.name"
            
            if ($windowsUserName) {
                git config --global user.name "$windowsUserName"
                Write-Success "Imported Git user.name from Windows: '$windowsUserName'"
            } else {
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
            }
        } else {
            Write-Success "Git user.name is already configured: $userName"
        }

        # Check if global user.email is set
        $userEmail = git config --global user.email 2>$null
        
        if (-not $userEmail -or $LASTEXITCODE -ne 0) {
            # Try to get user.email from Windows Git first
            $windowsUserEmail = Get-WindowsGitConfig -ConfigKey "user.email"
            
            if ($windowsUserEmail) {
                git config --global user.email "$windowsUserEmail"
                Write-Success "Imported Git user.email from Windows: '$windowsUserEmail'"
            } else {
                $userEmail = Read-Host "Enter your Git user.email (required)"
                while ([string]::IsNullOrWhiteSpace($userEmail)) {
                    $userEmail = Read-Host "Git user.email cannot be empty. Please enter your email"
                }
                
                git config --global user.email "$userEmail"
                Write-Success "Set Git user.email to '$userEmail'"
            }
        } else {
            Write-Success "Git user.email is already configured: $userEmail"
        }

        # Configure standard settings
        $gitConfigs = @{
            "safe.directory" = "*"
            "init.defaultBranch" = "main"
            "pull.rebase" = "false"
            "core.autocrlf" = "input"
            "core.filemode" = "true"
            "merge.tool" = "vscode"
            "mergetool.vscode.cmd" = "code --wait `$MERGED"
            "credential.useHttpPath" = "true"
        }
        
        foreach ($config in $gitConfigs.GetEnumerator()) {
            $result = git config --global $config.Key $config.Value 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Info "Set Git $($config.Key) to '$($config.Value)'"
            }
        }
        
        # Configure credential helper
        Set-GitCredentialHelper
        
        Write-Success "Git configuration completed"
        
    } catch {
        Write-Warning "Git configuration had issues: $($_.Exception.Message)"
    }
}

function Set-GitCredentialHelper {
    <#
    .SYNOPSIS
    Configure Git credential helper
    
    .DESCRIPTION
    Sets up the best available credential helper for the environment
    #>
    
    Write-Info "Configuring Git credential helper..."
    
    try {
        # Get current credential helpers to avoid duplicates
        $currentHelpers = @(git config --global --get-all credential.helper 2>$null)
        
        # Check for Windows Git Credential Manager (common in WSL)
        $windowsGCMPaths = @(
            "/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe",
            "/mnt/c/Program Files (x86)/Git/mingw64/bin/git-credential-manager.exe",
            "/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager-core.exe"
        )
        
        $foundWindowsGCM = $false
        foreach ($gcmPath in $windowsGCMPaths) {
            if (Test-Path $gcmPath) {
                # Check if this path is already configured
                $escapedPath = $gcmPath -replace " ", "\ "
                if ($currentHelpers -contains $escapedPath) {
                    Write-Success "Windows Credential Manager is already configured in credential helpers"
                } else {
                    # Use Windows GCM with proper escaping for spaces
                    git config --global --add credential.helper $escapedPath
                    Write-Success "Added Windows Credential Manager to credential helpers"
                }
                $foundWindowsGCM = $true
                break
            }
        }
        
        if (-not $foundWindowsGCM) {
            # Check for native Git Credential Manager
            $nativeGCM = git credential-manager --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                if ($currentHelpers -contains "manager") {
                    Write-Success "Git Credential Manager is already configured in credential helpers"
                } else {
                    git config --global --add credential.helper manager
                    Write-Success "Added native Git Credential Manager to credential helpers"
                }
            } else {
                # Check if store is already configured before adding
                if ($currentHelpers -contains "store") {
                    Write-Success "Credential store is already configured in credential helpers"
                } else {
                    # Fallback to credential store
                    git config --global --add credential.helper store
                    Write-Info "Added credential store to credential helpers (plaintext file)"
                    Write-Warning "Consider installing Git Credential Manager for better security"
                }
            }
        }
        
    } catch {
        Write-Warning "Could not configure Git credential helper: $($_.Exception.Message)"
        Write-Info "You may need to configure Git credentials manually"
    }
}

function Install-GitLinux {
    <#
    .SYNOPSIS
    Install Git in Linux environment
    
    .DESCRIPTION
    Installs Git using apt package manager and configures it with defaults
    #>
    
    # Initialize script
    if (-not (Initialize-LinuxScript -ScriptName "Git Installation")) {
        return $false
    }
    
    # Handle what-if mode
    if (${what-if}) {
        Write-Host "what if: Would install Git via apt package manager" -ForegroundColor Yellow
        Write-Host "what if: Would install git package" -ForegroundColor Yellow
        Write-Host "what if: Would configure Git with default settings" -ForegroundColor Yellow
        Write-Host "what if: Would set up credential helper" -ForegroundColor Yellow
        return $true
    }
    
    # Handle check-only mode
    if (${check-only}) {
        return Test-GitLinux -Detailed
    }
    
    # Test if Git is already installed and compliant
    if (Test-GitLinux) {
        Write-Success "Git is already installed and compliant"
        Set-GitConfiguration
        return $true
    }
    
    Write-Step "Installing Git (Linux/WSL)..."
    
    try {
        # Install Git using apt
        $installSuccess = Invoke-LinuxPackageInstall -Packages @("git") -UpdateFirst $true
        
        if (-not $installSuccess) {
            Write-Error "Git installation failed"
            return $false
        }
        
        Write-Success "Git installed successfully"
        
        # Verify installation
        Start-Sleep -Seconds 2
        $verificationResult = Test-GitLinux
        if ($verificationResult) {
            Write-Success "Git installation completed successfully"
            
            # Configure Git
            Set-GitConfiguration
            
            # Show next steps
            Write-Host ""
            Write-Host "📋 Next Steps:" -ForegroundColor Cyan
            Write-Host "  • Git is configured with recommended defaults" -ForegroundColor Gray
            Write-Host "  • Use 'git clone', 'git commit', etc. as normal" -ForegroundColor Gray
            Write-Host "  • Credential helper is configured for secure authentication" -ForegroundColor Gray
            
            return $true
        } else {
            Write-Error "Git installation verification failed"
            return $false
        }
        
    } catch {
        Write-Error "Failed to install Git: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Install-GitLinux
    if (-not $result) {
        exit 1
    }
}