# Test Git Configuration Functions
# Tests the Git configuration detection and setting functionality

param(
    [string]$Distribution = "Ubuntu-24.04"
)

Write-Host "Testing Git Configuration Functions..." -ForegroundColor Green

# Test 1: Check if existing Git config can be detected
Write-Host "`n1. Testing Git config detection..." -ForegroundColor Yellow

$existingName = wsl -d $Distribution -- bash -c "git config --global user.name 2>/dev/null || echo ''"
$existingEmail = wsl -d $Distribution -- bash -c "git config --global user.email 2>/dev/null || echo ''"

if ($existingName -and $existingName.Trim() -ne "") {
    Write-Host "   ✓ Found existing Git user name: '$($existingName.Trim())'" -ForegroundColor Green
} else {
    Write-Host "   ⚠ No existing Git user name found" -ForegroundColor Yellow
}

if ($existingEmail -and $existingEmail.Trim() -ne "") {
    Write-Host "   ✓ Found existing Git user email: '$($existingEmail.Trim())'" -ForegroundColor Green
} else {
    Write-Host "   ⚠ No existing Git user email found" -ForegroundColor Yellow
}

# Test 2: Test Git config setting with quotes
Write-Host "`n2. Testing Git config setting with special characters..." -ForegroundColor Yellow

$testName = "Test User With Spaces"
$testEmail = "test.user@example.com"

# Save original values
$originalName = $existingName
$originalEmail = $existingEmail

try {
    # Test setting name with spaces
    $nameCommand = "git config --global user.name '$testName'"
    wsl -d $Distribution -- bash -c $nameCommand
    
    $verifyName = wsl -d $Distribution -- bash -c "git config --global user.name"
    if ($verifyName -eq $testName) {
        Write-Host "   ✓ Successfully set Git user name with spaces" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Failed to set Git user name. Expected: '$testName', Got: '$verifyName'" -ForegroundColor Red
    }
    
    # Test setting email
    $emailCommand = "git config --global user.email '$testEmail'"
    wsl -d $Distribution -- bash -c $emailCommand
    
    $verifyEmail = wsl -d $Distribution -- bash -c "git config --global user.email"
    if ($verifyEmail -eq $testEmail) {
        Write-Host "   ✓ Successfully set Git user email" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Failed to set Git user email. Expected: '$testEmail', Got: '$verifyEmail'" -ForegroundColor Red
    }
    
} finally {
    # Restore original values
    if ($originalName -and $originalName.Trim() -ne "") {
        wsl -d $Distribution -- bash -c "git config --global user.name '$($originalName.Trim())'"
        Write-Host "   ↺ Restored original Git user name" -ForegroundColor Cyan
    }
    if ($originalEmail -and $originalEmail.Trim() -ne "") {
        wsl -d $Distribution -- bash -c "git config --global user.email '$($originalEmail.Trim())'"
        Write-Host "   ↺ Restored original Git user email" -ForegroundColor Cyan
    }
}

Write-Host "`n✓ Git configuration tests completed!" -ForegroundColor Green
