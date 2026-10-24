$u = "http://localhost:8080/api"
$h = @{ "Content-Type" = "application/json" }

# Step 10: list and item responses are wrapped as {"data": ...}. This wrapper returns the data
# part, so the checks below read the same fields as before.
function Invoke-RestMethod {
    [CmdletBinding()]
    param(
        [string]$Method = "GET",
        [Parameter(Mandatory = $true)][string]$Uri,
        $Headers = $null,
        $Body = $null
    )
    $params = @{ Method = $Method; Uri = $Uri; UseBasicParsing = $true }
    if ($null -ne $Headers) { $params["Headers"] = $Headers }
    if ($null -ne $Body) { $params["Body"] = $Body }
    $result = Microsoft.PowerShell.Utility\Invoke-RestMethod @params
    if ($null -ne $result -and $result.PSObject.Properties.Name -contains "data") { return $result.data }
    return $result
}

function Show($label, [scriptblock]$call) {
  try { $res = & $call; "$label -> OK"; $res }
  catch {
    $resp = $_.Exception.Response
    if ($resp) {
      $code = [int]$resp.StatusCode
      $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
      "$label -> $code " + $reader.ReadToEnd()
    } else { "$label -> NO RESPONSE: " + $_.Exception.Message }
  }
}

# A prescription body. The medicines go in the items list; the server needs at least one.
function Rx-Body($patientId, $doctorId, $appointmentId, $medicine) {
    return (@{
        patientId     = $patientId
        doctorId      = $doctorId
        appointmentId = $appointmentId
        instructions  = "After food"
        items         = @(@{ medicineName = $medicine; dosage = "200 mg"; frequency = "twice a day"; duration = "3 days" })
    } | ConvertTo-Json -Depth 5)
}

$p = Read-Host "Admin password"
$login = Invoke-RestMethod -Method Post -Uri "$u/auth/login" -Headers $h -Body (@{ username = "admin"; password = $p } | ConvertTo-Json)
$auth = @{ "Content-Type" = "application/json"; "Authorization" = "Bearer $($login.token)" }

Show "register patient1 for patient 1 (OK or 409)" { Invoke-RestMethod -Method Post -Uri "$u/auth/register" -Headers $auth -Body '{"username":"patient1","password":"ChangeMe-Patient-123","role":"PATIENT","patientId":1}' }
Show "register PATIENT without patientId (expect 400)" { Invoke-RestMethod -Method Post -Uri "$u/auth/register" -Headers $auth -Body '{"username":"patient2","password":"ChangeMe-Patient-123","role":"PATIENT"}' }

$d = Invoke-RestMethod -Method Post -Uri "$u/auth/login" -Headers $h -Body '{"username":"doctor1","password":"ChangeMe-Doctor-123"}'
$dAuth = @{ "Content-Type" = "application/json"; "Authorization" = "Bearer $($d.token)" }
$pt = Invoke-RestMethod -Method Post -Uri "$u/auth/login" -Headers $h -Body '{"username":"patient1","password":"ChangeMe-Patient-123"}'
$pAuth = @{ "Content-Type" = "application/json"; "Authorization" = "Bearer $($pt.token)" }

"=== Patient tests ==="
Show "P1 own details (expect Ram Sahu)" { Invoke-RestMethod -Uri "$u/me/patient" -Headers $pAuth }
Show "P2 own prescriptions (expect only patient 1's)" { Invoke-RestMethod -Uri "$u/me/prescriptions" -Headers $pAuth | Format-Table id, patientId, status }
Show "P3 own bills (expect empty)" { Invoke-RestMethod -Uri "$u/me/bills" -Headers $pAuth }
Show "P4 edit own phone (expect OK)" { Invoke-RestMethod -Method Put -Uri "$u/me/patient" -Headers $pAuth -Body '{"fullName":"Ram Sahu","age":36,"gender":"male","phone":"9000000000"}' }
Show "P5 list all patients (expect 403)" { Invoke-RestMethod -Uri "$u/patients" -Headers $pAuth }
Show "P6 edit someone via /patients (expect 403)" { Invoke-RestMethod -Method Put -Uri "$u/patients/4" -Headers $pAuth -Body '{"fullName":"X","age":20,"gender":"male","phone":"9111111111"}' }
Show "P7 all bills (expect 403)" { Invoke-RestMethod -Uri "$u/bills" -Headers $pAuth }
Show "P8 delete (expect 403)" { Invoke-RestMethod -Method Delete -Uri "$u/prescriptions/4" -Headers $pAuth }
Show "P9 patient token on staff-only change (expect 403)" { Invoke-RestMethod -Method Patch -Uri "$u/appointments/3/status" -Headers $pAuth -Body '{"status":"CANCELLED"}' }

"=== Doctor tests (doctor1 is doctor 3) ==="

# Setup: a fresh visit for patient 1 with doctor 3, so the status steps start from PENDING.
# Visit ids differ between databases, so the script books its own visit.
$slotHour   = Get-Random -Minimum 9 -Maximum 17          # 09:00 to 16:45
$slotMinute = (Get-Random -Minimum 0 -Maximum 4) * 15
$slotTime   = "{0:00}:{1:00}:00" -f $slotHour, $slotMinute
try {
    $visit = Invoke-RestMethod -Method Post -Uri "$u/appointments" -Headers $auth -Body (@{
        patientId = 1; doctorId = 3; appointmentDate = "2027-02-20"; appointmentTime = $slotTime; reason = "Fever check" } | ConvertTo-Json)
} catch {
    Write-Host "Setup failed: could not book patient 1 with doctor 3 at $slotTime. $($_.Exception.Message)"
    exit 1
}
$visitId = $visit.id
"Setup: visit $visitId booked for patient 1 with doctor 3 on 2027-02-20 at $slotTime (PENDING)"

Show "D0a admin confirms the visit (expect OK)" { Invoke-RestMethod -Method Patch -Uri "$u/appointments/$visitId/status" -Headers $auth -Body '{"status":"CONFIRMED"}' }
Show "D0b doctor starts the visit (expect OK)" { Invoke-RestMethod -Method Patch -Uri "$u/appointments/$visitId/status" -Headers $dAuth -Body '{"status":"IN_PROGRESS"}' }
Show "D1 doctor completes own visit (expect OK)" { Invoke-RestMethod -Method Patch -Uri "$u/appointments/$visitId/status" -Headers $dAuth -Body '{"status":"COMPLETED"}' }
Show "D2 prescription in another doctor's name (expect 403)" { Invoke-RestMethod -Method Post -Uri "$u/prescriptions" -Headers $dAuth -Body (Rx-Body 1 2 $visitId "Test") }
Show "D3 own prescription (expect OK, ACTIVE)" { Invoke-RestMethod -Method Post -Uri "$u/prescriptions" -Headers $dAuth -Body (Rx-Body 1 3 $visitId "Ibuprofen") }
