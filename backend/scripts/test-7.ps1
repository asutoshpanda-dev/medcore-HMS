# test-7.ps1 - Step 7: prescription items, medical records, visit lock, roles
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\test-7.ps1
# Creates new test data on every run (names end with a timestamp).

$BaseUrl     = "http://localhost:8080"
$DefaultUser = "ADMIN"
$NewPassword = "Test12345"
$VisitDate   = "2026-12-16"

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

# ---------------- Setup ----------------
Write-Host "== Setup" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $DefaultUser; password = $adminPass }
Expect "0a ADMIN logs in" ($r.Status -eq 200)
if ($r.Status -ne 200) { Write-Host "Cannot continue without the ADMIN login." -ForegroundColor Red; exit 1 }
$token = $r.Data.token

$r = Call-Api -Method POST -Path "/api/doctors" -Token $token -Body @{
    fullName = "Dr One $stamp"; specialization = "Cardiology"; phone = (New-Phone); email = "d7a$stamp@test.com" }
$d1 = $r.Data.id
$r = Call-Api -Method POST -Path "/api/doctors" -Token $token -Body @{
    fullName = "Dr Two $stamp"; specialization = "ENT"; phone = (New-Phone); email = "d7b$stamp@test.com" }
$d2 = $r.Data.id
$r = Call-Api -Method POST -Path "/api/patients" -Token $token -Body @{
    fullName = "Patient Seven $stamp"; age = 52; gender = "female"; phone = (New-Phone) }
$p = $r.Data.id
$r = Call-Api -Method POST -Path "/api/appointments" -Token $token -Body @{
    patientId = $p; doctorId = $d1; appointmentDate = $VisitDate; appointmentTime = "10:00:00"; reason = "Fever" }
Expect "0b doctors, patient and appointment created" (($null -ne $d1) -and ($null -ne $d2) -and ($null -ne $p) -and ($r.Status -eq 200))
$appt = $r.Data.id

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $token -Body @{
    username = "dr1$stamp"; password = $NewPassword; role = "DOCTOR"; doctorId = $d1 }
$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = "dr1$stamp"; password = $NewPassword }
$dr1Token = $r.Data.token

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $token -Body @{
    username = "dr2$stamp"; password = $NewPassword; role = "DOCTOR"; doctorId = $d2 }
$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = "dr2$stamp"; password = $NewPassword }
$dr2Token = $r.Data.token

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $token -Body @{
    username = "desk$stamp"; password = $NewPassword; role = "RECEPTIONIST" }
$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = "desk$stamp"; password = $NewPassword }
$deskToken = $r.Data.token

$r = Call-Api -Method POST -Path "/api/auth/register" -Token $token -Body @{
    username = "pt7$stamp"; password = $NewPassword; role = "PATIENT"; patientId = $p }
$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = "pt7$stamp"; password = $NewPassword }
$ptToken = $r.Data.token
Expect "0c doctor, doctor two, receptionist and patient can log in" (($null -ne $dr1Token) -and ($null -ne $dr2Token) -and ($null -ne $deskToken) -and ($null -ne $ptToken))

# ---------------- Prescriptions with several medicines ----------------
Write-Host "== Prescriptions" -ForegroundColor Cyan

$twoMedicines = @(
    @{ medicineName = "Paracetamol"; dosage = "500 mg"; frequency = "twice a day"; duration = "5 days" },
    @{ medicineName = "Vitamin C";   dosage = "500 mg"; frequency = "once a day";  duration = "10 days" }
)

$r = Call-Api -Method POST -Path "/api/prescriptions" -Token $dr1Token -Body @{
    patientId = $p; doctorId = $d1; appointmentId = $appt; instructions = "Take after food"; items = $twoMedicines }
Expect "1  prescription with two medicines is saved (200)" (($r.Status -eq 200) -and (@($r.Data.items).Count -eq 2))
$rx = $r.Data.id

$r = Call-Api -Method POST -Path "/api/prescriptions" -Token $dr1Token -Body @{
    patientId = $p; doctorId = $d1; appointmentId = $appt; instructions = "Rest"; items = @() }
Expect "2  prescription with no medicine is rejected (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/prescriptions" -Token $dr1Token -Body @{
    patientId = $p; doctorId = $d1; appointmentId = $appt; instructions = "Rest"
    items = @( @{ medicineName = "Cough syrup"; dosage = "10 ml"; duration = "3 days" } ) }
Expect "3  medicine without a frequency is rejected (400)" ($r.Status -eq 400)

$r = Call-Api -Method GET -Path "/api/prescriptions" -Token $dr1Token
$listed = $r.Data | Where-Object { $_.id -eq $rx }
Expect "4  doctor sees the prescription with its medicines" (($r.Status -eq 200) -and (@($listed.items).Count -eq 2))

$r = Call-Api -Method GET -Path "/api/me/prescriptions" -Token $ptToken
$mine = $r.Data | Where-Object { $_.id -eq $rx }
Expect "5  patient sees the same medicines in /api/me" (($r.Status -eq 200) -and (@($mine.items).Count -eq 2))

$r = Call-Api -Method PUT -Path "/api/prescriptions/$rx" -Token $dr1Token -Body @{
    patientId = $p; doctorId = $d1; appointmentId = $appt; instructions = "Take after food";
    items = @( @{ medicineName = "Paracetamol"; dosage = "650 mg"; frequency = "three times a day"; duration = "3 days" } ) }
Expect "6  updating replaces the medicine list (now 1 item)" (($r.Status -eq 200) -and (@($r.Data.items).Count -eq 1))

$r = Call-Api -Method PUT -Path "/api/prescriptions/$rx" -Token $dr2Token -Body @{
    patientId = $p; doctorId = $d2; appointmentId = $appt; instructions = "Changed"; items = $twoMedicines }
Expect "7  another doctor cannot change this prescription (403)" ($r.Status -eq 403)

# ---------------- Medical records ----------------
Write-Host "== Medical records" -ForegroundColor Cyan

$noteBody = @{
    appointmentId = $appt; diagnosis = "Viral fever"; clinicalNotes = "Rest and fluids";
    bloodPressure = "120/80"; pulseBpm = 72; temperatureC = 37.2; weightKg = 70.5 }

$r = Call-Api -Method POST -Path "/api/medical-records" -Token $dr1Token -Body $noteBody
Expect "8  notes cannot be written while the visit is PENDING (409)" ($r.Status -eq 409)

$r = Call-Api -Method PATCH -Path "/api/appointments/$appt/status" -Token $token -Body @{ status = "CONFIRMED" }
Expect "9  reception side: admin confirms the visit (200)" ($r.Status -eq 200)

$r = Call-Api -Method POST -Path "/api/medical-records" -Token $dr1Token -Body $noteBody
Expect "10 doctor writes the record for a confirmed visit (200)" (($r.Status -eq 200) -and ($r.Data.bloodPressure -eq "120/80") -and ($r.Data.patientId -eq $p))
$rec = $r.Data.id

$r = Call-Api -Method POST -Path "/api/medical-records" -Token $dr1Token -Body $noteBody
Expect "11 a second record for the same visit is refused (409)" ($r.Status -eq 409)

$r = Call-Api -Method POST -Path "/api/medical-records" -Token $dr1Token -Body @{
    appointmentId = $appt; bloodPressure = "abc" }
Expect "12 blood pressure in the wrong format is rejected (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/medical-records" -Token $dr1Token -Body @{
    appointmentId = $appt; temperatureC = 50 }
Expect "13 impossible temperature is rejected (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/medical-records" -Token $dr2Token -Body $noteBody
Expect "14 another doctor cannot write notes for this visit (403)" ($r.Status -eq 403)

$r = Call-Api -Method PUT -Path "/api/medical-records/$rec" -Token $dr2Token -Body @{ diagnosis = "Changed by someone else" }
Expect "15 another doctor cannot change this record (403)" ($r.Status -eq 403)

$r = Call-Api -Method GET -Path "/api/medical-records/$rec" -Token $dr1Token
Expect "16 doctor reads the record (200)" (($r.Status -eq 200) -and ($r.Data.diagnosis -eq "Viral fever"))

$r = Call-Api -Method GET -Path "/api/medical-records/$rec" -Token $deskToken
Expect "17 receptionist cannot read clinical notes (403)" ($r.Status -eq 403)

$r = Call-Api -Method GET -Path "/api/medical-records/$rec" -Token $ptToken
Expect "18 patient cannot use the staff endpoint (403)" ($r.Status -eq 403)

$r = Call-Api -Method GET -Path "/api/me/medical-records" -Token $ptToken
Expect "19 patient reads own records through /api/me (200)" (($r.Status -eq 200) -and (@($r.Data | Where-Object { $_.id -eq $rec }).Count -eq 1))

$r = Call-Api -Method PUT -Path "/api/medical-records/$rec" -Token $ptToken -Body @{ diagnosis = "Patient edit" }
Expect "20 patient cannot change the record (403)" ($r.Status -eq 403)

$r = Call-Api -Method POST -Path "/api/medical-records" -Token $deskToken -Body $noteBody
Expect "21 receptionist cannot write notes (403)" ($r.Status -eq 403)

# ---------------- Visit lock ----------------
Write-Host "== Visit lock" -ForegroundColor Cyan

$r = Call-Api -Method PATCH -Path "/api/appointments/$appt/status" -Token $token -Body @{ status = "IN_PROGRESS" }
Expect "22 admin moves the visit to IN_PROGRESS (200)" ($r.Status -eq 200)

$r = Call-Api -Method PUT -Path "/api/medical-records/$rec" -Token $dr1Token -Body @{
    diagnosis = "Viral fever"; clinicalNotes = "Rest, fluids, review in 3 days"; bloodPressure = "118/78"; pulseBpm = 70; temperatureC = 37.0; weightKg = 70.5 }
Expect "23 doctor updates notes during the visit (200)" (($r.Status -eq 200) -and ($r.Data.bloodPressure -eq "118/78"))

$r = Call-Api -Method PATCH -Path "/api/appointments/$appt/status" -Token $token -Body @{ status = "COMPLETED" }
Expect "24 admin completes the visit (200)" ($r.Status -eq 200)

$r = Call-Api -Method PUT -Path "/api/medical-records/$rec" -Token $dr1Token -Body @{ diagnosis = "Late change" }
Expect "25 doctor cannot change the record after completion (409)" ($r.Status -eq 409)

$r = Call-Api -Method PUT -Path "/api/medical-records/$rec" -Token $token -Body @{
    diagnosis = "Viral fever (confirmed by lab)"; clinicalNotes = "Rest, fluids"; bloodPressure = "120/80"; pulseBpm = 72; temperatureC = 37.2; weightKg = 70.5 }
Expect "26 hospital admin corrects the record after completion (200)" (($r.Status -eq 200) -and ($r.Data.diagnosis -eq "Viral fever (confirmed by lab)"))

# ---------------- Result ----------------
Write-Host ""
Write-Host ("Passed: " + $passed + "   Failed: " + $failed) -ForegroundColor Cyan
Write-Host ("Test data was created with the suffix " + $stamp + ".")
