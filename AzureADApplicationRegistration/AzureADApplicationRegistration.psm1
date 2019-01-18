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

    if ($AzureTenantIdSecondary -and $AzureAdAppIdSecondary -and $AzureAdAppCertificateThumbprintSecondary) {
        Invoke-AzureADConnection -AzureTenantIdSecondary $AzureTenantIdSecondary -AzureAdAppIdSecondary $AzureAdAppIdSecondary -AzureAdAppCertificateThumbprintSecondary $AzureAdAppCertificateThumbprintSecondary
        Invoke-AzureRMConnection -AzureTenantId $AzureTenantId -AzureAdAppId $AzureAdAppId -AzureAdAppCertificateThumbprint $AzureAdAppCertificateThumbprint -AzureSubscriptionId $AzureSubscriptionId
        $AADRegApp = Add-AzureADApp -AADAppName  $AzureADApplicationName
        Set-VSTSVariables -AADAppAsHashTable $AADRegApp
        if ($AADRegApp.Key) {
            Add-AzureADAppSecret -AzureKeyVaultName $AzureKeyVaultName -AADAppAsHashTable $AADRegApp -AADAppName $AzureADApplicationName
        }
        
    }
    else {
        Invoke-AzureConnection -AzureTenantId $AzureTenantId -AzureAdAppId $AzureAdAppId -AzureAdAppCertificateThumbprint $AzureAdAppCertificateThumbprint -AzureSubscriptionId $AzureSubscriptionId
        $AADRegApp = Add-AzureADApp -AADAppName  $AzureADApplicationName
        Set-VSTSVariables -AADAppAsHashTable $AADRegApp
        if ($AADRegApp.Key) {
            Add-AzureADAppSecret -AzureKeyVaultName $AzureKeyVaultName -AADAppAsHashTable $AADRegApp -AADAppName $AzureADApplicationName
        }
        
    }
} 