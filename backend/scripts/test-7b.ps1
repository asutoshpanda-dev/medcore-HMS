# test-7b.ps1 - Step 7b: bill checks
#   the patient must match the appointment, one bill per appointment,
#   no bill for a cancelled visit, and a payment date only on PAID bills
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\test-7b.ps1
# Creates new test data on every run (names end with a timestamp).

$BaseUrl     = "http://localhost:8080"
$DefaultUser = "ADMIN"
$BillDay     = "2026-12-20"

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
    param($PatientId, [string]$Time)
    $r = Call-Api -Method POST -Path "/api/appointments" -Token $token -Body @{
        patientId = $PatientId; doctorId = $doctorId; appointmentDate = $BillDay
        appointmentTime = $Time; reason = "Check-up" }
    return $r.Data.id
}

# ---------------- Setup ----------------
Write-Host "== Setup" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $DefaultUser; password = $adminPass }
Expect "0a ADMIN logs in" ($r.Status -eq 200)
if ($r.Status -ne 200) { Write-Host "Cannot continue without the ADMIN login." -ForegroundColor Red; exit 1 }
$token = $r.Data.token

$r = Call-Api -Method POST -Path "/api/doctors" -Token $token -Body @{
    fullName = "Dr Bill $stamp"; specialization = "General"; phone = (New-Phone); email = "bill7b$stamp@test.com" }
$doctorId = $r.Data.id
$r = Call-Api -Method POST -Path "/api/patients" -Token $token -Body @{
    fullName = "Bill Patient A $stamp"; age = 40; gender = "male"; phone = (New-Phone) }
$patientA = $r.Data.id
$r = Call-Api -Method POST -Path "/api/patients" -Token $token -Body @{
    fullName = "Bill Patient B $stamp"; age = 33; gender = "female"; phone = (New-Phone) }
$patientB = $r.Data.id

$apptA = New-Appointment $patientA "10:00:00"
$apptB = New-Appointment $patientA "10:15:00"
$apptC = New-Appointment $patientA "10:30:00"
$r = Call-Api -Method PATCH -Path "/api/appointments/$apptC/status" -Token $token -Body @{ status = "CANCELLED" }
Expect "0b doctor, two patients and three appointments created; the third is cancelled" ($null -ne $doctorId -and $null -ne $patientA -and $null -ne $patientB -and $null -ne $apptA -and $null -ne $apptB -and $null -ne $apptC -and $r.Status -eq 200)

# ---------------- Creating bills ----------------
Write-Host "== Creating bills" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/bills" -Token $token -Body @{
    patientId = $patientB; appointmentId = $apptA; consultationFee = 500; medicineFee = 200.5; paymentStatus = "PENDING" }
Expect "B1 bill for patient B on patient A's appointment is refused (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/bills" -Token $token -Body @{
    patientId = $patientA; appointmentId = $apptA; consultationFee = 500; medicineFee = 200.5; paymentStatus = "PENDING" }
Expect "B2 bill with the right patient is saved (200, total 700.5)" ($r.Status -eq 200 -and $r.Data.totalAmount -eq 700.5)
$billA = $r.Data.id

$r = Call-Api -Method POST -Path "/api/bills" -Token $token -Body @{
    patientId = $patientA; appointmentId = $apptA; consultationFee = 300; medicineFee = 0; paymentStatus = "PENDING" }
Expect "B3 second bill for the same appointment is refused (409)" ($r.Status -eq 409)

$r = Call-Api -Method POST -Path "/api/bills" -Token $token -Body @{
    patientId = $patientA; appointmentId = $apptC; consultationFee = 500; medicineFee = 0; paymentStatus = "PENDING" }
Expect "B4 bill for a cancelled appointment is refused (409)" ($r.Status -eq 409)

$r = Call-Api -Method POST -Path "/api/bills" -Token $token -Body @{
    patientId = $patientA; appointmentId = $apptB; consultationFee = 500; medicineFee = 0; paymentStatus = "PAID" }
Expect "B5 paid bill without a payment date is refused (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/bills" -Token $token -Body @{
    patientId = $patientA; appointmentId = $apptB; consultationFee = 500; medicineFee = 0; paymentStatus = "PENDING"; paymentDate = $BillDay }
Expect "B6 unpaid bill with a payment date is refused (400)" ($r.Status -eq 400)

$r = Call-Api -Method POST -Path "/api/bills" -Token $token -Body @{
    patientId = $patientA; appointmentId = $apptB; consultationFee = 500; medicineFee = 100; paymentStatus = "PAID"; paymentDate = $BillDay }
Expect "B7 paid bill with a payment date is saved (200, total 600)" ($r.Status -eq 200 -and $r.Data.totalAmount -eq 600)
$billB = $r.Data.id

# ---------------- Updating bills ----------------
Write-Host "== Updating bills" -ForegroundColor Cyan

$r = Call-Api -Method PUT -Path "/api/bills/$billA" -Token $token -Body @{
    patientId = $patientA; appointmentId = $apptB; consultationFee = 500; medicineFee = 0; paymentStatus = "PAID"; paymentDate = $BillDay }
Expect "B8 moving a bill onto an appointment that already has a bill is refused (409)" ($r.Status -eq 409)

$r = Call-Api -Method PUT -Path "/api/bills/$billB" -Token $token -Body @{
    patientId = $patientA; appointmentId = $apptB; consultationFee = 600; medicineFee = 100; paymentStatus = "PAID"; paymentDate = $BillDay }
Expect "B9 updating a bill keeps its own appointment and recalculates the total (200, total 700)" ($r.Status -eq 200 -and $r.Data.totalAmount -eq 700)

$r = Call-Api -Method PUT -Path "/api/bills/$billA" -Token $token -Body @{
    patientId = $patientB; appointmentId = $apptA; consultationFee = 500; medicineFee = 200.5; paymentStatus = "PENDING" }
Expect "B10 changing the bill's patient to someone else is refused (400)" ($r.Status -eq 400)

$r = Call-Api -Method PUT -Path "/api/bills/$billA" -Token $token -Body @{
    patientId = $patientA; appointmentId = $apptC; consultationFee = 500; medicineFee = 0; paymentStatus = "PENDING" }
Expect "B11 moving a bill to a cancelled appointment is refused (409)" ($r.Status -eq 409)

$r = Call-Api -Method PUT -Path "/api/bills/$billA" -Token $token -Body @{
    patientId = $patientA; appointmentId = $apptA; consultationFee = 450; medicineFee = 50; paymentStatus = "PENDING" }
Expect "B12 correcting the fees on the same bill is saved (200, total 500)" ($r.Status -eq 200 -and $r.Data.totalAmount -eq 500)

# ---------------- Final check ----------------
Write-Host "== Final check" -ForegroundColor Cyan

$r = Call-Api -Method GET -Path "/api/bills" -Token $token
$forA = @($r.Data | Where-Object { $_.appointmentId -eq $apptA })
Expect "B13 appointment A has exactly one bill in the list" ($r.Status -eq 200 -and $forA.Count -eq 1)

# ---------------- Result ----------------
Write-Host ""
Write-Host ("Passed: " + $passed + "   Failed: " + $failed) -ForegroundColor Cyan
Write-Host ("Test data was created with the suffix " + $stamp + ".")
