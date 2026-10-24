# test-7d.ps1 - Step 7d: appointment fixes
#   1. a visit that has a medical record keeps its doctor and patient
#   2. booking for today at a time that has already passed is refused
#   3. two bookings for the same patient, or the same doctor, at the same time: only one gets through
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\test-7d.ps1
# Creates new test data on every run (names end with a timestamp).
# Part 2 uses this computer's clock, so it picks today's times when the script runs.

$BaseUrl     = "http://localhost:8080"
$DefaultUser = "ADMIN"
$VisitDay    = "2027-01-18"

$adminPass = $env:ADMIN_PASSWORD
if (-not $adminPass) { $adminPass = Read-Host "Password of the ADMIN account" }

$stamp   = Get-Date -Format "HHmmss"
$passed  = 0
$failed  = 0
$skipped = 0

function New-Phone {
    return "96" + (Get-Random -Minimum 10000000 -Maximum 99999999).ToString()
}

# 570 -> "09:30:00"
function To-Clock {
    param([int]$Minutes)
    $h = [int][math]::Floor($Minutes / 60)
    $m = [int]($Minutes % 60)
    return ("{0:00}:{1:00}:00" -f $h, $m)
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

function Skip {
    param([string]$Name, [string]$Reason)
    Write-Host ("SKIP  " + $Name + " (" + $Reason + ")") -ForegroundColor Yellow
    $script:skipped++
}

function New-Doctor {
    param([string]$Tag)
    $r = Call-Api -Method POST -Path "/api/doctors" -Token $token -Body @{
        fullName = "Dr $Tag $stamp"; specialization = "General"; phone = (New-Phone)
        email = "d7d$Tag$stamp@test.com" }
    return $r.Data.id
}

function New-Patient {
    param([string]$Tag)
    $r = Call-Api -Method POST -Path "/api/patients" -Token $token -Body @{
        fullName = "Visit Patient $Tag $stamp"; age = 40; gender = "male"; phone = (New-Phone) }
    return $r.Data.id
}

# Creates a DOCTOR login for a doctor and returns its token, or $null if that failed
function New-DoctorToken {
    param($DoctorId, [string]$Tag)
    $user = "d7d$Tag$stamp"
    $pass = "Doc7d-pw-$stamp"
    $r = Call-Api -Method POST -Path "/api/auth/register" -Token $token -Body @{
        username = $user; password = $pass; role = "DOCTOR"; doctorId = $DoctorId }
    $created = ($r.Status -eq 201)
    $login = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $user; password = $pass }
    if ($created -and $login.Status -eq 200) { return $login.Data.token }
    return $null
}

function New-Booking {
    param($PatientId, $DoctorId, [string]$Day, [string]$Time)
    return Call-Api -Method POST -Path "/api/appointments" -Token $token -Body @{
        patientId = $PatientId; doctorId = $DoctorId; appointmentDate = $Day
        appointmentTime = $Time; reason = "Check-up" }
}

function Set-Booking {
    param($Id, $PatientId, $DoctorId, [string]$Day, [string]$Time, [string]$Reason)
    return Call-Api -Method PUT -Path "/api/appointments/$Id" -Token $token -Body @{
        patientId = $PatientId; doctorId = $DoctorId; appointmentDate = $Day
        appointmentTime = $Time; reason = $Reason }
}

# Sends one POST per body at the same moment, each on its own thread, and returns the status codes
function Send-Together {
    param([string]$Path, [string[]]$Bodies, [string]$Token)

    $sender = {
        param($Uri, $Json, $Token)
        try {
            $resp = Invoke-WebRequest -Method POST -Uri $Uri -ContentType "application/json" `
                -Headers @{ Authorization = "Bearer $Token" } -Body $Json -UseBasicParsing
            return [int]$resp.StatusCode
        }
        catch {
            $response = $_.Exception.Response
            if ($null -ne $response) { return [int]$response.StatusCode }
            return 0
        }
    }

    $pool = [runspacefactory]::CreateRunspacePool(1, $Bodies.Count)
    $pool.Open()
    $runs = @()
    foreach ($json in $Bodies) {
        $shell = [powershell]::Create()
        $shell.RunspacePool = $pool
        [void]$shell.AddScript($sender).AddArgument("$BaseUrl$Path").AddArgument($json).AddArgument($Token)
        $runs += [pscustomobject]@{ Shell = $shell; Handle = $shell.BeginInvoke() }
    }

    $codes = @()
    foreach ($run in $runs) {
        $out = $run.Shell.EndInvoke($run.Handle)
        if ($out.Count -gt 0) { $codes += [int]$out[0] } else { $codes += 0 }
        $run.Shell.Dispose()
    }
    $pool.Close()
    return $codes
}

# ---------------- Setup ----------------
Write-Host "== Setup" -ForegroundColor Cyan

$r = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $DefaultUser; password = $adminPass }
Expect "0a ADMIN logs in" ($r.Status -eq 200)
if ($r.Status -ne 200) { Write-Host "Cannot continue without the ADMIN login." -ForegroundColor Red; exit 1 }
$token = $r.Data.token

$docMain  = New-Doctor "m"
$docOther = New-Doctor "o"
$docRace  = New-Doctor "r"
$docMainToken = New-DoctorToken $docMain "m"

$pVisit     = New-Patient "visit"
$pOther     = New-Patient "other"
$pMove      = New-Patient "move"
$pYesterday = New-Patient "yesterday"
$pToday     = New-Patient "today1"
$pToday2    = New-Patient "today2"
$pRace      = New-Patient "race"
$pDocA      = New-Patient "docA"
$pDocB      = New-Patient "docB"

Expect "0b three doctors, the main doctor's login and nine patients are created" (
    $null -ne $docMain -and $null -ne $docOther -and $null -ne $docRace -and $null -ne $docMainToken -and
    $null -ne $pVisit -and $null -ne $pDocB)

# ---------------- 1. Medical record fixes the doctor and patient ----------------
Write-Host "== 1. Medical record fixes the doctor and patient" -ForegroundColor Cyan

$r = New-Booking $pVisit $docMain $VisitDay "09:00:00"
$visit = $r.Data.id
Expect "1a visit booked with the main doctor (200)" ($r.Status -eq 200 -and $null -ne $visit)

$r = Call-Api -Method PATCH -Path "/api/appointments/$visit/status" -Token $token -Body @{ status = "CONFIRMED" }
Expect "1b visit confirmed (200)" ($r.Status -eq 200)

$r = Call-Api -Method POST -Path "/api/medical-records" -Token $docMainToken -Body @{
    appointmentId = $visit; diagnosis = "Routine check" }
$record = $r.Data.id
Expect "1c the main doctor writes the medical record for the visit (200)" ($r.Status -eq 200 -and $null -ne $record)

$r = Set-Booking $visit $pVisit $docOther $VisitDay "09:00:00" "Check-up"
Expect "1d moving the visit with a record to another doctor is refused (409)" ($r.Status -eq 409)

$r = Set-Booking $visit $pOther $docMain $VisitDay "09:00:00" "Check-up"
Expect "1e changing the patient of the visit with a record is refused (409)" ($r.Status -eq 409)

$r = Set-Booking $visit $pVisit $docMain $VisitDay "09:00:00" "Follow-up"
Expect "1f changing only the reason of the visit with a record is allowed (200)" ($r.Status -eq 200 -and $r.Data.reason -eq "Follow-up")

$r = Call-Api -Method GET -Path "/api/medical-records/$record" -Token $token
Expect "1g the record still belongs to the original doctor" ($r.Status -eq 200 -and $r.Data.doctorId -eq $docMain)

$r = New-Booking $pMove $docMain $VisitDay "09:30:00"
$move = $r.Data.id
$r = Set-Booking $move $pMove $docOther $VisitDay "09:30:00" "Check-up"
Expect "1h a visit without a record can still move to another doctor (200)" ($r.Status -eq 200 -and $r.Data.doctorId -eq $docOther)

# ---------------- 2. Booking today at a time that has passed ----------------
Write-Host "== 2. Today's time must still be ahead" -ForegroundColor Cyan

$yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
$r = New-Booking $pYesterday $docMain $yesterday "10:00:00"
Expect "2a booking for yesterday is refused (400)" ($r.Status -eq 400)

$now          = Get-Date
$today        = $now.ToString("yyyy-MM-dd")
$floorMinutes = [int]([math]::Floor($now.TimeOfDay.TotalMinutes / 15) * 15)   # the grid slot that has started
$openMinutes  = 9 * 60
$closeMinutes = 17 * 60

# The slot that has just started is in the past (its start is not later than now)
if ($floorMinutes -ge $openMinutes -and $floorMinutes -lt $closeMinutes) {
    $pastTime = To-Clock $floorMinutes
    $r = New-Booking $pToday $docMain $today $pastTime
    Expect ("2b booking today at " + $pastTime + ", a time already past, is refused (400)") ($r.Status -eq 400)
}
else {
    Skip "2b booking today at a passed time" "the current time is outside opening hours"
}

# A slot at least 15 minutes ahead, so the result does not depend on the clock ticking
$aheadMinutes = $floorMinutes + 30
if ($aheadMinutes -ge $openMinutes -and $aheadMinutes -lt $closeMinutes) {
    $aheadTime = To-Clock $aheadMinutes
    $r = New-Booking $pToday2 $docMain $today $aheadTime
    Expect ("2c booking today at " + $aheadTime + ", still ahead, is accepted (200)") ($r.Status -eq 200)
}
else {
    Skip "2c booking today at a time still ahead" "no open slot is left today"
}

# ---------------- 3. Two bookings at the same time ----------------
Write-Host "== 3. Two bookings at the same time" -ForegroundColor Cyan

# 3a: one patient, two doctors, same time, sent together
$raceBodies = @(
    (ConvertTo-Json -InputObject @{ patientId = $pRace; doctorId = $docMain;  appointmentDate = $VisitDay; appointmentTime = "11:00:00"; reason = "Check-up" } -Depth 4),
    (ConvertTo-Json -InputObject @{ patientId = $pRace; doctorId = $docOther; appointmentDate = $VisitDay; appointmentTime = "11:00:00"; reason = "Check-up" } -Depth 4)
)
$codes   = Send-Together -Path "/api/appointments" -Bodies $raceBodies -Token $token
$booked  = @($codes | Where-Object { $_ -eq 200 }).Count
$refused = @($codes | Where-Object { $_ -eq 409 }).Count
Expect ("3a one patient, two doctors, same time at once: one booked, one refused (codes " + ($codes -join ", ") + ")") ($booked -eq 1 -and $refused -eq 1)

# 3b: one doctor, two patients, same time, sent together
$doctorBodies = @(
    (ConvertTo-Json -InputObject @{ patientId = $pDocA; doctorId = $docRace; appointmentDate = $VisitDay; appointmentTime = "11:15:00"; reason = "Check-up" } -Depth 4),
    (ConvertTo-Json -InputObject @{ patientId = $pDocB; doctorId = $docRace; appointmentDate = $VisitDay; appointmentTime = "11:15:00"; reason = "Check-up" } -Depth 4)
)
$codes   = Send-Together -Path "/api/appointments" -Bodies $doctorBodies -Token $token
$booked  = @($codes | Where-Object { $_ -eq 200 }).Count
$refused = @($codes | Where-Object { $_ -eq 409 }).Count
Expect ("3b one doctor, two patients, same time at once: one booked, one refused (codes " + ($codes -join ", ") + ")") ($booked -eq 1 -and $refused -eq 1)

# 3c, 3d: the lists show exactly one booking each
$r = Call-Api -Method GET -Path "/api/appointments" -Token $token
$patientRows = @($r.Data | Where-Object { $_.patientId -eq $pRace -and $_.appointmentDate -eq $VisitDay })
$doctorRows  = @($r.Data | Where-Object { $_.doctorId -eq $docRace -and $_.appointmentDate -eq $VisitDay })
Expect "3c the race patient has exactly one booking that day" ($r.Status -eq 200 -and $patientRows.Count -eq 1)
Expect "3d the race doctor has exactly one booking that day" ($r.Status -eq 200 -and $doctorRows.Count -eq 1)

# ---------------- Result ----------------
Write-Host ""
Write-Host ("Passed: " + $passed + "   Failed: " + $failed + "   Skipped: " + $skipped) -ForegroundColor Cyan
Write-Host ("Test data was created with the suffix " + $stamp + ".")
