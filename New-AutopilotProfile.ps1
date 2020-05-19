########################## Office 365 ############################
$ApplicationId = 'YourApplicationID'
$ApplicationSecret = 'SecretApplicationSecret' | Convertto-SecureString -AsPlainText -Force
$TenantID = 'YourTenantID'
$RefreshToken = 'SuperSecretRefreshToken'
$upn = 'UPN-Used-To-Generate-Tokens'
$CustomerTenantID = "YOURCLIENTSTENANT.onmicrosoft.com"
########################## Office 365 ############################
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
write-host "Generating token to log into Intune" -ForegroundColor Green
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $CustomerTenantID
$Header = @{
    Authorization = "Bearer $($graphToken.AccessToken)"
}
write-host "Creating Deployment Profile" -ForegroundColor Green
 
$intuneBody = @{
    "@odata.type"                          = "#microsoft.graph.activeDirectoryWindowsAutopilotDeploymentProfile"
    displayName                            = "CyberDrain.com Default Profile"
    description                            = "This deployment profile has been created by the CyberDrain.com Profile Deployment script"
    language                               = 'EN'
    hybridAzureADJoinSkipConnectivityCheck = $true
    extractHardwareHash                    = $true
    enableWhiteGlove                       = $true
    outOfBoxExperienceSettings             = @{
        "@odata.type"             = "microsoft.graph.outOfBoxExperienceSettings"
        hidePrivacySettings       = $true
        hideEULA                  = $true
        userType                  = 'Standard'
        deviceUsageType           = 'Shared'
        skipKeyboardSelectionPage = $true
        hideEscapeLink            = $true
    }
    enrollmentStatusScreenSettings         = @{
        '@odata.type'                                    = "microsoft.graph.windowsEnrollmentStatusScreenSettings"
        hideInstallationProgress                         = $true
        allowDeviceUseBeforeProfileAndAppInstallComplete = $true
        blockDeviceSetupRetryByUser                      = $false
        allowLogCollectionOnInstallFailure               = $true
        customErrorMessage                               = "An error has occured. Please contact your IT Administrator"
        installProgressTimeoutInMinutes                  = "15"
        allowDeviceUseOnInstallFailure                   = $true
    }
} | ConvertTo-Json
 
$InTuneProfileURI = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles"
Invoke-RestMethod -Uri $InTuneProfileURI -Headers $Header -body $intuneBody -Method POST -ContentType "application/json"