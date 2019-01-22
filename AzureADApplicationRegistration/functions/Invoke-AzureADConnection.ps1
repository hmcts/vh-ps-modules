# Function to connect to Azure AD using certificate (private key) stored in VM's certificate store
function Invoke-AzureADConnection {
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
        $AzureAdAppCertificateThumbprint
    )
    Connect-AzureAD -TenantId $AzureTenantId -ApplicationId $AzureAdAppId -CertificateThumbprint $AzureAdAppCertificateThumbprint -ErrorAction Stop
}