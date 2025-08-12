# Test Ubuntu Detection Logic
Write-Host "Testing Ubuntu Distribution Detection..." -ForegroundColor Yellow

$availableUbuntuDistros = @("Ubuntu-24.04", "Ubuntu-22.04", "Ubuntu-20.04", "Ubuntu")
$ubuntuDistro = $null

try {
    Write-Host "Checking WSL status for default distribution..." -ForegroundColor Cyan
    
    # First, try to get the default distribution from wsl --status
    $wslStatus = wsl --status 2>$null
    if ($wslStatus) {
        Write-Host "WSL Status output:" -ForegroundColor Gray
        $wslStatus | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        
        $defaultDistroLine = $wslStatus | Where-Object { $_ -match "Default Distribution:" }
        if ($defaultDistroLine) {
            $defaultDistro = ($defaultDistroLine -split ":")[1].Trim()
            Write-Host "Default distribution found: '$defaultDistro'" -ForegroundColor Green
            
            if ($defaultDistro -and $availableUbuntuDistros -contains $defaultDistro) {
                $ubuntuDistro = $defaultDistro
                Write-Host "✅ SUCCESS: Found default Ubuntu distribution: $ubuntuDistro" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Default distribution '$defaultDistro' is not Ubuntu, checking list..." -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠️  No default distribution line found in status" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  No WSL status output received" -ForegroundColor Yellow
    }
    
    # If default isn't Ubuntu, check the full list
    if (-not $ubuntuDistro) {
        Write-Host "Checking WSL distribution list..." -ForegroundColor Cyan
        $distributions = wsl --list --quiet 2>$null
        if ($distributions) {
            Write-Host "WSL Distribution list output:" -ForegroundColor Gray
            $distributions | ForEach-Object { Write-Host "  '$_'" -ForegroundColor Gray }
            
            foreach ($distroName in $availableUbuntuDistros) {
                foreach ($line in $distributions) {
                    if ($line -and $line -notmatch "^Windows Subsystem") {
                        $cleanLine = $line -replace '[^\x20-\x7F]', ''
                        Write-Host "Checking: '$cleanLine' against '$distroName'" -ForegroundColor Gray
                        if ($cleanLine -like "*$distroName*") {
                            $ubuntuDistro = $distroName
                            Write-Host "✅ SUCCESS: Found Ubuntu distribution in list: $ubuntuDistro" -ForegroundColor Green
                            break
                        }
                    }
                }
                if ($ubuntuDistro) { break }
            }
        } else {
            Write-Host "❌ No WSL distributions found in list output" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "❌ ERROR: Could not detect Ubuntu distributions: $($_.Exception.Message)" -ForegroundColor Red
}

# Final result
if ($ubuntuDistro) {
    Write-Host "`n🎉 FINAL RESULT: Ubuntu distribution detected: $ubuntuDistro" -ForegroundColor Green
} else {
    Write-Host "`n❌ FINAL RESULT: No Ubuntu distribution found" -ForegroundColor Red
}
