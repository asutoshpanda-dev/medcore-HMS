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
    } else {
      "$label -> NO RESPONSE: " + $_.Exception.Message
    }
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

Show "0 no token (expect 401)" { Invoke-RestMethod -Uri "$u/patients" }

# doctor1 must be linked to doctor 3 (a DOCTOR account needs a doctorId)
Show "register doctor1 for doctor 3 (OK or 409)" { Invoke-RestMethod -Method Post -Uri "$u/auth/register" -Headers $auth -Body '{"username":"doctor1","password":"ChangeMe-Doctor-123","role":"DOCTOR","doctorId":3}' }

Show "login doctor1" { $global:d = Invoke-RestMethod -Method Post -Uri "$u/auth/login" -Headers $h -Body '{"username":"doctor1","password":"ChangeMe-Doctor-123"}'; "token received" }
Show "login reception1" { $global:r = Invoke-RestMethod -Method Post -Uri "$u/auth/login" -Headers $h -Body '{"username":"reception1","password":"Reception123"}'; "token received" }
$dAuth = @{ "Content-Type" = "application/json"; "Authorization" = "Bearer $($d.token)" }
$rAuth = @{ "Content-Type" = "application/json"; "Authorization" = "Bearer $($r.token)" }

# Setup: a fresh visit for patient 1 with doctor 3, confirmed and started, so step 1 can complete it.
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
Show "setup admin confirms the visit (expect OK)" { Invoke-RestMethod -Method Patch -Uri "$u/appointments/$visitId/status" -Headers $auth -Body '{"status":"CONFIRMED"}' }
Show "setup doctor starts the visit (expect OK)" { Invoke-RestMethod -Method Patch -Uri "$u/appointments/$visitId/status" -Headers $dAuth -Body '{"status":"IN_PROGRESS"}' }

Show "1 doctor PATCH appointment COMPLETED (expect OK)" { Invoke-RestMethod -Method Patch -Uri "$u/appointments/$visitId/status" -Headers $dAuth -Body '{"status":"COMPLETED"}' }
Show "2 doctor PUT appointment (expect 403)" { Invoke-RestMethod -Method Put -Uri "$u/appointments/$visitId" -Headers $dAuth -Body '{"reason":"x"}' }
Show "3 invalid status (expect 400)" { Invoke-RestMethod -Method Patch -Uri "$u/appointments/$visitId/status" -Headers $dAuth -Body '{"status":"DONE"}' }
Show "4 doctor creates prescription (expect OK, ACTIVE)" { $global:rx = Invoke-RestMethod -Method Post -Uri "$u/prescriptions" -Headers $dAuth -Body (Rx-Body 1 3 $visitId "Paracetamol"); $global:rx }
Show "5 doctor PATCH prescription (expect OK, same id as 4, COMPLETED)" { Invoke-RestMethod -Method Patch -Uri "$u/prescriptions/$($rx.id)/status" -Headers $dAuth -Body '{"status":"COMPLETED"}' }
Show "6 receptionist PATCH prescription (expect 403)" { Invoke-RestMethod -Method Patch -Uri "$u/prescriptions/$($rx.id)/status" -Headers $rAuth -Body '{"status":"CANCELLED"}' }
Show "7 receptionist GET prescriptions (expect 403)" { Invoke-RestMethod -Uri "$u/prescriptions" -Headers $rAuth }
Show "8 receptionist GET bills (expect OK)" { Invoke-RestMethod -Uri "$u/bills" -Headers $rAuth }

"--- Prescriptions now (no duplicates expected) ---"
Invoke-RestMethod -Uri "$u/prescriptions" -Headers $auth | Format-Table id, patientId, status, @{ Label = "medicines"; Expression = { ($_.items | ForEach-Object { $_.medicineName }) -join ", " } }
