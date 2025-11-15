# strangeloop setup - Shared Output Functions
# Version: 1.0.0


# Output formatting functions for consistent messaging across all modules

function Write-Step {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    # Use ASCII-safe characters for cross-environment compatibility
    $separator = if ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP) { "===" } else { "═══" }
    Write-Host "`n[$timestamp] " -ForegroundColor Gray -NoNewline
    Write-Host "$separator $Message $separator" -ForegroundColor $Color
}

function Write-Header {
    <#
    .SYNOPSIS
        Displays a header message with consistent formatting
    
    .PARAMETER Message
        The header message to display
    
    .PARAMETER Color
        The color for the header (default: Magenta)
    #>
    param(
        [string]$Message,
        [string]$Color = "Magenta"
    )
    
    Write-Step -Message $Message -Color $Color
}

function Write-Success {
    param([string]$Message)
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    # Use ASCII-safe check mark for cross-environment compatibility
    $checkMark = if ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP) { "[OK]" } else { "✓" }
    Write-Host "[$timestamp] " -ForegroundColor Gray -NoNewline
    Write-Host "$checkMark $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    # Use ASCII-safe warning symbol for cross-environment compatibility
    $warningSymbol = if ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP) { "[WARN]" } else { "⚠" }
    Write-Host "[$timestamp] " -ForegroundColor Gray -NoNewline
    Write-Host "$warningSymbol $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    # Use ASCII-safe error symbol for cross-environment compatibility
    $errorSymbol = if ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP) { "[ERROR]" } else { "✗" }
    Write-Host "[$timestamp] " -ForegroundColor Gray -NoNewline
    Write-Host "$errorSymbol $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    # Use ASCII-safe info symbol for cross-environment compatibility
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

function Write-Banner {
    param(
        [string]$Title,
        [string]$Description = "",
        [string]$Version = ""
    )
    
    $width = 70
    $innerWidth = $width

    function PadBannerLine {
        param([string]$text)
        # Always render 'strangeloop' in lower case
        $text = $text -replace '(?i)strangeloop', 'strangeloop'
        return $text.PadLeft(($innerWidth + $text.Length) / 2).PadRight($innerWidth)
    }

    Write-Host ""
    Write-Host ("╔" + ('═' * $innerWidth) + "╗") -ForegroundColor Cyan
    $bannerTitle = $Title -replace '(?i)strangeloop', 'strangeloop'
    Write-Host ("║" + (PadBannerLine $bannerTitle) + "║") -ForegroundColor Cyan

    if ($Description) {
        Write-Host ("║" + (PadBannerLine $Description) + "║") -ForegroundColor White
    }

    if ($Version) {
        $versionText = "Version: $Version"
        Write-Host ("║" + (PadBannerLine $versionText) + "║") -ForegroundColor Gray
    }

    Write-Host ("╚" + ('═' * $innerWidth) + "╝") -ForegroundColor Cyan
    Write-Host ""
}

function Write-CompletionSummary {
    param(
        [hashtable]$Results,
        [string]$Title = "Operation Summary"
    )
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    $TitleLower = $Title -replace '(?i)strangeloop', 'strangeloop'
    Write-Host "║$((' ' + $TitleLower + ' ').PadLeft((64 + $TitleLower.Length) / 2).PadRight(62))║" -ForegroundColor Green
    Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Green

    foreach ($key in $Results.Keys) {
        $value = $Results[$key]
        $line = " $($key): $value".PadRight(62)
        # Print the whole line in green, but value in white for contrast
        Write-Host ("║" + $line.Substring(0, $line.IndexOf(':') + 2)) -NoNewline -ForegroundColor Green
        Write-Host ($line.Substring($line.IndexOf(':') + 2)) -NoNewline -ForegroundColor White
        Write-Host "║" -ForegroundColor Green
    }

    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}

function Read-UserPrompt {
    <#
    .SYNOPSIS
        Unified function for all user prompts with consistent formatting and validation
    
    .PARAMETER Prompt
        The prompt message to display to the user
    
    .PARAMETER DefaultValue
        The default value if user presses Enter without input (not used for Y/N prompts)
    
    .PARAMETER ValidValues
        Array of valid values for validation. Use @("y","n") for Y/N prompts
    
    .EXAMPLE
        Read-UserPrompt -Prompt "Enter project name" -DefaultValue "MyProject"
    
    .EXAMPLE
        Read-UserPrompt -Prompt "Continue with installation?" -ValidValues @("y","n")
    
    .EXAMPLE
        Read-UserPrompt -Prompt "Choose action" -ValidValues @("O", "N", "A")
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        
        [string]$DefaultValue = "",
        
        [string[]]$ValidValues = @()
    )
    
    # Determine if this is a Y/N prompt
    $isYesNo = $ValidValues.Count -eq 4 -and 
               ($ValidValues | ForEach-Object { $_.ToLower() }) -contains "y" -and
               ($ValidValues | ForEach-Object { $_.ToLower() }) -contains "yes" -and
               ($ValidValues | ForEach-Object { $_.ToLower() }) -contains "n" -and
               ($ValidValues | ForEach-Object { $_.ToLower() }) -contains "no"
    
    # For Y/N prompts, force no default and no empty input
    if ($isYesNo) {
        $DefaultValue = ""
        $emptyAllowed = $false
    } else {
        # For other prompts, allow empty if there's a default or no validation
        $emptyAllowed = ($DefaultValue -ne "") -or ($ValidValues.Count -eq 0)
    }
    
    # Build the prompt string
    $promptText = $Prompt
    
    # Add default value indicator if provided and empty is allowed
    if ($DefaultValue -and $emptyAllowed) {
        $promptText += " [$DefaultValue]"
    }
    
    # Add valid values indicator if specified
    if ($ValidValues.Count -gt 0) {
        if ($isYesNo) {
            $promptText += " (y/n)"
        } else {
            $promptText += " ($($ValidValues -join '/'))"
        }
    }
    
    $promptText += ": "
    
    do {
        Write-Host $promptText -NoNewline -ForegroundColor Yellow
        $userInput = Read-Host
        
        # Handle empty input
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            if ($emptyAllowed -and $DefaultValue) {
                return $DefaultValue
            } elseif ($emptyAllowed) {
                return ""
            } else {
                Write-Host "Input is required. Please enter a valid value." -ForegroundColor Red
                continue
            }
        }
        
        $userInput = $userInput.Trim()
        
        # Validate against valid values if specified
        if ($ValidValues.Count -gt 0) {
            $normalizedInput = $userInput.ToLower()
            $normalizedValidValues = $ValidValues | ForEach-Object { $_.ToLower() }
            
            if ($normalizedInput -notin $normalizedValidValues) {
                Write-Host "Invalid input. Please enter one of: $($ValidValues -join ', ')" -ForegroundColor Red
                continue
            }
        }
        
        return $userInput
        
    } while ($true)
}

function Test-YesResponse {
    <#
    .SYNOPSIS
        Tests if a response indicates "Yes" - supports y, yes (case insensitive)
    
    .PARAMETER Response
        The user's response to test
    
    .EXAMPLE
        $continue = Test-YesResponse (Read-UserPrompt -Prompt "Continue?" -IsYesNo $true)
    #>
    param(
        [string]$Response
    )
    
    return $Response.ToLower() -in @("y", "yes")
}

# Export functions for module usage only
if ($MyInvocation.MyCommand.ModuleName) {
    Export-ModuleMember -Function @(
        'Write-Step',
        'Write-Header',
        'Write-Success', 
        'Write-Warning',
        'Write-Error',
        'Write-Info',
        'Write-Progress',
        'Write-Banner',
        'Write-CompletionSummary',
        'Read-UserPrompt',
        'Test-YesResponse'
    )
}
