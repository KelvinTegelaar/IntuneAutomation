########################## Office 365 ############################
$ApplicationId = 'YourApplicationID'
$ApplicationSecret = 'SecretApplicationSecret' | Convertto-SecureString -AsPlainText -Force
$TenantID = 'YourTenantID'
$RefreshToken = 'SuperSecretRefreshToken'
$upn = 'UPN-Used-To-Generate-Tokens'
$CustomerTenantID = "YOURCLIENTSTENANT.onmicrosoft.com"
$CSVFilePath = "C:\Temp\Import-CSV-YourClientsTenant.txt"
########################## Office 365 ############################
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
write-host "Generating token to log into Intune" -ForegroundColor Green
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $CustomerTenantID
$Header = @{
    Authorization = "Bearer $($graphToken.AccessToken)"
}
write-host "Importing CSV File." -ForegroundColor Green
$CsvFile = Import-Csv $CSVFilePath -Delimiter ","
#$RandGuid = [guid]::NewGuid()
foreach ($Line in $CsvFile) {
    $intuneBody = @{
        orderIdentifier    = "CyberDrain.com Import Script"
        serialNumber       = $line.'Device Serial Number'
        productKey         = $line.'Windows Product ID'
        hardwareIdentifier = $Line.'Hardware Hash'
        state              = @{
            deviceImportStatus   = 'Complete'
            deviceRegistrationId = '1'
            deviceErrorCode      = '15'
            deviceErrorName      = "No Errors Detected"
        }
    } | ConvertTo-Json
 
    $InTuneDevicesURI = "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities"
    Invoke-RestMethod -Uri $InTuneDevicesURI -Headers $Header -body $intuneBody -Method POST -ContentType "application/json"
 
}