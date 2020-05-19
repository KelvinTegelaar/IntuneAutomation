# Intune Automation Scripts
Scripts made to ease intune usage for MSPs and Microsoft Partners. 

Requires the secure application model tokens. see https://www.cyberdrain.com/connect-to-exchange-online-automated-when-mfa-is-enabled-using-the-secureapp-model/

Requires extra permissions for the Azure Application:

- Go to the Azure Portal.
- Click on Azure Active Directory, now click on “App Registrations”.
- Find your Secure App Model application. You can search based on the ApplicationID.
- Go to “API Permissions” and click Add a permission.
- Choose “Microsoft Graph” and “Application permission”.
- Search for “Reports” and click on “DeviceManagementServiceConfig.ReadWrite.All”. Click on add permission
- Do the same for “Delegate Permissions”.
- Finally, click on “Grant Admin Consent for Company Name.

see https://www.cyberdrain.com/automating-with-powershell-automating-intune-autopilot-configuration/ and https://www.cyberdrain.com/automating-with-powershell-automatically-uploading-applications-to-intune-tenants/ for more information.

# New-AutoPilotProfile.ps1
Creates new autopilot profile for specified tenant. Can edit script to create same profile for all tenants.
# Import-DeviceIDsAutopilot.ps1
Automates the uploading or enter of hardware IDs from CSV files. can be schedulded to run automatically so zero-touch autopilot becomes possible.
# Upload-IntuneLobApplications.ps1
Uploads all applications in specified folder to intune for all tenants or a single tenant. Eases deployment by giving you the ability to roll-out a template of devices.

Requires JSON file in each application folder. See example.json