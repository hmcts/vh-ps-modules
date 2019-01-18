# Function to connect to Azure AD using certificate (private key) stored in VM's certificate store
function Invoke-AzureRMConnection {
    [CmdletBinding()]
    param (
        [String]
        [Alias("AzureTenantIdSecondary")]
        [Parameter(Mandatory)]
        $AzureTenantId,
        [String]
        [Alias("AzureAdAppIdSecondary")]
        [Parameter(Mandatory)]
        $AzureAdAppId,
        [string]
        [Alias("AzureAdAppCertificateThumbprintSecondary")]
        [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})] 
        $AzureAdAppCertificateThumbprint,
        [String]
        [Parameter(Mandatory)]
        $AzureSubscriptionId 
    )
    Connect-AzureRmAccount -ServicePrincipal -TenantId $AzureTenantId -ApplicationId $AzureAdAppId  -CertificateThumbprint $AzureAdAppCertificateThumbprint -Subscription $AzureSubscriptionId -ErrorAction Stop
}