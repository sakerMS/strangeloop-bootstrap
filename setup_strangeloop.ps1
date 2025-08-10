# StrangeLoop CLI Setup Launcher
# This launcher script downloads and executes the modular setup scripts
# 
# Usage: .\setup_strangeloop.ps1 [parameters]
# Parameters:
#   -SkipPrerequisites    : Skip system prerequisite installation
#   -SkipDevelopmentTools : Skip development tools installation
#   -MaintenanceMode      : Update packages only (for existing installations)
#   -Verbose              : Enable detailed logging for troubleshooting
#   (Default) Prefetches all scripts to ./temp-strangeloop-scripts (with overwrite prompt) and runs from local files
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
    [switch]$PrefetchOnly,
    [string]$UserName,
    [string]$UserEmail,
    [string]$BaseUrl = "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main"
)

# Prefixed logging for this script
$script:LogPrefix = "[LAUNCHER]"
function Write-Host {
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        $Object,
        [ConsoleColor]$ForegroundColor,
        [ConsoleColor]$BackgroundColor,
        [switch]$NoNewline,
        [string]$Separator
    )
    $prefix = $script:LogPrefix
    # Coerce object/array to string with separator if supplied
    if ($null -ne $Separator -and $Object -is [System.Array]) {
        $text = "$prefix " + ($Object -join $Separator)
    } else {
        $text = "$prefix $Object"
    }
    $splat = @{ Object = $text }
    if ($PSBoundParameters.ContainsKey('ForegroundColor')) { $splat['ForegroundColor'] = $ForegroundColor }
    if ($PSBoundParameters.ContainsKey('BackgroundColor')) { $splat['BackgroundColor'] = $BackgroundColor }
    if ($PSBoundParameters.ContainsKey('NoNewline'))      { $splat['NoNewline']      = $NoNewline }
    Microsoft.PowerShell.Utility\Write-Host @splat
}

function Write-Verbose {
    param([string]$Message)
    $prefix = $script:LogPrefix
    Microsoft.PowerShell.Utility\Write-Verbose -Message ("$prefix $Message")
}

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
Write-Host "📦 Prefetch mode: will download all scripts to ./temp-strangeloop-scripts and run from local files" -ForegroundColor Yellow
if ($PrefetchOnly) {
    Write-Host "🛠 PrefetchOnly: will only download/repair cached scripts and exit (no setup executed)" -ForegroundColor Yellow
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
    $executionSucceeded = $false
    
    try {
        Write-Verbose "Temp script path: $tempScriptPath"
        # Write script content to temp file
        Set-Content -Path $tempScriptPath -Value $ScriptContent -Encoding UTF8
        
        # Build parameter hashtable for splatting (avoids binding issues)
        $paramSplat = @{}
        foreach ($key in $Parameters.Keys) {
            $value = $Parameters[$key]

            # Normalize SwitchParameter/boolean handling
            if ($null -ne $value -and ($value -is [System.Management.Automation.SwitchParameter] -or $value -is [bool])) {
                if ([bool]$value) {
                    $paramSplat[$key] = $true
                    Write-Verbose "Added switch parameter: -$key"
                } else {
                    Write-Verbose "Omitted switch parameter (false): -$key"
                }
                continue
            }

            # Skip null/empty values
            if ($null -eq $value -or ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
                Write-Verbose "Omitted parameter (null/empty): -$key"
                continue
            }

            # Add normal key-value parameter
            $paramSplat[$key] = $value
            Write-Verbose "Added parameter: -$key = '$value'"
        }

    $paramPreview = $paramSplat.GetEnumerator() | ForEach-Object { "-$($_.Key)=$($_.Value)" }
    $previewStr = ($paramPreview -join ' ')
    Write-Verbose ("Executing script with parameters (splat): " + $previewStr)
    # Execute the script and allow its output to show in the console, but don't return its pipeline output
    $null = & $tempScriptPath @paramSplat
        $executionSucceeded = $true
        
        # Safely derive an exit code (avoid StrictMode error when $LASTEXITCODE is unset)
        $code = 0
        try {
            $code = (Get-Variable -Name LASTEXITCODE -Scope Global -ValueOnly -ErrorAction Stop)
            if ($null -eq $code -or ($code -isnot [int])) { $code = 0 }
        } catch {
            $code = 0
        }
    Write-Verbose ("Child script exit code: " + $code)
    return $code
    } catch {
        Write-Host "✗ Error while executing downloaded script." -ForegroundColor Red
        Write-Host "  Temp script path: $tempScriptPath" -ForegroundColor Yellow
        Write-Host "  Details: $($_.Exception.Message)" -ForegroundColor Red
        throw
    } finally {
        # Clean up temp file only on success to aid debugging
        if (Test-Path $tempScriptPath) {
            if ($executionSucceeded) {
                Write-Verbose "Cleaning up temporary script file"
                Remove-Item $tempScriptPath -Force -ErrorAction SilentlyContinue
            } else {
                Write-Verbose "Preserving temporary script for debugging: $tempScriptPath"
            }
        }
    }
}

# Sanitize downloaded script content to work around known corruption artifacts
function Sanitize-DownloadedScript {
    param(
        [string]$Content,
        [string]$ScriptName
    )

    $original = $Content

    # Detect and unescape literal escape sequences (e.g., "\n") whenever present
    $hasEscapedNewlines = ($Content -match "\\n|\\r")
    if ($hasEscapedNewlines) {
        if ($Verbose) { Write-Verbose "Detected literal newline escape sequences in $ScriptName; unescaping" }
        # Convert common literal escapes to their actual characters
        $Content = $Content -replace "\\r\\n", "`n"
        $Content = $Content -replace "\\n", "`n"
        $Content = $Content -replace "\\r", "`n"
        $Content = $Content -replace "\\t", "`t"
    }

    # Normalize newlines to LF to reduce CR/LF mishaps (handle CRLF and bare CR)
    $normalized = ($Content -replace "`r`n", "`n")
    $normalized = ($normalized -replace "`r", "`n")

    # Remove/replace specific corrupt tokens observed in remote scripts
    # Example: a stray "}n Entry Point" token injected after a closing brace
    $normalized = $normalized -replace "}\s*n Entry Point", "}\n# Main Entry Point"
    # Also handle a standalone line starting with just "n Entry Point" using a safe join
    $lines = $normalized -split "\n"
    $lines = $lines | ForEach-Object {
        if ($_ -match '^\s*n Entry Point\s*$') { '# Main Entry Point' } else { $_ }
    }
    $normalized = [string]::Join("\n", $lines)

    # Restore CRLF for temp-file execution
    $sanitized = ($normalized -replace "\n", "`r`n")

    if ($Verbose) {
        if ($sanitized -ne $original) {
            Write-Verbose "Applied content sanitization to $ScriptName (fixed known artifacts)"
        } else {
            Write-Verbose "No sanitization changes needed for $ScriptName"
        }
    }

    return $sanitized
}

# Ensure a directory exists
function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -Path $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Verbose "Created directory: $Path"
    }
}

# Open VS Code at a target folder (simple CLI call with fallback hint)
function Open-VSCode {
    param([string]$TargetPath)

    Write-Verbose "Attempting to open VS Code at $TargetPath"
    try {
        Start-Process -FilePath 'code' -ArgumentList @('-n', $TargetPath) -WindowStyle Normal -ErrorAction Stop | Out-Null
        Write-Host "Launching Visual Studio Code at: $TargetPath" -ForegroundColor Cyan
    } catch {
        Write-Host "Couldn't launch VS Code automatically. Try manually:" -ForegroundColor Yellow
        Write-Host "  code -n '$TargetPath'" -ForegroundColor Gray
    }
}

# Prompt the user for Yes/No with default choice
function Prompt-YesNo {
    param(
        [string]$Message,
        [bool]$DefaultYes = $true
    )

    $suffix = if ($DefaultYes) { 'Y/n' } else { 'y/N' }
    $answer = Read-Host "$Message [$suffix]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultYes }
    switch -Regex ($answer.Trim()) {
        '^(y|yes)$' { return $true }
        '^(n|no)$'  { return $false }
        default     { return $DefaultYes }
    }
}

# Download and save a script to a given path, with optional overwrite prompt
function Save-ScriptToPath {
    param(
        [string]$Url,
        [string]$Path,
        [string]$Name,
    [bool]$PromptOverwrite = $true,
    [Nullable[bool]]$OverwriteChoice = $null
    )

    $dir = Split-Path -Path $Path -Parent
    Ensure-Directory -Path $dir

    $shouldWrite = $true
    $exists = Test-Path -Path $Path -PathType Leaf
    if ($exists) {
        if ($OverwriteChoice -ne $null) {
            $shouldWrite = [bool]$OverwriteChoice
        } elseif ($PromptOverwrite) {
            if ($WhatIf) {
                Write-Host "WhatIf: Would overwrite existing $Name at $Path" -ForegroundColor Yellow
            } else {
                $shouldWrite = Prompt-YesNo -Message "File exists: $Path. Overwrite?" -DefaultYes:$true
            }
        }
    }

    if ($exists -and -not $shouldWrite) {
        Write-Host "↷ Keeping existing $Name at $Path" -ForegroundColor Gray
        return $Path
    }

    Write-Host "Preparing to save $Name to $Path" -ForegroundColor Yellow
    if ($WhatIf) {
        Write-Host "WhatIf: Would download $Name from $Url and save to $Path" -ForegroundColor Yellow
        return $Path
    }

    $content = Get-ScriptFromUrl -Url $Url -ScriptName $Name
    $content = Sanitize-DownloadedScript -Content $content -ScriptName $Name
    # Ensure CRLF endings before writing to file to avoid single-line issues
    $normalizedContent = ($content -replace "`r`n", "`n")
    $normalizedContent = ($normalizedContent -replace "`r", "`n")
    $normalizedContent = ($normalizedContent -replace "\n", "`r`n")
    Set-Content -Path $Path -Value $normalizedContent -Encoding UTF8
    Write-Host "✓ Saved $Name to $Path" -ForegroundColor Green
    return $Path
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

# Define script URLs (remote) and local cache paths
$scriptUrls = @{
    "Main" = "$BaseUrl/scripts/strangeloop_main.ps1"
    "Linux" = "$BaseUrl/scripts/strangeloop_linux.ps1"
    "Windows" = "$BaseUrl/scripts/strangeloop_windows.ps1"
}
$localCacheDir = Join-Path $PSScriptRoot "temp-strangeloop-scripts"
$localScripts = @{
    "Main" = Join-Path $localCacheDir "strangeloop_main.ps1"
    "Linux" = Join-Path $localCacheDir "strangeloop_linux.ps1"
    "Windows" = Join-Path $localCacheDir "strangeloop_windows.ps1"
}

if ($Verbose) {
    Write-Verbose "Script URLs configured:"
    foreach ($script in $scriptUrls.GetEnumerator()) {
        Write-Verbose "- $($script.Key): $($script.Value)"
    }
    Write-Verbose "Local cache script paths (temp-strangeloop-scripts):"
    foreach ($script in $localScripts.GetEnumerator()) {
        Write-Verbose "- $($script.Key): $($script.Value)"
    }
}

try {
    # Prefetch flow (default): download all scripts locally and then run from saved files
    Write-Host "=== Prefetching All Setup Scripts Locally ===" -ForegroundColor Cyan
    # Decide overwrite behavior once for all files
    $globalOverwrite = $null
    if ($WhatIf) {
        Write-Host "WhatIf: Would prompt once to overwrite existing files in $localCacheDir (default Yes)" -ForegroundColor Yellow
        $globalOverwrite = $true
    } else {
        if ($PrefetchOnly) {
            # In PrefetchOnly mode, default to overwrite to ensure repair
            $globalOverwrite = $true
        } else {
        # Determine if any target files exist
        $targetsExist = @($localScripts.Main, $localScripts.Linux, $localScripts.Windows) | ForEach-Object { Test-Path -Path $_ -PathType Leaf } | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
        if ($targetsExist -gt 0) {
            $globalOverwrite = Prompt-YesNo -Message "One or more files already exist in $localCacheDir. Overwrite all?" -DefaultYes:$true
        } else {
            $globalOverwrite = $true
        }
        }
    }

    $savedMain    = Save-ScriptToPath -Url $scriptUrls.Main    -Path $localScripts.Main    -Name "strangeloop_main.ps1"    -PromptOverwrite:$false -OverwriteChoice:$globalOverwrite
    $savedLinux   = Save-ScriptToPath -Url $scriptUrls.Linux   -Path $localScripts.Linux   -Name "strangeloop_linux.ps1"   -PromptOverwrite:$false -OverwriteChoice:$globalOverwrite
    $savedWindows = Save-ScriptToPath -Url $scriptUrls.Windows -Path $localScripts.Windows -Name "strangeloop_windows.ps1" -PromptOverwrite:$false -OverwriteChoice:$globalOverwrite

    # Repair any cached scripts that might have been saved with literal "\n" sequences (from previous runs)
    if (-not $WhatIf) {
    function Repair-LiteralEscapesInFile {
            param([string]$Path, [string]$Name)
            try {
                if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
                $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $hasEscapes = ($raw -match "\\n|\\r")
        if ($hasEscapes) {
                    Write-Host "Detected literal \\n sequences in $Name; repairing line endings" -ForegroundColor Yellow
                    $fixed = $raw -replace "\\r\\n", "`n"
                    $fixed = $fixed -replace "\\n", "`n"
                    $fixed = $fixed -replace "\\r", "`n"
                    $fixed = $fixed -replace "\\t", "`t"
                    # Write back as CRLF
                    $fixed = ($fixed -replace "\n", "`r`n")
                    Set-Content -LiteralPath $Path -Value $fixed -Encoding UTF8
                    Write-Host "✓ Repaired $Name" -ForegroundColor Green
                }
            } catch {
                Write-Verbose "Repair check failed for $Name at ${Path}: $($_.Exception.Message)"
            }
        }
        Repair-LiteralEscapesInFile -Path $savedMain -Name "strangeloop_main.ps1"
        Repair-LiteralEscapesInFile -Path $savedLinux -Name "strangeloop_linux.ps1"
        Repair-LiteralEscapesInFile -Path $savedWindows -Name "strangeloop_windows.ps1"
    }

    # If only prefetch/repair is requested, exit early
    if ($PrefetchOnly) {
        Write-Host "`n=== Prefetch/Repair Complete ===" -ForegroundColor Green
        Write-Host "Cached scripts saved to: $localCacheDir" -ForegroundColor Gray
        return 0
    }

    # Load main content from the saved local file unless in WhatIf (preview only)
    if ($WhatIf) {
        $mainScriptContent = ''
    } else {
        $mainScriptContent = Get-Content -Path $savedMain -Raw -ErrorAction Stop
    }
    
    # Prepare parameters for main script
    $mainParams = @{
        SkipPrerequisites = $SkipPrerequisites
        SkipDevelopmentTools = $SkipDevelopmentTools
        MaintenanceMode = $MaintenanceMode
        Verbose = $Verbose
        WhatIf = $WhatIf
        UserName = $UserName
        UserEmail = $UserEmail
    # Always use saved local script paths
    LinuxScriptPath = $localScripts.Linux
    WindowsScriptPath = $localScripts.Windows
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
        Write-Host "  • Target scripts: strangeloop_main.ps1 (local)" -ForegroundColor Gray
        if (-not $SkipDevelopmentTools) {
            Write-Host "  • Platform-specific setup (Linux/Windows)" -ForegroundColor Gray
            Write-Host "    - Using local OS setup scripts from $localCacheDir" -ForegroundColor Gray
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
    # VS Code opening is handled by the main script to target the project directory
    
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
