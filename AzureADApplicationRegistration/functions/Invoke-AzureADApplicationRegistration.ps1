<#
.Synopsis
   This function will register new AAD applications and Service Principals.
.DESCRIPTION
   This function will register new AAD applications and Service Principals. This is required to setup service to service authentication and to grant access to Microsoft's API's.
   Once the AAD application registration has been completed it will output the App Name, App ID, App Key, App ID URI as environment variables for consumption in VSTS.
   Also, it will push the App Name, App ID, App Key, App ID URI to the specified Azure Key Vault.
.EXAMPLE
   Invoke-AzureADApplicationRegistration -AzureTenantId "xxx" -AzureAdAppId "xxx" -AzureAdAppCertificateThumbprint "xxx" -AzureSubscriptionId "xxx" -AzureKeyVaultName "xxx" -AzureADApplicationName "xxx"
.EXAMPLE
   Invoke-AzureADApplicationRegistration -AzureTenantId "xxx" -AzureAdAppId "xxx" -AzureAdAppCertificateThumbprint "xxx" -AzureSubscriptionId "xxx" -AzureKeyVaultName "xxx" -AzureADApplicationName "xxx" -AzureTenantIdSecondary "xxx" -AzureAdAppIdSecondary "xxx" -AzureAdAppCertificateThumbprintSecondary "xxx"
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>

#Requires -Version 5.0
#Requires -Module AzureAD
#Requires -Module AzureRM.KeyVault

function Invoke-AzureADApplicationRegistration {

    [CmdletBinding()]
    param (
        [String] 
        [Parameter(Mandatory)]
        $AzureTenantId,
        [String]
        [Parameter(Mandatory)]
        $AzureAdAppId,
        [string]
        [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})] 
        $AzureAdAppCertificateThumbprint,
        [String]
        [Parameter(Mandatory)]
        $AzureSubscriptionId,
        [String]
        [Parameter(Mandatory)]
        $AzureADApplicationName,
        [String]
        [Parameter(Mandatory)]
        $AzureKeyVaultName,
        [String]
        $identifierUrisPrefix = "hearings.reform.hmcts.net/",
        [String]
        $AzureTenantIdSecondary,
        [String]
        $AzureAdAppIdSecondary,
        [String]
        [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})] 
        $AzureAdAppCertificateThumbprintSecondary
    )

    # If the secondary Tenant details are present the first block of code will be executed. This will Register AAD apps in secondary tenant but
    # will push the details to the key vault located in primary tenant, Azure Subscription.

    if ($AzureTenantIdSecondary -and $AzureAdAppIdSecondary -and $AzureAdAppCertificateThumbprintSecondary) {
        Invoke-AzureADConnection -AzureTenantIdSecondary $AzureTenantIdSecondary -AzureAdAppIdSecondary $AzureAdAppIdSecondary -AzureAdAppCertificateThumbprintSecondary $AzureAdAppCertificateThumbprintSecondary
        Invoke-AzureRMConnection -AzureTenantId $AzureTenantId -AzureAdAppId $AzureAdAppId -AzureAdAppCertificateThumbprint $AzureAdAppCertificateThumbprint -AzureSubscriptionId $AzureSubscriptionId
        $AADRegApp = Add-AzureADApp -AADAppName  $AzureADApplicationName -identifierUrisPrefix $identifierUrisPrefix -AzureKeyVaultName $AzureKeyVaultName
        Set-VSTSVariables -AADAppAsHashTable $AADRegApp
        if ($AADRegApp.Key) {
            Add-AzureADAppSecret -AzureKeyVaultName $AzureKeyVaultName -AADAppAsHashTable $AADRegApp -AADAppName $AzureADApplicationName
        }
      
    }
    # Application registration is performed in the same tenant where the Azure Key vault is located.
    else {
        Invoke-AzureConnection -AzureTenantId $AzureTenantId -AzureAdAppId $AzureAdAppId -AzureAdAppCertificateThumbprint $AzureAdAppCertificateThumbprint -AzureSubscriptionId $AzureSubscriptionId
        $AADRegApp = Add-AzureADApp -AADAppName  $AzureADApplicationName -identifierUrisPrefix $identifierUrisPrefix -AzureKeyVaultName $AzureKeyVaultName
        Set-VSTSVariables -AADAppAsHashTable $AADRegApp
        if ($AADRegApp.Key) {
            Add-AzureADAppSecret -AzureKeyVaultName $AzureKeyVaultName -AADAppAsHashTable $AADRegApp -AADAppName $AzureADApplicationName
        }
      
    }
} 