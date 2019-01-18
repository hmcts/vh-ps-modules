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
        [Parameter()]
        [switch]
        $AzureTenantIdSecondary,
        [Parameter()]
        [switch]
        $AzureAdAppIdSecondary,
        [switch]
        [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})] 
        $AzureAdAppCertificateThumbprintSecondary
    )

    if ($AzureTenantIdSecondary -and $AzureAdAppIdSecondary -and $AzureAdAppCertificateThumbprintSecondary) {
        
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

function Invoke-AzureConnection {
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
        $AzureSubscriptionId 
    )
    Connect-AzureAD -TenantId $AzureTenantId -ApplicationId $AzureAdAppId -CertificateThumbprint $AzureAdAppCertificateThumbprint -ErrorAction Stop
    Connect-AzureRmAccount -ServicePrincipal -TenantId $AzureTenantId -ApplicationId $AzureAdAppId  -CertificateThumbprint $AzureAdAppCertificateThumbprint -Subscription $AzureSubscriptionId -ErrorAction Stop
}
