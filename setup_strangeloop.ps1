# StrangeLoop CLI Setup Launcher
# This launcher script downloads and executes the modular setup scripts
# 
# Usage: .\setup_strangeloop.ps1 [parameters]
# Parameters:
#   -SkipPrerequisites    : Skip system prerequisite installation
#   -SkipDevelopmentTools : Skip development tools installation
#   -MaintenanceMode      : Update packages only (for existing installations)
#   -Verbose              : Enable detailed logging for troubleshooting
#   -UserName            : Git username for configuration
#   -UserEmail           : Git email for configuration
#   -BaseUrl             : Custom base URL for script downloads
# 
# All scripts are downloaded from GitHub and executed dynamically

param(
    [switch]$SkipPrerequisites,
    [switch]$SkipDevelopmentTools,
    [switch]$MaintenanceMode,
    [switch]$Verbose,
    [switch]$WhatIf,
    [string]$UserName,
    [string]$UserEmail,
    [string]$BaseUrl = "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main"
)

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Enable verbose output if Verbose is specified
if ($Verbose) {
    $VerbosePreference = "Continue"
    Write-Host "🔍 VERBOSE MODE ENABLED - Detailed logging activated" -ForegroundColor Cyan
}
if ($WhatIf) {
    Write-Host "🔍 WHATIF MODE ENABLED - No operations will be executed" -ForegroundColor Yellow
}

# Function to download script content
function Get-ScriptFromUrl {
    param([string]$Url, [string]$ScriptName)
    
    Write-Verbose "Attempting to download $ScriptName from $Url"
    Write-Host "Downloading $ScriptName..." -ForegroundColor Yellow
    try {
        Write-Verbose "Invoking web request..."
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Verbose "Download successful, content length: $($response.Content.Length) characters"
            Write-Host "✓ $ScriptName downloaded successfully" -ForegroundColor Green
            return $response.Content
        } else {
            throw "HTTP $($response.StatusCode)"
        }
    } catch {
        Write-Verbose "Download failed with error: $($_.Exception.Message)"
        Write-Host "✗ Failed to download $ScriptName from $Url" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Function to execute script content with parameters
function Invoke-ScriptContent {
    param([string]$ScriptContent, [hashtable]$Parameters = @{})
    
    Write-Verbose "Creating temporary script file for execution"
    # Create a temporary script file
    $tempScriptPath = [System.IO.Path]::GetTempFileName() + ".ps1"
    
    try {
        Write-Verbose "Temp script path: $tempScriptPath"
        # Write script content to temp file
        Set-Content -Path $tempScriptPath -Value $ScriptContent -Encoding UTF8
        
        # Build parameter array
        $paramArray = @()
        foreach ($key in $Parameters.Keys) {
            if ($Parameters[$key] -is [switch] -and $Parameters[$key]) {
                $paramArray += "-$key"
                Write-Verbose "Added switch parameter: -$key"
            } elseif ($Parameters[$key] -and $Parameters[$key] -ne $false) {
                $paramArray += "-$key", "`"$($Parameters[$key])`""
                Write-Verbose "Added parameter: -$key `"$($Parameters[$key])`""
            }
        }
        
        Write-Verbose "Executing script with parameters: $($paramArray -join ' ')"
        # Execute the script
        & $tempScriptPath @paramArray
        return $LASTEXITCODE
    } finally {
        # Clean up temp file
        if (Test-Path $tempScriptPath) {
            Write-Verbose "Cleaning up temporary script file"
            Remove-Item $tempScriptPath -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║           StrangeLoop CLI Setup - Standalone Launcher         ║
║                   Downloading Latest Scripts                  ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

Write-Host "`nThis launcher will download and execute the latest StrangeLoop setup scripts." -ForegroundColor Cyan
Write-Host "Source: GitHub - strangeloop-bootstrap repository" -ForegroundColor Gray
Write-Host "Base URL: $BaseUrl" -ForegroundColor Gray
if ($Verbose) { 
    Write-Verbose "Parameters received:"
    Write-Verbose "- SkipPrerequisites: $SkipPrerequisites"
    Write-Verbose "- SkipDevelopmentTools: $SkipDevelopmentTools"
    Write-Verbose "- MaintenanceMode: $MaintenanceMode"
    Write-Verbose "- UserName: $UserName"
    Write-Verbose "- UserEmail: $UserEmail"
}
Write-Host ""

# Define script URLs
$scriptUrls = @{
    "Main" = "$BaseUrl/scripts/strangeloop_main.ps1"
    "Linux" = "$BaseUrl/scripts/strangeloop_linux.ps1"
    "Windows" = "$BaseUrl/scripts/strangeloop_windows.ps1"
}

if ($Verbose) {
    Write-Verbose "Script URLs configured:"
    foreach ($script in $scriptUrls.GetEnumerator()) {
        Write-Verbose "- $($script.Key): $($script.Value)"
    }
}

try {
    # Download the main script
    Write-Host "=== Downloading Main Setup Script ===" -ForegroundColor Cyan
    $mainScriptContent = Get-ScriptFromUrl $scriptUrls.Main "strangeloop_main.ps1"
    
    # Prepare parameters for main script
    $mainParams = @{
        SkipPrerequisites = $SkipPrerequisites
        SkipDevelopmentTools = $SkipDevelopmentTools
        MaintenanceMode = $MaintenanceMode
        Verbose = $Verbose
        WhatIf = $WhatIf
        UserName = $UserName
        UserEmail = $UserEmail
        # Pass script URLs to main script so it can download Linux/Windows scripts
        LinuxScriptUrl = $scriptUrls.Linux
        WindowsScriptUrl = $scriptUrls.Windows
    }
    
    if ($Verbose) {
        Write-Verbose "Parameters prepared for main script:"
        foreach ($param in $mainParams.GetEnumerator()) {
            Write-Verbose "- $($param.Key): $($param.Value)"
        }
    }
    
    if ($WhatIf) {
        Write-Host "`n=== WhatIf Mode - Script Execution Preview ===" -ForegroundColor Yellow
        Write-Host "Would execute main script with the following operations:" -ForegroundColor Gray
        Write-Host "  • Prerequisites check (skipped: $SkipPrerequisites)" -ForegroundColor Gray
        Write-Host "  • Development tools setup (skipped: $SkipDevelopmentTools)" -ForegroundColor Gray
        Write-Host "  • Maintenance mode: $MaintenanceMode" -ForegroundColor Gray
        Write-Host "  • Target scripts: strangeloop_main.ps1" -ForegroundColor Gray
        if (-not $SkipDevelopmentTools) {
            Write-Host "  • Platform-specific setup (Linux/Windows)" -ForegroundColor Gray
        }
        Write-Host "`nNo actual operations performed in WhatIf mode." -ForegroundColor Yellow
        return 0
    }
    
    Write-Host "`n=== Executing Main Setup Script ===" -ForegroundColor Cyan
    $exitCode = Invoke-ScriptContent $mainScriptContent $mainParams
    
    Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
    if ($exitCode -eq 0) {
        Write-Host "✓ StrangeLoop setup completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "⚠ Setup completed with exit code: $exitCode" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "`n=== Setup Failed ===" -ForegroundColor Red
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check your internet connection" -ForegroundColor Gray
    Write-Host "2. Ensure you can access GitHub/external URLs" -ForegroundColor Gray
    Write-Host "3. Verify the BaseUrl parameter is correct" -ForegroundColor Gray
    Write-Host "4. Try running with administrator privileges" -ForegroundColor Gray
    Write-Host "5. Check if the repository URL is accessible in your browser" -ForegroundColor Gray
    $exitCode = 1
}

# Exit with the same code as the main script
exit $exitCode
