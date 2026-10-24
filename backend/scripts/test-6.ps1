# test-6.ps1 - Step 6: slots, conflicts, emergencies, status lifecycle, patient booking
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\test-6.ps1
# Creates new test data on every run (names end with a timestamp).

$BaseUrl     = "http://localhost:8080"
$DefaultUser = "ADMIN"
$NewPassword = "Test12345"
$ApptDate    = "2026-12-15"

$adminPass = $env:ADMIN_PASSWORD
if (-not $adminPass) { $adminPass = Read-Host "Password of the ADMIN account" }

$stamp  = Get-Date -Format "HHmmss"
$passed = 0
$failed = 0

function New-Phone {
    return "97" + (Get-Random -Minimum 10000000 -Maximum 99999999).ToString()
}

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
        $params["Body"] = ConvertTo-Json -InputObject $Body -Depth 5
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

# ---------------- Setup ----------------
Write-Host "== Setup" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $DefaultUser; password = $adminPass }
Expect "0a ADMIN logs in" ($r.Status -eq 200)
if ($r.Status -ne 200) { Write-Host "Cannot continue without the ADMIN login." -ForegroundColor Red; exit 1 }
$token = $r.Data.token

$r = Call-Api -Method POST -Path "/api/doctors" -Token $token -Body @{
    fullName = "Dr A $stamp"; specialization = "Cardiology"; phone = (New-Phone); email = "docA$stamp@test.com" }
$docA = $r.Data.id
$r = Call-Api -Method POST -Path "/api/doctors" -Token $token -Body @{
    fullName = "Dr B $stamp"; specialization = "ENT"; phone = (New-Phone); email = "docB$stamp@test.com" }
$docB = $r.Data.id

$r = Call-Api -Method POST -Path "/api/patients" -Token $token -Body @{
    fullName = "Patient One $stamp"; age = 30; gender = "male"; phone = (New-Phone) }
$p1 = $r.Data.id
$r = Call-Api -Method POST -Path "/api/patients" -Token $token -Body @{
    fullName = "Patient Two $stamp"; age = 41; gender = "female"; phone = (New-Phone) }
$p2 = $r.Data.id
$r = Call-Api -Method POST -Path "/api/patients" -Token $token -Body @{
    fullName = "Patient Three $stamp"; age = 55; gender = "male"; phone = (New-Phone) }
$p3 = $r.Data.id
Expect "0b two doctors and three patients created" (($null -ne $docA) -and ($null -ne $docB) -and ($null -ne $p1) -and ($null -ne $p2) -and ($null -ne $p3))

function Book($patient, $doctor, $time, $priority = $null) {
    $body = @{ patientId = $patient; doctorId = $doctor; appointmentDate = $ApptDate; appointmentTime = $time; reason = "Checkup" }
    if ($priority) { $body["priority"] = $priority }
    return Call-Api -Method POST -Path "/api/appointments" -Token $token -Body $body
}

# ---------------- Slot rules ----------------
Write-Host "== Slot rules" -ForegroundColor Cyan

$r = Book $p1 $docA "10:07:00"
Expect "1  start time off the 15-minute grid is rejected (400)" ($r.Status -eq 400)

$r = Book $p1 $docA "08:00:00"
Expect "2  time before opening (08:00) is rejected (400)" ($r.Status -eq 400)

$r = Book $p1 $docA "17:00:00"
Expect "3  time at closing (17:00) is rejected (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/appointments" -Token $token -Body @{
    patientId = $p1; doctorId = $docA; appointmentDate = "2020-01-01"; appointmentTime = "10:00:00"; reason = "Checkup" }
Expect "4  date in the past is rejected (400)" ($r.Status -eq 400)

# ---------------- Conflicts and emergencies ----------------
Write-Host "== Conflicts and emergencies" -ForegroundColor Cyan

$r = Book $p1 $docA "10:00:00"
Expect "5  normal booking at 10:00 succeeds (PENDING, NORMAL)" (($r.Status -eq 200) -and ($r.Data.status -eq "PENDING") -and ($r.Data.priority -eq "NORMAL"))
$a1 = $r.Data.id

$r = Book $p2 $docA "10:00:00"
Expect "6  same doctor and same slot is refused (409)" ($r.Status -eq 409)

$r = Book $p1 $docB "10:00:00"
Expect "7  same patient and same slot with another doctor is refused (409)" ($r.Status -eq 409)

$r = Book $p2 $docA "10:00:00" "EMERGENCY"
Expect "8  emergency is accepted on top of a booked slot (EMERGENCY)" (($r.Status -eq 200) -and ($r.Data.priority -eq "EMERGENCY"))
$e1 = $r.Data.id

$r = Book $p3 $docA "10:00:00"
Expect "9  normal booking in a slot held by an emergency is refused (409)" ($r.Status -eq 409)

$r = Book $p2 $docA "10:15:00"
Expect "10 another slot for the same doctor succeeds (10:15)" ($r.Status -eq 200)
$a2 = $r.Data.id

# ---------------- Reschedule ----------------
Write-Host "== Reschedule" -ForegroundColor Cyan

$r = Call-Api -Method PUT -Path "/api/appointments/$a2" -Token $token -Body @{
    patientId = $p2; doctorId = $docA; appointmentDate = $ApptDate; appointmentTime = "10:15:00"; reason = "Follow-up" }
Expect "11 saving an appointment at its own time is not a conflict (200)" ($r.Status -eq 200)

$r = Call-Api -Method PUT -Path "/api/appointments/$a2" -Token $token -Body @{
    patientId = $p2; doctorId = $docA; appointmentDate = $ApptDate; appointmentTime = "10:00:00"; reason = "Follow-up" }
Expect "12 moving onto a slot the doctor already holds is refused (409)" ($r.Status -eq 409)

# ---------------- Status lifecycle ----------------
Write-Host "== Status lifecycle" -ForegroundColor Cyan

$r = Call-Api -Method PATCH -Path "/api/appointments/$a1/status" -Token $token -Body @{ status = "COMPLETED" }
Expect "13 PENDING cannot jump to COMPLETED (409)" ($r.Status -eq 409)

$r = Call-Api -Method PATCH -Path "/api/appointments/$a1/status" -Token $token -Body @{ status = "CONFIRMED" }
Expect "14 PENDING to CONFIRMED (200)" (($r.Status -eq 200) -and ($r.Data.status -eq "CONFIRMED"))

$r = Call-Api -Method PATCH -Path "/api/appointments/$a1/status" -Token $token -Body @{ status = "IN_PROGRESS" }
Expect "15 CONFIRMED to IN_PROGRESS (200)" (($r.Status -eq 200) -and ($r.Data.status -eq "IN_PROGRESS"))

$r = Call-Api -Method PATCH -Path "/api/appointments/$a1/status" -Token $token -Body @{ status = "COMPLETED" }
Expect "16 IN_PROGRESS to COMPLETED (200)" (($r.Status -eq 200) -and ($r.Data.status -eq "COMPLETED"))

$r = Call-Api -Method PATCH -Path "/api/appointments/$a1/status" -Token $token -Body @{ status = "CANCELLED" }
Expect "17 COMPLETED is final, cannot be cancelled (409)" ($r.Status -eq 409)

$r = Call-Api -Method PUT -Path "/api/appointments/$a1" -Token $token -Body @{
    patientId = $p1; doctorId = $docA; appointmentDate = $ApptDate; appointmentTime = "11:30:00"; reason = "Checkup" }
Expect "18 a completed appointment cannot be rescheduled (409)" ($r.Status -eq 409)

# ---------------- Patient self-booking ----------------
Write-Host "== Patient booking" -ForegroundColor Cyan

$patUser = "pat$stamp"
$r = Call-Api -Method POST -Path "/api/auth/register" -Token $token -Body @{
    username = $patUser; password = $NewPassword; role = "PATIENT"; patientId = $p2 }
Expect "19 patient account created for Patient Two (201)" ($r.Status -eq 201)

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $patUser; password = $NewPassword }
$patToken = $r.Data.token

# The body tries to set another patient and an emergency priority; the server must ignore both
$r = Call-Api -Method POST -Path "/api/me/appointments" -Token $patToken -Body @{
    patientId = $p1; doctorId = $docB; appointmentDate = $ApptDate; appointmentTime = "11:00:00"; reason = "Fever"; priority = "EMERGENCY" }
Expect "20 patient books with a doctor (200, PENDING)" (($r.Status -eq 200) -and ($r.Data.status -eq "PENDING"))
Expect "21 patient cannot set another patient or an emergency priority" (($r.Data.patientId -eq $p2) -and ($r.Data.priority -eq "NORMAL"))
$pBook = $r.Data.id

$r = Call-Api -Method POST -Path "/api/me/appointments" -Token $patToken -Body @{
    doctorId = $docA; appointmentDate = $ApptDate; appointmentTime = "11:00:00"; reason = "Second visit" }
Expect "22 patient cannot book two appointments at the same time (409)" ($r.Status -eq 409)

$r = Call-Api -Method POST -Path "/api/me/appointments" -Token $patToken -Body @{
    doctorId = $docA; appointmentDate = "2020-01-01"; appointmentTime = "10:00:00"; reason = "Checkup" }
Expect "23 patient booking in the past is rejected (400)" ($r.Status -eq 400)

$r = Call-Api -Method PATCH -Path "/api/me/appointments/$a2/cancel" -Token $patToken
Expect "24 patient cancels own pending appointment (CANCELLED)" (($r.Status -eq 200) -and ($r.Data.status -eq "CANCELLED"))

$r = Call-Api -Method PATCH -Path "/api/me/appointments/$a1/cancel" -Token $patToken
Expect "25 patient cannot cancel another patient's appointment (404)" ($r.Status -eq 404)

$r = Call-Api -Method POST -Path "/api/appointments" -Token $token -Body @{
    patientId = $p1; doctorId = $docA; appointmentDate = $ApptDate; appointmentTime = "10:15:00"; reason = "Checkup" }
Expect "26 cancelled slot is free again for staff (200)" ($r.Status -eq 200)

$r = Call-Api -Method GET -Path "/api/me/appointments" -Token $patToken
Expect "27 patient's list shows the new booking" (($r.Status -eq 200) -and (($r.Data | Where-Object { $_.id -eq $pBook }) -ne $null))

# ---------------- Result ----------------
Write-Host ""
Write-Host ("Passed: " + $passed + "   Failed: " + $failed) -ForegroundColor Cyan
Write-Host ("Test data was created with the suffix " + $stamp + ".")
