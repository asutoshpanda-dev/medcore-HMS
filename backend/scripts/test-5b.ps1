# test-5b.ps1 - Step 5b: hospital isolation (multi-tenancy)
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\test-5b.ps1
# Every run creates new test data (names end with a timestamp), so it can run again.

$BaseUrl     = "http://localhost:8080"
$SuperUser   = "superadmin"      # must match app.superadmin.username
$DefaultUser = "ADMIN"           # the old admin, now HOSPITAL_ADMIN of the default hospital
$NewPassword = "Test12345"       # password for the throwaway accounts this script creates

$superPass = $env:SUPER_ADMIN_PASSWORD
if (-not $superPass) { $superPass = Read-Host "Super admin password ($SuperUser)" }
$adminPass = $env:ADMIN_PASSWORD
if (-not $adminPass) { $adminPass = Read-Host "Password of the existing ADMIN account" }

$stamp  = Get-Date -Format "HHmmss"
$passed = 0
$failed = 0

function New-Phone {
    return "98" + (Get-Random -Minimum 10000000 -Maximum 99999999).ToString()
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

# ---------------- Setup: logins ----------------
Write-Host "== Setup" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $SuperUser; password = $superPass }
Expect "1  super admin logs in" ($r.Status -eq 200)
Expect "2  super admin role is SUPER_ADMIN, no hospital" (($r.Data.role -eq "SUPER_ADMIN") -and ($null -eq $r.Data.hospitalId))
if ($r.Status -ne 200) { Write-Host "Cannot continue without the super admin login." -ForegroundColor Red; exit 1 }
$superToken = $r.Data.token

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $DefaultUser; password = $adminPass }
Expect "3  existing ADMIN logs in as HOSPITAL_ADMIN" (($r.Status -eq 200) -and ($r.Data.role -eq "HOSPITAL_ADMIN"))
if ($r.Status -ne 200) { Write-Host "Cannot continue without the ADMIN login." -ForegroundColor Red; exit 1 }
$defToken    = $r.Data.token
$defHospital = $r.Data.hospitalId
Expect "4  default hospital is linked to the ADMIN account" ($null -ne $defHospital)

# ---------------- Hospitals (super admin only) ----------------
Write-Host "== Hospitals" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/hospitals" -Token $superToken -Body @{
    name = "Test Hospital $stamp"; city = "Pune"; contactEmail = "contact$stamp@test.com" }
Expect "5  super admin creates a hospital (201)" ($r.Status -eq 201)
Expect "6  new hospital starts unverified" ($r.Data.verified -eq $false)
$newHospital = $r.Data.id

$r = Call-Api -Method POST -Path "/api/hospitals" -Token $superToken -Body @{
    name = "TEST HOSPITAL $stamp"; city = "Pune"; contactEmail = "other$stamp@test.com" }
Expect "7  duplicate hospital name is rejected (409, ignores case)" ($r.Status -eq 409)

$r = Call-Api -Method POST -Path "/api/hospitals" -Token $superToken -Body @{
    name = "Bad Hospital"; city = "Pune"; contactEmail = "not-an-email" }
Expect "8  invalid contact email is rejected (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/hospitals" -Token $defToken -Body @{
    name = "Sneaky $stamp"; city = "Pune"; contactEmail = "sneaky$stamp@test.com" }
Expect "9  hospital admin cannot create hospitals (403)" ($r.Status -eq 403)

# ---------------- Hospital admin: verification gate ----------------
Write-Host "== Hospital admin" -ForegroundColor Cyan

$hadminUser = "hadmin$stamp"
$r = Call-Api -Method POST -Path "/api/auth/register" -Token $superToken -Body @{
    username = $hadminUser; password = $NewPassword; role = "HOSPITAL_ADMIN"; hospitalId = $newHospital }
Expect "10 super admin creates a HOSPITAL_ADMIN for the new hospital (201)" ($r.Status -eq 201)
Expect "11 that admin belongs to the new hospital" ($r.Data.hospitalId -eq $newHospital)

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $hadminUser; password = $NewPassword }
Expect "12 login is refused until the hospital is verified (403)" ($r.Status -eq 403)

$r = Call-Api -Method PATCH -Path "/api/hospitals/$newHospital/verify" -Token $superToken
Expect "13 super admin verifies the hospital (200)" (($r.Status -eq 200) -and ($r.Data.verified -eq $true))

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $hadminUser; password = $NewPassword }
Expect "14 hospital admin logs in after verification" ($r.Status -eq 200)
Expect "15 login token carries the hospitalId" ($r.Data.hospitalId -eq $newHospital)
$hToken = $r.Data.token

# ---------------- Patients ----------------
Write-Host "== Patients" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/patients" -Token $hToken -Body @{
    fullName = "Test Patient $stamp"; age = 40; gender = "female"; phone = (New-Phone); hospitalId = $defHospital }
Expect "16 hospital admin creates a patient (200)" ($r.Status -eq 200)
Expect "17 hospitalId sent in the body is ignored (server sets the caller's hospital)" ($r.Data.hospitalId -eq $newHospital)
$cPatient = $r.Data.id

$r = Call-Api -Method POST -Path "/api/patients" -Token $defToken -Body @{
    fullName = "Default Patient $stamp"; age = 30; gender = "male"; phone = (New-Phone) }
Expect "18 default hospital admin creates a patient (200)" ($r.Status -eq 200)
$dPatient = $r.Data.id

$r = Call-Api -Method GET -Path "/api/patients" -Token $defToken
Expect "19 default hospital cannot list the other hospital's patient" (($r.Status -eq 200) -and (-not ($r.Data | Where-Object { $_.id -eq $cPatient })))
Expect "20 default hospital still sees its own patient" (($r.Status -eq 200) -and (($r.Data | Where-Object { $_.id -eq $dPatient }) -ne $null))

$r = Call-Api -Method PUT -Path "/api/patients/$cPatient" -Token $defToken -Body @{
    fullName = "Changed $stamp"; age = 40; gender = "female"; phone = "9000000001" }
Expect "21 default hospital cannot update the other hospital's patient (404)" ($r.Status -eq 404)

$r = Call-Api -Method DELETE -Path "/api/patients/$cPatient" -Token $defToken
Expect "22 default hospital cannot delete the other hospital's patient (404)" ($r.Status -eq 404)

$r = Call-Api -Method GET -Path "/api/patients" -Token $hToken
Expect "23 the patient is untouched in its own hospital" (($r.Status -eq 200) -and (($r.Data | Where-Object { $_.id -eq $cPatient }) -ne $null))

# ---------------- Doctors and appointments ----------------
Write-Host "== Doctors and appointments" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/doctors" -Token $hToken -Body @{
    fullName = "Dr Test $stamp"; specialization = "Cardiology"; phone = (New-Phone); email = "cdoc$stamp@test.com" }
Expect "24 hospital admin creates a doctor (200)" ($r.Status -eq 200)
$cDoctor = $r.Data.id

$r = Call-Api -Method POST -Path "/api/doctors" -Token $defToken -Body @{
    fullName = "Dr Default $stamp"; specialization = "ENT"; phone = (New-Phone); email = "defdoc$stamp@test.com" }
Expect "25 default hospital admin creates a doctor (200)" ($r.Status -eq 200)
$dDoctor = $r.Data.id

$r = Call-Api -Method POST -Path "/api/appointments" -Token $defToken -Body @{
    patientId = $cPatient; doctorId = $dDoctor; appointmentDate = "2026-12-01"; appointmentTime = "10:30:00"; reason = "Checkup" }
Expect "26 default hospital cannot book the other hospital's patient (404)" ($r.Status -eq 404)

$r = Call-Api -Method POST -Path "/api/appointments" -Token $defToken -Body @{
    patientId = $dPatient; doctorId = $cDoctor; appointmentDate = "2026-12-01"; appointmentTime = "11:00:00"; reason = "Checkup" }
Expect "27 default hospital cannot book the other hospital's doctor (404)" ($r.Status -eq 404)

$r = Call-Api -Method POST -Path "/api/appointments" -Token $hToken -Body @{
    patientId = $cPatient; doctorId = $cDoctor; appointmentDate = "2026-12-01"; appointmentTime = "10:30:00"; reason = "Checkup" }
Expect "28 hospital admin books an appointment in its own hospital (200)" ($r.Status -eq 200)
$cAppt = $r.Data.id

$r = Call-Api -Method PATCH -Path "/api/appointments/$cAppt/status" -Token $defToken -Body @{ status = "CONFIRMED" }
Expect "29 default hospital cannot change the other hospital's appointment (404)" ($r.Status -eq 404)

# ---------------- Staff roles ----------------
Write-Host "== Staff roles" -ForegroundColor Cyan

$recUser = "rec$stamp"
$r = Call-Api -Method POST -Path "/api/auth/register" -Token $hToken -Body @{
    username = $recUser; password = $NewPassword; role = "RECEPTIONIST" }
Expect "30 hospital admin creates a receptionist (201)" ($r.Status -eq 201)
Expect "31 receptionist belongs to the hospital admin's hospital" ($r.Data.hospitalId -eq $newHospital)

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $recUser; password = $NewPassword }
$recToken = $r.Data.token

$r = Call-Api -Method GET -Path "/api/appointments" -Token $recToken
Expect "32 receptionist sees the appointment of its hospital" (($r.Status -eq 200) -and (($r.Data | Where-Object { $_.id -eq $cAppt }) -ne $null))

$r = Call-Api -Method GET -Path "/api/doctors" -Token $recToken
Expect "33 receptionist sees the doctors of its hospital" (($r.Status -eq 200) -and (($r.Data | Where-Object { $_.id -eq $cDoctor }) -ne $null))

$r = Call-Api -Method POST -Path "/api/bills" -Token $recToken -Body @{
    patientId = $cPatient; appointmentId = $cAppt; consultationFee = 500; medicineFee = 150.5; paymentStatus = "PENDING" }
Expect "34 receptionist creates a bill (200)" ($r.Status -eq 200)
Expect "35 bill total is calculated by the server (650.5)" ($r.Data.totalAmount -eq 650.5)
$cBill = $r.Data.id

$r = Call-Api -Method GET -Path "/api/bills" -Token $defToken
Expect "36 default hospital cannot see the other hospital's bill" (($r.Status -eq 200) -and (-not ($r.Data | Where-Object { $_.id -eq $cBill })))

$nurseUser = "nurse$stamp"
$r = Call-Api -Method POST -Path "/api/auth/register" -Token $hToken -Body @{
    username = $nurseUser; password = $NewPassword; role = "NURSE" }
Expect "37 hospital admin creates a NURSE (201)" ($r.Status -eq 201)

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $nurseUser; password = $NewPassword }
$nurseToken = $r.Data.token

$r = Call-Api -Method GET -Path "/api/patients" -Token $nurseToken
Expect "38 nurse has no patient access yet (403)" ($r.Status -eq 403)

$r = Call-Api -Method GET -Path "/api/patients" -Token $superToken
Expect "39 super admin cannot read patient data (403)" ($r.Status -eq 403)

# ---------------- Account creation rules ----------------
Write-Host "== Account creation rules" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $hToken -Body @{
    username = "hx$stamp"; password = $NewPassword; role = "HOSPITAL_ADMIN" }
Expect "40 hospital admin cannot create another hospital admin (403)" ($r.Status -eq 403)

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $hToken -Body @{
    username = "ox$stamp"; password = $NewPassword; role = "RECEPTIONIST"; hospitalId = $defHospital }
Expect "41 hospital admin cannot create accounts in another hospital (403)" ($r.Status -eq 403)

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $hToken -Body @{
    username = "px$stamp"; password = $NewPassword; role = "PATIENT"; patientId = $dPatient }
Expect "42 patient account cannot link to another hospital's patient (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $superToken -Body @{
    username = "sx$stamp"; password = $NewPassword; role = "HOSPITAL_ADMIN"; hospitalId = 999999 }
Expect "43 super admin cannot create an admin for a missing hospital (400)" ($r.Status -eq 400)

# ---------------- Patient's own account ----------------
Write-Host "== Patient account" -ForegroundColor Cyan

$patUser = "pat$stamp"
$r = Call-Api -Method POST -Path "/api/auth/register" -Token $hToken -Body @{
    username = $patUser; password = $NewPassword; role = "PATIENT"; patientId = $cPatient }
Expect "44 hospital admin links a patient account to its own patient (201)" ($r.Status -eq 201)

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $patUser; password = $NewPassword }
$patToken = $r.Data.token

$r = Call-Api -Method GET -Path "/api/me/patient" -Token $patToken
Expect "45 patient reads its own record through /api/me" (($r.Status -eq 200) -and ($r.Data.id -eq $cPatient))

# ---------------- Result ----------------
Write-Host ""
Write-Host ("Passed: " + $passed + "   Failed: " + $failed) -ForegroundColor Cyan
Write-Host ("Test data was created with the suffix " + $stamp + " (test hospital: 'Test Hospital " + $stamp + "').")
