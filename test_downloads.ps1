<#
StrangeLoop Bootstrap Download Tester

Purpose:
  - Verify that all scripts fetched dynamically by the launcher are downloadable.
  - Detect known corruption patterns (e.g., stray "}n Entry Point").
  - Validate that downloaded scripts parse cleanly in PowerShell (no syntax errors).

Usage:
  pwsh -File .\test_downloads.ps1 [-BaseUrl <url>] [-Verbose] [-OutDir <path>] [-IncludeLauncher]

Defaults:
  -BaseUrl defaults to the repository's raw GitHub main branch.
  -OutDir defaults to a temp folder under $env:TEMP.

Exit Codes:
  0 = All downloads OK, no corruption, parse clean
  1 = One or more warnings/errors (download failed, corruption detected, or parse errors)
#>

param(
    [string]$BaseUrl = "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main",
    [string]$OutDir,
    [switch]$IncludeLauncher,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($Verbose) { $VerbosePreference = "Continue" }

Write-Host "\n=== StrangeLoop Bootstrap: Download/Parse Test ===" -ForegroundColor Cyan
Write-Host "BaseUrl: $BaseUrl" -ForegroundColor Gray

if (-not $OutDir) {
    $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $OutDir = Join-Path $env:TEMP "strangeloop-downloads-$timestamp"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Verbose "Artifacts directory: $OutDir"

# List of scripts to test
$scriptPaths = [ordered]@{
    Main    = "scripts/strangeloop_main.ps1"
    Linux   = "scripts/strangeloop_linux.ps1"
    Windows = "scripts/strangeloop_windows.ps1"
}
if ($IncludeLauncher) {
    $scriptPaths = [ordered]@{ Launcher = "setup_strangeloop.ps1" } + $scriptPaths
}

# Known corruption indicators observed in remote content (non-regex)
$corruptionIndicators = @(
    "}n Entry Point"  # stray token injected after closing brace
)

function Test-DownloadScript {
    param(
        [string]$Name,
        [string]$RelativePath
    )

    $url = "$BaseUrl/" + $RelativePath.TrimStart('/')
    $result = [ordered]@{
        Name = $Name
        Url = $url
        File = $null
        SizeBytes = 0
        HttpOk = $false
        CorruptionDetected = $false
        CorruptionDetails = @()
        ParseOk = $false
        ParseErrors = @()
        Notes = @()
    }

    Write-Host "\n- Downloading: $Name" -ForegroundColor Yellow
    Write-Verbose "URL: $url"
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        if ($response.StatusCode -ne 200) {
            throw "HTTP $($response.StatusCode)"
        }
        $content = $response.Content
        $bytes = [System.Text.Encoding]::UTF8.GetByteCount($content)
        $result.SizeBytes = $bytes
        $result.HttpOk = $true
        $filePath = Join-Path $OutDir ("$Name.ps1")
        Set-Content -Path $filePath -Value $content -Encoding UTF8
        $result.File = $filePath
        Write-Host "  ✓ Downloaded ($bytes bytes) -> $filePath" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Download failed: $($_.Exception.Message)" -ForegroundColor Red
        $result.Notes += $_.Exception.Message
        return $result
    }

    # Corruption scan (substring and exact-line checks)
    $raw = Get-Content -Path $result.File -Raw
    foreach ($ind in $corruptionIndicators) {
        if ($raw -like "*${ind}*") {
            $result.CorruptionDetected = $true
            $result.CorruptionDetails += "Indicator '$ind' found in content"
        }
    }
    # Also check for any line that is exactly 'n Entry Point' (ignoring surrounding whitespace)
    $lines = $raw -split "\r?\n"
    $lineCount = ($lines | Where-Object { $_.Trim() -eq 'n Entry Point' } | Measure-Object).Count
    if ($lineCount -gt 0) {
        $result.CorruptionDetected = $true
        $result.CorruptionDetails += "Found $lineCount line(s) equal to 'n Entry Point'"
    }
    if ($result.CorruptionDetected) {
        Write-Host "  ⚠ Corruption markers detected" -ForegroundColor Yellow
        foreach ($d in $result.CorruptionDetails) { Write-Host "    - $d" -ForegroundColor DarkYellow }
    } else {
        Write-Verbose "  No known corruption patterns found"
    }

    # Parse validation using PowerShell parser (no execution)
    try {
        $tokens = $null
        $errors = $null
        # Parse input from string to avoid file encoding issues
        [void][System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Path $result.File -Raw), [ref]$tokens, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            $result.ParseOk = $false
            $result.ParseErrors = $errors | ForEach-Object { $_.Message }
            Write-Host "  ✗ Parse errors: $($errors.Count)" -ForegroundColor Red
            foreach ($e in $result.ParseErrors | Select-Object -First 5) { Write-Host "    - $e" -ForegroundColor DarkRed }
        } else {
            $result.ParseOk = $true
            Write-Host "  ✓ Parse OK" -ForegroundColor Green
        }
    } catch {
        $result.ParseOk = $false
        $result.ParseErrors = @($_.Exception.Message)
        Write-Host "  ✗ Parser threw exception: $($_.Exception.Message)" -ForegroundColor Red
    }

    return $result
}

$results = @()
foreach ($kvp in $scriptPaths.GetEnumerator()) {
    $results += Test-DownloadScript -Name $kvp.Key -RelativePath $kvp.Value
}

Write-Host "\n=== Summary ===" -ForegroundColor Cyan
$failCount = 0
foreach ($r in $results) {
    $status = if ($r.HttpOk -and $r.ParseOk -and -not $r.CorruptionDetected) { "OK" } else { "FAIL" }
    if ($status -eq "FAIL") { $failCount++ }
    $details = @()
    if (-not $r.HttpOk) { $details += "download" }
    if ($r.CorruptionDetected) { $details += "corruption" }
    if (-not $r.ParseOk) { $details += "parse" }
    Write-Host (" - {0,-8} : {1} ({2})" -f $r.Name, $status, ($details -join ", ")) -ForegroundColor ($status -eq 'OK' ? 'Green' : 'Red')
}

if ($failCount -gt 0) {
    Write-Host "\n✗ One or more checks failed. See artifacts in: $OutDir" -ForegroundColor Red
    exit 1
} else {
    Write-Host "\n✓ All downloads look good. Artifacts in: $OutDir" -ForegroundColor Green
    exit 0
}
