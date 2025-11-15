# strangeloop Setup - Shared Version Functions (Minimal)
# Version: 1.0.0

# Essential version management - unused functions removed

function ConvertFrom-Yaml {
    <#
    .SYNOPSIS
        Simple YAML parser for basic key-value pairs and nested structures
    
    .PARAMETER YamlString
        The YAML string to parse
    
    .RETURNS
        Hashtable representing the YAML structure
    #>
    param(
        [Parameter(Mandatory)]
        [string]$YamlString
    )
    
    $result = @{}
    $lines = $YamlString -split "`n" | Where-Object { $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") }
    
    foreach ($line in $lines) {
        $line = $line.Trim()
        
        # Handle key-value pairs
        if ($line -match '^([^:]+):\s*(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            
            # Remove quotes if present
            if ($value -match '^["\''](.*)["\'']\s*$') {
                $value = $Matches[1]
            }
            
            # Handle nested structure (simple support)
            if ($key.Contains('.')) {
                $keyParts = $key -split '\.'
                $current = $result
                
                for ($i = 0; $i -lt $keyParts.Length - 1; $i++) {
                    $part = $keyParts[$i]
                    if (-not $current.ContainsKey($part)) {
                        $current[$part] = @{}
                    }
                    $current = $current[$part]
                }
                
                $current[$keyParts[-1]] = $value
            } else {
                $result[$key] = $value
            }
        }
    }
    
    return $result
}

function Get-BootstrapScriptVersion {
    <#
    .SYNOPSIS
        Gets the bootstrap script version from unified bootstrap_config.yaml
    
    .RETURNS
        Version string from the bootstrap configuration
    #>
    
    try {
        # Look for bootstrap_config.yaml in the bootstrap config directory
        $configPath = ""
        $currentDir = $PSScriptRoot
        
        # Walk up directory tree to find bootstrap config
        while ($currentDir -and -not (Test-Path (Join-Path $currentDir "config\bootstrap_config.yaml"))) {
            $parentDir = Split-Path $currentDir -Parent
            if ($parentDir -eq $currentDir) {
                break  # Reached root without finding file
            }
            $currentDir = $parentDir
        }
        
        if ($currentDir) {
            $configPath = Join-Path $currentDir "config\bootstrap_config.yaml"
        }
        
        if (-not $configPath -or -not (Test-Path $configPath)) {
            # Fallback: try relative to this script
            $fallbackPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config\bootstrap_config.yaml"
            if (Test-Path $fallbackPath) {
                $configPath = $fallbackPath
            } else {
                Write-Warning "bootstrap_config.yaml not found, using default version"
                return "0.1.0"  # Default fallback version
            }
        }
        
        $content = Get-Content $configPath -Raw
        
        # Extract bootstrap script version using regex
        if ($content -match 'bootstrap_script:\s*\n\s*version:\s*["\''](.*?)["\'']\s*\n') {
            return $Matches[1]
        } else {
            Write-Warning "Version not found in bootstrap_config.yaml, using default"
            return "0.1.0"
        }
        
    } catch {
        Write-Warning "Error reading bootstrap version: $($_.Exception.Message)"
        return "0.1.0"
    }
}

function Get-PrereqVersionConfig {
    <#
    .SYNOPSIS
        Gets version configuration for prerequisites from bootstrap_config.yaml
    
    .RETURNS
        Hashtable with version requirements for tools
    #>
    
    try {
        # Look for bootstrap_config.yaml in the bootstrap config directory
        $configPath = ""
        $currentDir = $PSScriptRoot
        
        # Walk up directory tree to find bootstrap config
        while ($currentDir -and -not (Test-Path (Join-Path $currentDir "config\bootstrap_config.yaml"))) {
            $parentDir = Split-Path $currentDir -Parent
            if ($parentDir -eq $currentDir) {
                break  # Reached root without finding file
            }
            $currentDir = $parentDir
        }
        
        if ($currentDir) {
            $configPath = Join-Path $currentDir "config\bootstrap_config.yaml"
        }
        
        if (-not $configPath -or -not (Test-Path $configPath)) {
            # Fallback: try relative to this script
            $fallbackPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config\bootstrap_config.yaml"
            if (Test-Path $fallbackPath) {
                $configPath = $fallbackPath
            } else {
                return @{}
            }
        }
        
        # Read and parse the specific tool configurations we need
        $content = Get-Content $configPath -Raw
        $versionConfig = @{}
        
        # Parse tool sections using regex patterns
        $toolPatterns = @{
            'strangeloop_cli' = 'strangeloop_cli:\s*\n\s*minimum_version:\s*["\''](.*?)["\'']\s*\n\s*recommended_version:\s*["\''](.*?)["\'']\s*\n\s*notes:\s*["\''](.*?)["\'']\s*'
            'azure_cli' = 'azure_cli:\s*\n\s*minimum_version:\s*["\''](.*?)["\'']\s*\n\s*recommended_version:\s*["\''](.*?)["\'']\s*\n\s*notes:\s*["\''](.*?)["\'']\s*'
            'git' = 'git:\s*\n\s*minimum_version:\s*["\''](.*?)["\'']\s*\n\s*recommended_version:\s*["\''](.*?)["\'']\s*\n\s*notes:\s*["\''](.*?)["\'']\s*'
            'python' = 'python:\s*\n\s*minimum_version:\s*["\''](.*?)["\'']\s*\n\s*recommended_version:\s*["\''](.*?)["\'']\s*\n\s*notes:\s*["\''](.*?)["\'']\s*'
            'poetry' = 'poetry:\s*\n\s*minimum_version:\s*["\''](.*?)["\'']\s*\n\s*recommended_version:\s*["\''](.*?)["\'']\s*\n\s*notes:\s*["\''](.*?)["\'']\s*'
            'docker' = 'docker:\s*\n\s*minimum_version:\s*["\''](.*?)["\'']\s*\n\s*recommended_version:\s*["\''](.*?)["\'']\s*\n\s*notes:\s*["\''](.*?)["\'']\s*'
            'git_lfs' = 'git_lfs:\s*\n\s*minimum_version:\s*["\''](.*?)["\'']\s*\n\s*recommended_version:\s*["\''](.*?)["\'']\s*\n\s*notes:\s*["\''](.*?)["\'']\s*'
        }
        
        foreach ($toolName in $toolPatterns.Keys) {
            $pattern = $toolPatterns[$toolName]
            if ($content -match $pattern) {
                $versionConfig[$toolName] = @{
                    'minimum_version' = $Matches[1]
                    'recommended_version' = $Matches[2]  
                    'notes' = $Matches[3]
                }
            }
        }
        
        return $versionConfig
        
    } catch {
        Write-Warning "Failed to read prerequisite configuration: $($_.Exception.Message)"
        return @{}
    }
}

function Test-ToolVersionCompliance {
    <#
    .SYNOPSIS
        Tests if a tool version meets minimum requirements
    
    .PARAMETER ToolName
        Name of the tool to check
    
    .PARAMETER InstalledVersion
        Currently installed version
    
    .PARAMETER TargetDistro
        Target distribution (for WSL scenarios)
    
    .RETURNS
        Hashtable with compliance information
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ToolName,
        
        [Parameter(Mandatory)]
        [string]$InstalledVersion,
        
        [string]$TargetDistro
    )
    
    try {
        # Get configuration requirements
        $config = Get-PrereqVersionConfig
        
        # Default compliance result
        $result = @{
            IsCompliant = $true
            CurrentVersion = $InstalledVersion
            RequiredVersion = "any"
            RecommendedVersion = "latest"
            Status = "Compliant"
            Action = "None required"
        }
        
        # If no configuration found, assume compliance
        if (-not $config -or -not $config.ContainsKey($ToolName)) {
            return $result
        }
        
        $toolConfig = $config[$ToolName]
        if (-not $toolConfig) {
            return $result
        }
        
        # Extract version requirements
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
        
        # Handle special cases
        if ($InstalledVersion -eq "unknown-but-functional") {
            $result.Status = "Unknown"
            $result.Action = "Version detection failed but tool appears functional"
            return $result
        }
        
        # If minimum version is specified, check compliance
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
        Write-Warning "Error checking version compliance for $ToolName`: $($_.Exception.Message)"
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
    <#
    .SYNOPSIS
        Compares two semantic version strings
    
    .PARAMETER Version1
        First version to compare
    
    .PARAMETER Version2
        Second version to compare
    
    .PARAMETER Operator
        Comparison operator: "eq", "gt", "gte", "lt", "lte"
    
    .RETURNS
        Boolean result of the comparison
    #>
    param(
        [string]$Version1,
        [string]$Version2,
        [string]$Operator = "eq"
    )
    
    try {
        # Clean version strings
        $v1 = $Version1 -replace '^v', '' -replace '[^\d\.].*$', ''
        $v2 = $Version2 -replace '^v', '' -replace '[^\d\.].*$', ''
        
        # Parse version components
        $v1Parts = $v1 -split '\.' | ForEach-Object { [int]$_ }
        $v2Parts = $v2 -split '\.' | ForEach-Object { [int]$_ }
        
        # Normalize to same length
        $maxLength = [Math]::Max($v1Parts.Length, $v2Parts.Length)
        while ($v1Parts.Length -lt $maxLength) { $v1Parts += 0 }
        while ($v2Parts.Length -lt $maxLength) { $v2Parts += 0 }
        
        # Compare
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
        
        # Versions are equal
        switch ($Operator) {
            "eq" { return $true }
            "gte" { return $true }
            "lte" { return $true }
            "gt" { return $false }
            "lt" { return $false }
        }
        
    } catch {
        Write-Warning "Error comparing versions $Version1 and $Version2`: $($_.Exception.Message)"
        return $false
    }
}

function Write-VersionComplianceReport {
    <#
    .SYNOPSIS
        Writes a compliance report for a tool version
    
    .PARAMETER ToolName
        Name of the tool
    
    .PARAMETER ComplianceResult
        Result from Test-ToolVersionCompliance
    
    .PARAMETER PromptForUpgrade
        Whether to prompt user for upgrade decisions
    
    .RETURNS
        Hashtable with user decision if PromptForUpgrade is used
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ToolName,
        
        [Parameter(Mandatory)]
        [hashtable]$ComplianceResult,
        
        [switch]$PromptForUpgrade
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
            
            if ($PromptForUpgrade) {
                $response = Read-Host "Would you like to upgrade $ToolName now? (y/N)"
                if ($response -eq 'y' -or $response -eq 'Y') {
                    return @{
                        ShouldUpgrade = $true
                        NewVersion = $ComplianceResult.RecommendedVersion
                    }
                }
            }
        }
        
        return @{
            ShouldUpgrade = $false
            NewVersion = $null
        }
        
    } catch {
        Write-Warning "Error writing compliance report: $($_.Exception.Message)"
        return @{
            ShouldUpgrade = $false
            NewVersion = $null
        }
    }
}
