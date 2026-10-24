# run-all-tests.ps1
# Runs every test-*.ps1 script in this folder, one after another, then prints one summary table.
#
# How to run (in PowerShell, from the folder that contains the test scripts):
#   powershell -ExecutionPolicy Bypass -File .\run-all-tests.ps1
#
# The backend must already be running on port 8080.
# A few scripts still ask for a password or a reset code in the terminal. Type it when asked.
# The full output of each script is saved in a new test-results-<time> folder next to this file.

$ErrorActionPreference = "Continue"

# Run order follows the project steps. Any other test-*.ps1 file in this folder runs at the end.
$order = @(
    "test-3b.ps1",
    "test-3b-extra.ps1",
    "test-4.ps1",
    "test-5a.ps1",
    "test-5b.ps1",
    "test-6.ps1",
    "test-7.ps1",
    "test-7b.ps1",
    "test-7c.ps1",
    "test-7d.ps1",
    "test-9.ps1",
    "test-10.ps1",
    "test-12.ps1",
    "test-api.ps1"
)

$found = @(Get-ChildItem -Path $PSScriptRoot -Filter "test-*.ps1" | ForEach-Object { $_.Name })
$names = @()
foreach ($n in $order) { if ($found -contains $n) { $names += $n } }
foreach ($n in $found) { if ($names -notcontains $n) { $names += $n } }

if ($names.Count -eq 0) {
    Write-Host ("No test-*.ps1 files found in " + $PSScriptRoot) -ForegroundColor Red
    exit 1
}

# Most scripts read the admin password from ADMIN_PASSWORD, so it is asked for once here
if (-not $env:ADMIN_PASSWORD) {
    $secure = Read-Host "Admin password (asked once, used by the scripts)" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $env:ADMIN_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resultFolder = Join-Path $PSScriptRoot ("test-results-" + $stamp)
New-Item -ItemType Directory -Path $resultFolder | Out-Null

$rows = @()
$totalFailed = 0

foreach ($name in $names) {
    Write-Host ""
    Write-Host ("===== " + $name + " =====") -ForegroundColor Yellow

    # Show the output live and keep a copy in $captured
    & (Join-Path $PSScriptRoot $name) *>&1 | Tee-Object -Variable captured | Out-Host
    $text = ($captured | Out-String)
    $text | Out-File -FilePath (Join-Path $resultFolder ($name -replace '\.ps1$', '.txt')) -Encoding utf8

    if ($text -match 'Passed:\s*(\d+)\s+Failed:\s*(\d+)') {
        $passed = [int]$Matches[1]
        $failed = [int]$Matches[2]
        $totalFailed += $failed
        $result = "OK"
        if ($failed -gt 0) { $result = "FAILED" }
        $rows += [pscustomobject]@{ Script = $name; Passed = $passed; Failed = $failed; Result = $result }
    } else {
        $rows += [pscustomobject]@{ Script = $name; Passed = "-"; Failed = "-"; Result = "NO SUMMARY (see the .txt file)" }
    }
}

Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
$table = $rows | Format-Table -AutoSize | Out-String
Write-Host $table
$table | Out-File -FilePath (Join-Path $resultFolder "summary.txt") -Encoding utf8

# List every failed check line from the saved outputs
$failLines = @()
foreach ($file in Get-ChildItem -Path $resultFolder -Filter "*.txt") {
    $hits = Select-String -Path $file.FullName -Pattern '^\s*FAIL\s'
    foreach ($hit in $hits) {
        $failLines += ($file.BaseName + ": " + $hit.Line.Trim())
    }
}
if ($failLines.Count -gt 0) {
    Write-Host "Failed checks:" -ForegroundColor Red
    foreach ($line in $failLines) { Write-Host ("  " + $line) -ForegroundColor Red }
    Write-Host ""
}

if ($totalFailed -eq 0) {
    Write-Host "All scripts finished with 0 failed checks." -ForegroundColor Green
} else {
    Write-Host ("Total failed checks: " + $totalFailed) -ForegroundColor Red
}
Write-Host ("Full output saved in: " + $resultFolder)
