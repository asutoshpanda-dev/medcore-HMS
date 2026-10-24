# test-7c.ps1 - Step 7c: prescription checks
#   the prescription must match its appointment's patient and doctor,
#   no prescriptions for cancelled or no-show visits,
#   and a prescription can change only while ACTIVE (ACTIVE -> COMPLETED or CANCELLED)
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\test-7c.ps1
# Creates new test data on every run (names end with a timestamp).

$BaseUrl     = "http://localhost:8080"
$DefaultUser = "ADMIN"
$VisitDay    = "2026-12-21"
$NewPassword = "Test12345"

$adminPass = $env:ADMIN_PASSWORD
if (-not $adminPass) { $adminPass = Read-Host "Password of the ADMIN account" }

$stamp  = Get-Date -Format "HHmmss"
$passed = 0
$failed = 0

function New-Phone {
    return "96" + (Get-Random -Minimum 10000000 -Maximum 99999999).ToString()
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

function New-Appointment {
    param($PatientId, $DoctorId, [string]$Time)
    $r = Call-Api -Method POST -Path "/api/appointments" -Token $token -Body @{
        patientId = $PatientId; doctorId = $DoctorId; appointmentDate = $VisitDay
        appointmentTime = $Time; reason = "Follow-up" }
    return $r.Data.id
}

function Set-AppointmentStatus {
    param($AppointmentId, [string]$Status)
    $r = Call-Api -Method PATCH -Path "/api/appointments/$AppointmentId/status" -Token $token -Body @{ status = $Status }
    return $r.Status
}

# ---------------- Setup ----------------
Write-Host "== Setup" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $DefaultUser; password = $adminPass }
Expect "0a ADMIN logs in" ($r.Status -eq 200)
if ($r.Status -ne 200) { Write-Host "Cannot continue without the ADMIN login." -ForegroundColor Red; exit 1 }
$token = $r.Data.token

$r = Call-Api -Method POST -Path "/api/doctors" -Token $token -Body @{
    fullName = "Dr Rx One $stamp"; specialization = "General"; phone = (New-Phone); email = "rxa$stamp@test.com" }
$doc1 = $r.Data.id
$r = Call-Api -Method POST -Path "/api/doctors" -Token $token -Body @{
    fullName = "Dr Rx Two $stamp"; specialization = "ENT"; phone = (New-Phone); email = "rxb$stamp@test.com" }
$doc2 = $r.Data.id
$r = Call-Api -Method POST -Path "/api/patients" -Token $token -Body @{
    fullName = "Rx Patient A $stamp"; age = 50; gender = "female"; phone = (New-Phone) }
$pA = $r.Data.id
$r = Call-Api -Method POST -Path "/api/patients" -Token $token -Body @{
    fullName = "Rx Patient B $stamp"; age = 22; gender = "male"; phone = (New-Phone) }
$pB = $r.Data.id
Expect "0b two doctors and two patients created" ($null -ne $doc1 -and $null -ne $doc2 -and $null -ne $pA -and $null -ne $pB)

$apptA     = New-Appointment $pA $doc1 "10:00:00"
$apptC     = New-Appointment $pA $doc1 "10:30:00"
$apptD     = New-Appointment $pA $doc1 "10:45:00"
$apptOther = New-Appointment $pA $doc2 "11:00:00"
$sA  = Set-AppointmentStatus $apptA "CONFIRMED"
$sC  = Set-AppointmentStatus $apptC "CANCELLED"
$sD1 = Set-AppointmentStatus $apptD "CONFIRMED"
$sD2 = Set-AppointmentStatus $apptD "NO_SHOW"
Expect "0c four appointments created; A confirmed, C cancelled, D a no-show" ($null -ne $apptA -and $null -ne $apptC -and $null -ne $apptD -and $null -ne $apptOther -and $sA -eq 200 -and $sC -eq 200 -and $sD1 -eq 200 -and $sD2 -eq 200)

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $token -Body @{
    username = "rxdoc$stamp"; password = $NewPassword; role = "DOCTOR"; doctorId = $doc1 }
$regStatus = $r.Status
$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = "rxdoc$stamp"; password = $NewPassword }
$docToken = $r.Data.token
Expect "0d doctor one's account is created and can log in" ($regStatus -eq 201 -and $null -ne $docToken)

$oneMed = @( @{ medicineName = "Amoxicillin"; dosage = "500 mg"; frequency = "three times a day"; duration = "5 days" } )

# ---------------- Creating prescriptions ----------------
Write-Host "== Creating prescriptions" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/prescriptions" -Token $docToken -Body @{
    patientId = $pA; doctorId = $doc1; appointmentId = $apptA; instructions = "Take after food"; items = $oneMed }
Expect "P1 prescription for the right patient and doctor is saved (200)" ($r.Status -eq 200)
$rx1 = $r.Data.id

$r = Call-Api -Method POST -Path "/api/prescriptions" -Token $docToken -Body @{
    patientId = $pB; doctorId = $doc1; appointmentId = $apptA; instructions = "Rest"; items = $oneMed }
Expect "P2 patient B on patient A's appointment is refused (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/prescriptions" -Token $docToken -Body @{
    patientId = $pA; doctorId = $doc1; appointmentId = $apptOther; instructions = "Rest"; items = $oneMed }
Expect "P3 doctor one writing for doctor two's appointment is refused (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/prescriptions" -Token $docToken -Body @{
    patientId = $pA; doctorId = $doc1; appointmentId = $apptC; instructions = "Rest"; items = $oneMed }
Expect "P4 prescription for a cancelled appointment is refused (409)" ($r.Status -eq 409)

$r = Call-Api -Method POST -Path "/api/prescriptions" -Token $docToken -Body @{
    patientId = $pA; doctorId = $doc1; appointmentId = $apptD; instructions = "Rest"; items = $oneMed }
Expect "P5 prescription for a no-show appointment is refused (409)" ($r.Status -eq 409)

# ---------------- Editing a finished prescription ----------------
Write-Host "== Editing" -ForegroundColor Cyan

$r = Call-Api -Method PUT -Path "/api/prescriptions/$rx1" -Token $docToken -Body @{
    patientId = $pA; doctorId = $doc1; appointmentId = $apptA; instructions = "Take after food, twice a day";
    items = @( @{ medicineName = "Paracetamol"; dosage = "650 mg"; frequency = "twice a day"; duration = "3 days" } ) }
Expect "E1 an ACTIVE prescription can be edited; its medicine list is replaced (200, 1 item)" ($r.Status -eq 200 -and @($r.Data.items).Count -eq 1)

$r = Call-Api -Method PUT -Path "/api/prescriptions/$rx1" -Token $docToken -Body @{
    patientId = $pA; doctorId = $doc1; appointmentId = $apptOther; instructions = "Rest"; items = $oneMed }
Expect "E2 moving a prescription onto another doctor's appointment is refused (400)" ($r.Status -eq 400)

$r = Call-Api -Method PATCH -Path "/api/prescriptions/$rx1/status" -Token $docToken -Body @{ status = "COMPLETED" }
Expect "E3 ACTIVE -> COMPLETED is allowed (200)" ($r.Status -eq 200 -and $r.Data.status -eq "COMPLETED")

$r = Call-Api -Method PATCH -Path "/api/prescriptions/$rx1/status" -Token $docToken -Body @{ status = "ACTIVE" }
Expect "E4 COMPLETED -> ACTIVE is refused (409)" ($r.Status -eq 409)

$r = Call-Api -Method PATCH -Path "/api/prescriptions/$rx1/status" -Token $docToken -Body @{ status = "CANCELLED" }
Expect "E5 COMPLETED -> CANCELLED is refused (409)" ($r.Status -eq 409)

$r = Call-Api -Method PUT -Path "/api/prescriptions/$rx1" -Token $docToken -Body @{
    patientId = $pA; doctorId = $doc1; appointmentId = $apptA; instructions = "Changed after completion"; items = $oneMed }
Expect "E6 a COMPLETED prescription cannot be edited (409)" ($r.Status -eq 409)

$r = Call-Api -Method DELETE -Path "/api/prescriptions/$rx1" -Token $token
Expect "E7 a COMPLETED prescription cannot be deleted (409)" ($r.Status -eq 409)

# ---------------- Lifecycle ----------------
Write-Host "== Lifecycle" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/prescriptions" -Token $docToken -Body @{
    patientId = $pA; doctorId = $doc1; appointmentId = $apptA; instructions = "Cancel test"; items = $oneMed }
Expect "L0a prescription for the cancel test is saved (200)" ($r.Status -eq 200)
$rx2 = $r.Data.id

$r = Call-Api -Method PATCH -Path "/api/prescriptions/$rx2/status" -Token $docToken -Body @{ status = "CANCELLED" }
Expect "L1 ACTIVE -> CANCELLED is allowed (200)" ($r.Status -eq 200)

$r = Call-Api -Method PATCH -Path "/api/prescriptions/$rx2/status" -Token $docToken -Body @{ status = "COMPLETED" }
Expect "L2 CANCELLED -> COMPLETED is refused (409)" ($r.Status -eq 409)

$r = Call-Api -Method POST -Path "/api/prescriptions" -Token $docToken -Body @{
    patientId = $pA; doctorId = $doc1; appointmentId = $apptA; instructions = "Active test"; items = $oneMed }
Expect "L0b prescription for the active test is saved (200)" ($r.Status -eq 200)
$rx3 = $r.Data.id

$r = Call-Api -Method PATCH -Path "/api/prescriptions/$rx3/status" -Token $docToken -Body @{ status = "ACTIVE" }
Expect "L3 ACTIVE -> ACTIVE is refused (409)" ($r.Status -eq 409)

$r = Call-Api -Method PUT -Path "/api/prescriptions/$rx3" -Token $docToken -Body @{
    patientId = $pA; doctorId = $doc1; appointmentId = $apptA; instructions = "Edited while ACTIVE"; items = $oneMed }
Expect "L4 an ACTIVE prescription can still be edited (200)" ($r.Status -eq 200)

$r = Call-Api -Method DELETE -Path "/api/prescriptions/$rx3" -Token $token
Expect "L5 an ACTIVE prescription can be deleted by the hospital admin (204)" ($r.Status -eq 204)

# ---------------- Result ----------------
Write-Host ""
Write-Host ("Passed: " + $passed + "   Failed: " + $failed) -ForegroundColor Cyan
Write-Host ("Test data was created with the suffix " + $stamp + ".")
