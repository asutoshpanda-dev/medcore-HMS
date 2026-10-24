# test-10.ps1 - Step 10: response envelope, paging and search, soft delete, audit log, Swagger
#   Creates new records on every run (names end with a timestamp).
#   Uses the hospital admin account (default "admin"; password from ADMIN_PASSWORD or asked for).
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\test-10.ps1

$BaseUrl     = "http://localhost:8080"
$DefaultUser = "admin"

$adminPass = $env:ADMIN_PASSWORD
if (-not $adminPass) { $adminPass = Read-Host "Password of the admin account" }

$stamp  = Get-Date -Format "HHmmss"
$passed = 0
$failed = 0

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

# Same helper as the other scripts, plus Raw: the body exactly as the server sent it (envelope included)
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
        $raw  = $null
        $data = $null
        if ($resp.Content) {
            $raw  = ConvertFrom-Json -InputObject $resp.Content
            $data = $raw
            if ($null -ne $raw -and $raw.PSObject.Properties.Name -contains "data") { $data = $raw.data }
        }
        return @{ Status = [int]$resp.StatusCode; Data = $data; Raw = $raw }
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
        return @{ Status = $status; Data = $data; Raw = $data }
    }
}

# ---------------- login ----------------
$admin = Call-Api -Method POST -Path "/api/auth/login" -Body @{ username = $DefaultUser; password = $adminPass }
if ($admin.Status -ne 200) { Write-Host "Cannot continue without the admin login." -ForegroundColor Red; exit 1 }
$token = $admin.Data.token
Expect "0  login returns the token inside the data wrapper (200)" ($admin.Status -eq 200 -and $null -ne $token)

# ---------------- envelope and DTOs ----------------
$phone = "9" + (Get-Random -Minimum 100000000 -Maximum 999999999)     # 10 digits
$name  = "Api10x$stamp Patient"
$r = Call-Api -Method POST -Path "/api/patients" -Token $token -Body @{
    fullName = $name; age = 40; gender = "female"; phone = $phone; hospitalId = 999999; id = 5 }
Expect "1  create patient returns 200 with the data wrapper" ($r.Status -eq 200 -and $null -ne $r.Raw.data.id)
Expect "2  a single item has no page block" ($null -eq $r.Raw.page)
Expect "3  hospitalId and id sent in the body are ignored" ($r.Data.hospitalId -ne 999999 -and $r.Data.id -ne 5)
$patId = $r.Data.id

$bad = Call-Api -Method POST -Path "/api/patients" -Token $token -Body @{ fullName = ""; age = 0; gender = "x"; phone = "12" }
Expect "4  invalid patient is refused (400)" ($bad.Status -eq 400)
Expect "5  the problem body lists every field error in errors[]" ($bad.Data.status -eq 400 -and @($bad.Data.errors).Count -ge 2)

# ---------------- paging ----------------
$p2 = Call-Api -Method GET -Path "/api/patients?size=2" -Token $token
Expect "6  a list has data and page blocks (200)" ($p2.Status -eq 200 -and $null -ne $p2.Raw.page -and $null -ne $p2.Raw.data)
Expect "7  size=2 returns at most 2 items and says so" ($p2.Raw.page.size -eq 2 -and @($p2.Raw.data).Count -le 2)
$big = Call-Api -Method GET -Path "/api/patients?size=500" -Token $token
Expect "8  size is capped at 100 by the server" ($big.Status -eq 200 -and $big.Raw.page.size -eq 100)
$badSort = Call-Api -Method GET -Path "/api/patients?sort=noSuchField" -Token $token
Expect "9  an unknown sort field is refused (400, problem body)" ($badSort.Status -eq 400 -and $badSort.Data.status -eq 400)

# ---------------- search ----------------
$byName = Call-Api -Method GET -Path "/api/patients?q=api10x$stamp" -Token $token
Expect "10 search by name finds the new patient" ($byName.Status -eq 200 -and @($byName.Raw.data | Where-Object { $_.id -eq $patId }).Count -eq 1)
$byPhone = Call-Api -Method GET -Path "/api/patients?q=$phone" -Token $token
Expect "11 search by phone finds the new patient" (@($byPhone.Raw.data | Where-Object { $_.id -eq $patId }).Count -eq 1)
$wild = Call-Api -Method GET -Path "/api/patients?q=%25" -Token $token
Expect "12 a % in the search is literal, so it matches nothing here" ($wild.Status -eq 200 -and @($wild.Raw.data).Count -eq 0)

# ---------------- update and audit trail ----------------
$upd = Call-Api -Method PUT -Path "/api/patients/$patId" -Token $token -Body @{
    fullName = "$name Changed"; age = 41; gender = "female"; phone = $phone }
Expect "13 update returns the new values (200)" ($upd.Status -eq 200 -and $upd.Data.age -eq 41)

$log = Call-Api -Method GET -Path "/api/audit-logs?entityType=Patient&entityId=$patId" -Token $token
$actions = @($log.Raw.data | ForEach-Object { $_.action })
Expect "14 audit log has CREATE and UPDATE for the patient (200)" ($log.Status -eq 200 -and ($actions -contains "CREATE") -and ($actions -contains "UPDATE"))
Expect "15 audit entries record the account that made the change" (@($log.Raw.data | Where-Object { $_.username -eq $DefaultUser }).Count -ge 2)

# ---------------- soft delete ----------------
$del = Call-Api -Method DELETE -Path "/api/patients/$patId" -Token $token
Expect "16 delete returns 204" ($del.Status -eq 204)
$gone = Call-Api -Method PUT -Path "/api/patients/$patId" -Token $token -Body @{
    fullName = "Nobody"; age = 30; gender = "male"; phone = $phone }
Expect "17 a deleted patient is no longer found (404)" ($gone.Status -eq 404)
$after = Call-Api -Method GET -Path "/api/patients?q=api10x$stamp" -Token $token
Expect "18 a deleted patient is missing from the list" (@($after.Raw.data | Where-Object { $_.id -eq $patId }).Count -eq 0)
$logAfter = Call-Api -Method GET -Path "/api/audit-logs?entityType=Patient&entityId=$patId" -Token $token
Expect "19 the delete is recorded in the audit log" (@($logAfter.Raw.data | Where-Object { $_.action -eq "DELETE" }).Count -eq 1)

# ---------------- soft delete frees a doctor's email ----------------
$docEmail = "api10doc$stamp@example.test"
$doc1 = Call-Api -Method POST -Path "/api/doctors" -Token $token -Body @{
    fullName = "Api10Doc$stamp"; specialization = "General"; phone = ("8" + (Get-Random -Minimum 100000000 -Maximum 999999999)); email = $docEmail }
Expect "20 create doctor (200)" ($doc1.Status -eq 200)
$docDel = Call-Api -Method DELETE -Path "/api/doctors/$($doc1.Data.id)" -Token $token
Expect "21 delete doctor (204)" ($docDel.Status -eq 204)
$doc2 = Call-Api -Method POST -Path "/api/doctors" -Token $token -Body @{
    fullName = "Api10Doc$stamp"; specialization = "General"; phone = ("7" + (Get-Random -Minimum 100000000 -Maximum 999999999)); email = $docEmail }
Expect "22 the same email can be used again after the doctor was deleted (200)" ($doc2.Status -eq 200)
$docSearch = Call-Api -Method GET -Path "/api/doctors?q=api10doc$stamp" -Token $token
Expect "23 doctor search finds only the live doctor" (@($docSearch.Raw.data).Count -eq 1 -and $docSearch.Raw.data[0].id -eq $doc2.Data.id)
$cleanDoc = Call-Api -Method DELETE -Path "/api/doctors/$($doc2.Data.id)" -Token $token
Expect "24 clean-up: delete the second test doctor (204)" ($cleanDoc.Status -eq 204)

# ---------------- Swagger and security ----------------
$api = Call-Api -Method GET -Path "/v3/api-docs"
Expect "25 the OpenAPI document is served without a login (200)" ($api.Status -eq 200 -and $null -ne $api.Raw.openapi)
$noAuth = Call-Api -Method GET -Path "/api/patients"
Expect "26 the API still needs a token (401)" ($noAuth.Status -eq 401)

Write-Host ""
Write-Host "Passed: $passed   Failed: $failed"
if ($failed -gt 0) { exit 1 }
