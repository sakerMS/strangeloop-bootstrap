# StrangeLoop CLI Setup Launcher
# This launcher script downloads and executes the modular setup scripts
# 
# Usage: .\setup-strangeloop.ps1 [parameters]
# All scripts are downloaded from GitHub and executed dynamically

param(
    [switch]$SkipPrerequisites,
    [switch]$SkipDevelopmentTools,
    [string]$UserName,
    [string]$UserEmail,
    [string]$BaseUrl = "https://msasg.visualstudio.com/Bing_Ads/_apis/git/repositories/AdsSnR_Containers/items?path=/strangeloop-bootstrap"
)

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Function to download script content
function Get-ScriptFromUrl {
    param([string]$Url, [string]$ScriptName)
    
    Write-Host "Downloading $ScriptName..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ $ScriptName downloaded successfully" -ForegroundColor Green
            return $response.Content
        } else {
            throw "HTTP $($response.StatusCode)"
        }
    } catch {
        Write-Host "✗ Failed to download $ScriptName from $Url" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Function to execute script content with parameters
function Invoke-ScriptContent {
    param([string]$ScriptContent, [hashtable]$Parameters = @{})
    
    # Create a temporary script file
    $tempScriptPath = [System.IO.Path]::GetTempFileName() + ".ps1"
    
    try {
        # Write script content to temp file
        Set-Content -Path $tempScriptPath -Value $ScriptContent -Encoding UTF8
        
        # Build parameter array
        $paramArray = @()
        foreach ($key in $Parameters.Keys) {
            if ($Parameters[$key] -is [switch] -and $Parameters[$key]) {
                $paramArray += "-$key"
            } elseif ($Parameters[$key] -and $Parameters[$key] -ne $false) {
                $paramArray += "-$key", "`"$($Parameters[$key])`""
            }
        }
        
        # Execute the script
        & $tempScriptPath @paramArray
        return $LASTEXITCODE
    } finally {
        # Clean up temp file
        if (Test-Path $tempScriptPath) {
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
Write-Host "Source: Azure DevOps - AdsSnR_Containers/strangeloop-bootstrap" -ForegroundColor Gray
Write-Host "Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host ""

# Define script URLs
$scriptUrls = @{
    "Main" = "$BaseUrl/setup_strangeloop_main.ps1?version=GBstrangeloop-bootstrap&download=true"
    "Linux" = "$BaseUrl/setup_strangeloop_linux.ps1?version=GBstrangeloop-bootstrap&download=true"
    "Windows" = "$BaseUrl/setup_strangeloop_windows.ps1?version=GBstrangeloop-bootstrap&download=true"
}

try {
    # Download the main script
    Write-Host "=== Downloading Main Setup Script ===" -ForegroundColor Cyan
    $mainScriptContent = Get-ScriptFromUrl $scriptUrls.Main "setup_strangeloop_main.ps1"
    
    # Prepare parameters for main script
    $mainParams = @{
        SkipPrerequisites = $SkipPrerequisites
        SkipDevelopmentTools = $SkipDevelopmentTools
        UserName = $UserName
        UserEmail = $UserEmail
        # Pass script URLs to main script so it can download Linux/Windows scripts
        LinuxScriptUrl = $scriptUrls.Linux
        WindowsScriptUrl = $scriptUrls.Windows
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
    # Fallback to local scripts if download fails and local scripts exist
    $localMainScript = ".\setup_strangeloop_main.ps1"
    if (Test-Path $localMainScript) {
        Write-Host "`n=== Download Failed - Using Local Scripts ===" -ForegroundColor Yellow
        Write-Host "✓ Found local scripts, proceeding with local execution..." -ForegroundColor Green
        
        # Prepare parameters for local script execution
        $localParams = @()
        if ($SkipPrerequisites) { $localParams += "-SkipPrerequisites" }
        if ($SkipDevelopmentTools) { $localParams += "-SkipDevelopmentTools" }
        if ($UserName) { $localParams += "-UserName", "`"$UserName`"" }
        if ($UserEmail) { $localParams += "-UserEmail", "`"$UserEmail`"" }
        
        # Execute local main script
        & $localMainScript @localParams
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host "`n✓ StrangeLoop setup completed successfully using local scripts!" -ForegroundColor Green
        } else {
            Write-Host "`n⚠ Setup completed with exit code: $exitCode" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n=== Setup Failed ===" -ForegroundColor Red
        Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
        Write-Host "1. Check your internet connection" -ForegroundColor Gray
        Write-Host "2. Ensure you can access GitHub/external URLs" -ForegroundColor Gray
        Write-Host "3. Verify the BaseUrl parameter is correct" -ForegroundColor Gray
        Write-Host "4. Try running with administrator privileges" -ForegroundColor Gray
        Write-Host "5. Download scripts manually to same folder as launcher" -ForegroundColor Gray
        $exitCode = 1
    }
}

# Exit with the same code as the main script
exit $exitCode
