# test-9.ps1 - Step 9: refresh tokens, logout, /me, change password, password reset by email code
#   Creates a new test account on every run (names end with a timestamp).
#   Needs the restarted app with app.otp.mode=log. The reset code is printed in the app console.
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\test-9.ps1

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

# ---------------- Setup ----------------
Write-Host "== Setup" -ForegroundColor Cyan

$admin = Login $DefaultUser $adminPass
Expect "0a ADMIN logs in (200)" ($admin.Status -eq 200)
if ($admin.Status -ne 200) { Write-Host "Cannot continue without the ADMIN login." -ForegroundColor Red; exit 1 }
$adminToken = $admin.Data.token

$user     = "sess$stamp"
$firstPw  = "FirstPw-$stamp"
$secondPw = "SecondPw-$stamp"
$resetPw  = "ResetPw-$stamp"
$email    = "sess$stamp@example.test"

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $adminToken -Body @{
    username = $user; password = $firstPw; role = "RECEPTIONIST"; email = $email }
Expect "0b test account with an email is created (201)" ($r.Status -eq 201)

# ---------------- Refresh tokens ----------------
Write-Host "== Refresh tokens" -ForegroundColor Cyan

$login = Login $user $firstPw
Expect "S1 login returns an access token and a refresh token (200)" ($login.Status -eq 200 -and $null -ne $login.Data.refreshToken)
$refresh1 = $login.Data.refreshToken

$r = Call-Api -Method POST -Path "/api/auth/refresh" -Body @{ refreshToken = $refresh1 }
Expect "S2 refresh gives a new access token and a new refresh token (200)" ($r.Status -eq 200 -and $r.Data.refreshToken -ne $refresh1)
$refresh2 = $r.Data.refreshToken
$access2  = $r.Data.token

$r = Call-Api -Method POST -Path "/api/auth/refresh" -Body @{ refreshToken = $refresh1 }
Expect "S3 the old refresh token cannot be used again (401)" ($r.Status -eq 401)

$r = Call-Api -Method POST -Path "/api/auth/refresh" -Body @{ refreshToken = $refresh2 }
Expect "S4 reuse ends every session: the newer refresh token is refused too (401)" ($r.Status -eq 401)

$r = Call-Api -Method GET -Path "/api/auth/me" -Token $access2
Expect "S5 the access token from S2 still works for /me (200)" ($r.Status -eq 200 -and $r.Data.username -eq $user)

# ---------------- Logout ----------------
Write-Host "== Logout" -ForegroundColor Cyan

$login = Login $user $firstPw
$refresh3 = $login.Data.refreshToken
$r = Call-Api -Method POST -Path "/api/auth/logout" -Body @{ refreshToken = $refresh3 }
Expect "O1 logout ends this session (204)" ($r.Status -eq 204)

$r = Call-Api -Method POST -Path "/api/auth/refresh" -Body @{ refreshToken = $refresh3 }
Expect "O2 the logged-out refresh token is refused (401)" ($r.Status -eq 401)

$r = Call-Api -Method POST -Path "/api/auth/logout" -Body @{ refreshToken = "not-a-real-token" }
Expect "O3 logout with an unknown token is still 204 (nothing to revoke)" ($r.Status -eq 204)

# ---------------- Logout everywhere ----------------
Write-Host "== Logout everywhere" -ForegroundColor Cyan

$deviceA = Login $user $firstPw
$deviceB = Login $user $firstPw
$r = Call-Api -Method POST -Path "/api/auth/logout-all" -Token $deviceB.Data.token
Expect "G1 logout-all with a valid access token (204)" ($r.Status -eq 204)

$r = Call-Api -Method POST -Path "/api/auth/refresh" -Body @{ refreshToken = $deviceA.Data.refreshToken }
Expect "G2 the first device's session is ended (401)" ($r.Status -eq 401)

$r = Call-Api -Method POST -Path "/api/auth/refresh" -Body @{ refreshToken = $deviceB.Data.refreshToken }
Expect "G3 the second device's session is ended (401)" ($r.Status -eq 401)

# ---------------- /me ----------------
Write-Host "== Me" -ForegroundColor Cyan

$r = Call-Api -Method GET -Path "/api/auth/me"
Expect "M1 /me without a token is refused (401)" ($r.Status -eq 401)

$login = Login $user $firstPw
$r = Call-Api -Method GET -Path "/api/auth/me" -Token $login.Data.token
Expect "M2 /me returns the account (200, role RECEPTIONIST)" ($r.Status -eq 200 -and $r.Data.role -eq "RECEPTIONIST" -and $r.Data.username -eq $user)

# ---------------- Change password ----------------
Write-Host "== Change password" -ForegroundColor Cyan

$login = Login $user $firstPw
$oldAccess  = $login.Data.token
$oldRefresh = $login.Data.refreshToken

$r = Call-Api -Method POST -Path "/api/auth/change-password" -Token $oldAccess -Body @{
    currentPassword = "wrong-current"; newPassword = $secondPw }
Expect "C1 a wrong current password is refused (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/auth/change-password" -Token $oldAccess -Body @{
    currentPassword = $firstPw; newPassword = $secondPw }
Expect "C2 the password is changed (204)" ($r.Status -eq 204)

$login = Login $user $firstPw
Expect "C3 the old password no longer works (401)" ($login.Status -eq 401)

$login = Login $user $secondPw
Expect "C4 the new password works (200)" ($login.Status -eq 200)

$r = Call-Api -Method POST -Path "/api/auth/refresh" -Body @{ refreshToken = $oldRefresh }
Expect "C5 sessions from before the change are ended (401)" ($r.Status -eq 401)

# ---------------- Password reset by email code ----------------
Write-Host "== Password reset" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/auth/password-reset/request" -Body @{ username = "nobody$stamp" }
Expect "P1 a reset for an unknown username is accepted the same way (202)" ($r.Status -eq 202)

$login = Login $user $secondPw
$beforeReset = $login.Data.refreshToken

$r = Call-Api -Method POST -Path "/api/auth/password-reset/request" -Body @{ username = $user }
Expect "P2 a reset is requested for the account (202)" ($r.Status -eq 202)

# Asked again straight away: no second code is made, so the first one still works
$r = Call-Api -Method POST -Path "/api/auth/password-reset/request" -Body @{ username = $user }
Expect "P3 asking again at once is accepted (202)" ($r.Status -eq 202)

Write-Host ""
Write-Host "Look in the app console for 'DEV ONLY - password reset code' and copy the 6 digits." -ForegroundColor Yellow
$code  = (Read-Host "Reset code").Trim()
$wrong = if ($code -eq "000000") { "111111" } else { "000000" }

$r = Call-Api -Method POST -Path "/api/auth/password-reset/confirm" -Body @{
    username = $user; code = $wrong; newPassword = $resetPw }
Expect "P4 a wrong code is refused (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/auth/password-reset/confirm" -Body @{
    username = $user; code = $code; newPassword = $resetPw }
Expect "P5 the right code sets the new password (204)" ($r.Status -eq 204)

$r = Call-Api -Method POST -Path "/api/auth/password-reset/confirm" -Body @{
    username = $user; code = $code; newPassword = "AnotherPw-$stamp" }
Expect "P6 the same code cannot be used twice (400)" ($r.Status -eq 400)

$login = Login $user $resetPw
Expect "P7 the new password logs in (200)" ($login.Status -eq 200)

$r = Call-Api -Method POST -Path "/api/auth/refresh" -Body @{ refreshToken = $beforeReset }
Expect "P8 the session from before the reset is ended (401)" ($r.Status -eq 401)

$login = Login $user $secondPw
Expect "P9 the password from before the reset is refused (401)" ($login.Status -eq 401)

# ---------------- Without a token ----------------
Write-Host "== Protected endpoints" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/auth/change-password" -Body @{ currentPassword = "x"; newPassword = "long-enough-pw" }
Expect "U1 change-password without a token is refused (401)" ($r.Status -eq 401)

# ---------------- Result ----------------
Write-Host ""
Write-Host ("Passed: " + $passed + "   Failed: " + $failed) -ForegroundColor Cyan
Write-Host ("Test account created with the suffix " + $stamp + ". Run scripts\test-12.ps1 as well: the lockout must still work.")
