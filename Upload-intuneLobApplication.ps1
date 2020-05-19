########################## Secure App Model Settings ############################
$ApplicationId = 'YourAppID'
$ApplicationSecret = 'YourAppSecret' | Convertto-SecureString -AsPlainText -Force
$TenantID = 'YourCSPTenantID'
$RefreshToken = 'yourverylongrefeshtoken'
$upn = 'UPN-Used-To-Generate-Tokens'
$CustomerTenantID = "YourCustomerTenant.onmicrosoft.com"
########################## Script Settings  ############################
$ApplicationFolder = "C:\intune\Applications"
$Baseuri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
$AzCopyUri = "https://cyberdrain.com/wp-content/uploads/2020/04/azcopy.exe"
$IntuneWinAppUri = "https://cyberdrain.com/wp-content/uploads/2020/04/IntuneWinAppUtil.exe"
$ContinueOnExistingApp = $false
###################################################################
write-host "Checking AZCopy prerequisites and downloading these if required" -ForegroundColor Green
try {
    $AzCopyDownloadLocation = Test-Path "$ApplicationFolder\AzCopy.exe"
    if (!$AzCopyDownloadLocation) { 
        Invoke-WebRequest -UseBasicParsing -Uri $AzCopyUri -OutFile "$($ApplicationFolder)\AzCopy.exe"
    }
}
catch {
    write-host "The download and extraction of AzCopy failed. The script will stop. Error: $($_.Exception.Message)"
    exit 1
}
write-host "Checking IntuneWinAppUtil prerequisites and downloading these if required" -ForegroundColor Green
 
try {
    $AzCopyDownloadLocation = Test-Path "$ApplicationFolder\IntuneWinAppUtil.exe"
    if (!$AzCopyDownloadLocation) { Invoke-WebRequest -UseBasicParsing -Uri $IntuneWinAppUri -OutFile "$($ApplicationFolder)\IntuneWinAppUtil.exe" }
}
catch {
    write-host "The download and extraction of IntuneWinApp failed. The script will stop. Error: $($_.Exception.Message)"
    exit 1
}
 
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
write-host "Generating token to log into Intune" -ForegroundColor Green
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $CustomerTenantID
$Header = @{
    Authorization = "Bearer $($graphToken.AccessToken)"
}
$AppFolders = Get-ChildItem $ApplicationFolder -Directory
foreach ($App in $AppFolders) {
    $intuneBody = get-content "$($app.fullname)\app.json"
    $Settings = $intuneBody | ConvertFrom-Json
    write-host "Creating if intune package for $($app.name) does not exists." -ForegroundColor Green
    $ApplicationList = (Invoke-RestMethod -Uri $baseuri -Headers $Header -Method get -ContentType "application/json").value | where-object { $_.DisplayName -eq $settings.displayName }
    if ($ApplicationList.count -gt 1 -and $ContinueOnExistingApp -eq $false) { 
        write-host "$($app.name) exists. Skipping this application." -ForegroundColor yellow
        continue
    }
    write-host "Creating intune package for $($App.Name)" -ForegroundColor Green
    $bytes = 10MB
    [System.Security.Cryptography.RNGCryptoServiceProvider] $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $rndbytes = New-Object byte[] $bytes
    $rng.GetBytes($rndbytes)
    [System.IO.File]::WriteAllBytes("$($App.fullname)\dummy.dat", $rndbytes)
    $FileToExecute = $Settings.installCommandLine.split(" ")[0]
    start-process "$applicationfolder\IntuneWinAppUtil.exe" -argumentlist "-c $($App.FullName) -s $FileToExecute -o $($App.FullName)" -wait
    write-host "Creating Application on intune platform for $($App.Name)" -ForegroundColor Green
    $InTuneProfileURI = "$($BaseURI)"
    $NewApp = Invoke-RestMethod -Uri $InTuneProfileURI -Headers $Header -body $intuneBody -Method POST -ContentType "application/json"
    write-host "Getting encryption information for intune file for $($App.Name)" -ForegroundColor Green
 
    $intuneWin = get-childitem $App.fullname -Filter *.intunewin
    #unzip the detection.xml file to get manifest info and encryptioninfo.
    $Directory = [System.IO.Path]::GetDirectoryName("$($intuneWin.fullname)")
    Add-Type -Assembly System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead("$($intuneWin.fullname)")
    $zip.Entries | Where-Object { $_.Name -like "Detection.xml" } | ForEach-Object {
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$Directory\Detection.xml", $true)
    }
    $zip.Dispose()
    $intunexml = get-content "$Directory\Detection.xml"
    remove-item  "$Directory\Detection.xml" -Force
    #Unzip the encrypted file to prepare for upload.
    $Directory = [System.IO.Path]::GetDirectoryName("$($intuneWin.fullname)")
    Add-Type -Assembly System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead("$($intuneWin.fullname)")
    $zip.Entries | Where-Object { $_.Name -like "IntunePackage.intunewin" } | ForEach-Object {
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$Directory\IntunePackage.intunewin", $true)
    }
    $zip.Dispose()
    $ExtactedEncFile = (Get-Item "$Directory\IntunePackage.intunewin")
    $intunewinFileSize = (Get-Item "$Directory\IntunePackage.intunewin").Length
   
    $ContentBody = ConvertTo-Json @{
        name          = $intunexml.ApplicationInfo.FileName
        size          = [int64]$intunexml.ApplicationInfo.UnencryptedContentSize
        sizeEncrypted = [int64]$intunewinFileSize
    } 
    write-host "Uploading content information for $($App.Name)." -ForegroundColor Green
 
    $ContentURI = "$($BaseURI)/$($NewApp.id)/microsoft.graph.win32lobapp/contentVersions/1/files/"
    $ContentReq = Invoke-RestMethod -Uri $ContentURI -Headers $Header -body $ContentBody -Method POST -ContentType "application/json"
    write-host "Trying to get file uri for $($App.Name)." -ForegroundColor Green
    do {
        write-host "Still trying to get file uri for $($App.Name) Please wait." -ForegroundColor Green
        $AzFileUriCheck = "$($BaseURI)/$($NewApp.id)/microsoft.graph.win32lobapp/contentVersions/1/files/$($ContentReq.id)"
        $AzFileUri = Invoke-RestMethod -Uri $AzFileUriCheck -Headers $Header -Method get -ContentType "application/json"
        if ($AZfileuri.uploadState -like "*fail*") { break }
        start-sleep 5
    } while ($AzFileUri.AzureStorageUri -eq $null) 
    write-host "Retrieved upload URL. Uploading package $($App.Name) via AzCopy." -ForegroundColor Green
 
    $UploadResults = & "$($ApplicationFolder)\azCopy.exe" cp "$($ExtactedEncFile.fullname)" "$($Azfileuri.AzureStorageUri)"  --block-size-mb 4 --output-type 'json'   
    remove-item @($intunewin.fullname, $ExtactedEncFile) -Force
    start-sleep 2
 
    write-host "File uploaded. Commiting $($App.Name) with Encryption Info" -ForegroundColor Green
 
    $EncBody = @{
        fileEncryptionInfo = @{
            encryptionKey        = $intunexml.ApplicationInfo.EncryptionInfo.EncryptionKey
            macKey               = $intunexml.ApplicationInfo.EncryptionInfo.MacKey
            initializationVector = $intunexml.ApplicationInfo.EncryptionInfo.InitializationVector
            mac                  = $intunexml.ApplicationInfo.EncryptionInfo.Mac
            profileIdentifier    = $intunexml.ApplicationInfo.EncryptionInfo.ProfileIdentifier
            fileDigest           = $intunexml.ApplicationInfo.EncryptionInfo.FileDigest
            fileDigestAlgorithm  = $intunexml.ApplicationInfo.EncryptionInfo.FileDigestAlgorithm
        }
    } | ConvertTo-Json
    $CommitURI = "$($BaseURI)/$($NewApp.id)/microsoft.graph.win32lobapp/contentVersions/1/files/$($ContentReq.id)/commit"
    $CommitReq = Invoke-RestMethod -Uri $CommitURI -Headers $Header -body $EncBody -Method POST -ContentType "application/json"
 
    write-host "Waiting for file commit results for $($App.Name)." -ForegroundColor Green
 
    do {
        write-host "Still trying to get commit state. Please wait." -ForegroundColor Green
 
        $CommitStateURL = "$($BaseURI)/$($NewApp.id)/microsoft.graph.win32lobapp/contentVersions/1/files/$($ContentReq.id)"
        $CommitStateReq = Invoke-RestMethod -Uri $CommitStateURL -Headers $Header -Method get -ContentType "application/json"
        if ($CommitStateReq.uploadState -like "*fail*") { write-host "Commit Failed for $($App.Name). Moving on to Next application. Manual intervention will be required" -ForegroundColor red; break }
        start-sleep 10
    } while ($CommitStateReq.uploadState -eq "commitFilePending") 
    if ($CommitStateReq.uploadState -like "*fail*") { continue }
    write-host "Commiting application version" -ForegroundColor Green
    $ConfirmBody = @{
        "@odata.type"             = "#microsoft.graph.win32lobapp"
        "committedContentVersion" = "1"
    } | Convertto-Json
    $CommitFinalizeURI = "$($BaseURI)/$($NewApp.id)"
    $CommitFinalizeReq = Invoke-RestMethod -Uri $CommitFinalizeURI -Headers $Header -body $Confirmbody -Method PATCH -ContentType "application/json"
    write-host "Deployment completed for app $($app.name). You can assign this app to users now." -ForegroundColor Green
}