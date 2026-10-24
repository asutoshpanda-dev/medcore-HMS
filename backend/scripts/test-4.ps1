$base = "http://localhost:8080"
$adminPw = Read-Host "Admin password"
$script:pass = 0
$script:fail = 0

function Invoke-Api {
    param([string]$Method, [string]$Path, $Body = $null, [string]$Token = "")
    $params = @{ Uri = "$base$Path"; Method = $Method; UseBasicParsing = $true }
    if ($Token) { $params.Headers = @{ Authorization = "Bearer $Token" } }
    if ($Body -ne $null) {
        $params.Body = ($Body | ConvertTo-Json)
        $params.ContentType = "application/json"
    }
    try {
        $r = Invoke-WebRequest @params
        return [pscustomobject]@{ Code = [int]$r.StatusCode; Body = [string]$r.Content }
    } catch {
        $resp = $_.Exception.Response
        if ($resp -ne $null) {
            $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
            return [pscustomobject]@{ Code = [int]$resp.StatusCode; Body = $reader.ReadToEnd() }
        }
        return [pscustomobject]@{ Code = 0; Body = $_.Exception.Message }
    }
}

function Expect {
    param([string]$Label, [int[]]$Codes, $Result)
    if ($Codes -contains $Result.Code) { $script:pass++; $tag = "PASS" } else { $script:fail++; $tag = "FAIL" }
    $text = [string]$Result.Body
    if ($text.Length -gt 140) { $text = $text.Substring(0, 140) + "..." }
    Write-Host ("[{0}] {1} -> {2} (expected {3})  {4}" -f $tag, $Label, $Result.Code, ($Codes -join "/"), $text)
}

function Check {
    param([string]$Label, [bool]$Condition, $Detail = "")
    if ($Condition) { $script:pass++; $tag = "PASS" } else { $script:fail++; $tag = "FAIL" }
    Write-Host ("[{0}] {1}  {2}" -f $tag, $Label, $Detail)
}

function Parse($Result) {
    if ($Result.Code -eq 200 -or $Result.Code -eq 201) {
        $json = $Result.Body | ConvertFrom-Json
        if ($null -ne $json -and $json.PSObject.Properties.Name -contains "data") { return $json.data }
        return $json
    }
    return $null
}

# ---- login ----
$login = Invoke-Api POST "/api/auth/login" @{ username = "admin"; password = $adminPw }
Expect "Login as admin" 200 $login
if ($login.Code -ne 200) { Write-Host "Cannot continue without a token."; exit 1 }
$tok = (Parse $login).token

# ---- setup: throwaway patient and doctor ----
$rnd = Get-Random -Minimum 100000000 -Maximum 999999999
$phone = "9$rnd"

$r = Invoke-Api POST "/api/patients" @{ fullName = "FK Test Patient"; age = 30; gender = "Male"; phone = $phone } $tok
Expect "Setup: create patient" 200,201 $r
$p = Parse $r

$r = Invoke-Api POST "/api/doctors" @{ fullName = "FK Test Doctor"; specialization = "General"; phone = $phone; email = "fk${rnd}@example.com" } $tok
Expect "Setup: create doctor" 200,201 $r
$d = Parse $r

if ($p -eq $null -or $d -eq $null) { Write-Host "Setup failed - stopping."; exit 1 }
$patId = $p.id
$docId = $d.id

# ---- appointment status rules ----
$apptBody = @{ patientId = $patId; doctorId = $docId; appointmentDate = "2027-01-15"; appointmentTime = "10:30:00"; reason = "FK test"; status = "BOGUS" }
$r = Invoke-Api POST "/api/appointments" $apptBody $tok
Expect "A1 appointment with invalid status" 400 $r

$unknown = @{ patientId = 999999; doctorId = $docId; appointmentDate = "2027-01-15"; appointmentTime = "10:30:00"; reason = "FK test" }
$r = Invoke-Api POST "/api/appointments" $unknown $tok
Expect "A2 appointment with unknown patient id" 404 $r

$apptBody.status = "COMPLETED"
$r = Invoke-Api POST "/api/appointments" $apptBody $tok
Expect "A3 create appointment (body says COMPLETED, server must force PENDING)" 200,201 $r
$a = Parse $r
if ($a -eq $null) { Write-Host "Appointment setup failed - stopping."; exit 1 }
$apptId = $a.id
Check "A3b status is PENDING" ($a.status -eq "PENDING") "got: $($a.status)"

$apptBody.status = "CANCELLED"
$r = Invoke-Api PUT "/api/appointments/$apptId" $apptBody $tok
Expect "A4 PUT appointment (body says CANCELLED, must be ignored)" 200 $r
$a = Parse $r
if ($a -ne $null) { Check "A4b status still PENDING" ($a.status -eq "PENDING") "got: $($a.status)" }

# A5: the lifecycle forbids PENDING -> COMPLETED (a visit must be confirmed and started first)
$r = Invoke-Api PATCH "/api/appointments/$apptId/status" @{ status = "COMPLETED" } $tok
Expect "A5 PENDING -> COMPLETED is refused" 409 $r

# A5a-A5c: walk the allowed path PENDING -> CONFIRMED -> IN_PROGRESS -> COMPLETED
$r = Invoke-Api PATCH "/api/appointments/$apptId/status" @{ status = "CONFIRMED" } $tok
Expect "A5a PATCH status CONFIRMED is allowed" 200 $r

$r = Invoke-Api PATCH "/api/appointments/$apptId/status" @{ status = "IN_PROGRESS" } $tok
Expect "A5b PATCH status IN_PROGRESS is allowed" 200 $r

$r = Invoke-Api PATCH "/api/appointments/$apptId/status" @{ status = "COMPLETED" } $tok
Expect "A5c PATCH status COMPLETED is allowed" 200 $r
$a = Parse $r
if ($a -ne $null) { Check "A5d status is COMPLETED" ($a.status -eq "COMPLETED") "got: $($a.status)" }

$r = Invoke-Api PATCH "/api/appointments/$apptId/status" @{ status = "BOGUS" } $tok
Expect "A6 PATCH status BOGUS" 400 $r

# ---- bill payment status rules ----
$billBody = @{ patientId = $patId; appointmentId = $apptId; consultationFee = 500; medicineFee = 200.5; paymentStatus = "BOGUS" }
$r = Invoke-Api POST "/api/bills" $billBody $tok
Expect "B1 bill with invalid paymentStatus" 400 $r

$billBody.paymentStatus = "PENDING"
$r = Invoke-Api POST "/api/bills" $billBody $tok
Expect "B2 create bill PENDING" 200,201 $r
$b = Parse $r
if ($b -eq $null) { Write-Host "Bill setup failed - stopping."; exit 1 }
$billId = $b.id

# A paid bill needs a payment date (Step 7b)
$billBody.paymentStatus = "PAID"
$billBody.paymentDate = (Get-Date).ToString("yyyy-MM-dd")
$r = Invoke-Api PUT "/api/bills/$billId" $billBody $tok
Expect "B3 PUT bill PAID (with a payment date)" 200 $r
$b = Parse $r
if ($b -ne $null) { Check "B3b paymentStatus is PAID" ($b.paymentStatus -eq "PAID") "got: $($b.paymentStatus)" }

# ---- foreign keys: records in use cannot be deleted ----
$r = Invoke-Api DELETE "/api/patients/$patId" $null $tok
Expect "F1 delete patient that has appointment and bill" 409 $r

$r = Invoke-Api DELETE "/api/doctors/$docId" $null $tok
Expect "F2 delete doctor that has an appointment" 409 $r

$r = Invoke-Api DELETE "/api/appointments/$apptId" $null $tok
Expect "F3 delete appointment that has a bill" 409 $r

# ---- cleanup in the right order ----
$r = Invoke-Api DELETE "/api/bills/$billId" $null $tok
Expect "Cleanup: delete bill" 200,204 $r
$r = Invoke-Api DELETE "/api/appointments/$apptId" $null $tok
Expect "Cleanup: delete appointment" 200,204 $r
$r = Invoke-Api DELETE "/api/patients/$patId" $null $tok
Expect "Cleanup: delete patient" 200,204 $r
$r = Invoke-Api DELETE "/api/doctors/$docId" $null $tok
Expect "Cleanup: delete doctor" 200,204 $r

$r = Invoke-Api DELETE "/api/patients/$patId" $null $tok
Expect "F4 delete the same patient again" 404 $r

Write-Host ""
Write-Host "Passed: $($script:pass)   Failed: $($script:fail)"
