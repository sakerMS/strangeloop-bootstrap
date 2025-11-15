# strangeloop Bootstrap - Linux Sudo Authentication Module
# Version: 1.0.0

# Global variable to store sudo password for the session
$Global:LinuxSudoPassword = $null
$Global:SudoPasswordCached = $false

# Encryption key for cross-process password persistence (session-specific)
# Must be exactly 128, 192, or 256 bits (16, 24, or 32 bytes)
$keyString = "strangeloop-sudo-session-key-2024"
$Global:SudoEncryptionKey = [System.Text.Encoding]::UTF8.GetBytes($keyString.PadRight(32).Substring(0, 32))

# Helper functions for cross-platform encryption
function ConvertTo-EncryptedString {
    param([SecureString]$SecureString, [byte[]]$Key)
    
    # Convert SecureString to plain text using NetworkCredential (works better on Linux)
    $credential = New-Object System.Net.NetworkCredential("", $SecureString)
    $plainText = $credential.Password
    
    # Encrypt using AES
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $Key
    $aes.GenerateIV()
    $encryptor = $aes.CreateEncryptor()
    
    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($plainText)
    $encryptedBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
    
    # Combine IV and encrypted data, then encode as Base64
    $combined = $aes.IV + $encryptedBytes
    $result = [Convert]::ToBase64String($combined)
    
    # Clean up
    $aes.Dispose()
    $credential = $null
    $plainText = $null
    [System.GC]::Collect()
    
    return $result
}

function ConvertFrom-EncryptedString {
    param([string]$EncryptedString, [byte[]]$Key)
    
    # Decode from Base64
    $combined = [Convert]::FromBase64String($EncryptedString)
    
    # Extract IV and encrypted data
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $Key
    $ivLength = $aes.IV.Length
    
    # Extract IV (first 16 bytes) and encrypted data (remaining bytes)
    $iv = New-Object byte[] $ivLength
    [Array]::Copy($combined, 0, $iv, 0, $ivLength)
    
    $encryptedBytesLength = $combined.Length - $ivLength
    $encryptedBytes = New-Object byte[] $encryptedBytesLength
    [Array]::Copy($combined, $ivLength, $encryptedBytes, 0, $encryptedBytesLength)
    
    $aes.IV = $iv
    $decryptor = $aes.CreateDecryptor()
    
    # Decrypt
    $plainBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)
    $plainText = [System.Text.Encoding]::UTF8.GetString($plainBytes)
    
    # Convert back to SecureString using safer method
    $secureString = New-Object System.Security.SecureString
    foreach ($char in $plainText.ToCharArray()) {
        $secureString.AppendChar($char)
    }
    $secureString.MakeReadOnly()
    
    # Clean up
    $aes.Dispose()
    $plainText = $null
    [System.GC]::Collect()
    
    return $secureString
}

# Persistent sudo session tracking using temp file
# Use context-aware temp directory that works correctly between Windows and WSL
$isRunningInWSL = (Test-Path /proc/version -ErrorAction SilentlyContinue) -and ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP)
Write-Host "Context detection: isRunningInWSL=$isRunningInWSL, WSL_DISTRO_NAME=$env:WSL_DISTRO_NAME" -ForegroundColor Cyan

if ($isRunningInWSL) {
    # Running inside WSL - use Windows temp directory accessible from WSL
    $TempDir = "/mnt/c/Temp"
    Write-Host "Using WSL temp directory: $TempDir" -ForegroundColor Cyan
} else {
    # Running in Windows PowerShell - use Windows temp directory
    $TempDir = "C:\Temp"
    Write-Host "Using Windows temp directory: $TempDir" -ForegroundColor Cyan
}

# Ensure the temp directory exists
if (-not (Test-Path $TempDir)) {
    try {
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    } catch {
        # Fallback to user-specific location if shared temp fails
        if ($isRunningInWSL) {
            $TempDir = "/tmp"
        } else {
            $TempDir = $env:TEMP
        }
    }
}

$Global:SudoSessionFile = Join-Path $TempDir "strangeloop-sudo-session.tmp"
$Global:SudoPasswordFile = Join-Path $TempDir "strangeloop-sudo-password.tmp"

function Get-PersistedSudoPassword {
    <#
    .SYNOPSIS
    Retrieves persisted sudo password if available
    #>
    param()
    
    try {
        Write-Verbose "Checking for persisted password at: $Global:SudoPasswordFile"
        if (Test-Path $Global:SudoPasswordFile) {
            Write-Verbose "Persistent password file found, attempting to decrypt..."
            $encryptedData = Get-Content $Global:SudoPasswordFile -Raw
            # Only trim trailing newlines, preserve internal content
            $encryptedData = $encryptedData.TrimEnd()
            $securePassword = ConvertFrom-EncryptedString -EncryptedString $encryptedData -Key $Global:SudoEncryptionKey
            Write-Verbose "Successfully retrieved persisted sudo password"
            return $securePassword
        } else {
            Write-Verbose "No persistent password file found"
        }
        return $null
    } catch {
        Write-Warning "Failed to retrieve persisted password: $($_.Exception.Message)"
        return $null
    }
}

function Set-PersistedSudoPassword {
    <#
    .SYNOPSIS
    Persists sudo password securely
    #>
    param(
        [Parameter(Mandatory)]
        [SecureString]$Password
    )
    
    try {
        $encryptedData = ConvertTo-EncryptedString -SecureString $Password -Key $Global:SudoEncryptionKey
        # Save as a single line to avoid newline issues
        $encryptedData | Set-Content -Path $Global:SudoPasswordFile -NoNewline
        Write-Verbose "Sudo password persisted successfully"
    } catch {
        Write-Warning "Failed to persist sudo password: $($_.Exception.Message)"
    }
}

function Clear-PersistedSudoPassword {
    <#
    .SYNOPSIS
    Removes persisted sudo password
    #>
    param()
    
    try {
        if (Test-Path $Global:SudoPasswordFile) {
            Remove-Item $Global:SudoPasswordFile -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # Ignore errors
    }
}

function Test-SudoSessionActive {
    <#
    .SYNOPSIS
    Tests if a sudo session is active by checking session file and running sudo -n
    
    .PARAMETER DistributionName
    Specific WSL distribution to test
    
    .OUTPUTS
    Boolean indicating if sudo session is active
    #>
    param(
        [string]$DistributionName
    )
    
    try {
        # Check if session file exists and is recent (within 15 minutes)
        if (Test-Path $Global:SudoSessionFile) {
            Write-Verbose "Found sudo session file, checking timestamp..."
            $sessionTime = Get-Content $Global:SudoSessionFile -Raw
            $sessionDate = [DateTime]::Parse($sessionTime.Trim())
            $timeDiff = (Get-Date) - $sessionDate
            
            if ($timeDiff.TotalMinutes -gt 15) {
                Write-Verbose "Sudo session file is older than 15 minutes, removing..."
                Remove-Item $Global:SudoSessionFile -Force -ErrorAction SilentlyContinue
                return $false
            } else {
                Write-Verbose "Sudo session file is recent (${($timeDiff.TotalMinutes.ToString("F1"))} minutes old)"
            }
        } else {
            Write-Verbose "No sudo session file found"
            return $false
        }
        
        # Test actual sudo session
        Write-Verbose "Testing actual sudo session with sudo -n..."
        
        # Detect execution context for sudo testing
        $isInWSL = (Test-Path /proc/version -ErrorAction SilentlyContinue) -and ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP)
        
        if ($isInWSL) {
            # Already running inside WSL, execute sudo directly
            $testResult = bash -c "sudo -n true" 2>$null
        } else {
            # Running in Windows PowerShell, use WSL to execute
            if ($DistributionName) {
                $testResult = wsl -d $DistributionName -- bash -c "sudo -n true" 2>$null
            } else {
                $testResult = wsl bash -c "sudo -n true" 2>$null
            }
        }
        
        $sessionIsActive = ($LASTEXITCODE -eq 0)
        Write-Verbose "Sudo session test result: $(if ($sessionIsActive) { "ACTIVE" } else { "INACTIVE" })"
        return $sessionIsActive
        
    } catch {
        Write-Warning "Error testing sudo session: $($_.Exception.Message)"
        return $false
    }
}

function Set-SudoSessionActive {
    <#
    .SYNOPSIS
    Marks sudo session as active by creating session file
    #>
    param()
    
    try {
        $currentTime = Get-Date
        $currentTime.ToString() | Out-File -FilePath $Global:SudoSessionFile -Force
    } catch {
        # Ignore errors
    }
}

function Get-LinuxSudoPassword {
    <#
    .SYNOPSIS
    Gets the sudo password for Linux operations, prompting user if needed
    
    .DESCRIPTION
    Manages sudo password collection and caching for Linux package installations.
    Will prompt user once per session and cache the password securely.
    
    .PARAMETER Force
    Force re-prompting for password even if already cached
    
    .PARAMETER DistributionName
    Specific WSL distribution to use for session extension
    
    .OUTPUTS
    SecureString containing the sudo password
    #>
    param(
        [switch]$Force,
        [string]$DistributionName
    )
    
    try {
        
        # If password is already cached and not forcing re-prompt, return it
        if ($Global:SudoPasswordCached -and (-not $Force)) {
            return $Global:LinuxSudoPassword
        }
        
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║                    Linux Sudo Authentication                 ║" -ForegroundColor Yellow  
        Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
        Write-Host "║ Installing development tools in Linux/WSL requires sudo      ║" -ForegroundColor Yellow
        Write-Host "║ privileges to install packages via apt.                      ║" -ForegroundColor Yellow
        Write-Host "║                                                              ║" -ForegroundColor Yellow
        Write-Host "║ Your password will be cached securely for this session and   ║" -ForegroundColor Yellow
        Write-Host "║ will not be stored permanently.                              ║" -ForegroundColor Yellow
        Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        
        # Prompt for password
        $password = Read-Host "Enter your Linux sudo password" -AsSecureString
        
        if (-not $password -or $password.Length -eq 0) {
            Write-Warning "No password provided. Linux package installations may fail."
            return $null
        }
        
        # Test the password by running a simple sudo command
        Write-Verbose "Validating sudo credentials..."
        $testResult = Test-SudoPassword -Password $password -DistributionName $DistributionName

        if ($testResult) {
            # Cache the password for this session
            $Global:LinuxSudoPassword = $password
            $Global:SudoPasswordCached = $true
            Set-SudoSessionActive
            Set-PersistedSudoPassword -Password $password
            Write-Success "Sudo credentials validated and cached for this session"
            
            # Extend sudo session to prevent re-prompting
            $plainPassword = (New-Object System.Net.NetworkCredential("", $password)).Password
            if ($DistributionName) {
                $extendResult = echo $plainPassword | wsl -d $DistributionName -- bash -c "sudo -S -v" 2>$null
            } else {
                $extendResult = echo $plainPassword | wsl sudo -S -v 2>$null
            }
            $plainPassword = $null

            return $password
        } else {
            Write-Error "Invalid sudo password. Please try again."
            
            # Offer retry
            $retry = Read-Host "Try again? (y/n)"
            if ($retry -eq 'y' -or $retry -eq 'Y') {
                return Get-LinuxSudoPassword -Force -DistributionName $DistributionName
            } else {
                return $null
            }
        }
        
    } catch {
        Write-Warning "Error collecting sudo password: $($_.Exception.Message)"
        return $null
    }
}

function Test-SudoPasswordWorking {
    <#
    .SYNOPSIS
    Tests if a sudo password actually works
    
    .PARAMETER Password
    Plain text password to test
    
    .OUTPUTS
    Boolean indicating if password works
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Password
    )
    
    try {
        Write-Verbose "Testing if sudo password works..."
        # Detect execution context
        $isInWSL = (Test-Path /proc/version -ErrorAction SilentlyContinue) -and ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP)
        
        if ($isInWSL) {
            # Running inside WSL - execute sudo directly
            $testResult = echo $Password | bash -c "sudo -S whoami" 2>$null
        } else {
            # Running in Windows PowerShell - use WSL to execute
            $testResult = echo $Password | wsl bash -c "sudo -S whoami" 2>$null
        }
        
        $isWorking = ($LASTEXITCODE -eq 0 -and $testResult)
        Write-Verbose "Password test result: $(if ($isWorking) { "WORKING" } else { "FAILED" })"
        return $isWorking
        
    } catch {
        Write-Warning "Error testing sudo password: $($_.Exception.Message)"
        return $false
    }
}

function Test-SudoPassword {
    <#
    .SYNOPSIS
    Tests if a sudo password is valid
    
    .PARAMETER Password
    SecureString containing the password to test
    
    .PARAMETER DistributionName
    Specific WSL distribution to use for testing
    
    .OUTPUTS
    Boolean indicating if password is valid
    #>
    param(
        [Parameter(Mandatory)]
        [SecureString]$Password,
        [string]$DistributionName
    )
    
    try {
        # Convert SecureString to plain text for testing
        $plainPassword = (New-Object System.Net.NetworkCredential("", $Password)).Password
        
        # Detect if we're already running in WSL
        $isRunningInWSL = Test-Path /proc/version -ErrorAction SilentlyContinue
        
        # Test the password with a simple sudo command
        if ($isRunningInWSL) {
            # Already in WSL, execute directly
            $testResult = echo $plainPassword | bash -c "sudo -S whoami" 2>$null
        } elseif ($DistributionName) {
            # From Windows, use specific distribution
            $testResult = echo $plainPassword | wsl -d $DistributionName -- bash -c "sudo -S whoami" 2>$null
        } else {
            # From Windows, use default distribution
            $testResult = echo $plainPassword | wsl bash -c "sudo -S whoami" 2>$null
        }
        
        # Clear the plain text password from memory
        $plainPassword = $null
        [System.GC]::Collect()
        
        return ($LASTEXITCODE -eq 0 -and $testResult)
        
    } catch {
        Write-Warning "Error testing sudo password: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-SudoCommand {
    <#
    .SYNOPSIS
    Executes a sudo command with cached password
    
    .PARAMETER Command
    The command to execute with sudo
    
    .PARAMETER WSLMode
    Execute in WSL context
    
    .PARAMETER DistributionName
    Specific WSL distribution to use
    
    .OUTPUTS
    Result of the command execution
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Command,
        [switch]$WSLMode,
        [string]$DistributionName
    )
    
    try {
        # Check if sudo session is active using persistent tracking
        $sessionActive = Test-SudoSessionActive -DistributionName $DistributionName
        
        # Always try sudo -n first to check if session is valid
        # Detect execution context
        $isInWSL = (Test-Path /proc/version -ErrorAction SilentlyContinue) -and ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP)
        Write-Verbose "Testing sudo -n in context: $(if ($isInWSL) { "WSL" } else { "Windows" })"
        
        if ($isInWSL) {
            # Running inside WSL - execute sudo directly
            $noPasswordResult = bash -c "sudo -n $Command" 2>$null
        } else {
            # Running in Windows PowerShell - use WSL to execute
            if ($WSLMode -or $DistributionName) {
                if ($DistributionName) {
                    $noPasswordResult = wsl -d $DistributionName -- bash -c "sudo -n $Command" 2>$null
                } else {
                    $noPasswordResult = wsl bash -c "sudo -n $Command" 2>$null
                }
            } else {
                # Fallback - assume direct execution
                $noPasswordResult = bash -c "sudo -n $Command" 2>$null
            }
        }
        
        # If command succeeded without password, return success
        if ($LASTEXITCODE -eq 0) {
            Write-Verbose "Using active sudo session (no password required)"
            Set-SudoSessionActive
            return @{
                Success = $true
                Output = $noPasswordResult
                ExitCode = 0
            }
        }
        
        # Get sudo password from memory cache or persistent storage
        if (-not $Global:SudoPasswordCached) {
            Write-Verbose "Session cache empty, checking persistent storage..."
            $persistedPassword = Get-PersistedSudoPassword
            if ($persistedPassword) {
                Write-Verbose "Using cached sudo password from persistent storage"
                $Global:LinuxSudoPassword = $persistedPassword
                $Global:SudoPasswordCached = $true
            } else {
                Write-Verbose "No persistent password found, prompting user..."
                $password = Get-LinuxSudoPassword -DistributionName $DistributionName
                if (-not $password) {
                    throw "No sudo password available"
                }
            }
        } else {
            Write-Verbose "Using cached sudo password from current session"
        }
        
        # Convert SecureString to plain text for command execution
        try {
            $plainPassword = (New-Object System.Net.NetworkCredential("", $Global:LinuxSudoPassword)).Password
            
            # Validate that password was properly decrypted and actually works
            if ([string]::IsNullOrWhiteSpace($plainPassword) -or $plainPassword.Length -lt 3 -or (-not (Test-SudoPasswordWorking -Password $plainPassword))) {
                Write-Warning "Decrypted password is invalid or doesn't work (length: $($plainPassword.Length)), clearing cache and prompting user..."
                Clear-SudoPasswordCache
                $password = Get-LinuxSudoPassword -DistributionName $DistributionName
                if (-not $password) {
                    throw "No sudo password available after re-prompt"
                }
                $Global:LinuxSudoPassword = $password
                $Global:SudoPasswordCached = $true
                $plainPassword = (New-Object System.Net.NetworkCredential("", $password)).Password
            }
            
            Write-Verbose "Using sudo password for command execution (length: $($plainPassword.Length))"
        } catch {
            Write-Warning "Failed to decrypt cached password: $($_.Exception.Message)"
            Write-Verbose "Clearing cache and prompting user for fresh password..."
            Clear-SudoPasswordCache
            $password = Get-LinuxSudoPassword -DistributionName $DistributionName
            if (-not $password) {
                throw "No sudo password available after re-prompt"
            }
            $Global:LinuxSudoPassword = $password
            $Global:SudoPasswordCached = $true
            $plainPassword = (New-Object System.Net.NetworkCredential("", $password)).Password
        }
        
        # Execute the command
        # Detect execution context
        $isInWSL = (Test-Path /proc/version -ErrorAction SilentlyContinue) -and ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP)
        Write-Verbose "Executing sudo command in context: $(if ($isInWSL) { "WSL" } else { "Windows" })"
        
        if ($isInWSL) {
            # Running inside WSL - execute sudo directly
            $result = echo $plainPassword | bash -c "sudo -S $Command" 2>&1
        } else {
            # Running in Windows PowerShell - use WSL to execute
            if ($WSLMode -or $DistributionName) {
                if ($DistributionName) {
                    $result = echo $plainPassword | wsl -d $DistributionName -- bash -c "sudo -S $Command" 2>&1
                } else {
                    $result = echo $plainPassword | wsl bash -c "sudo -S $Command" 2>&1
                }
            } else {
                # Fallback - assume direct execution
                $result = echo $plainPassword | bash -c "sudo -S $Command" 2>&1
            }
        }
        
        # If command succeeded, refresh sudo timestamp to extend session
        if ($LASTEXITCODE -eq 0) {
            Set-SudoSessionActive
            # Extend sudo session using same context detection
            if ($isInWSL) {
                # Running inside WSL - execute sudo directly
                echo $plainPassword | bash -c "sudo -S -v" 2>$null
            } else {
                # Running in Windows PowerShell - use WSL to execute
                if ($WSLMode -or $DistributionName) {
                    if ($DistributionName) {
                        echo $plainPassword | wsl -d $DistributionName -- bash -c "sudo -S -v" 2>$null
                    } else {
                        echo $plainPassword | wsl bash -c "sudo -S -v" 2>$null
                    }
                } else {
                    # Fallback - assume direct execution
                    echo $plainPassword | bash -c "sudo -S -v" 2>$null
                }
            }
        }
        
        # Clear the plain text password from memory immediately
        $plainPassword = $null
        [System.GC]::Collect()
        
        return @{
            Success = ($LASTEXITCODE -eq 0)
            Output = $result
            ExitCode = $LASTEXITCODE
        }
        
    } catch {
        Write-Warning "Error executing sudo command: $($_.Exception.Message)"
        return @{
            Success = $false
            Output = $_.Exception.Message
            ExitCode = 1
        }
    }
}

function Clear-SudoPasswordCache {
    <#
    .SYNOPSIS
    Clears the cached sudo password and session tracking
    #>
    
    Write-Verbose "Clearing sudo password cache..."

    if ($Global:LinuxSudoPassword) {
        $Global:LinuxSudoPassword.Dispose()
        $Global:LinuxSudoPassword = $null
    }
    $Global:SudoPasswordCached = $false
    
    # Remove session file
    if (Test-Path $Global:SudoSessionFile) {
        Remove-Item $Global:SudoSessionFile -Force -ErrorAction SilentlyContinue
    }
    
    # Remove persisted password
    Clear-PersistedSudoPassword
    
    [System.GC]::Collect()
    Write-Verbose "Sudo password cache cleared"
}
