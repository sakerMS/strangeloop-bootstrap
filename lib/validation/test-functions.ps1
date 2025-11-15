# strangeloop Setup - Shared Test Functions
# Version: 1.0.0

# Testing and validation functions for system requirements and tool availability

function Test-Command {
    param([string]$Command)
    
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-AdminPrivileges {
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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

function Test-WindowsVersion {
    param([string]$MinimumVersion = "10.0")
    
    try {
        $osVersion = [System.Environment]::OSVersion.Version
        $requiredVersion = [Version]$MinimumVersion
        return $osVersion -ge $requiredVersion
    } catch {
        return $false
    }
}

function Test-PowerShellVersion {
    param([string]$MinimumVersion = "5.1")
    
    try {
        $psVersion = $PSVersionTable.PSVersion
        $requiredVersion = [Version]$MinimumVersion
        return $psVersion -ge $requiredVersion
    } catch {
        return $false
    }
}

function Test-DiskSpace {
    param(
        [string]$Path = "C:\",
        [int]$RequiredGB = 5
    )
    
    try {
        $drive = Get-PSDrive -Name $Path.Substring(0,1) -ErrorAction Stop
        $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
        return $freeSpaceGB -ge $RequiredGB
    } catch {
        return $false
    }
}

function Get-ToolVersion {
    param([string]$Tool)
    
    try {
        switch ($Tool.ToLower()) {
            "git" {
                $output = git --version 2>$null
                if ($output -match "git version ([0-9]+\.[0-9]+\.[0-9]+)") {
                    return $matches[1]
                }
            }
            "az" {
                $output = az version --output json 2>$null | ConvertFrom-Json
                return $output.'azure-cli'
            }
            "git-lfs" {
                $output = git lfs version 2>$null
                if ($output -match "git-lfs/([0-9]+\.[0-9]+\.[0-9]+)") {
                    return $matches[1]
                }
            }
            "docker" {
                $output = docker --version 2>$null
                if ($output -match "Docker version ([0-9]+\.[0-9]+\.[0-9]+)") {
                    return $matches[1]
                }
            }
            "strangeloop" {
                $output = strangeloop version 2>$null
                $outputString = $output -join "`n"
                if ($outputString -match "\[INFO\] strangeloop ([0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9]+)?)") {
                    return $matches[1]
                }
            }
            "python" {
                # Test if Python actually works (not just the Microsoft Store alias)
                try {
                    $output = python --version 2>&1
                    if ($output -like "*was not found*" -or $output -like "*Microsoft Store*") {
                        return $null
                    }
                    if ($output -match "Python ([0-9]+\.[0-9]+\.[0-9]+)") {
                        return $matches[1]
                    }
                } catch {
                    return $null
                }
            }
            "pip" {
                $output = pip --version 2>$null
                if ($output -match "pip ([0-9]+\.[0-9]+\.[0-9]+)") {
                    return $matches[1]
                }
            }
            "poetry" {
                $output = poetry --version 2>$null
                if ($output -match "Poetry \(version ([0-9]+\.[0-9]+\.[0-9]+)\)") {
                    return $matches[1]
                }
            }
        }
    } catch {
        return $null
    }
    
    return $null
}

function Invoke-CommandWithTimeout {
    param(
        [scriptblock]$ScriptBlock,
        [int]$TimeoutSeconds = 300,
        [string]$Description = "Command"
    )
    
    try {
        $job = Start-Job -ScriptBlock $ScriptBlock
        $result = Wait-Job $job -Timeout $TimeoutSeconds
        
        if ($result) {
            $output = Receive-Job $job
            Remove-Job $job
            return @{
                Success = $true
                Output = $output
                Error = $null
            }
        } else {
            Stop-Job $job
            Remove-Job $job
            return @{
                Success = $false
                Output = $null
                Error = "Command timed out after $TimeoutSeconds seconds"
            }
        }
    } catch {
        return @{
            Success = $false
            Output = $null
            Error = $_.Exception.Message
        }
    }
}

function Test-SystemRequirements {
    param([switch]$Detailed)
    
    $results = @{
        WindowsVersion = Test-WindowsVersion
        PowerShellVersion = Test-PowerShellVersion  
        DiskSpace = Test-DiskSpace -RequiredGB 5
        InternetConnection = Test-InternetConnection
        AdminPrivileges = Test-AdminPrivileges
    }
    
    $overallSuccess = $true
    foreach ($result in $results.Values) {
        if (-not $result) {
            $overallSuccess = $false
            break
        }
    }
    
    if ($Detailed) {
        foreach ($requirement in $results.GetEnumerator()) {
            if ($requirement.Value) {
                Write-Success "$($requirement.Key): Passed"
            } else {
                Write-Error "$($requirement.Key): Failed"
            }
        }
    }
    
    return @{
        Success = $overallSuccess
        Results = $results
    }
}

function Test-DirectoryWritable {
    param([string]$Path)
    
    try {
        $testFile = Join-Path $Path "test_write_$(Get-Random).tmp"
        $null = New-Item -Path $testFile -ItemType File -Force
        Remove-Item $testFile -Force
        return $true
    } catch {
        return $false
    }
}

function Test-InstallationPrerequisites {
    <#
    .SYNOPSIS
    Tests if the required package managers and tools are available for installation
    
    .DESCRIPTION
    Validates that winget and Python/pip are available before attempting tool installations
    
    .PARAMETER RequireWinget
    Whether winget is required (default: true)
    
    .PARAMETER RequirePython
    Whether Python is required (default: false, set to true for Poetry installation)
    
    .PARAMETER Detailed
    Show detailed results for each prerequisite
    #>
    param(
        [bool]$RequireWinget = $true,
        [bool]$RequirePython = $false,
        [switch]$Detailed
    )
    
    $results = @{}
    $overallSuccess = $true
    
    if ($RequireWinget) {
        Write-Info "Checking winget availability..."
        $wingetAvailable = Test-Command "winget"
        $results["WinGet Available"] = $wingetAvailable
        
        if (-not $wingetAvailable) {
            $overallSuccess = $false
            Write-Error "winget (Windows Package Manager) is not available"
            Write-Info "winget is required for automated tool installation"
            Write-Info "Solutions:"
            Write-Info "  • Update to Windows 10 version 1809 or later"
            Write-Info "  • Install App Installer from Microsoft Store"
            Write-Info "  • Download winget from: https://github.com/microsoft/winget-cli"
        } else {
            # Test if winget is functional
            try {
                $wingetTest = winget --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "winget is available and functional"
                    $results["WinGet Functional"] = $true
                } else {
                    Write-Warning "winget is available but may not be functional"
                    $results["WinGet Functional"] = $false
                }
            } catch {
                Write-Warning "winget availability test failed: $($_.Exception.Message)"
                $results["WinGet Functional"] = $false
            }
        }
    }
    
    if ($RequirePython) {
        Write-Info "Checking Python availability..."
        
        # Check if Python command is available (skip MS Store alias)
        $pythonAvailable = $false
        try {
            $pythonCommand = Get-Command "python" -ErrorAction Stop
            if ($pythonCommand.Source -like "*WindowsApps*") {
                Write-Warning "Found Windows Store Python alias, not a real installation"
                $results["Python Available"] = $false
            } else {
                $pythonVersion = python --version 2>&1
                if ($pythonVersion -match "Python (\d+\.\d+\.\d+)") {
                    Write-Success "Python $($matches[1]) is available"
                    $pythonAvailable = $true
                    $results["Python Available"] = $true
                    
                    # Test pip availability
                    Write-Info "Checking pip availability..."
                    try {
                        $null = python -m pip --version 2>$null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "pip is available and functional"
                            $results["pip Available"] = $true
                        } else {
                            Write-Warning "pip is not available or not working"
                            $results["pip Available"] = $false
                            $overallSuccess = $false
                        }
                    } catch {
                        Write-Warning "pip test failed: $($_.Exception.Message)"
                        $results["pip Available"] = $false
                        $overallSuccess = $false
                    }
                } else {
                    Write-Warning "Python command available but version detection failed"
                    $results["Python Available"] = $false
                }
            }
        } catch {
            Write-Warning "Python command not found"
            $results["Python Available"] = $false
        }
        
        if (-not $pythonAvailable) {
            $overallSuccess = $false
            Write-Error "Python is required but not properly installed"
            Write-Info "Solutions:"
            Write-Info "  • Install Python first using: winget install Python.Python.3.12"
            Write-Info "  • Download from: https://www.python.org/downloads/"
        }
    }
    
    # Test internet connectivity for downloads
    Write-Info "Checking internet connectivity..."
    $internetAvailable = Test-InternetConnection
    $results["Internet Connection"] = $internetAvailable
    
    if (-not $internetAvailable) {
        $overallSuccess = $false
        Write-Error "Internet connection is required for tool installation"
    } else {
        Write-Success "Internet connection is available"
    }
    
    if ($Detailed) {
        Write-Info "Prerequisites validation summary:"
        foreach ($requirement in $results.GetEnumerator()) {
            if ($requirement.Value) {
                Write-Success "  ✓ $($requirement.Key)"
            } else {
                Write-Warning "  ✗ $($requirement.Key)"
            }
        }
    }
    
    return @{
        Success = $overallSuccess
        Results = $results
        WingetAvailable = $results["WinGet Available"]
        PythonAvailable = $results["Python Available"]
        PipAvailable = $results["pip Available"]
        InternetAvailable = $results["Internet Connection"]
    }
}

# Export functions for module usage only
if ($MyInvocation.MyCommand.ModuleName) {
    Export-ModuleMember -Function @(
        'Test-Command',
        'Test-AdminPrivileges',
        'Test-InternetConnection', 
        'Test-WindowsVersion',
        'Test-PowerShellVersion',
        'Test-DiskSpace',
        'Get-ToolVersion',
        'Invoke-CommandWithTimeout',
        'Test-SystemRequirements',
        'Test-DirectoryWritable',
        'Test-InstallationPrerequisites'
    )
}
