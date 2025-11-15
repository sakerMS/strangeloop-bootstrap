#Requires -Version 5.1

<#
.SYNOPSIS
    strangeloop Setup Wrapper - PowerShell 5.1 Compatible Entry Point

.DESCRIPTION
    This wrapper script ensures PowerShell 7 is available and then executes the main setup script.
    It provides backward compatibility with PowerShell 5.1 while leveraging PowerShell 7 features.

.PARAMETER LoopName
    The name of the loop to set up (optional)

.PARAMETER ProjectName
    The name of the project to create (optional)

.PARAMETER ProjectPath
    The path where the project should be created (optional)

.PARAMETER Mode
    Setup mode: "core" (phase 1), "environment" (phase 2), "bootstrap" (phase 3), or "full" (phases 1,2,3)
    Default: "full"

.PARAMETER StartFromPhase
    Start execution from this phase number (1-3) or name and continue through all subsequent phases
    Valid numbers: "1", "2", "3"
    Valid names: "core", "prerequisites", "bootstrap"
    Phase mapping: 1=Core Prerequisites, 2=Environment Prerequisites, 3=Project Bootstrap
    Aliases: "core-prerequisites", "additional-prerequisites", "environment", "env", "setup", "project", "init", "selection", "loop-selection", "tools", "integration"

.PARAMETER StartFromStage
    Start execution from this stage within Phase 3 (Project Bootstrap) and continue through all subsequent stages
    Valid stage names:
    • "selection" or "loop-selection" - Loop Selection & Target Platform Decision
    • "project" or "project-setup" - Project Setup & Target Platform-Specific Configuration
    • "tools" or "development-tools" - Development Tools Integration (both pipelines and VS Code)
    • "pipelines" - Only pipelines setup within Development Tools Integration
    • "vscode" - Only VS Code integration within Development Tools Integration

.PARAMETER OnlyStage
    Run only this specific stage within Phase 3 (Project Bootstrap)
    Valid stage names:
    • "selection" or "loop-selection" - Loop Selection & Target Platform Decision
    • "project" or "project-setup" - Project Setup & Target Platform-Specific Configuration
    • "tools" or "development-tools" - Development Tools Integration (both pipelines and VS Code)
    • "pipelines" - Only pipelines setup
    • "vscode" - Only VS Code integration

.PARAMETER SkipStages
    Skip specific stages within Phase 3 (comma-separated)
    All phase stages: "powershell/policy", "azure-cli/azure", "strangeloop-cli/cli", "git/version-control", "docker/containers", "python/language", "poetry/packages", "wsl/linux", "selection/loop-selection", "project/project-setup", "tools/development-tools", "pipelines", "vscode"

.PARAMETER ListPhases
    List all available phases and their descriptions

.PARAMETER ListStages
    List all available stages across all phases with details

.PARAMETER ListModes
    List all available setup modes and their descriptions

.PARAMETER Help
    Display comprehensive help information

.PARAMETER BootstrapOnly
    Run in bootstrap mode (equivalent to -Mode bootstrap) - Phase 3 only: project creation

.PARAMETER CoreOnly
    Run in core mode (equivalent to -Mode core) - Phase 1 only: core prerequisites

.PARAMETER EnvOnly
    Run in environment mode (equivalent to -Mode environment) - Phase 2 only: development environment

.PARAMETER SetupOnly
    DEPRECATED: Use -EnvOnly instead. Will be mapped to environment mode.

.PARAMETER ProjectOnly
    DEPRECATED: Use -BootstrapOnly instead. Will be mapped to bootstrap mode.

.PARAMETER ExecutionEngine
    Execution engine: "StrangeloopCLI" (use strangeloop CLI commands) or "PowerShell" (use detailed individual PowerShell scripts)
    Default: "StrangeloopCLI"

.PARAMETER Verbose
    Enable verbose output with detailed explanations and additional information

.PARAMETER WhatIf
    Show what would be performed without making any changes

.PARAMETER CheckOnly
    Run in check mode without making permanent changes

.EXAMPLE
    .\setup-wrapper.ps1
    Run the complete setup process with all phases

.EXAMPLE
    .\setup-wrapper.ps1 -LoopName "python-mcp-server" -ProjectName "MyApp"
    Run setup with specific loop and project names

.EXAMPLE
    .\setup-wrapper.ps1 -LoopName "python-cli" -ProjectName "MyApp" -ProjectPath "C:\Projects\MyApp"
    Run setup with specific loop, project name, and project path

.EXAMPLE
    .\setup-wrapper.ps1 -Mode bootstrap -LoopName "python-cli" -ProjectName "MyApp"
    Create project only (assumes environment is already set up)

.EXAMPLE
    .\setup-wrapper.ps1 -Mode environment
    Set up development environment only (Git, Docker, Python, Poetry, WSL)

.EXAMPLE
    .\setup-wrapper.ps1 -Mode core
    Install core prerequisites only (Azure CLI, strangeloop CLI, PowerShell policy)

.EXAMPLE
    .\setup-wrapper.ps1 -BootstrapOnly -LoopName "python-cli" -ProjectName "MyApp"
    Create project only (equivalent to -Mode bootstrap)

.EXAMPLE
    .\setup-wrapper.ps1 -EnvOnly
    Setup development environment only (equivalent to -Mode environment)

.EXAMPLE
    .\setup-wrapper.ps1 -CoreOnly
    Install core prerequisites only (equivalent to -Mode core)
    Create project only (equivalent to -Mode project-only)

.EXAMPLE
    .\setup-wrapper.ps1 -StartFromPhase "3" -LoopName "python-cli" -ProjectName "MyApp"
    Start from phase 3 (Project Bootstrap) with specific parameters

.EXAMPLE
    .\setup-wrapper.ps1 -StartFromPhase "selection" -LoopName "python-cli" -ProjectName "MyApp"
    Start from phase 3 using alias name (selection) with specific parameters

.EXAMPLE
    .\setup-wrapper.ps1 -OnlyStage "pipelines" -LoopName "csharp-mcp-server" -ProjectName "MyApp"
    Run only the pipelines setup stage

.EXAMPLE
    .\setup-wrapper.ps1 -OnlyStage "vscode" -ProjectName "MyApp"
    Run only the VS Code integration stage

.EXAMPLE
    .\setup-wrapper.ps1 -StartFromStage "project" -LoopName "python-cli" -ProjectName "MyApp"
    Start from Project Setup stage and continue through Development Tools Integration

.EXAMPLE
    .\setup-wrapper.ps1 -SkipStages "vscode" -LoopName "csharp-mcp-server" -ProjectName "MyApp"
    Skip VS Code integration stage

.EXAMPLE
    .\setup-wrapper.ps1 -OnlyStage "selection" -LoopName "python-cli"
    Run only the loop selection and target platform decision stage

.EXAMPLE
    .\setup-wrapper.ps1 -StartFromStage "tools" -ProjectName "MyApp"
    Start from Development Tools Integration (both pipelines and VS Code)

.EXAMPLE
    .\setup-wrapper.ps1 -ExecutionEngine PowerShell -Verbose
    Run in PowerShell engine mode with verbose output
#>

[CmdletBinding()]
param(
    [string]$LoopName,
    [string]$ProjectName,
    [string]$ProjectPath,
    [string]$Mode = "full",
    [string]$StartFromPhase,
    [ValidateSet("powershell", "policy", "azure-cli", "azure", "strangeloop-cli", "cli", "git", "version-control", "docker", "containers", "python", "language", "poetry", "packages", "wsl", "linux", "selection", "loop-selection", "project", "project-setup", "tools", "development-tools", "pipelines", "vscode")]
    [string]$StartFromStage,
    [ValidateSet("powershell", "policy", "azure-cli", "azure", "strangeloop-cli", "cli", "git", "version-control", "docker", "containers", "python", "language", "poetry", "packages", "wsl", "linux", "selection", "loop-selection", "project", "project-setup", "tools", "development-tools", "pipelines", "vscode")]
    [string]$OnlyStage,
    [ValidateSet("powershell", "policy", "azure-cli", "azure", "strangeloop-cli", "cli", "git", "version-control", "docker", "containers", "python", "language", "poetry", "packages", "wsl", "linux", "selection", "loop-selection", "project", "project-setup", "tools", "development-tools", "pipelines", "vscode")]
    [string[]]$SkipStages = @(),
    [switch]$ListPhases,
    [switch]$ListStages,
    [switch]$ListModes,
    [switch]$Help,
    [switch]$BootstrapOnly,
    [switch]$CoreOnly,
    [switch]$EnvOnly,
    [switch]$SetupOnly,
    [switch]$ProjectOnly,
    [switch]$WhatIf,
    [switch]$CheckOnly,
    [ValidateSet("StrangeloopCLI", "PowerShell")]
    [string]$ExecutionEngine = "StrangeloopCLI",
    [switch]$NoWSL
)

# Script version and info
# Import version functions to get the same version as main script
. (Join-Path $PSScriptRoot "..\lib\version\version-functions.ps1")
# Import configuration functions
. (Join-Path $PSScriptRoot "..\lib\platform\config-functions.ps1")
$WrapperVersion = Get-BootstrapScriptVersion
$RequiredPSVersion = "7.0"

function Write-WrapperInfo {
    param([string]$Message, [string]$Color = "Cyan")
    
    # Minimal logging - only show critical messages
    if ($VerbosePreference -eq 'Continue') {
        $timestamp = Get-Date -Format 'HH:mm:ss'
        Write-Host "[$timestamp] [WRAPPER] $Message" -ForegroundColor $Color
    }
}

function Write-WrapperError {
    param([string]$Message)
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp] [ERROR] $Message" -ForegroundColor Red
}

function Write-WrapperSuccess {
    param([string]$Message)
    
    # Always show success messages but without timestamp
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Test-PowerShell7Available {
    <#
    .SYNOPSIS
    Check if PowerShell 7+ is available on the system
    #>
    
    Write-WrapperInfo "Checking for PowerShell 7+ availability..."
    
    # Check if pwsh command is available
    try {
        $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwshPath) {
            # Get PowerShell version
            $versionOutput = & pwsh -Command '$PSVersionTable.PSVersion.ToString()'
            if ($versionOutput) {
                $version = [Version]$versionOutput
                $requiredVersion = [Version]$RequiredPSVersion
                
                if ($version -ge $requiredVersion) {
                    Write-WrapperInfo "PowerShell $versionOutput found"
                    return @{
                        Available = $true
                        Version = $versionOutput
                        Path = $pwshPath.Source
                    }
                } else {
                    Write-WrapperError "PowerShell $versionOutput found but version $RequiredPSVersion or higher is required"
                    return @{
                        Available = $false
                        Version = $versionOutput
                        Path = $pwshPath.Source
                        Reason = "Version too old"
                    }
                }
            }
        }
    } catch {
        Write-WrapperError "Error checking PowerShell 7: $($_.Exception.Message)"
    }
    
    Write-WrapperError "PowerShell 7+ not found on system"
    return @{
        Available = $false
        Version = $null
        Path = $null
        Reason = "Not installed"
    }
}

function Install-PowerShell7 {
    <#
    .SYNOPSIS
    Install PowerShell 7 using the most reliable methods for older systems
    #>
    
    Write-WrapperInfo "Installing PowerShell 7..." "Yellow"
    
    # Method 1: Try winget first if available (Windows 10 1809+)
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetPath) {
        Write-WrapperInfo "Attempting winget installation..."
        try {
            $wingetArgs = @("install", "--id", "Microsoft.Powershell", "--silent", "--accept-package-agreements", "--accept-source-agreements")
            $wingetProcess = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
            
            if ($wingetProcess.ExitCode -eq 0 -or $wingetProcess.ExitCode -eq -1978335189 -or $wingetProcess.ExitCode -eq -1978335212) {
                Write-WrapperInfo "winget installation completed"
                
                # Refresh PATH and test
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                Start-Sleep -Seconds 2
                
                if (Test-PowerShell7AfterInstall) {
                    Write-WrapperSuccess "PowerShell 7 installed via winget"
                    return $true
                }
            }
        } catch {
            Write-WrapperInfo "winget installation failed, trying direct download..."
        }
    }
    
    # Method 2: Direct MSI download (most reliable, works on all Windows versions)
    Write-WrapperInfo "Attempting direct MSI download..."
    try {
        # Get latest release info from GitHub API
        $apiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        Write-WrapperInfo "Getting release info from GitHub API..."
        
        # Use .NET WebClient for API call (compatible with older systems)
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "strangeloop-bootstrap/1.0")
        
        # Set SSL/TLS protocols for older systems
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11
        
        $releaseJson = $webClient.DownloadString($apiUrl)
        $releaseInfo = $releaseJson | ConvertFrom-Json
        
        # Find the Windows x64 MSI asset
        $msiAsset = $releaseInfo.assets | Where-Object { $_.name -like "*win-x64.msi" } | Select-Object -First 1
        
        if (-not $msiAsset) {
            throw "Could not find Windows x64 MSI in latest release"
        }
        
        $downloadUrl = $msiAsset.browser_download_url
        $fileName = $msiAsset.name
        
        Write-WrapperInfo "Found: $fileName ($([math]::Round($msiAsset.size/1MB, 1)) MB)"
        
        $tempPath = [System.IO.Path]::GetTempPath()
        $msiPath = Join-Path $tempPath $fileName
        
        Write-WrapperInfo "Downloading PowerShell 7 MSI..."
        
        # Use the same WebClient instance for downloading
        $webClient.DownloadFile($downloadUrl, $msiPath)
        $webClient.Dispose()
        
        if (Test-Path $msiPath) {
            $fileSize = (Get-Item $msiPath).Length
            if ($fileSize -lt 50MB) {
                Write-WrapperError "Downloaded file appears incomplete"
                Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
                throw "Download incomplete"
            }
            
            Write-WrapperInfo "Installing PowerShell 7 MSI..."
            $msiArgs = @("/i", $msiPath, "/quiet", "/norestart")
            $msiProcess = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
            
            # Clean up
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
            
            if ($msiProcess.ExitCode -eq 0) {
                # Refresh PATH
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                Start-Sleep -Seconds 3
                
                if (Test-PowerShell7AfterInstall) {
                    Write-WrapperSuccess "PowerShell 7 installed via direct download"
                    return $true
                }
            }
        }
        
        throw "MSI installation failed with exit code: $($msiProcess.ExitCode)"
        
    } catch {
        Write-WrapperError "Direct MSI installation failed: $($_.Exception.Message)"
    }
    
    # All methods failed
    Write-WrapperError "All installation methods failed"
    Write-WrapperError "Please install PowerShell 7 manually:"
    Write-Host "  1. Visit: https://aka.ms/powershell-release" -ForegroundColor Yellow
    Write-Host "  2. Download: PowerShell-7.x.x-win-x64.msi" -ForegroundColor Yellow
    Write-Host "  3. Run the installer as Administrator" -ForegroundColor Yellow
    Write-Host "  4. Restart this script" -ForegroundColor Green
    
    return $false
}

function Get-WingetExitCodeMeaning {
    <#
    .SYNOPSIS
    Translate common winget exit codes to human-readable meanings
    #>
    param([int]$ExitCode)
    
    switch ($ExitCode) {
        0 { return "Success" }
        -1978335189 { return "Already installed or newer version available" }
        -1978335212 { return "Already installed" }
        -1978335191 { return "Package not found" }
        -1978335213 { return "No applicable upgrade found" }
        -1978335222 { return "User cancelled" }
        -1978335160 { return "Multiple packages found" }
        -1978335215 { return "Package agreement required" }
        -1978335214 { return "Source agreement required" }
        -1978335216 { return "Administrator privileges required" }
        default { return "Unknown error code: $ExitCode" }
    }
}

function Test-PowerShell7AfterInstall {
    <#
    .SYNOPSIS
    Test if PowerShell 7 is available after installation attempt
    #>
    try {
        $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwshPath) {
            $versionOutput = & pwsh -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
            if ($versionOutput) {
                $version = [Version]$versionOutput
                $requiredVersion = [Version]$RequiredPSVersion
                return ($version -ge $requiredVersion)
            }
        }
    } catch {
        # Ignore errors during testing
    }
    return $false
}

function Invoke-MainSetupScript {
    <#
    .SYNOPSIS
    Execute the main setup script using PowerShell 7
    #>
    param(
        [hashtable]$Parameters
    )
    
    $mainSetupScript = Join-Path $PSScriptRoot "..\core\main.ps1"
    
    if (-not (Test-Path $mainSetupScript)) {
        Write-WrapperError "Main setup script not found: $mainSetupScript"
        return $false
    }
    
    Write-WrapperInfo "Executing main setup script with PowerShell 7..."
    
    try {
        # Build parameter array for splatting
        $paramArray = @()
        foreach ($key in $Parameters.Keys) {
            $value = $Parameters[$key]
            if ($value -is [switch] -or $value -is [bool]) {
                if ($value) {
                    $paramArray += "-$key"
                }
            } elseif ($value -is [array]) {
                $paramArray += "-$key"
                $paramArray += ($value -join ',')
            } elseif ($value) {
                $paramArray += "-$key"
                $paramArray += $value
            }
        }
        
        # Execute with PowerShell 7
        $pwshArgs = @("-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", $mainSetupScript) + $paramArray
        
        Write-WrapperInfo "Launching: pwsh $($pwshArgs -join ' ')"
        
        # Use System.Diagnostics.Process with WaitForExit() to only wait for main process
        # This prevents hanging when child processes (tool installations) are still running
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "pwsh"
        $psi.Arguments = $pwshArgs -join " "
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $false
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        $process.Start() | Out-Null
        $process.WaitForExit()
        
        $exitCode = $process.ExitCode
        
        if ($exitCode -eq 0) {
            return $true
        } else {
            Write-WrapperError "Setup failed with exit code: $exitCode"
            return $false
        }
        
    } catch {
        Write-WrapperError "Error executing main setup script: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
function Start-WrapperSetup {
    # Handle mode switch parameters (map to new mode names)
    if ($BootstrapOnly) {
        $Script:Mode = "bootstrap"
    } elseif ($CoreOnly) {
        $Script:Mode = "core"
    } elseif ($EnvOnly) {
        $Script:Mode = "environment"
    } elseif ($SetupOnly) {
        # Legacy parameter - map to environment mode
        $Script:Mode = "environment"
        Write-Host "⚠️  -SetupOnly is deprecated. Use -EnvOnly instead." -ForegroundColor Yellow
    } elseif ($ProjectOnly) {
        # Legacy parameter - map to bootstrap mode
        $Script:Mode = "bootstrap"
        Write-Host "⚠️  -ProjectOnly is deprecated. Use -BootstrapOnly instead." -ForegroundColor Yellow
    }
    
    # Validate StartFromPhase parameter if provided
    if ($StartFromPhase) {
        $validPhaseValues = Get-ValidPhaseValues
        if ($StartFromPhase -notin $validPhaseValues) {
            Write-Host ""
            Write-Host "❌ Invalid phase value: '$StartFromPhase'" -ForegroundColor Red
            Write-Host ""
            Write-Host "Valid phase values:" -ForegroundColor Yellow
            $phases = Get-BootstrapPhases
            foreach ($phaseNumber in ($phases.Keys | Sort-Object)) {
                $phase = $phases[$phaseNumber]
                Write-Host "  $phaseNumber, $($phase.Name)" -ForegroundColor Cyan -NoNewline
                if ($phase.Aliases -and $phase.Aliases.Count -gt 0) {
                    Write-Host ", $($phase.Aliases -join ', ')" -ForegroundColor Gray -NoNewline
                }
                Write-Host " - $($phase.Title)" -ForegroundColor White
            }
            Write-Host ""
            return $false
        }
    }
    
    # Validate Mode parameter
    $validModeValues = Get-ValidModeValues
    if ($Mode -notin $validModeValues) {
        Write-Host ""
        Write-Host "❌ Invalid mode value: '$Mode'" -ForegroundColor Red
        Write-Host ""
        Write-Host "Valid mode values:" -ForegroundColor Yellow
        $modes = Get-BootstrapModes
        foreach ($modeName in ($modes.Keys | Sort-Object)) {
            $mode = $modes[$modeName]
            Write-Host "  $modeName" -ForegroundColor Cyan -NoNewline
            if ($mode.Aliases -and $mode.Aliases.Count -gt 0) {
                Write-Host ", $($mode.Aliases -join ', ')" -ForegroundColor Gray -NoNewline
            }
            Write-Host " - $($mode.Title)" -ForegroundColor White
        }
        Write-Host ""
        return $false
    }
    
    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Blue
    Write-Host "                        strangeloop Setup Wrapper v$WrapperVersion" -ForegroundColor Blue  
    Write-Host "                     PowerShell 5.1+ Compatible Entry Point" -ForegroundColor Blue
    Write-Host "===============================================================================" -ForegroundColor Blue
    Write-Host ""
    
    # Check PowerShell 7 availability
    $ps7Status = Test-PowerShell7Available
    
    if (-not $ps7Status.Available) {
        Write-WrapperInfo "PowerShell 7+ is required but not available" "Yellow"
        
        if ($WhatIf) {
            Write-WrapperInfo "WHAT-IF: Would install PowerShell 7 and then execute setup" "Yellow"
            return $true
        }
        
        if (Install-PowerShell7) {
            # Verify installation
            Start-Sleep -Seconds 2
            $ps7Status = Test-PowerShell7Available
            if (-not $ps7Status.Available) {
                Write-WrapperError "PowerShell 7 installation appears to have failed"
                Write-WrapperError "Please install PowerShell 7 manually and run this script again"
                return $false
            }
        } else {
            Write-WrapperError "Failed to install PowerShell 7"
            return $false
        }
    }
    
    # Build parameters to pass to main script
    $mainScriptParams = @{}
    
    if ($LoopName) { $mainScriptParams['loop-name'] = $LoopName }
    if ($ProjectName) { $mainScriptParams['project-name'] = $ProjectName }
    if ($ProjectPath) { $mainScriptParams['project-path'] = $ProjectPath }
    if ($Mode -and $Mode -ne "full") { $mainScriptParams['Mode'] = $Mode }
    if ($StartFromPhase) { 
        $phaseNumber = Convert-PhaseNameToNumber -PhaseName $StartFromPhase
        $mainScriptParams['start-from-phase'] = $phaseNumber 
    }
    if ($StartFromStage) { $mainScriptParams['start-from-stage'] = $StartFromStage }
    if ($OnlyStage) { $mainScriptParams['only-stage'] = $OnlyStage }
    if ($SkipStages -and $SkipStages.Count -gt 0) { $mainScriptParams['skip-stages'] = $SkipStages }
    if ($ListPhases) { $mainScriptParams['list-phases'] = $true }
    if ($ListStages) { $mainScriptParams['list-stages'] = $true }
    if ($ListModes) { $mainScriptParams['list-modes'] = $true }
    if ($Help) { $mainScriptParams['help'] = $true }
    if ($WhatIf) { $mainScriptParams['what-if'] = $true }
    if ($CheckOnly) { $mainScriptParams['check-only'] = $true }
    if ($ExecutionEngine) { $mainScriptParams['execution-engine'] = $ExecutionEngine }
    if ($NoWSL) { $mainScriptParams['no-wsl'] = $true }
    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') -and $VerbosePreference -eq 'Continue') { 
        $mainScriptParams['Verbose'] = $true 
    }
    
    # Execute main setup script
    $success = Invoke-MainSetupScript -Parameters $mainScriptParams
    
    if ($success) {
        Write-WrapperSuccess "strangeloop setup completed successfully"
    } else {
        Write-WrapperError "strangeloop setup failed"
    }
    
    return $success
}

# Execute main function
if ($MyInvocation.InvocationName -ne '.') {
    $result = Start-WrapperSetup
    
    if (-not $result) {
        exit 1
    }
    exit 0
}
