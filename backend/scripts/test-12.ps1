# test-12.ps1 - login lockout: five wrong passwords in a row lock the username for 15 minutes
#   Creates new test accounts on every run (names end with a timestamp).
#   Needs the restarted app and the Step 7d files (Clock bean).
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\test-12.ps1

$BaseUrl     = "http://localhost:8080"
$DefaultUser = "ADMIN"

$adminPass = $env:ADMIN_PASSWORD
if (-not $adminPass) { $adminPass = Read-Host "Password of the ADMIN account" }

$stamp  = Get-Date -Format "HHmmss"
$passed = 0
$failed = 0

function Call-Api {
    param(
        [string]$Method,
        [string]$Path,
        $Body = $null,
        [string]$Token = ""
    )

    $headers = @{}
    if ($Token -ne "") { $headers["Authorization"] = "Bearer $Token" }

    if ($Method -eq "GET" -and $Path -notmatch "\?") { $Path = $Path + '?size=100' }
    $params = @{
        Method          = $Method
        Uri             = "$BaseUrl$Path"
        Headers         = $headers
        ContentType     = "application/json"
        UseBasicParsing = $true
    }
    if ($null -ne $Body) {
        $params["Body"] = ConvertTo-Json -InputObject $Body -Depth 6
    }

    try {
        $resp = Invoke-WebRequest @params
        $data = $null
        if ($resp.Content) {
            $data = ConvertFrom-Json -InputObject $resp.Content
            if ($null -ne $data -and $data.PSObject.Properties.Name -contains "data") { $data = $data.data }
        }
        return @{ Status = [int]$resp.StatusCode; Data = $data }
    }
    catch {
        $status = 0
        $text   = ""
        $response = $_.Exception.Response
        if ($null -ne $response) {
            $status = [int]$response.StatusCode
            if ($response -is [System.Net.HttpWebResponse]) {        # Windows PowerShell 5.1
                $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
                $text = $reader.ReadToEnd()
            }
            else {                                                    # PowerShell 7
                $text = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            }
        }
        $data = $null
        if ($text) {
            try { $data = ConvertFrom-Json -InputObject $text } catch { $data = $null }
        }
        return @{ Status = $status; Data = $data }
    }
}

function Expect {
    param([string]$Name, [bool]$Condition)
    if ($Condition) {
        Write-Host ("PASS  " + $Name) -ForegroundColor Green
        $script:passed++
    }
    else {
        Write-Host ("FAIL  " + $Name) -ForegroundColor Red
        $script:failed++
    }
}

function Login {
    param([string]$User, [string]$Pass)
    return Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $User; password = $Pass }
}

# Sends `Count` wrong passwords for a user; returns $true only if every answer was 401
function Wrong-Logins {
    param([string]$User, [int]$Count)
    $allRefused = $true
    for ($i = 1; $i -le $Count; $i++) {
        $r = Login $User "wrong-password-$i"
        if ($r.Status -ne 401) { $allRefused = $false }
    }
    return $allRefused
}

# ---------------- Setup ----------------
Write-Host "== Setup" -ForegroundColor Cyan

$r = Login $DefaultUser $adminPass
Expect "0a ADMIN logs in" ($r.Status -eq 200)
if ($r.Status -ne 200) { Write-Host "Cannot continue without the ADMIN login." -ForegroundColor Red; exit 1 }
$token = $r.Data.token

$lockUser = "lock$stamp"
$lockPass = "LockPw-$stamp"
$okUser   = "okay$stamp"
$okPass   = "OkayPw-$stamp"

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $token -Body @{
    username = $lockUser; password = $lockPass; role = "RECEPTIONIST" }
Expect "0b account for the lock test is created (201)" ($r.Status -eq 201)

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $token -Body @{
    username = $okUser; password = $okPass; role = "RECEPTIONIST" }
Expect "0c account for the other-user test is created (201)" ($r.Status -eq 201)

# ---------------- Lock after five wrong passwords ----------------
Write-Host "== Lock after five wrong passwords" -ForegroundColor Cyan

Expect "L1 four wrong passwords are each refused (401)" (Wrong-Logins $lockUser 4)

$r = Login $lockUser "wrong-password-5"
Expect "L2 the fifth wrong password is refused (401) and locks the username" ($r.Status -eq 401)

$r = Login $lockUser $lockPass
Expect "L3 the correct password is refused while locked (429)" ($r.Status -eq 429)

$r = Login $lockUser "wrong-password-6"
Expect "L4 a wrong password while locked is 429, not 401 (no more guessing)" ($r.Status -eq 429)

$r = Login $okUser $okPass
Expect "L5 another username is not affected (200)" ($r.Status -eq 200)

# ---------------- Unknown usernames are counted too ----------------
Write-Host "== Unknown usernames" -ForegroundColor Cyan

$ghost = "ghost$stamp"
Expect "G1 five wrong tries for an unknown username are each 401" (Wrong-Logins $ghost 5)

$r = Login $ghost "wrong-password-6"
Expect "G2 the next try is 429, the same answer a real locked account gets" ($r.Status -eq 429)

# ---------------- A success clears the count ----------------
Write-Host "== A success clears the count" -ForegroundColor Cyan

Expect "R1 four wrong passwords for the other user are each 401" (Wrong-Logins $okUser 4)

$r = Login $okUser $okPass
Expect "R2 the correct password works and clears the count (200)" ($r.Status -eq 200)

Expect "R3 four more wrong passwords still do not lock (each 401)" (Wrong-Logins $okUser 4)

$r = Login $okUser $okPass
Expect "R4 the account still logs in (200)" ($r.Status -eq 200)

# ---------------- Result ----------------
Write-Host ""
Write-Host ("Passed: " + $passed + "   Failed: " + $failed) -ForegroundColor Cyan
Write-Host ("Test accounts were created with the suffix " + $stamp + ". Locks end 15 minutes after the last wrong password.")
