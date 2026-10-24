$base = "http://localhost:8080"
$adminPw = Read-Host "Admin password"
$recPw = Read-Host "reception2 password"
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

$r = Invoke-Api POST "/api/auth/login" @{ username = "admin"; password = $adminPw }
Expect "Login admin" 200 $r
if ($r.Code -ne 200) { exit 1 }
$adm = (Parse $r).token

$r = Invoke-Api POST "/api/auth/login" @{ username = "reception2"; password = $recPw }
Expect "Login reception2" 200 $r
if ($r.Code -ne 200) { exit 1 }
$rec = (Parse $r).token

$rnd = Get-Random -Minimum 100000000 -Maximum 999999999
$phone = "9$rnd"
$p = Parse (Invoke-Api POST "/api/patients" @{ fullName = "5a Test Patient"; age = 30; gender = "Male"; phone = $phone } $adm)
$d = Parse (Invoke-Api POST "/api/doctors" @{ fullName = "5a Test Doctor"; specialization = "General"; phone = $phone; email = "t5a${rnd}@example.com" } $adm)
if ($p -eq $null -or $d -eq $null) { Write-Host "Setup failed - stopping."; exit 1 }

# First visit: runs the full path to COMPLETED
$body = @{ patientId = $p.id; doctorId = $d.id; appointmentDate = "2027-02-10"; appointmentTime = "11:00:00"; reason = "5a test" }
$r = Invoke-Api POST "/api/appointments" $body $rec
Expect "Receptionist creates appointment" 200,201 $r
$a = Parse $r
if ($a -eq $null) { Write-Host "Appointment setup failed - stopping."; exit 1 }
Check "New appointment starts as PENDING" ($a.status -eq "PENDING") "got: $($a.status)"

foreach ($s in @("CONFIRMED", "IN_PROGRESS", "COMPLETED")) {
    $r = Invoke-Api PATCH "/api/appointments/$($a.id)/status" @{ status = $s } $rec
    Expect "Receptionist sets status $s" 200 $r
}

# COMPLETED is final: NO_SHOW is no longer allowed after the visit is completed
$r = Invoke-Api PATCH "/api/appointments/$($a.id)/status" @{ status = "NO_SHOW" } $rec
Expect "COMPLETED -> NO_SHOW is refused (final status)" 409 $r

# Second visit: the patient does not come, so CONFIRMED -> NO_SHOW is allowed
$body2 = @{ patientId = $p.id; doctorId = $d.id; appointmentDate = "2027-02-10"; appointmentTime = "12:00:00"; reason = "5a no-show test" }
$r = Invoke-Api POST "/api/appointments" $body2 $rec
Expect "Receptionist creates a second appointment" 200,201 $r
$a2 = Parse $r
if ($a2 -eq $null) { Write-Host "Second appointment setup failed - stopping."; exit 1 }

$r = Invoke-Api PATCH "/api/appointments/$($a2.id)/status" @{ status = "CONFIRMED" } $rec
Expect "Second visit set to CONFIRMED" 200 $r
$r = Invoke-Api PATCH "/api/appointments/$($a2.id)/status" @{ status = "NO_SHOW" } $rec
Expect "CONFIRMED -> NO_SHOW is allowed (patient did not come)" 200 $r

$r = Invoke-Api PATCH "/api/appointments/$($a.id)/status" @{ status = "SCHEDULED" } $rec
Expect "Old value SCHEDULED is rejected" 400 $r

$r = Invoke-Api DELETE "/api/appointments/$($a.id)" $null $rec
Expect "Receptionist cannot delete (admin only)" 403 $r

# Cleanup, admin only, in the right order
$r = Invoke-Api DELETE "/api/appointments/$($a.id)" $null $adm
Expect "Cleanup: delete first appointment" 200,204 $r
$r = Invoke-Api DELETE "/api/appointments/$($a2.id)" $null $adm
Expect "Cleanup: delete second appointment" 200,204 $r
$r = Invoke-Api DELETE "/api/patients/$($p.id)" $null $adm
Expect "Cleanup: delete patient" 200,204 $r
$r = Invoke-Api DELETE "/api/doctors/$($d.id)" $null $adm
Expect "Cleanup: delete doctor" 200,204 $r

Write-Host ""
Write-Host "Passed: $($script:pass)   Failed: $($script:fail)"
