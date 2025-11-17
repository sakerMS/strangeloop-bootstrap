#Requires -Version 5.1

<#
.SYNOPSIS
    strangeloop Bootstrap - Complete Core Tools Setup

.DESCRIPTION
    Single-script solution for installing strangeloop core prerequisites: Azure CLI and strangeloop CLI
    Compatible with PowerShell 5.1+, automatically bootstraps to PowerShell 7+ if needed
    Includes all library functions embedded for complete self-sufficiency
    
.PARAMETER what-if
    Test mode - shows what would be installed without making changes
    
.PARAMETER check-only
    Check current tool versions without installing/upgrading

.EXAMPLE
    .\setup-strangeloop.ps1
    Install core prerequisites

.EXAMPLE
    .\setup-strangeloop.ps1 -what-if
    Test mode - show what would be installed
#>

param(
    [switch]${what-if},
    [switch]${check-only}
)

$ErrorActionPreference = 'Stop'

#region Embedded Configuration

# Embedded bootstrap configuration (no external YAML file needed)
$Script:BootstrapConfig = @{
    bootstrap_script = @{
        version = "0.1.2"
        description = "strangeloop Core Tools Setup"
    }
    azure_cli = @{
        minimum_version = "2.50.0"
        recommended_version = "latest"
        notes = "Azure CLI for Azure DevOps and resource management"
    }
    strangeloop_cli = @{
        minimum_version = "0.3.31"
        recommended_version = "latest"
        notes = "strangeloop CLI for project scaffolding and management"
    }
}

#endregion

#region Embedded Library Functions

# Version Functions
function Get-BootstrapScriptVersion {
    return $Script:BootstrapConfig.bootstrap_script.version
}

function Get-PrereqVersionConfig {
    return @{
        'azure_cli' = $Script:BootstrapConfig.azure_cli
        'strangeloop_cli' = $Script:BootstrapConfig.strangeloop_cli
    }
}

function Test-ToolVersionCompliance {
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][string]$InstalledVersion
    )
    
    try {
        $config = Get-PrereqVersionConfig
        
        $result = @{
            IsCompliant = $true
            CurrentVersion = $InstalledVersion
            RequiredVersion = "any"
            RecommendedVersion = "latest"
            Status = "Compliant"
            Action = "None required"
        }
        
        if (-not $config -or -not $config.ContainsKey($ToolName)) {
            return $result
        }
        
        $toolConfig = $config[$ToolName]
        if (-not $toolConfig) {
            return $result
        }
        
        $minVersion = $null
        $recommendedVersion = $null
        
        if ($toolConfig.ContainsKey('minimum_version')) {
            $minVersion = $toolConfig['minimum_version']
            $result.RequiredVersion = $minVersion
        }
        
        if ($toolConfig.ContainsKey('recommended_version')) {
            $recommendedVersion = $toolConfig['recommended_version']
            $result.RecommendedVersion = $recommendedVersion
        }
        
        if ($InstalledVersion -eq "unknown-but-functional") {
            $result.Status = "Unknown"
            $result.Action = "Version detection failed but tool appears functional"
            return $result
        }
        
        if ($minVersion -and $minVersion -ne "latest") {
            $isCompliant = Compare-Versions -Version1 $InstalledVersion -Version2 $minVersion -Operator "gte"
            
            if (-not $isCompliant) {
                $result.IsCompliant = $false
                $result.Status = "Non-Compliant"
                $result.Action = "Upgrade to version $minVersion or higher"
            }
        }
        
        return $result
        
    } catch {
        return @{
            IsCompliant = $true
            CurrentVersion = $InstalledVersion
            RequiredVersion = "unknown"
            Status = "Unknown"
            Action = "Version check failed"
        }
    }
}

function Compare-Versions {
    param(
        [string]$Version1,
        [string]$Version2,
        [string]$Operator = "eq"
    )
    
    try {
        $v1 = $Version1 -replace '^v', '' -replace '[^\d\.].*$', ''
        $v2 = $Version2 -replace '^v', '' -replace '[^\d\.].*$', ''
        
        $v1Parts = $v1 -split '\.' | ForEach-Object { [int]$_ }
        $v2Parts = $v2 -split '\.' | ForEach-Object { [int]$_ }
        
        $maxLength = [Math]::Max($v1Parts.Length, $v2Parts.Length)
        while ($v1Parts.Length -lt $maxLength) { $v1Parts += 0 }
        while ($v2Parts.Length -lt $maxLength) { $v2Parts += 0 }
        
        for ($i = 0; $i -lt $maxLength; $i++) {
            if ($v1Parts[$i] -gt $v2Parts[$i]) {
                switch ($Operator) {
                    "gt" { return $true }
                    "gte" { return $true }
                    "eq" { return $false }
                    "lt" { return $false }
                    "lte" { return $false }
                }
            } elseif ($v1Parts[$i] -lt $v2Parts[$i]) {
                switch ($Operator) {
                    "gt" { return $false }
                    "gte" { return $false }
                    "eq" { return $false }
                    "lt" { return $true }
                    "lte" { return $true }
                }
            }
        }
        
        switch ($Operator) {
            "eq" { return $true }
            "gte" { return $true }
            "lte" { return $true }
            "gt" { return $false }
            "lt" { return $false }
        }
        
    } catch {
        return $false
    }
}

function Write-VersionComplianceReport {
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][hashtable]$ComplianceResult
    )
    
    try {
        if ($ComplianceResult.IsCompliant) {
            Write-Success "$ToolName version $($ComplianceResult.CurrentVersion) meets requirements"
            
            if ($ComplianceResult.Status -eq "Unknown") {
                Write-Info "$($ComplianceResult.Action)"
            }
        } else {
            Write-Warning "$ToolName version $($ComplianceResult.CurrentVersion) does not meet requirements"
            Write-Info "Required: $($ComplianceResult.RequiredVersion)"
            Write-Info "Action: $($ComplianceResult.Action)"
        }
        
        return @{
            ShouldUpgrade = $false
            NewVersion = $null
        }
        
    } catch {
        return @{
            ShouldUpgrade = $false
            NewVersion = $null
        }
    }
}

# Display Functions
function Show-Banner {
    param(
        [string]$Version = "",
        [string]$Title = "strangeloop Setup"
    )
    
    if ([string]::IsNullOrEmpty($Version)) {
        try {
            $Version = Get-BootstrapScriptVersion
        } catch {
            $Version = "1.0.0"
        }
    }
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║                                                 _                             ║" -ForegroundColor Blue
    Write-Host "║               _                                | |                            ║" -ForegroundColor Blue
    Write-Host "║         ___ _| |_  ____ _____ ____   ____ _____| | ___   ___  ____            ║" -ForegroundColor Blue
    Write-Host "║        /___|_   _)/ ___|____ |  _ \ / _  | ___ | |/ _ \ / _ \|  _ \           ║" -ForegroundColor Blue
    Write-Host "║       |___ | | |_| |   / ___ | | | ( (_| | ____| | |_| | |_| | |_| |          ║" -ForegroundColor Blue
    Write-Host "║       (___/   \__)_|   \_____|_| |_|\___ |_____)\_)___/ \___/|  __/           ║" -ForegroundColor Blue
    Write-Host "║                                    (_____|                   |_|              ║" -ForegroundColor Blue
    Write-Host "║  $($Title.PadRight(75))  ║" -ForegroundColor Blue
    Write-Host "║  Version: $($Version.PadRight(67)) ║" -ForegroundColor Blue
    Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
}

# Write Functions
function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $separator = if ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP) { "===" } else { "═══" }
    Write-Host "`n[$timestamp] " -ForegroundColor Gray -NoNewline
    Write-Host "$separator $Message $separator" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $checkMark = if ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP) { "[OK]" } else { "✓" }
    Write-Host "[$timestamp] " -ForegroundColor Gray -NoNewline
    Write-Host "$checkMark $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $infoSymbol = if ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP) { "[INFO]" } else { "ℹ" }
    Write-Host "[$timestamp] " -ForegroundColor Gray -NoNewline
    Write-Host "$infoSymbol $Message" -ForegroundColor Cyan
}

function Write-Progress {
    param([string]$Message)
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp] " -ForegroundColor Gray -NoNewline
    Write-Host "⌛ $Message" -ForegroundColor Yellow
}

# Test Functions
function Test-Command {
    param([string]$Command)
    
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-InternetConnection {
    param(
        [string]$TestUrl = "https://www.bing.com",
        [int]$TimeoutSeconds = 10
    )
    
    try {
        $response = Invoke-WebRequest -Uri $TestUrl -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Get-ToolVersion {
    param([string]$Tool)
    
    try {
        switch ($Tool.ToLower()) {
            "az" {
                $output = az version --output json 2>$null | ConvertFrom-Json
                return $output.'azure-cli'
            }
            "strangeloop" {
                $output = strangeloop version 2>$null
                $outputString = $output -join "`n"
                if ($outputString -match "\[INFO\] strangeloop ([0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9]+)?)") {
                    return $matches[1]
                }
            }
        }
    } catch {
        return $null
    }
    
    return $null
}

# Path Functions
function Update-EnvironmentPath {
    param(
        [Parameter(Mandatory = $true)][string]$ToolName,
        [Parameter(Mandatory = $false)][string[]]$CommonPaths = @(),
        [Parameter(Mandatory = $false)][int]$WaitSeconds = 2
    )
    
    try {
        Write-Info "Refreshing environment PATH for $ToolName..."
        
        $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
        
        try {
            $machinePath = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $userPath = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $env:PATH = $machinePath + ";" + $userPath
            Write-Info "PATH refreshed from registry for $ToolName"
        } catch {
            Write-Warning "Could not refresh PATH from registry: $($_.Exception.Message)"
        }
        
        if ($CommonPaths.Count -gt 0) {
            foreach ($path in $CommonPaths) {
                $expandedPath = [Environment]::ExpandEnvironmentVariables($path)
                
                if (Test-Path $expandedPath) {
                    Write-Info "Found $ToolName installation at: $expandedPath"
                    if ($env:PATH -notlike "*$expandedPath*") {
                        $env:PATH = $env:PATH + ";" + $expandedPath
                        Write-Info "Added to current session PATH: $expandedPath"
                    }
                }
            }
        }
        
        if ($WaitSeconds -gt 0) {
            Start-Sleep -Seconds $WaitSeconds
        }
        
        return $true
        
    } catch {
        Write-Warning "Error during PATH refresh for $ToolName`: $($_.Exception.Message)"
        return $false
    }
}

function Get-CommonToolPaths {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("strangeloop", "azure-cli")]
        [string]$ToolName
    )
    
    switch ($ToolName.ToLower()) {
        "strangeloop" {
            return @(
                "C:\Program Files (x86)\Microsoft strangeloop CLI",
                "C:\Program Files\Microsoft strangeloop CLI",
                "$env:LOCALAPPDATA\Microsoft\strangeloop CLI",
                "$env:PROGRAMFILES\Microsoft strangeloop CLI",
                "${env:PROGRAMFILES(X86)}\Microsoft strangeloop CLI"
            )
        }
        "azure-cli" {
            return @(
                "${env:ProgramFiles}\Microsoft SDKs\Azure\CLI2\wbin",
                "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\CLI2\wbin",
                "${env:LOCALAPPDATA}\Programs\Azure CLI\wbin"
            )
        }
        default {
            return @()
        }
    }
}

#endregion

#region PowerShell 7 Bootstrap Functions

function Test-PowerShell7Available {
    $pwsh7Paths = @(
        "C:\Program Files\PowerShell\7\pwsh.exe",
        "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    )
    
    foreach ($path in $pwsh7Paths) {
        if (Test-Path $path) {
            return $true
        }
    }
    
    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCommand -and $pwshCommand.Version.Major -ge 7) {
        return $true
    }
    
    return $false
}

function Install-PowerShell7 {
    Write-Host "🔧 PowerShell 7 not found. Installing..." -ForegroundColor Yellow
    
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "winget is required to install PowerShell 7 but was not found."
        exit 1
    }
    
    try {
        Write-Host "📦 Installing PowerShell 7 via winget..." -ForegroundColor Cyan
        winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "PowerShell 7 installation failed with exit code $LASTEXITCODE"
            exit 1
        }
        
        Write-Host "✅ PowerShell 7 installed successfully" -ForegroundColor Green
        
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
    } catch {
        Write-Error "Failed to install PowerShell 7: $($_.Exception.Message)"
        exit 1
    }
}

function Invoke-InPowerShell7 {
    param(
        [switch]${what-if},
        [switch]${check-only}
    )
    
    if (-not (Test-PowerShell7Available)) {
        Install-PowerShell7
    }
    
    $pwsh7Exe = $null
    $pwsh7Paths = @(
        "C:\Program Files\PowerShell\7\pwsh.exe",
        "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    )
    
    foreach ($path in $pwsh7Paths) {
        if (Test-Path $path) {
            $pwsh7Exe = $path
            break
        }
    }
    
    if (-not $pwsh7Exe) {
        $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwshCommand) {
            $pwsh7Exe = $pwshCommand.Source
        }
    }
    
    if (-not $pwsh7Exe) {
        Write-Error "Could not locate PowerShell 7 executable after installation"
        exit 1
    }
    
    # Pass the entire current script to PowerShell 7
    $scriptContent = Get-Content $PSCommandPath -Raw
    
    # Save to temp file
    $tempScript = Join-Path $env:TEMP "strangeloop-core-setup-$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
    $scriptContent | Set-Content -Path $tempScript -Encoding UTF8
    
    try {
        $params = @()
        if (${what-if}) { $params += "-what-if" }
        if (${check-only}) { $params += "-check-only" }
        
        Write-Host "🚀 Launching core tools setup in PowerShell 7..." -ForegroundColor Cyan
        Write-Host ""
        
        & $pwsh7Exe -NoProfile -ExecutionPolicy Bypass -File $tempScript @params
        
        $exitCode = $LASTEXITCODE
        return $exitCode
        
    } finally {
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        }
    }
}

#endregion

#region Azure CLI Functions

function Test-AzureCLI {
    param([switch]$Detailed)
    
    Write-Info "Testing Azure CLI installation..."
    
    if (-not (Test-Command "az")) {
        Write-Info "Azure CLI not found in current PATH, refreshing environment..."
        
        $refreshSuccess = Update-EnvironmentPath -ToolName "Azure CLI" -CommonPaths (Get-CommonToolPaths -ToolName "azure-cli")
        
        if (-not $refreshSuccess -or -not (Test-Command "az")) {
            Write-Warning "Azure CLI command 'az' not found"
            return $false
        } else {
            Write-Info "Azure CLI found after PATH refresh"
        }
    }
    
    $version = Get-ToolVersion "az"
    if (-not $version) {
        Write-Warning "Could not determine Azure CLI version"
        return $false
    }
    
    $compliance = Test-ToolVersionCompliance -ToolName "azure_cli" -InstalledVersion $version
    Write-VersionComplianceReport -ToolName "Azure CLI" -ComplianceResult $compliance
    
    if (-not $compliance.IsCompliant) {
        Write-Warning "Azure CLI version $version does not meet minimum requirements"
        return $false
    }
    
    Write-Success "Azure CLI $version is properly installed and compliant"
    
    try {
        $versionOutput = az version --output json 2>$null
        if ($versionOutput) {
            Write-Success "Azure CLI functionality test passed"
            
            if ($Detailed) {
                try {
                    $account = az account show --output json 2>$null | ConvertFrom-Json
                    if ($account) {
                        Write-Success "Azure CLI is logged in as: $($account.user.name)"
                        Write-Info "Current subscription: $($account.name)"
                    } else {
                        Write-Info "Azure CLI is not currently logged in"
                    }
                } catch {
                    Write-Info "Azure CLI is not currently logged in"
                }
            }
            
            return $true
        } else {
            Write-Warning "Azure CLI functionality test failed"
            return $false
        }
    } catch {
        Write-Warning "Azure CLI functionality test failed: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-AzureAuthentication {
    param([switch]${what-if})
    
    Write-Step "Setting up Azure Authentication..."
    
    if (${what-if}) {
        Write-Host "what if: Would check current Azure login status with 'az account show'" -ForegroundColor Yellow
        Write-Host "what if: Would perform Azure login with 'az login' if not already logged in" -ForegroundColor Yellow
        return $true
    }
    
    try {
        Write-Progress "Checking Azure login status..."
        
        try {
            $account = az account show --output json 2>$null | ConvertFrom-Json
            if ($account) {
                Write-Success "Already logged in to Azure as: $($account.user.name)"
                Write-Info "Current subscription: $($account.name)"
                return $true
            }
        } catch {
            Write-Info "Not currently logged in to Azure"
        }
        
        Write-Progress "Initiating Azure login..."
        Write-Info "A browser window will open for Azure authentication..."
        
        try {
            Write-Info "Running Azure CLI login..."
            $loginOutput = az login --allow-no-subscriptions --output json 2>&1
            $loginExitCode = $LASTEXITCODE
            
            if ($loginExitCode -eq 0) {
                Write-Success "Azure login completed successfully"
                
                $account = az account show --output json 2>$null | ConvertFrom-Json
                if ($account) {
                    Write-Success "Successfully authenticated as: $($account.user.name)"
                    Write-Info "Active subscription: $($account.name)"
                    return $true
                } else {
                    Write-Warning "Login succeeded but could not verify account"
                    return $false
                }
            } else {
                Write-Warning "Azure login failed with exit code: $loginExitCode"
                return $false
            }
            
        } catch {
            Write-Warning "Azure login failed: $($_.Exception.Message)"
            Write-Info "You can authenticate later by running 'az login'"
            return $false
        }
        
    } catch {
        Write-Warning "Authentication setup failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-AzureCLI {
    param(
        [string]$Version = "latest",
        [switch]${check-only},
        [switch]${what-if}
    )
    
    if (${check-only}) {
        $testResult = Test-AzureCLI -Detailed
        
        if ($testResult) {
            Write-Info "Azure CLI is installed. Checking authentication status..."
            if (${what-if}) {
                $authResult = Initialize-AzureAuthentication -what-if
            } else {
                $authResult = Initialize-AzureAuthentication
            }
            
            if ($authResult) {
                Write-Success "Azure CLI is installed and authenticated"
            } else {
                Write-Warning "Azure CLI is installed but authentication needs attention"
                Write-Info "You can complete authentication by running 'az login'"
            }
        }
        
        return $testResult
    }
    
    if (${what-if}) {
        Write-Host "what if: Would test if Azure CLI is already installed" -ForegroundColor Yellow
        Write-Host "what if: Would check Azure CLI version compliance against requirements" -ForegroundColor Yellow
        Write-Host "what if: Would check and setup Azure authentication (az login)" -ForegroundColor Yellow
        Write-Host "what if: Would install Azure CLI via winget if not installed" -ForegroundColor Yellow
        return $true
    }
    
    Write-Step "Installing Azure CLI..."
    
    try {
        if (Test-AzureCLI) {
            Write-Success "Azure CLI installation confirmed and compliant"
            
            Write-Info "Checking Azure authentication status..."
            if (${what-if}) {
                $authResult = Initialize-AzureAuthentication -what-if
            } else {
                $authResult = Initialize-AzureAuthentication
            }
            
            if ($authResult) {
                Write-Success "Azure CLI is installed and authenticated"
            } else {
                Write-Warning "Azure CLI is installed but authentication needs attention"
                Write-Info "You can complete authentication by running 'az login'"
            }
            
            return $true
        }
        
        if (-not (Test-InternetConnection)) {
            Write-Error "Internet connection required for Azure CLI installation"
            return $false
        }
        
        Write-Progress "Attempting Azure CLI installation..."
        
        if (-not (Test-Command "winget")) {
            Write-Error "winget is not available. Azure CLI installation requires Windows Package Manager (winget)."
            return $false
        }
        
        $installationSuccessful = $false
        
        try {
            Write-Info "Installing Azure CLI via winget..."
            Write-Info "This may take several minutes. Please wait..."
            
            $process = Start-Process -FilePath "winget" -ArgumentList @(
                "install", 
                "Microsoft.AzureCLI", 
                "--accept-package-agreements", 
                "--accept-source-agreements", 
                "--silent"
            ) -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                $installationSuccessful = $true
                Write-Success "Azure CLI installed via winget"
            } elseif ($process.ExitCode -eq -1978335189) {
                Write-Info "Azure CLI may already be installed (winget exit code: $($process.ExitCode))"
                $installationSuccessful = $true
            } else {
                Write-Error "winget installation failed with exit code: $($process.ExitCode)"
                return $false
            }
        } catch {
            Write-Error "winget installation failed: $($_.Exception.Message)"
            return $false
        }
        
        if (-not $installationSuccessful) {
            Write-Error "Azure CLI installation via winget failed"
            return $false
        }
        
        Write-Progress "Refreshing PATH and verifying Azure CLI installation..."
        
        Write-Info "Refreshing environment PATH after installation..."
        $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
        
        try {
            $machinePath = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $userPath = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $env:PATH = $machinePath + ";" + $userPath
            Write-Info "PATH refreshed from registry"
        } catch {
            Write-Warning "Could not refresh PATH from registry: $($_.Exception.Message)"
        }
        
        $commonPaths = @(
            "${env:ProgramFiles}\Microsoft SDKs\Azure\CLI2\wbin",
            "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\CLI2\wbin",
            "${env:LOCALAPPDATA}\Programs\Azure CLI\wbin"
        )
        
        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                Write-Info "Found Azure CLI installation at: $path"
                if ($env:PATH -notlike "*$path*") {
                    $env:PATH = $env:PATH + ";" + $path
                    Write-Info "Added to current session PATH: $path"
                }
            }
        }
        
        Write-Info "Waiting for PATH changes to take effect..."
        Start-Sleep -Seconds 5
        
        if (Test-AzureCLI) {
            Write-Success "Azure CLI installation completed and verified successfully"
            
            Write-Info "Proceeding with Azure authentication setup..."
            if (${what-if}) {
                $authResult = Initialize-AzureAuthentication -what-if
            } else {
                $authResult = Initialize-AzureAuthentication
            }
            
            if ($authResult) {
                Write-Success "Azure CLI installation and authentication completed successfully"
            } else {
                Write-Warning "Azure CLI installed successfully but authentication setup had issues"
                Write-Info "You can complete authentication later by running 'az login'"
            }
            
            return $true
        } else {
            Write-Warning "Azure CLI was installed but verification failed"
            Write-Info "Try restarting your terminal or PowerShell session"
            return $false
        }
        
    } catch {
        Write-Error "Azure CLI installation failed: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region strangeloop CLI Functions

function Test-strangeloopCLI {
    param([switch]$Detailed)
    
    try {
        Write-Info "Testing strangeloop CLI installation..."
        
        if (-not (Test-Command "strangeloop")) {
            Write-Info "strangeloop CLI not found in current PATH, refreshing environment..."
            
            $refreshSuccess = Update-EnvironmentPath -ToolName "strangeloop CLI" -CommonPaths (Get-CommonToolPaths -ToolName "strangeloop")
            
            if (-not $refreshSuccess -or -not (Test-Command "strangeloop")) {
                Write-Warning "strangeloop CLI command 'strangeloop' not found even after PATH refresh"
                return $false
            } else {
                Write-Info "strangeloop CLI found after PATH refresh"
            }
        }
        
        $strangeloopVersion = Get-ToolVersion "strangeloop"
        if (-not $strangeloopVersion) {
            Write-Warning "Could not get strangeloop CLI version"
            
            try {
                $versionOutput = strangeloop version 2>&1
                if ($versionOutput -and $versionOutput -match "strangeloop ([0-9]+\.[0-9]+\.[0-9]+)") {
                    $strangeloopVersion = $matches[1]
                } else {
                    $helpOutput = strangeloop --help 2>&1
                    if ($helpOutput -and $helpOutput -match "strangeloop|loops|init") {
                        $strangeloopVersion = "unknown-but-functional"
                    } else {
                        return $false
                    }
                }
            } catch {
                return $false
            }
        }
        
        if ($strangeloopVersion -eq "unknown-but-functional") {
            $compliance = @{
                IsCompliant = $true
                CurrentVersion = $strangeloopVersion
                RequiredVersion = "unknown"
            }
        } else {
            $compliance = Test-ToolVersionCompliance -ToolName "strangeloop_cli" -InstalledVersion $strangeloopVersion
        }
        Write-VersionComplianceReport -ToolName "strangeloop CLI" -ComplianceResult $compliance
        
        if (-not $compliance.IsCompliant) {
            Write-Warning "strangeloop CLI version $strangeloopVersion does not meet minimum requirements"
            return $false
        }
        
        try {
            $helpOutput = strangeloop --help 2>$null
            if (-not $helpOutput) {
                Write-Warning "strangeloop CLI functionality test failed"
                return $false
            }
        } catch {
            Write-Warning "strangeloop CLI functionality test failed: $($_.Exception.Message)"
            return $false
        }
        
        Write-Success "strangeloop CLI is properly installed and compliant: $strangeloopVersion"
        return $true
        
    } catch {
        Write-Warning "Error testing strangeloop CLI: $($_.Exception.Message)"
        return $false
    }
}

function Install-strangeloopCLI {
    param(
        [string]$Version = "latest",
        [switch]${check-only},
        [switch]${what-if}
    )
    
    if (${what-if}) {
        Write-Host "what if: Would check for strangeloop CLI installation" -ForegroundColor Yellow
        Write-Host "what if: Would check for available upgrades if already installed" -ForegroundColor Yellow
        Write-Host "what if: Would download and install strangeloop CLI from Azure Artifacts if not found" -ForegroundColor Yellow
        return $true
    }
    
    if (${check-only}) {
        return Test-strangeloopCLI -Detailed
    }
    
    $currentlyInstalled = Test-strangeloopCLI
    if ($currentlyInstalled) {
        Write-Success "strangeloop CLI is already installed and working"
        
        $currentVersion = Get-ToolVersion "strangeloop"
        if ($currentVersion) {
            Write-Info "Current installed version: $currentVersion"
            
            Write-Info "Attempting to upgrade strangeloop CLI using built-in upgrade command..."
            
            try {
                Write-Info "Running: strangeloop cli upgrade"
                $upgradeResult = & strangeloop cli upgrade 2>&1
                $upgradeExitCode = $LASTEXITCODE
                
                if ($upgradeExitCode -eq 0) {
                    Write-Success "strangeloop CLI upgrade command completed successfully"
                    
                    $upgradeOutput = $upgradeResult -join ' '
                    if ($upgradeOutput -match "CLI is up to date") {
                        Write-Success "strangeloop CLI is already up to date - no upgrade necessary"
                        return $true
                    } else {
                        Write-Info "strangeloop CLI upgrade initiated..."
                        Write-Host ""
                        Write-Host "🔄 Please wait for the MSI installer to complete, then press any key to continue..." -ForegroundColor Yellow
                        Write-Host ""
                        
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        Write-Info "Continuing with installation verification..."
                    }
                    
                    Write-Info "Verifying installation after upgrade..."
                    Start-Sleep -Seconds 5
                    Update-EnvironmentPath -ToolName "strangeloop CLI" -CommonPaths (Get-CommonToolPaths -ToolName "strangeloop") -WaitSeconds 0
                    
                    if (Test-strangeloopCLI -Detailed) {
                        Write-Success "Upgrade verification successful"
                        return $true
                    }
                }
            } catch {
                Write-Warning "Error running strangeloop CLI upgrade: $($_.Exception.Message)"
            }
        }
    }
    
    Write-Step "Installing strangeloop CLI..."
    
    try {
        if (-not (Test-InternetConnection)) {
            Write-Error "Internet connection required for strangeloop CLI installation"
            return $false
        }
        
        if (-not (Test-Command "az")) {
            Write-Error "Azure CLI is required for strangeloop CLI installation"
            return $false
        }
        
        try {
            $account = az account show --output json 2>$null | ConvertFrom-Json
            if (-not $account) {
                Write-Error "Azure CLI is not authenticated. Please run 'az login' first."
                return $false
            }
            Write-Info "Azure CLI authenticated as: $($account.user.name)"
        } catch {
            Write-Warning "Could not verify Azure CLI authentication"
        }
        
        $tempDir = Join-Path $env:TEMP "strangeloop-install-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        try {
            Push-Location $tempDir
            
            Write-Info "Downloading strangeloop CLI from Azure Artifacts..."
            Write-Info "This may take several minutes..."
            
            # Build the command as a string for better debugging
            $downloadCmd = "az artifacts universal download " +
                "--organization `"https://msasg.visualstudio.com/`" " +
                "--project `"Bing_Ads`" " +
                "--scope project " +
                "--feed `"strangeloop`" " +
                "--name `"strangeloop-x86`" " +
                "--version `"*`" " +
                "--path `".`""
            
            Write-Info "Executing: $downloadCmd"
            Write-Host "⏳ Downloading... (this may appear to hang but is downloading in background)" -ForegroundColor Yellow
            
            try {
                # Get the full path to az.cmd
                $azPath = (Get-Command az -ErrorAction Stop).Source
                Write-Info "Using Azure CLI at: $azPath"
                
                # For .cmd files, we need to use cmd.exe
                $useCmd = $azPath -match '\.cmd$'
                
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                
                if ($useCmd) {
                    $psi.FileName = "cmd.exe"
                    # Properly quote the path and arguments for cmd.exe
                    $psi.Arguments = "/c `"`"$azPath`" artifacts universal download --organization `"https://msasg.visualstudio.com/`" --project `"Bing_Ads`" --scope project --feed `"strangeloop`" --name `"strangeloop-x86`" --version `"*`" --path `".`"`""
                } else {
                    $psi.FileName = $azPath
                    $psi.Arguments = "artifacts universal download --organization `"https://msasg.visualstudio.com/`" --project `"Bing_Ads`" --scope project --feed `"strangeloop`" --name `"strangeloop-x86`" --version `"*`" --path `".`""
                }
                
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.CreateNoWindow = $true
                $psi.WorkingDirectory = Get-Location
                
                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $psi
                
                # Event handlers for output
                $outputBuilder = New-Object System.Text.StringBuilder
                $errorBuilder = New-Object System.Text.StringBuilder
                
                $outputHandler = {
                    if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
                        $Event.MessageData.AppendLine($EventArgs.Data)
                        Write-Host "  $($EventArgs.Data)" -ForegroundColor Gray
                    }
                }
                
                $errorHandler = {
                    if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
                        $Event.MessageData.AppendLine($EventArgs.Data)
                        Write-Host "  [ERROR] $($EventArgs.Data)" -ForegroundColor Red
                    }
                }
                
                $outputEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $outputHandler -MessageData $outputBuilder
                $errorEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $errorHandler -MessageData $errorBuilder
                
                $process.Start() | Out-Null
                $process.BeginOutputReadLine()
                $process.BeginErrorReadLine()
                
                # Wait with timeout (1 minute for large downloads)
                $timeoutMs = 60000
                if (-not $process.WaitForExit($timeoutMs)) {
                    $process.Kill()
                    throw "Download timed out after $($timeoutMs/1000) seconds"
                }
                
                # Clean up events
                Unregister-Event -SourceIdentifier $outputEvent.Name
                Unregister-Event -SourceIdentifier $errorEvent.Name
                
                $azExitCode = $process.ExitCode
                $output = $outputBuilder.ToString()
                $errorOutput = $errorBuilder.ToString()
                
                Write-Host ""
                if ($errorOutput) {
                    Write-Host "Error output:" -ForegroundColor Yellow
                    Write-Host $errorOutput -ForegroundColor Red
                }
                
            } catch {
                Write-Error "Exception during download: $($_.Exception.Message)"
                Write-Error "Stack: $($_.ScriptStackTrace)"
                return $false
            }
            
            if ($azExitCode -ne 0) {
                Write-Error "Download failed with exit code: $azExitCode"
                return $false
            }
            
            $msiFiles = @(Get-ChildItem -Path "." -Filter "*.msi" -ErrorAction SilentlyContinue)
            if ($msiFiles.Count -eq 0) {
                Write-Error "No MSI file found after download"
                return $false
            }
            
            $msiPath = $msiFiles[0].FullName
            Write-Info "Installing from: $msiPath"
            
            $installArgs = @("/i", "`"$msiPath`"", "/quiet", "/norestart")
            $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -Verb RunAs
            
            if ($process.ExitCode -ne 0) {
                Write-Error "Installation failed with exit code: $($process.ExitCode)"
                return $false
            }
            
            Write-Success "strangeloop CLI installed successfully"
            
        } finally {
            Pop-Location
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Write-Info "Refreshing environment PATH after installation..."
        Update-EnvironmentPath -ToolName "strangeloop CLI" -CommonPaths (Get-CommonToolPaths -ToolName "strangeloop") -WaitSeconds 3
        
        if (Test-strangeloopCLI) {
            Write-Success "strangeloop CLI installation completed and verified"
            return $true
        } else {
            Write-Warning "Installation completed but verification failed"
            Write-Info "You may need to restart your terminal"
            return $false
        }
        
    } catch {
        Write-Error "strangeloop CLI installation failed: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Main Installation Function

function Install-CoreTools {
    param(
        [string]$Version = "latest",
        [switch]${check-only},
        [switch]${what-if}
    )
    
    $results = @{
        AzureCLI = $false
        StrangeloopCLI = $false
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Azure CLI" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    $params = @{ 'Version' = $Version }
    if (${check-only}) { $params['check-only'] = $true }
    if (${what-if}) { $params['what-if'] = $true }
    
    $results.AzureCLI = Install-AzureCLI @params
    
    if ($results.AzureCLI) {
        Write-Success "Azure CLI setup completed"
    } else {
        Write-Error "Azure CLI setup failed"
        if (-not ${check-only}) {
            Write-Warning "strangeloop CLI installation requires Azure CLI - skipping"
            return $false
        }
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  strangeloop CLI" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    $slParams = @{ 'Version' = $Version }
    if (${check-only}) { $slParams['check-only'] = $true }
    if (${what-if}) { $slParams['what-if'] = $true }
    
    $results.StrangeloopCLI = Install-strangeloopCLI @slParams
    
    if ($results.StrangeloopCLI) {
        Write-Success "strangeloop CLI setup completed"
    } else {
        Write-Error "strangeloop CLI setup failed"
    }
    
    $allSuccessful = $results.AzureCLI -and $results.StrangeloopCLI
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Summary" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    if ($allSuccessful) {
        Write-Host "✅ Azure CLI: " -NoNewline -ForegroundColor Green
        Write-Host (Get-ToolVersion "az") -ForegroundColor White
        
        $slVersion = Get-ToolVersion "strangeloop"
        if (-not $slVersion) {
            try {
                $versionOutput = strangeloop version 2>&1
                if ($versionOutput -and $versionOutput -match "strangeloop ([0-9]+\.[0-9]+\.[0-9]+)") {
                    $slVersion = $matches[1]
                } else {
                    $slVersion = "Installed (version detection failed)"
                }
            } catch {
                $slVersion = "Installed (version unknown)"
            }
        }
        
        Write-Host "✅ strangeloop CLI: " -NoNewline -ForegroundColor Green
        Write-Host $slVersion -ForegroundColor White
        Write-Host ""
        Write-Host "🎉 All core tools are ready!" -ForegroundColor Green
    } else {
        if ($results.AzureCLI) {
            Write-Host "✅ Azure CLI: " -NoNewline -ForegroundColor Green
            Write-Host (Get-ToolVersion "az") -ForegroundColor White
        } else {
            Write-Host "❌ Azure CLI: Failed" -ForegroundColor Red
        }
        
        if ($results.StrangeloopCLI) {
            $slVersion = Get-ToolVersion "strangeloop"
            if (-not $slVersion) {
                $slVersion = "Installed (version unknown)"
            }
            Write-Host "✅ strangeloop CLI: " -NoNewline -ForegroundColor Green
            Write-Host $slVersion -ForegroundColor White
        } else {
            Write-Host "❌ strangeloop CLI: Failed" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "⚠️  Some tools failed to install/check" -ForegroundColor Yellow
    }
    
    return $allSuccessful
}

#endregion

#region Main Execution Logic

if ($PSVersionTable.PSVersion.Major -ge 7) {
    # Already in PowerShell 7, execute directly
    
    try {
        $startTime = Get-Date
        
        Show-Banner -Version (Get-BootstrapScriptVersion)
        
        Write-Host "📋 Core Prerequisites Setup" -ForegroundColor Cyan
        Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
        Write-Host "Installing core tools (Azure CLI, strangeloop CLI)" -ForegroundColor White
        Write-Host ""
        
        try {
            $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
            if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "Undefined") {
                Write-Host "🔐 Setting PowerShell execution policy..." -ForegroundColor Yellow
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Write-Host "✓ PowerShell execution policy set to RemoteSigned" -ForegroundColor Green
            } else {
                Write-Host "✓ PowerShell execution policy is configured ($currentPolicy)" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Could not set execution policy: $($_.Exception.Message)"
        }
        Write-Host ""
        
        $params = @{ 'Version' = 'latest' }
        if (${check-only}) { $params['check-only'] = $true }
        if (${what-if}) { $params['what-if'] = $true }
        
        $result = Install-CoreTools @params
        
        $endTime = Get-Date
        $totalDuration = $endTime - $startTime
        
        Write-Host ""
        Write-Host "🎯 Setup Summary" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        if ($result) {
            Write-Host "✅ Core Tools Setup: Success ($([math]::Round($totalDuration.TotalSeconds, 1))s)" -ForegroundColor Green
            Write-Host ""
            Write-Host "⏱️  Total duration: $([math]::Round($totalDuration.TotalMinutes, 1)) minutes" -ForegroundColor Gray
            Write-Host ""
            Write-Host "🎉 Core tools setup completed successfully!" -ForegroundColor Green
            Write-Host ""
            exit 0
        } else {
            Write-Host "❌ Core Tools Setup: Failed" -ForegroundColor Red
            Write-Host ""
            Write-Host "⏱️  Duration before failure: $([math]::Round($totalDuration.TotalMinutes, 1)) minutes" -ForegroundColor Gray
            Write-Host ""
            Write-Error "Core tools setup failed"
            exit 1
        }
        
    } catch {
        Write-Error "Critical error during setup: $($_.Exception.Message)"
        Write-Host "Stack trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        exit 1
    }
    
} else {
    # Running in PowerShell 5.1, bootstrap to PowerShell 7
    $exitCode = Invoke-InPowerShell7 -what-if:${what-if} -check-only:${check-only}
    exit $exitCode
}

#endregion
