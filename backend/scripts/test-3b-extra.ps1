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

$d = Invoke-RestMethod -Method Post -Uri "$u/auth/login" -Headers $h -Body '{"username":"doctor1","password":"ChangeMe-Doctor-123"}'
$dAuth = @{ "Content-Type" = "application/json"; "Authorization" = "Bearer $($d.token)" }
$pt = Invoke-RestMethod -Method Post -Uri "$u/auth/login" -Headers $h -Body '{"username":"patient1","password":"ChangeMe-Patient-123"}'
$pAuth = @{ "Content-Type" = "application/json"; "Authorization" = "Bearer $($pt.token)" }

Show "D4 doctor1 (doctor 3) changes doctor 1's appointment (expect 403)" { Invoke-RestMethod -Method Patch -Uri "$u/appointments/1/status" -Headers $dAuth -Body '{"status":"CANCELLED"}' }
Show "D5 doctor1 changes own appointment 3 (expect OK)" { Invoke-RestMethod -Method Patch -Uri "$u/appointments/3/status" -Headers $dAuth -Body '{"status":"PENDING"}' }
Show "P10 patient changes own phone (expect OK, phone 9000000009)" { Invoke-RestMethod -Method Put -Uri "$u/me/patient" -Headers $pAuth -Body '{"fullName":"Ram Sahu","age":36,"gender":"male","phone":"9000000009"}' }
Show "P11 read it back (expect phone 9000000009)" { Invoke-RestMethod -Uri "$u/me/patient" -Headers $pAuth }
