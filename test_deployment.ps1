# Test StrangeLoop Standalone Setup Deployment
# This script validates that your standalone setup is properly configured

param(
    [string]$BaseUrl = "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap",
    [switch]$TestDownload,
    [switch]$ValidateScripts
)

Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║            StrangeLoop Standalone Setup Validator             ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "Testing deployment at: $BaseUrl" -ForegroundColor Gray
Write-Host ""

# Test script URLs
$scriptUrls = @{
    "Main" = "$BaseUrl/setup_strangeloop_main.ps1&version=GBstrangeloop-bootstrap&download=true"
    "Linux" = "$BaseUrl/setup_strangeloop_linux.ps1&version=GBstrangeloop-bootstrap&download=true"
    "Windows" = "$BaseUrl/setup_strangeloop_windows.ps1&version=GBstrangeloop-bootstrap&download=true"
}

function Test-ScriptUrl {
    param([string]$Url, [string]$ScriptName)
    
    Write-Host "Testing $ScriptName..." -NoNewline
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host " ✓" -ForegroundColor Green
            return $true
        } else {
            Write-Host " ✗ (HTTP $($response.StatusCode))" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host " ✗ ($($_.Exception.Message))" -ForegroundColor Red
        return $false
    }
}

# Test all script URLs
Write-Host "=== Testing Script Availability ===" -ForegroundColor Yellow
$allScriptsAvailable = $true

foreach ($script in $scriptUrls.GetEnumerator()) {
    $available = Test-ScriptUrl $script.Value $script.Key
    if (-not $available) {
        $allScriptsAvailable = $false
    }
}

if ($allScriptsAvailable) {
    Write-Host "`n✓ All scripts are accessible!" -ForegroundColor Green
} else {
    Write-Host "`n✗ Some scripts are not accessible!" -ForegroundColor Red
    Write-Host "Check your BaseUrl and ensure all scripts are uploaded." -ForegroundColor Yellow
}

# Test download functionality
if ($TestDownload) {
    Write-Host "`n=== Testing Download Functionality ===" -ForegroundColor Yellow
    
    try {
        Write-Host "Downloading main script content..." -NoNewline
        $response = Invoke-WebRequest -Uri $scriptUrls.Main -UseBasicParsing
        $content = $response.Content
        
        if ($content.Length -gt 0) {
            Write-Host " ✓ ($($content.Length) bytes)" -ForegroundColor Green
            
            # Basic content validation
            if ($content -match "param\(" -and $content -match "StrangeLoop") {
                Write-Host "✓ Script content appears valid" -ForegroundColor Green
            } else {
                Write-Host "⚠ Script content may be invalid" -ForegroundColor Yellow
            }
        } else {
            Write-Host " ✗ (Empty content)" -ForegroundColor Red
        }
    } catch {
        Write-Host " ✗ ($($_.Exception.Message))" -ForegroundColor Red
    }
}

# Validate script syntax
if ($ValidateScripts) {
    Write-Host "`n=== Validating Script Syntax ===" -ForegroundColor Yellow
    
    foreach ($script in $scriptUrls.GetEnumerator()) {
        Write-Host "Validating $($script.Key) syntax..." -NoNewline
        
        try {
            $response = Invoke-WebRequest -Uri $script.Value -UseBasicParsing
            $tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
            
            try {
                Set-Content -Path $tempFile -Value $response.Content -Encoding UTF8
                
                # Parse the script for syntax errors
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($tempFile, [ref]$null, [ref]$errors)
                
                if ($errors.Count -eq 0) {
                    Write-Host " ✓" -ForegroundColor Green
                } else {
                    Write-Host " ✗ ($($errors.Count) syntax errors)" -ForegroundColor Red
                    foreach ($syntaxError in $errors) {
                        Write-Host "  Line $($syntaxError.StartPosition.StartLine): $($syntaxError.Message)" -ForegroundColor Red
                    }
                }
            } finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Host " ✗ ($($_.Exception.Message))" -ForegroundColor Red
        }
    }
}

# Generate sample commands
Write-Host "`n=== Sample Usage Commands ===" -ForegroundColor Yellow
Write-Host "Basic installation:" -ForegroundColor Gray
Write-Host "  Invoke-WebRequest -Uri `"https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop.ps1&version=GBstrangeloop-bootstrap&download=true`" -OutFile `"setup_strangeloop.ps1`"; .\setup_strangeloop.ps1" -ForegroundColor White

Write-Host "`nWith custom parameters:" -ForegroundColor Gray
Write-Host "  .\setup_strangeloop.ps1 -UserName `"Your Name`" -UserEmail `"you@domain.com`"" -ForegroundColor White

Write-Host "`nSkip components:" -ForegroundColor Gray
Write-Host "  .\setup_strangeloop.ps1 -SkipPrerequisites -SkipDevelopmentTools" -ForegroundColor White

Write-Host "`n=== Deployment Status ===" -ForegroundColor Yellow
if ($allScriptsAvailable) {
    Write-Host "✓ Ready for deployment!" -ForegroundColor Green
    Write-Host "Users can now download and run the standalone setup." -ForegroundColor Gray
} else {
    Write-Host "✗ Deployment not ready" -ForegroundColor Red
    Write-Host "Fix the issues above before deploying to users." -ForegroundColor Gray
}

Write-Host ""
