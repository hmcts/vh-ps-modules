# Based on https://gitlab.com/Lieben/assortedFunctions/blob/master/Grant-OAuth2PermissionsToApp.ps1
Function Grant-OAuth2PermissionsToApp {
    Param(
        [Parameter(Mandatory)]
        [Alias("AppName")]
        $azureAdAppName,

        [string]
        [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})] 
        $AzureAdAppCertificateThumbprint,

        [Parameter(Mandatory)]
        $AzureAdAppId
    )

    # Search for an existing AAD app
    $azureADAppClient = Get-AzureADApplication -SearchString $azureAdAppName | Where-Object DisplayName -EQ $azureAdAppName

    if ($null -eq $azureADAppClient) {
        Write-Error ("Unable to find app {0}. Check if you are connected to the correct AAD tenant." -f $azureADAppClient) -ErrorAction Stop
    }

    $azureAppId = $azureADAppClient.AppId
    
    $tenant = Get-AzureADTenantDetail
    $tenantId = $tenant.objectId
    #$token = Get-AzureADToken -TenantId $tenantId -ApplicationId $AzureAdAppId -CertThumbprint $AzureAdAppCertificateThumbprint -ResourceURI "74658136-14ec-4630-ad9b-26e160ff0fc6"
    #Write-Host $token
    $authority = 'https://login.microsoftonline.com/common/' + $tenantId
    #$authContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($authority)
    #$ClientCred = [Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential]::new($UserName, $Password)
    $ClientCred = Get-Credential
    $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $ClientCred)
    
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $token)
    $headers.Add("X-Requested-With", "XMLHttpRequest")
    $headers.Add("x-ms-client-request-id", [guid]::NewGuid())
    $headers.Add("x-ms-correlation-id", [guid]::NewGuid())

    $url = "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$azureAppId/Consent?onBehalfOfAll=true"
    Invoke-RestMethod -Uri $url -Method POST -ErrorAction Stop -Headers $headers
}
