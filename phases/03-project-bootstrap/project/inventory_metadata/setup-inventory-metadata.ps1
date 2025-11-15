# strangeloop Setup - Inventory Metadata Configuration
# Version: 1.0.0
# Purpose: Collect and configure inventory metadata for the project

param(
    [string]$ProjectPath,
    [string]$ProjectName,
    [string]$LoopName,
    [switch]$WhatIf,
    [switch]$CheckOnly,
    [switch]$SkipPrompt
)

# Import required modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")

function Test-ServiceTreeId {
    <#
    .SYNOPSIS
    Comprehensive validation of Service Tree ID (GUID)
    
    .DESCRIPTION
    Validates Service Tree ID format, checks against known patterns,
    and optionally validates against Service Tree API if available
    
    .PARAMETER ServiceTreeId
    The Service Tree ID to validate
    
    .RETURNS
    Hashtable with validation results
    #>
    param(
        [string]$ServiceTreeId
    )
    
    $result = @{
        IsValid = $false
        FormattedGuid = $null
        ErrorMessage = $null
        ValidationErrors = @()
        HasWarnings = $false
        Warnings = @()
    }
    
    # Basic null/empty check
    if ([string]::IsNullOrWhiteSpace($ServiceTreeId)) {
        $result.ErrorMessage = "Service Tree ID cannot be empty"
        $result.ValidationErrors += "Empty or null value provided"
        return $result
    }
    
    # Trim whitespace
    $ServiceTreeId = $ServiceTreeId.Trim()
    
    # Check for common invalid patterns
    if ($ServiceTreeId -match "^0+$|^0{8}-0{4}-0{4}-0{4}-0{12}$") {
        $result.ErrorMessage = "Invalid Service Tree ID: All zeros GUID is not allowed"
        $result.ValidationErrors += "Service Tree ID cannot be all zeros"
        return $result
    }
    
    # Validate GUID format
    try {
        $guid = [System.Guid]::Parse($ServiceTreeId)
        $result.FormattedGuid = $guid.ToString().ToLower()
        
        # Check for empty GUID
        if ($guid -eq [System.Guid]::Empty) {
            $result.ErrorMessage = "Invalid Service Tree ID: Empty GUID is not allowed"
            $result.ValidationErrors += "Service Tree ID cannot be empty GUID (00000000-0000-0000-0000-000000000000)"
            return $result
        }
        
        # Check GUID version (Service Tree typically uses version 4 UUIDs)
        $guidBytes = $guid.ToByteArray()
        $version = ($guidBytes[7] -shr 4) -band 0x0F
        if ($version -notin @(1, 4)) {
            $result.HasWarnings = $true
            $result.Warnings += "Service Tree ID appears to be version $version UUID. Service Tree typically uses version 1 or 4 UUIDs."
        }
        
        # Check for sequential or pattern-based GUIDs that might be test data
        $guidString = $result.FormattedGuid -replace '-', ''
        if ($guidString -match '^(12345678|abcdef|fedcba|123abc)' -or 
            $guidString -match '(1234|abcd){8}$' -or
            $guidString -match '^(\w)\1{31}$') {
            $result.HasWarnings = $true
            $result.Warnings += "This appears to be a test or placeholder GUID. Please verify this is a real Service Tree ID."
        }
        
        # Optional: Check if GUID looks like it could be from Microsoft's Service Tree
        # Service Tree GUIDs often have certain patterns in the timestamp portions
        if ($version -eq 1) {
            # Version 1 UUIDs contain timestamp - can validate timestamp is reasonable
            $timestampLow = [BitConverter]::ToUInt32($guidBytes[0..3], 0)
            if ($timestampLow -lt 100000000) {  # Very old timestamp, unlikely for Service Tree
                $result.HasWarnings = $true
                $result.Warnings += "This UUID has a very old timestamp. Please verify this is a current Service Tree ID."
            }
        }
        
        $result.IsValid = $true
        
    } catch {
        $result.ErrorMessage = "Invalid GUID format"
        $result.ValidationErrors += "Could not parse as valid GUID: $($_.Exception.Message)"
        $result.ValidationErrors += "Expected format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        $result.ValidationErrors += "Example: 12345678-1234-5678-9abc-123456789abc"
        return $result
    }
    
    # Service Tree API validation is not available (web app, not REST API)
    # Provide manual verification guidance instead
    if ($result.IsValid) {
        Write-Host "  ✅ Service Tree ID format validated successfully!" -ForegroundColor Green
        Write-Host "  📋 Please verify manually at: https://microsoftservicetree.com/services" -ForegroundColor Cyan
        Write-Host "     Search for service ID: $($result.FormattedGuid)" -ForegroundColor Gray
    }
    
    return $result
}



function Test-AdoAreaPath {
    <#
    .SYNOPSIS
    Comprehensive validation of Azure DevOps Area Path
    
    .DESCRIPTION
    Validates ADO Area Path format, checks against known patterns,
    and optionally validates against Azure DevOps organization if available
    
    .PARAMETER AdoAreaPath
    The ADO Area Path to validate
    
    .RETURNS
    Hashtable with validation results
    #>
    param(
        [string]$AdoAreaPath
    )
    
    $result = @{
        IsValid = $false
        FormattedPath = $null
        ErrorMessage = $null
        ValidationErrors = @()
        HasWarnings = $false
        Warnings = @()
    }
    
    # Basic null/empty check
    if ([string]::IsNullOrWhiteSpace($AdoAreaPath)) {
        $result.ErrorMessage = "ADO Area Path cannot be empty"
        $result.ValidationErrors += "Empty or null value provided"
        return $result
    }
    
    # Trim whitespace and normalize
    $AdoAreaPath = $AdoAreaPath.Trim()
    
    # Check for invalid characters
    $invalidChars = @('<', '>', ':', '"', '|', '?', '*', '/', '%')
    $foundInvalidChars = @()
    foreach ($char in $invalidChars) {
        if ($AdoAreaPath.Contains($char)) {
            $foundInvalidChars += $char
        }
    }
    
    if ($foundInvalidChars.Count -gt 0) {
        $result.ErrorMessage = "Invalid characters found in ADO Area Path"
        $result.ValidationErrors += "The following characters are not allowed: $($foundInvalidChars -join ', ')"
        $result.ValidationErrors += "ADO Area Paths can only contain letters, numbers, spaces, backslashes, and basic punctuation"
        return $result
    }
    
    # Check length constraints
    if ($AdoAreaPath.Length -gt 256) {
        $result.ErrorMessage = "ADO Area Path is too long"
        $result.ValidationErrors += "Maximum length is 256 characters (current: $($AdoAreaPath.Length))"
        return $result
    }
    
    # Check for proper backslash format
    if ($AdoAreaPath -notmatch '\\') {
        $result.HasWarnings = $true
        $result.Warnings += "Area path doesn't contain backslash separators. This may be a root-level area or project name only."
    }
    
    # Check for double backslashes or invalid separators
    if ($AdoAreaPath -match '\\\\') {
        $result.ErrorMessage = "Invalid area path format"
        $result.ValidationErrors += "Double backslashes (\\\\) are not allowed"
        return $result
    }
    
    # Check for leading/trailing backslashes
    if ($AdoAreaPath.StartsWith('\') -or $AdoAreaPath.EndsWith('\')) {
        $result.ErrorMessage = "Invalid area path format"
        $result.ValidationErrors += "Area path cannot start or end with backslash"
        return $result
    }
    
    # Split into components and validate each part
    $pathComponents = $AdoAreaPath.Split('\')
    $validatedComponents = @()
    
    foreach ($component in $pathComponents) {
        $trimmedComponent = $component.Trim()
        
        if ([string]::IsNullOrWhiteSpace($trimmedComponent)) {
            $result.ErrorMessage = "Invalid area path component"
            $result.ValidationErrors += "Empty components are not allowed (check for extra spaces around backslashes)"
            return $result
        }
        
        # Check component length
        if ($trimmedComponent.Length -gt 64) {
            $result.ErrorMessage = "Area path component is too long"
            $result.ValidationErrors += "Component '$trimmedComponent' exceeds 64 characters"
            return $result
        }
        
        # Check for reserved names
        $reservedNames = @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')
        if ($trimmedComponent.ToUpper() -in $reservedNames) {
            $result.ErrorMessage = "Reserved name used in area path"
            $result.ValidationErrors += "Component '$trimmedComponent' is a reserved system name"
            return $result
        }
        
        $validatedComponents += $trimmedComponent
    }
    
    # Reconstruct the normalized path
    $result.FormattedPath = $validatedComponents -join '\'
    
    # Check for common patterns and provide warnings
    if ($pathComponents.Count -eq 1) {
        $result.HasWarnings = $true
        $result.Warnings += "This appears to be a project name only. Consider using a more specific area path like 'Project\Area'"
    }
    
    if ($pathComponents.Count -gt 10) {
        $result.HasWarnings = $true
        $result.Warnings += "Very deep area path ($($pathComponents.Count) levels). Consider simplifying for better maintainability."
    }
    
    # Check for test/placeholder patterns
    $testPatterns = @('test', 'sample', 'example', 'temp', 'temporary', 'placeholder', 'todo', 'tbd')
    $foundTestPatterns = @()
    foreach ($component in $pathComponents) {
        foreach ($pattern in $testPatterns) {
            if ($component.ToLower() -like "*$pattern*") {
                $foundTestPatterns += $component
                break
            }
        }
    }
    
    if ($foundTestPatterns.Count -gt 0) {
        $result.HasWarnings = $true
        $result.Warnings += "Area path contains test/placeholder terms: $($foundTestPatterns -join ', '). Please verify this is the correct production area path."
    }
    
    $result.IsValid = $true
    
    # ADO Area Path API validation skipped - provide manual verification guidance
    if ($result.IsValid) {
        Write-Host "  ✅ ADO Area Path format validated successfully!" -ForegroundColor Green
        Write-Host "  📋 Please verify manually in Azure DevOps that this area path exists" -ForegroundColor Cyan
        Write-Host "     Area Path: $($result.FormattedPath)" -ForegroundColor Gray

    }
    
    return $result
}

function Update-YamlField {
    <#
    .SYNOPSIS
    Update a specific YAML field value, removing any inline comments
    
    .DESCRIPTION
    Updates a YAML field value and removes any trailing comments on the same line
    
    .PARAMETER Content
    The YAML content as a string
    
    .PARAMETER FieldName
    The name of the field to update
    
    .PARAMETER NewValue
    The new value for the field
    
    .PARAMETER Indent
    The indentation level (number of spaces)
    
    .PARAMETER QuoteValue
    Whether to quote the value (default: true, set to false for boolean/numeric values)
    
    .RETURNS
    Updated YAML content
    #>
    param(
        [string]$Content,
        [string]$FieldName,
        [string]$NewValue,
        [int]$Indent = 2,
        [bool]$QuoteValue = $true
    )
    
    # Pattern to match the entire line with the field, capturing indentation
    # This will match everything from the field name to the end of line (including all comments)
    $pattern = "(?m)^(\s*)${FieldName}:.*$"
    
    # Replacement with the new value (no trailing comment)
    if ($QuoteValue) {
        $replacement = "`$1${FieldName}: '$NewValue'"
    } else {
        $replacement = "`$1${FieldName}: $NewValue"
    }
    
    # Apply the replacement
    $updatedContent = $Content -replace $pattern, $replacement
    
    return $updatedContent
}



function Get-InventoryMetadataFromUser {
    <#
    .SYNOPSIS
    Collect inventory metadata information from the user
    
    .DESCRIPTION
    Prompts the user for service tree ID, production status, and ADO area path
    
    .RETURNS
    Hashtable with ServiceTreeId, IsProduction, and AdoAreaPath
    #>
    
    Write-Host ""
    Write-Host "📊 Inventory Metadata Configuration" -ForegroundColor Cyan
    Write-Host "───────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Info "This step will configure inventory metadata for your project."
    Write-Info "This information is used for service tracking, compliance, and deployment automation."
    Write-Host ""
    
    # Ask if user wants to configure inventory metadata
    do {
        $configureInventory = Read-Host "Do you want to configure inventory metadata for this project? (y/n) [y]"
        if ([string]::IsNullOrWhiteSpace($configureInventory)) {
            $configureInventory = "y"
        }
        $configureInventory = $configureInventory.ToLower()
    } while ($configureInventory -notin @("y", "yes", "n", "no"))
    
    if ($configureInventory -in @("n", "no")) {
        Write-Info "Skipping inventory metadata configuration"
        return $null
    }
    
    Write-Host ""
    Write-Info "Collecting inventory metadata information..."
    Write-Host ""
    
    # Collect Service Tree ID
    do {
        Write-Host "Service Tree ID:" -ForegroundColor Yellow
        Write-Host "  This is a GUID that identifies your service in the Microsoft Service Tree." -ForegroundColor Gray
        Write-Host "  Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -ForegroundColor Gray
        Write-Host "  Example: 12345678-1234-5678-9abc-123456789abc" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Default: DeliveryEngine-US (4b1d6723-2256-4aa0-b883-ee38c0fc8db5)" -ForegroundColor Green
        $serviceTreeId = Read-Host "Enter Service Tree ID (GUID) or press Enter for default"
        
        # Use default if empty
        if ([string]::IsNullOrWhiteSpace($serviceTreeId)) {
            $serviceTreeId = "4b1d6723-2256-4aa0-b883-ee38c0fc8db5"
            Write-Info "Using default Service Tree ID: DeliveryEngine-US"
        }
        
        # Enhanced GUID validation
        $validationResult = Test-ServiceTreeId $serviceTreeId
        if ($validationResult.IsValid) {
            $serviceTreeId = $validationResult.FormattedGuid
            if ($validationResult.HasWarnings) {
                foreach ($warning in $validationResult.Warnings) {
                    Write-Warning $warning
                }
                $continue = Read-Host "Continue with this Service Tree ID? (y/n) [y]"
                if ([string]::IsNullOrWhiteSpace($continue)) { $continue = "y" }
                if ($continue.ToLower() -in @("n", "no")) { continue }
            }
            break
        } else {
            Write-Warning $validationResult.ErrorMessage
            Write-Host "  Validation details:" -ForegroundColor Gray
            foreach ($validationError in $validationResult.ValidationErrors) {
                Write-Host "    • $validationError" -ForegroundColor Red
            }
        }
    } while ($true)
    
    Write-Host ""
    
    # Collect Production Status
    do {
        Write-Host "Production Status:" -ForegroundColor Yellow
        Write-Host "  Indicates whether this service handles production workloads." -ForegroundColor Gray
        Write-Host "  This affects compliance requirements and deployment processes." -ForegroundColor Gray
        $isProductionInput = Read-Host "Is this a production service? (y/n) [y]"
        
        if ([string]::IsNullOrWhiteSpace($isProductionInput)) {
            $isProductionInput = "y"
        }
        
        $isProductionInput = $isProductionInput.ToLower()
        if ($isProductionInput -in @("y", "yes", "true", "1")) {
            $isProduction = $true
            break
        } elseif ($isProductionInput -in @("n", "no", "false", "0")) {
            $isProduction = $false
            break
        } else {
            Write-Warning "Please enter 'y' for yes or 'n' for no"
        }
    } while ($true)
    
    Write-Host ""
    
    # Collect ADO Area Path
    do {
        Write-Host "Azure DevOps Area Path:" -ForegroundColor Yellow
        Write-Host "  The area path in Azure DevOps where work items for this service are tracked." -ForegroundColor Gray
        Write-Host "  Format: Project\Area\SubArea (e.g., 'MyProject\Services\WebAPI')" -ForegroundColor Gray
        Write-Host "  Example: 'Azure\Engineering\ServicePlatform'" -ForegroundColor Gray
        $adoAreaPath = Read-Host "Enter ADO Area Path"
        
        if ([string]::IsNullOrWhiteSpace($adoAreaPath)) {
            Write-Warning "ADO Area Path is required"
            continue
        }
        
        # Enhanced ADO Area Path validation
        $validationResult = Test-AdoAreaPath $adoAreaPath
        if ($validationResult.IsValid) {
            $adoAreaPath = $validationResult.FormattedPath
            if ($validationResult.HasWarnings) {
                foreach ($warning in $validationResult.Warnings) {
                    Write-Warning $warning
                }
                $continue = Read-Host "Continue with this ADO Area Path? (y/n) [y]"
                if ([string]::IsNullOrWhiteSpace($continue)) { $continue = "y" }
                if ($continue.ToLower() -in @("n", "no")) { continue }
            }
            break
        } else {
            Write-Warning $validationResult.ErrorMessage
            Write-Host "  Validation details:" -ForegroundColor Gray
            foreach ($validationError in $validationResult.ValidationErrors) {
                Write-Host "    • $validationError" -ForegroundColor Red
            }
        }
    } while ($true)
    
    Write-Host ""
    
    # Confirm the entered information
    Write-Host "📋 Review Inventory Metadata:" -ForegroundColor Cyan
    Write-Host "  Service Tree ID: $serviceTreeId" -ForegroundColor White
    Write-Host "  Production Service: $(if ($isProduction) { 'Yes' } else { 'No' })" -ForegroundColor White
    Write-Host "  ADO Area Path: $adoAreaPath" -ForegroundColor White
    Write-Host ""
    
    $confirmation = Read-Host "Is this information correct? (y/n) [y]"
    if ([string]::IsNullOrWhiteSpace($confirmation)) {
        $confirmation = "y"
    }
    
    if ($confirmation.ToLower() -in @("n", "no")) {
        Write-Info "Please re-run the script to enter the information again"
        return $null
    }
    
    return @{
        ServiceTreeId = $serviceTreeId
        IsProduction = $isProduction
        AdoAreaPath = $adoAreaPath
    }
}

function Update-SettingsWithInventoryMetadata {
    <#
    .SYNOPSIS
    Update the settings.yaml file with inventory metadata
    
    .PARAMETER ProjectPath
    Path to the project directory
    
    .PARAMETER InventoryMetadata
    Hashtable containing inventory metadata
    #>
    param(
        [string]$ProjectPath,
        [hashtable]$InventoryMetadata
    )
    
    # Convert to WSL-compatible path if needed
    if ($ProjectPath -match '^\\') {
        # Convert Windows-style path to WSL path
        $ProjectPath = $ProjectPath -replace '^\\', '/'
        $ProjectPath = $ProjectPath -replace '\\', '/'
    }
    
    # The settings.yaml file is in the strangeloop subdirectory
    if ($ProjectPath -match '^/') {
        # WSL path - construct manually to avoid backslashes
        $settingsPath = "$ProjectPath/strangeloop/settings.yaml"
        $strangeloopDir = "$ProjectPath/strangeloop"
    } else {
        # Windows path - use Join-Path
        $settingsPath = Join-Path $ProjectPath "strangeloop" "settings.yaml"
        $strangeloopDir = Join-Path $ProjectPath "strangeloop"
    }
    
    Write-Info "Looking for settings.yaml at: $settingsPath"
    Write-Info "Project path provided: $ProjectPath"
    Write-Info "Project path exists: $(Test-Path $ProjectPath)"
    
    # Check if project path exists first
    if (-not (Test-Path $ProjectPath)) {
        Write-Warning "Project path does not exist: $ProjectPath"
        
        # Try accessing via WSL if this looks like a Linux path
        if ($ProjectPath -match '^/') {
            Write-Info "Attempting to verify WSL path access..."
            try {
                $wslCheck = wsl test -d "$ProjectPath" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Info "WSL path verified: $ProjectPath"
                } else {
                    Write-Warning "WSL path check failed: $wslCheck"
                    return $false
                }
            } catch {
                Write-Warning "Failed to check WSL path: $($_.Exception.Message)"
                return $false
            }
        } else {
            return $false
        }
    }
    
    # Check if strangeloop directory exists
    $strangeloopExists = $false
    
    if ($ProjectPath -match '^/') {
        # WSL path - use wsl to check
        try {
            $null = wsl test -d "$strangeloopDir" 2>&1
            $strangeloopExists = ($LASTEXITCODE -eq 0)
        } catch {
            Write-Warning "Failed to check strangeloop directory via WSL: $($_.Exception.Message)"
        }
    } else {
        # Windows path - use Test-Path
        $strangeloopExists = Test-Path $strangeloopDir
    }
    
    if (-not $strangeloopExists) {
        Write-Warning "strangeloop directory not found at: $strangeloopDir"
        return $false
    }
    
    # Check if settings.yaml exists
    $settingsExists = $false
    
    if ($ProjectPath -match '^/') {
        # WSL path - use wsl to check and read file
        try {
            $null = wsl test -f "$settingsPath" 2>&1
            $settingsExists = ($LASTEXITCODE -eq 0)
        } catch {
            Write-Warning "Failed to check settings.yaml via WSL: $($_.Exception.Message)"
        }
    } else {
        # Windows path - use Test-Path
        $settingsExists = Test-Path $settingsPath
    }
    
    # If settings.yaml doesn't exist, create it
    if (-not $settingsExists) {
        Write-Info "settings.yaml not found, creating new file at: $settingsPath"
        try {
            $initialContent = @"
# Project Settings
# Generated by strangeloop inventory metadata setup

"@
            if ($ProjectPath -match '^/') {
                # WSL path - use wsl to create file
                $tempFile = [System.IO.Path]::GetTempFileName()
                Set-Content -Path $tempFile -Value $initialContent -Encoding UTF8
                $escapedTempFile = $tempFile -replace '\\', '/'
                $escapedTempFile = $escapedTempFile -replace '^C:', '/mnt/c'
                wsl cp "$escapedTempFile" "$settingsPath"
                Remove-Item $tempFile
            } else {
                # Windows path
                Set-Content -Path $settingsPath -Value $initialContent -Encoding UTF8
            }
            Write-Info "Created new settings.yaml file"
        } catch {
            Write-Warning "Failed to create settings.yaml: $($_.Exception.Message)"
            return $false
        }
    }
    
    try {
        Write-Info "Updating settings.yaml with inventory metadata..."
        
        # Read current settings
        $settingsContent = $null
        if ($ProjectPath -match '^/') {
            # WSL path - use wsl to read file
            try {
                $settingsContent = wsl cat "$settingsPath" 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to read settings.yaml via WSL: $settingsContent"
                }
                $settingsContent = $settingsContent -join "`n"
            } catch {
                throw "Failed to read settings.yaml via WSL: $($_.Exception.Message)"
            }
        } else {
            # Windows path
            $settingsContent = Get-Content $settingsPath -Raw
        }
        
        # Check if inventory_metadata section already exists (active or commented)
        if ($settingsContent -match "inventory_metadata:") {
            Write-Info "Found inventory_metadata section in settings.yaml"
            
            # Check for commented inventory_metadata
            $hasCommentedInventory = $settingsContent -match "(?m)^\s*#\s*inventory_metadata:"
            $hasActiveInventory = $settingsContent -match "(?m)^\s*inventory_metadata:"
            
            # Check if the main inventory_metadata section is commented out
            # Look for the pattern where inventory_metadata is part of a commented template
            if ($hasCommentedInventory -and -not $hasActiveInventory) {
                Write-Info "Uncommenting and updating existing inventory metadata template..."
                
                # Pattern to match the entire commented one_engineering_system section
                $commentedPattern = '(?ms)^\s*#\s*todo:.*?1ES inventory.*?\n\s*#\s*one_engineering_system:\s*\n(?:\s*#.*?\n)*?(?=\n\s*[^#\s]|\n*$)'
                
                # Create the replacement content
                $newOneESSection = @"
  # 1ES inventory as code metadata for service tracking and compliance
  one_engineering_system:
    inventory_metadata:
      # Service Tree ID - GUID that identifies your service (aka.ms/servicetree)
      service_tree_id: '$($InventoryMetadata.ServiceTreeId)'
      # Production service indicator - affects compliance requirements and deployment processes
      is_production: $($InventoryMetadata.IsProduction.ToString().ToLower())
      # ADO Area Path - used for work item routing (bugs, vulnerabilities, etc)
      # Format: Organization\Project\Area\SubArea
      ado_area_path: '$($InventoryMetadata.AdoAreaPath)'
"@

                # Test the pattern match
                $patternMatches = [regex]::Matches($settingsContent, $commentedPattern)
                
                if ($patternMatches.Count -gt 0) {
                    Write-Info "Using main pattern for replacement..."
                    $settingsContent = $settingsContent -replace $commentedPattern, $newOneESSection
                    
                } else {
                    # Try a simpler pattern
                    $simplePattern = '(?ms)^\s*#\s*todo:.*?1ES inventory.*?\n(?:\s*#.*?\n)*(?=\s*$|\s*[a-zA-Z])'
                    $simpleMatches = [regex]::Matches($settingsContent, $simplePattern)
                    
                    if ($simpleMatches.Count -gt 0) {
                        Write-Info "Using simple pattern for replacement..."
                        $settingsContent = $settingsContent -replace $simplePattern, $newOneESSection
                    } else {
                        Write-Info "Using fallback replacement..."
                        # Fallback: Replace the specific commented inventory_metadata section
                        $inventoryPattern = '(?m)^\s*#\s*inventory_metadata:\s*\n(?:\s*#.*?\n)*'
                        $newInventorySection = @"
    inventory_metadata:
      # Service Tree ID - GUID that identifies your service (aka.ms/servicetree)
      service_tree_id: '$($InventoryMetadata.ServiceTreeId)'
      # Production service indicator - affects compliance requirements and deployment processes
      is_production: $($InventoryMetadata.IsProduction.ToString().ToLower())
      # ADO Area Path - used for work item routing (bugs, vulnerabilities, etc)
      # Format: Organization\Project\Area\SubArea
      ado_area_path: '$($InventoryMetadata.AdoAreaPath)'
"@
                        $settingsContent = $settingsContent -replace $inventoryPattern, $newInventorySection
                        # Also uncomment the one_engineering_system line if it's commented
                        $settingsContent = $settingsContent -replace '^\s*#\s*one_engineering_system:', '  one_engineering_system:'
                    }
                }
                
                # Clean up any problematic concatenated lines
                Write-Info "Cleaning up any concatenated comments..."
                $lines = $settingsContent -split "`n"
                $cleanedLines = @()
                
                foreach ($line in $lines) {
                    if ($line -match "^\s*ado_area_path:\s*'[^']*'\s*#") {
                        # Extract just the field assignment part before the #
                        if ($line -match "^(\s*ado_area_path:\s*'[^']*')") {
                            $cleanedLines += $matches[1]
                        } else {
                            $cleanedLines += $line
                        }
                    } else {
                        $cleanedLines += $line
                    }
                }
                
                $settingsContent = $cleanedLines -join "`n"
                
            } else {
                # Active inventory_metadata section exists - update individual fields
                Write-Warning "inventory_metadata section already exists and is active in settings.yaml"
                Write-Info "Updating existing inventory metadata fields and removing inline comments..."
                
                # Update each field individually, removing any inline comments
                $settingsContent = Update-YamlField -Content $settingsContent -FieldName "service_tree_id" -NewValue $InventoryMetadata.ServiceTreeId -Indent 6 -QuoteValue $true
                $settingsContent = Update-YamlField -Content $settingsContent -FieldName "is_production" -NewValue $InventoryMetadata.IsProduction.ToString().ToLower() -Indent 6 -QuoteValue $false
                $settingsContent = Update-YamlField -Content $settingsContent -FieldName "ado_area_path" -NewValue $InventoryMetadata.AdoAreaPath -Indent 6 -QuoteValue $true
            }
        } else {
            # Append new inventory_metadata section
            Write-Info "Adding new inventory_metadata section to settings.yaml..."
            
            $inventorySection = @"

# Inventory Metadata - Service tracking and compliance information
inventory_metadata:
  service_tree_id: "$($InventoryMetadata.ServiceTreeId)"
  is_production: $($InventoryMetadata.IsProduction.ToString().ToLower())
  ado_area_path: "$($InventoryMetadata.AdoAreaPath)"
"@
            
            $settingsContent += $inventorySection
        }
        
        # Write updated content back to file
        if ($ProjectPath -match '^/') {
            # WSL path - use wsl to write file
            try {
                $tempFile = [System.IO.Path]::GetTempFileName()
                Set-Content -Path $tempFile -Value $settingsContent -Encoding UTF8
                $escapedTempFile = $tempFile -replace '\\', '/'
                $escapedTempFile = $escapedTempFile -replace '^C:', '/mnt/c'
                wsl cp "$escapedTempFile" "$settingsPath"
                Remove-Item $tempFile
            } catch {
                throw "Failed to write settings.yaml via WSL: $($_.Exception.Message)"
            }
        } else {
            # Windows path
            Set-Content -Path $settingsPath -Value $settingsContent -Encoding UTF8
        }
        
        # Verify the file was written correctly by reading it back
        try {
            $verificationContent = $null
            if ($ProjectPath -match '^/') {
                # WSL path - use wsl to read file
                $verificationContent = wsl cat "$settingsPath" 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Failed to read settings.yaml for verification via WSL: $verificationContent"
                } else {
                    $verificationContent = $verificationContent -join "`n"
                }
            } else {
                # Windows path
                $verificationContent = Get-Content $settingsPath -Raw
            }
            
            if ($verificationContent) {
                # Check for problematic lines in the final file
                $finalProblemLines = $verificationContent -split "`n" | Where-Object { $_ -match "ado_area_path.*#.*ado_area_path" }
                if ($finalProblemLines.Count -gt 0) {
                    Write-Warning "Found problematic lines in written file - this may indicate a template processing issue"
                } else {
                    Write-Success "Inventory metadata updated successfully in settings.yaml"
                }
            } else {
                Write-Warning "Could not read settings.yaml for verification"
            }
        } catch {
            Write-Warning "Failed to verify settings.yaml: $($_.Exception.Message)"
        }
        
        Write-Success "settings.yaml updated successfully with inventory metadata"
        
        return $true
        
    } catch {
        Write-Error "Failed to update settings.yaml: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-StrangeloopRecurse {
    <#
    .SYNOPSIS
    Execute strangeloop recurse to reflect latest settings
    
    .PARAMETER ProjectPath
    Path to the project directory
    #>
    param(
        [string]$ProjectPath
    )
    
    try {
        Write-Info "Running 'strangeloop recurse' to reflect latest settings..."
        
        # Execute strangeloop recurse
        $result = $null
        if ($ProjectPath -match '^/') {
            # WSL path - run command in WSL
            try {
                Write-Info "Executing strangeloop recurse in WSL..."
                $result = wsl bash -c "cd '$ProjectPath' && strangeloop --force recurse" 2>&1
                $exitCode = $LASTEXITCODE
            } catch {
                throw "Failed to execute strangeloop recurse in WSL: $($_.Exception.Message)"
            }
        } else {
            # Windows path - change to project directory and run
            Push-Location $ProjectPath
            try {
                $result = & strangeloop --force recurse 2>&1
                $exitCode = $LASTEXITCODE
            } finally {
                Pop-Location
            }
        }
        
        if ($exitCode -eq 0) {
            Write-Success "strangeloop recurse completed successfully"
            if ($result) {
                Write-Host ""
                Write-Host "strangeloop recurse output:" -ForegroundColor Gray
                $result | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
                Write-Host ""
            }
            return $true
        } else {
            Write-Warning "strangeloop recurse failed with exit code: $exitCode"
            if ($result) {
                Write-Host "Output:" -ForegroundColor Red
                $result | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
            }
            return $false
        }
        
    } catch {
        Write-Error "Failed to execute strangeloop recurse: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-InventoryMetadata {
    <#
    .SYNOPSIS
    Main function to setup inventory metadata for the project
    
    .PARAMETER ProjectPath
    Path to the project directory
    
    .PARAMETER ProjectName
    Name of the project
    
    .PARAMETER LoopName
    Name of the selected loop
    
    .PARAMETER WhatIf
    Show what would be done without making changes
    
    .PARAMETER CheckOnly
    Only validate current configuration
    
    .PARAMETER SkipPrompt
    Skip user prompts (for automated scenarios)
    #>
    param(
        [string]$ProjectPath,
        [string]$ProjectName,
        [string]$LoopName,
        [switch]$WhatIf,
        [switch]$CheckOnly,
        [switch]$SkipPrompt
    )
    
    # Parameter validation
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        Write-Error "ProjectPath parameter is required and cannot be empty"
        return @{
            Success = $false
            Message = "ProjectPath parameter is required"
            Configured = $false
        }
    }
    
    # Convert to WSL-compatible path if needed
    if ($ProjectPath -match '^\\') {
        # Convert Windows-style path to WSL path
        $ProjectPath = $ProjectPath -replace '^\\', '/'
        $ProjectPath = $ProjectPath -replace '\\', '/'
    }
    
    # Convert to absolute path if relative (Windows paths only)
    if ($ProjectPath -notmatch '^/' -and -not [System.IO.Path]::IsPathRooted($ProjectPath)) {
        $ProjectPath = Resolve-Path $ProjectPath -ErrorAction SilentlyContinue
        if (-not $ProjectPath) {
            Write-Error "Could not resolve project path to absolute path"
            return @{
                Success = $false
                Message = "Invalid project path"
                Configured = $false
            }
        }
    }
    
    # Check if project path exists
    $projectPathExists = $false
    if ($ProjectPath -match '^/') {
        # WSL path - use wsl to check
        try {
            $null = wsl test -d "$ProjectPath" 2>&1
            $projectPathExists = ($LASTEXITCODE -eq 0)
        } catch {
            $projectPathExists = $false
        }
    } else {
        # Windows path - use Test-Path
        $projectPathExists = Test-Path $ProjectPath
    }
    
    Write-Info "Parameter validation:"
    Write-Info "  ProjectPath: '$ProjectPath'"
    Write-Info "  ProjectName: '$ProjectName'"
    Write-Info "  LoopName: '$LoopName'"
    Write-Info "  ProjectPath exists: $projectPathExists"
    
    if (-not $projectPathExists) {
        Write-Error "Project path does not exist: $ProjectPath"
        return @{
            Success = $false
            Message = "Project path does not exist: $ProjectPath"
            Configured = $false
        }
    }
    
    if ($WhatIf) {
        Write-Host ""
        Write-Host "=== INVENTORY METADATA SETUP (WHAT-IF MODE) ===" -ForegroundColor Yellow
        Write-Host "what if: Would prompt user for inventory metadata configuration" -ForegroundColor Yellow
        Write-Host "what if: Would collect the following information:" -ForegroundColor Yellow
        Write-Host "what if:   - Service Tree ID (GUID)" -ForegroundColor Yellow
        Write-Host "what if:   - Is Production (boolean, default: true)" -ForegroundColor Yellow
        Write-Host "what if:   - ADO Area Path (string)" -ForegroundColor Yellow
        Write-Host "what if: Would update settings.yaml with collected metadata" -ForegroundColor Yellow
        Write-Host "what if: Would execute 'strangeloop recurse' to reflect changes" -ForegroundColor Yellow
        Write-Host ""
        
        return @{
            Success = $true
            Message = "What-if completed for inventory metadata setup"
            Configured = $false
        }
    }
    
    if ($CheckOnly) {
        Write-Info "Checking inventory metadata configuration..."
        
        # The settings.yaml file is in the strangeloop subdirectory
        if ($ProjectPath -match '^/') {
            # WSL path - construct manually to avoid backslashes
            $settingsPath = "$ProjectPath/strangeloop/settings.yaml"
        } else {
            # Windows path - use Join-Path
            $settingsPath = Join-Path $ProjectPath "strangeloop" "settings.yaml"
        }
        
        # Check if settings.yaml exists
        $settingsExists = $false
        if ($ProjectPath -match '^/') {
            # WSL path - use wsl to check
            try {
                $null = wsl test -f "$settingsPath" 2>&1
                $settingsExists = ($LASTEXITCODE -eq 0)
            } catch {
                $settingsExists = $false
            }
        } else {
            # Windows path - use Test-Path
            $settingsExists = Test-Path $settingsPath
        }
        
        if (-not $settingsExists) {
            Write-Warning "settings.yaml not found - inventory metadata cannot be validated"
            Write-Info "Expected location: $settingsPath"
            return @{
                Success = $false
                Message = "settings.yaml not found"
                Configured = $false
            }
        }
        
        try {
            # Read settings content
            $settingsContent = $null
            if ($ProjectPath -match '^/') {
                # WSL path - use wsl to read file
                try {
                    $settingsContent = wsl cat "$settingsPath" 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to read settings.yaml via WSL: $settingsContent"
                    }
                    $settingsContent = $settingsContent -join "`n"
                } catch {
                    throw "Failed to read settings.yaml via WSL: $($_.Exception.Message)"
                }
            } else {
                # Windows path
                $settingsContent = Get-Content $settingsPath -Raw
            }
            
            if ($settingsContent -match "inventory_metadata:") {
                # Check if it's commented out
                if ($settingsContent -match "#\s*inventory_metadata:") {
                    Write-Info "Found commented-out inventory metadata template in settings.yaml"
                    Write-Info "Run without -CheckOnly to uncomment and configure the metadata"
                    return @{
                        Success = $true
                        Message = "Inventory metadata template found but not configured"
                        Configured = $false
                    }
                } else {
                    # Active inventory metadata section
                    Write-Success "Inventory metadata section found in settings.yaml"
                    
                    # Check for required fields and extract their values using simpler patterns
                    $serviceTreeIdLine = ($settingsContent -split "`n" | Where-Object { $_ -match "service_tree_id:" }).Trim()
                    $isProductionLine = ($settingsContent -split "`n" | Where-Object { $_ -match "is_production:" }).Trim()
                    $adoAreaPathLine = ($settingsContent -split "`n" | Where-Object { $_ -match "ado_area_path:" }).Trim()
                    
                    $hasValidServiceTreeId = $false
                    $hasValidIsProduction = $false
                    $hasValidAdoAreaPath = $false
                    $validationIssues = @()
                    
                    # Validate service_tree_id
                    if ($serviceTreeIdLine) {
                        $serviceTreeIdValue = ($serviceTreeIdLine -split ":", 2)[1].Trim()
                        # Remove quotes if present
                        $serviceTreeIdValue = $serviceTreeIdValue.Trim("'", '"')
                        # Remove any trailing comments that might be on the same line
                        if ($serviceTreeIdValue -match "^([^#]+)") {
                            $serviceTreeIdValue = $matches[1].Trim()
                        }
                        
                        if ([string]::IsNullOrWhiteSpace($serviceTreeIdValue) -or $serviceTreeIdValue -eq '') {
                            $validationIssues += "service_tree_id is empty or has placeholder value"
                        } elseif ($serviceTreeIdValue -match "^(123e4567-e89b-12d3-a456-426614174000|00000000-0000-0000-0000-000000000000)$") {
                            $validationIssues += "service_tree_id appears to be a placeholder/example GUID"
                        } else {
                            # Try to parse as GUID to validate format
                            try {
                                $guid = [System.Guid]::Parse($serviceTreeIdValue)
                                if ($guid -eq [System.Guid]::Empty) {
                                    $validationIssues += "service_tree_id is empty GUID"
                                } else {
                                    $hasValidServiceTreeId = $true
                                }
                            } catch {
                                $validationIssues += "service_tree_id has invalid GUID format"
                            }
                        }
                    } else {
                        $validationIssues += "service_tree_id field not found"
                    }
                    
                    # Validate is_production
                    if ($isProductionLine) {
                        $isProductionValue = ($isProductionLine -split ":", 2)[1].Trim()
                        if ([string]::IsNullOrWhiteSpace($isProductionValue)) {
                            $validationIssues += "is_production is empty"
                        } elseif ($isProductionValue -match "^(true|false)$") {
                            $hasValidIsProduction = $true
                        } else {
                            $validationIssues += "is_production must be 'true' or 'false', found: '$isProductionValue'"
                        }
                    } else {
                        $validationIssues += "is_production field not found"
                    }
                    
                    # Validate ado_area_path
                    if ($adoAreaPathLine) {
                        $adoAreaPathValue = ($adoAreaPathLine -split ":", 2)[1].Trim()
                        # Remove quotes if present
                        $adoAreaPathValue = $adoAreaPathValue.Trim("'", '"')
                        # Remove any trailing comments that might be on the same line
                        if ($adoAreaPathValue -match "^([^#]+)") {
                            $adoAreaPathValue = $matches[1].Trim()
                        }
                        
                        if ([string]::IsNullOrWhiteSpace($adoAreaPathValue) -or $adoAreaPathValue -eq '') {
                            $validationIssues += "ado_area_path is empty or has placeholder value"
                        } elseif ($adoAreaPathValue -match "^(PATH\\TO\\ADO\\AREA|Project\\Area|Organization\\Project\\Area\\SubArea)$") {
                            $validationIssues += "ado_area_path appears to be a placeholder/example value"
                        } else {
                            # Basic validation for ADO area path format
                            if ($adoAreaPathValue.Length -le 256 -and $adoAreaPathValue -notmatch '[<>:"|?*/%]') {
                                $hasValidAdoAreaPath = $true
                            } else {
                                $validationIssues += "ado_area_path has invalid format or is too long"
                            }
                        }
                    } else {
                        $validationIssues += "ado_area_path field not found"
                    }
                    
                    if ($hasValidServiceTreeId -and $hasValidIsProduction -and $hasValidAdoAreaPath) {
                        Write-Success "All required inventory metadata fields are present"
                        return @{
                            Success = $true
                            Message = "Inventory metadata is properly configured"
                            Configured = $true
                        }
                    } else {
                        Write-Warning "Inventory metadata validation issues found:"
                        foreach ($issue in $validationIssues) {
                            Write-Host "    • $issue" -ForegroundColor Red
                        }
                        return @{
                            Success = $false
                            Message = "Inventory metadata configuration has validation issues"
                            Configured = $false
                        }
                    }
                }
            } else {
                Write-Info "No inventory metadata configuration found"
                return @{
                    Success = $true
                    Message = "Inventory metadata not configured"
                    Configured = $false
                }
            }
        } catch {
            Write-Error "Failed to check inventory metadata: $($_.Exception.Message)"
            return @{
                Success = $false
                Message = "Error checking inventory metadata: $($_.Exception.Message)"
                Configured = $false
            }
        }
    }
    
    try {
        Write-Step "Inventory Metadata Setup"
        Write-Info "Project: $ProjectName"
        Write-Info "Loop: $LoopName"
        Write-Info "Path: $ProjectPath"
        
        if ($SkipPrompt) {
            Write-Info "Skipping inventory metadata setup (automated mode)"
            return @{
                Success = $true
                Message = "Inventory metadata setup skipped"
                Configured = $false
            }
        }
        
        # Collect inventory metadata from user
        $inventoryMetadata = Get-InventoryMetadataFromUser
        
        if (-not $inventoryMetadata) {
            Write-Info "Inventory metadata setup skipped by user"
            return @{
                Success = $true
                Message = "Inventory metadata setup skipped by user"
                Configured = $false
            }
        }
        
        # Update settings.yaml with the collected metadata
        $updateResult = Update-SettingsWithInventoryMetadata -ProjectPath $ProjectPath -InventoryMetadata $inventoryMetadata
        
        if (-not $updateResult) {
            Write-Error "Failed to update settings.yaml with inventory metadata"
            return @{
                Success = $false
                Message = "Failed to update settings.yaml"
                Configured = $false
            }
        }
        
        # Execute strangeloop recurse to reflect the changes
        $recurseResult = Invoke-StrangeloopRecurse -ProjectPath $ProjectPath
        
        if (-not $recurseResult) {
            Write-Warning "strangeloop recurse failed, but inventory metadata was saved to settings.yaml"
            Write-Info "You may need to run 'strangeloop recurse' manually later"
        }
        
        Write-Success "Inventory metadata setup completed successfully"
        
        return @{
            Success = $true
            Message = "Inventory metadata configured successfully"
            Configured = $true
            Metadata = $inventoryMetadata
            RecurseResult = $recurseResult
        }
        
    } catch {
        Write-Error "Inventory metadata setup failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Message = "Inventory metadata setup failed: $($_.Exception.Message)"
            Configured = $false
        }
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Initialize-InventoryMetadata -ProjectPath $ProjectPath -ProjectName $ProjectName -LoopName $LoopName -WhatIf:$WhatIf -CheckOnly:$CheckOnly -SkipPrompt:$SkipPrompt
    return $result
}

# Export functions for module usage
if (Get-Module -Name $MyInvocation.MyCommand.Name -ErrorAction SilentlyContinue) {
    Export-ModuleMember -Function @(
        'Initialize-InventoryMetadata',
        'Get-InventoryMetadataFromUser',
        'Update-SettingsWithInventoryMetadata',
        'Invoke-StrangeloopRecurse'
    )
}