# strangeloop Setup - Shared Path Functions (Minimal)
# Version: 1.0.0

# Essential path handling functions - unused functions removed

function Convert-WindowsPathToWSL {
    <#
    .SYNOPSIS
        Converts a Windows path to WSL format
    
    .PARAMETER WindowsPath
        The Windows path to convert
    
    .EXAMPLE
        Convert-WindowsPathToWSL "C:\Users\john\project" # Returns: /mnt/c/users/john/project
    #>
    param(
        [Parameter(Mandatory)]
        [string]$WindowsPath
    )
    
    if ([string]::IsNullOrEmpty($WindowsPath)) {
        return $WindowsPath
    }
    
    # Handle UNC paths
    if ($WindowsPath.StartsWith('\\')) {
        Write-Warning "UNC paths are not supported in WSL conversion: $WindowsPath"
        return $WindowsPath
    }
    
    # Convert drive letter paths (C:\path -> /mnt/c/path)
    if ($WindowsPath -match '^([A-Za-z]):(.*)$') {
        $driveLetter = $Matches[1].ToLower()
        $pathPart = $Matches[2] -replace '\\', '/'
        return "/mnt/$driveLetter$pathPart"
    }
    
    # If it's already a Unix-style path, return as-is
    if ($WindowsPath.StartsWith('/') -or $WindowsPath.Contains('/home/')) {
        return $WindowsPath
    }
    
    # For relative paths, just convert backslashes to forward slashes
    return $WindowsPath -replace '\\', '/'
}

function Convert-WSLPathToWindows {
    <#
    .SYNOPSIS
        Converts a WSL path to Windows format
    
    .PARAMETER WSLPath
        The WSL path to convert
    
    .EXAMPLE
        Convert-WSLPathToWindows "/mnt/c/users/john/project" # Returns: C:\users\john\project
    #>
    param(
        [Parameter(Mandatory)]
        [string]$WSLPath
    )
    
    if ([string]::IsNullOrEmpty($WSLPath)) {
        return $WSLPath
    }
    
    # Convert /mnt/drive/path to Windows drive format
    if ($WSLPath -match '^/mnt/([a-z])/(.*)$') {
        $driveLetter = $Matches[1].ToUpper()
        $pathPart = $Matches[2] -replace '/', '\'
        return "${driveLetter}:\$pathPart"
    }
    
    # If it's already a Windows path, return as-is
    if ($WSLPath -match '^[A-Za-z]:') {
        return $WSLPath
    }
    
    # For other Unix paths (like /home/), return as-is since they don't have Windows equivalents
    return $WSLPath
}

function Test-PathExists {
    <#
    .SYNOPSIS
        Tests if a path exists, handling both Windows and WSL paths
    
    .PARAMETER Path
        The path to test
    
    .PARAMETER PathType
        The type of path to check for: 'Any', 'File', 'Directory'
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [ValidateSet('Any', 'File', 'Directory')]
        [string]$PathType = 'Any'
    )
    
    if ([string]::IsNullOrEmpty($Path)) {
        return $false
    }
    
    try {
        switch ($PathType) {
            'File' { 
                return Test-Path $Path -PathType Leaf 
            }
            'Directory' { 
                return Test-Path $Path -PathType Container 
            }
            default { 
                return Test-Path $Path 
            }
        }
    } catch {
        return $false
    }
}

function New-DirectoryIfNotExists {
    <#
    .SYNOPSIS
        Creates a directory if it doesn't exist
    
    .PARAMETER Path
        The directory path to create
    
    .PARAMETER Force
        Force creation even if parent directories don't exist
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$Force
    )
    
    if ([string]::IsNullOrEmpty($Path)) {
        throw "Path cannot be null or empty"
    }
    
    if (-not (Test-PathExists -Path $Path -PathType Directory)) {
        try {
            if ($Force) {
                $null = New-Item -Path $Path -ItemType Directory -Force
            } else {
                $null = New-Item -Path $Path -ItemType Directory
            }
            Write-Verbose "Created directory: $Path"
        } catch {
            Write-Error "Failed to create directory '$Path': $($_.Exception.Message)"
            throw
        }
    }
}

function Update-EnvironmentPath {
    <#
    .SYNOPSIS
        Comprehensive PATH refresh function for tool installations
    
    .DESCRIPTION
        Refreshes the current session's PATH environment variable using multiple methods:
        1. Environment variables refresh
        2. Registry-based refresh (primary method)
        3. Common installation paths checking and addition
        
        This function consolidates PATH refresh logic used across multiple installation scripts.
    
    .PARAMETER ToolName
        The name of the tool for logging purposes (e.g., "Azure CLI", "strangeloop CLI")
    
    .PARAMETER CommonPaths
        Array of common installation paths to check and add if found
    
    .PARAMETER WaitSeconds
        Number of seconds to wait after PATH refresh for changes to take effect (default: 2)
    
    .OUTPUTS
        Boolean indicating whether the PATH refresh was successful
    
    .EXAMPLE
        Update-EnvironmentPath -ToolName "strangeloop CLI" -CommonPaths @(
            "C:\Program Files (x86)\Microsoft strangeloop CLI",
            "C:\Program Files\Microsoft strangeloop CLI"
        )
    
    .EXAMPLE
        Update-EnvironmentPath -ToolName "Azure CLI" -CommonPaths @(
            "${env:ProgramFiles}\Microsoft SDKs\Azure\CLI2\wbin",
            "${env:LOCALAPPDATA}\Programs\Azure CLI\wbin"
        ) -WaitSeconds 3
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        
        [Parameter(Mandatory = $false)]
        [string[]]$CommonPaths = @(),
        
        [Parameter(Mandatory = $false)]
        [int]$WaitSeconds = 2
    )
    
    try {
        Write-Info "Refreshing environment PATH for $ToolName..."
        
        # Method 1: Refresh from environment variables
        Write-Verbose "Method 1: Refreshing from environment variables..."
        $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Method 2: Refresh from registry (primary method)
        Write-Verbose "Method 2: Refreshing from registry..."
        try {
            $machinePath = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $userPath = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $env:PATH = $machinePath + ";" + $userPath
            Write-Info "PATH refreshed from registry for $ToolName"
        } catch {
            Write-Warning "Could not refresh PATH from registry: $($_.Exception.Message)"
        }
        
        # Method 3: Check common installation locations and add to PATH if found
        if ($CommonPaths.Count -gt 0) {
            Write-Verbose "Method 3: Checking common installation locations..."
            foreach ($path in $CommonPaths) {
                # Expand environment variables in the path
                $expandedPath = [Environment]::ExpandEnvironmentVariables($path)
                
                if (Test-PathExists -Path $expandedPath -PathType Directory) {
                    Write-Info "Found $ToolName installation at: $expandedPath"
                    if ($env:PATH -notlike "*$expandedPath*") {
                        $env:PATH = $env:PATH + ";" + $expandedPath
                        Write-Info "Added to current session PATH: $expandedPath"
                    } else {
                        Write-Verbose "$ToolName path already in PATH: $expandedPath"
                    }
                } else {
                    Write-Verbose "$ToolName not found at: $expandedPath"
                }
            }
        }
        
        # Wait for PATH changes to take effect
        if ($WaitSeconds -gt 0) {
            Write-Verbose "Waiting $WaitSeconds seconds for PATH changes to take effect..."
            Start-Sleep -Seconds $WaitSeconds
        }
        
        Write-Verbose "PATH refresh completed for $ToolName"
        return $true
        
    } catch {
        Write-Warning "Error during PATH refresh for $ToolName`: $($_.Exception.Message)"
        return $false
    }
}

function Get-CommonToolPaths {
    <#
    .SYNOPSIS
        Returns common installation paths for well-known tools
    
    .PARAMETER ToolName
        The name of the tool to get paths for
    
    .OUTPUTS
        Array of common installation paths for the specified tool
    
    .EXAMPLE
        Get-CommonToolPaths -ToolName "strangeloop"
        
    .EXAMPLE
        Get-CommonToolPaths -ToolName "azure-cli"
    #>
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
            Write-Warning "Unknown tool: $ToolName"
            return @()
        }
    }
}
