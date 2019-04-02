# Based on https://gitlab.com/Lieben/assortedFunctions/blob/master/Grant-OAuth2PermissionsToApp.ps1
Function Grant-OAuth2PermissionsToApp {
    Param(
        [Parameter(Mandatory)]
        [Alias("AppName")]
        $azureAdAppName,
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateScript({
              try 
              {
                [System.Guid]::Parse($_) | Out-Null
                $true
              } 
              catch 
              {
                $false
              }
        })]
        [String]
        [Alias("AzureTenantIdSecondary")]
        $AzureTenantId,
        [string]
        [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})] 
        $AzureAdAppCertificateThumbprint,
        [Parameter(Mandatory)]
        $AzureAdAppId
    )

    # Search for an existing AAD app
    $azureADAppClient =  Search-AzureADApp -azureAdAppName $azureAdAppName

    if ($null -eq $azureADAppClient) {
        Write-Error ("Unable to find app {0}. Check if you are connected to the correct AAD tenant." -f $azureADAppClient) -ErrorAction Stop
    }

    # Find Azure AD App's Service Principal
    $azureADAppSP = Get-AzureADServicePrincipal -SearchString  $azureADAppClient.DisplayName | Where DisplayName -eq $azureADAppClient.DisplayName | where AppId -eq $azureADAppClient.AppId 

    # Check if a SP exists for the Azure AD app and create one if it doesn't
    if ($azureADAppSP) {
      Write-Output ("Service Principal with ID {0} for Azure AD app {1} has been found." -f $azureADAppSP.ObjectId, $azureADAppClient.DisplayName)
    }
    else {
      Write-Output ("Creating new Service Principal for Azure AD app {0}." -f $azureADAppClient.DisplayName)
      $azureADAppSP = New-AzureADServicePrincipal -AppId $azureADAppClient.AppId
    }

    # Get bearer token 
    $token = $null
    $token = Get-AADToken -AzureTenantId $AzureTenantId -AzureAdAppId $AzureAdAppId -AzureAdAppCertificateThumbprint $AzureAdAppCertificateThumbprint

    foreach ($requiredResourceAccess in $azureADAppClient.RequiredResourceAccess) {
      # Clean scope variable
      $scope = $null
      $appRoleScopeArray = @()

      # Builds header that will be used in all API requests
      $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
      $headers.Add("Authorization", $token)
      $headers.Add("Content-Type", "application/json")

      # Gets the service principal of Azure AD API e.g. Windows Azure Active Directory or Microsoft Graph 
      $url = ("https://graph.windows.net/myorganization/servicePrincipals?api-version=1.6&`$filter=appId+eq+'{0}'" -f $RequiredResourceAccess.ResourceAppId)
      $oauth2ServicePrincipal = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop -Headers $headers

      foreach ($resourceAccess in $RequiredResourceAccess.ResourceAccess) {
      

        # Set scope variable by searching Azure AD apps resource access scope ID's in $oauth2ServicePrincipal object and adding to scop variable 
        foreach ($oauth2Permissions in $oauth2ServicePrincipal.value.oauth2Permissions) {
          if ($oauth2Permissions.id -eq $resourceAccess.Id) {
            $scope += ($oauth2Permissions.value + " ")
          }
        }

        # Set scope variable by searching Azure AD apps resource access scope ID's in $oauth2ServicePrincipal object and adding to scop variable 
        foreach ($appRoles in $oauth2ServicePrincipal.value.appRoles) {
          if ($appRoles.id -eq $resourceAccess.Id) {
            $appRoleIdScopeArray.add($appRoles.id)
          }
        }
      }

      # Get existing OAuth2 Permission Grants

      $url = ("https://graph.windows.net/myorganization/oauth2PermissionGrants?api-version=1.6&`$filter=clientId+eq+'{0}'" -f $azureADAppSP.ObjectId)
      $existingOAuth2PermissionGrants = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop -Headers $headers

      # Compare existing scope to required scope patch if scope need updating
      
      ### code goes here

      $createOAuth2PermissionGrantsBody = @{
        "clientId"="YOUR APPLICATIONS’S SERVICE PRINCIPAL OBJECT ID";
        "consentType"="AllPrincipals";
        "resourceId"="OBJECT ID OF THE SERVICE PRINCIPAL REPRESENTING AZURE AD APPLICATION IN YOUR TENANT";
        "scope"="PERMISSION NAME OF THE SERVICE PRINCIPAL REPRESENTING AZURE AD APPLICATION IN YOUR TENANT";
        "startTime"="0001-01-01T00:00:00";
        "expiryTime"="9000-01-01T00:00:00"
        }
  
        # Update the request body with relative details. 
        # clientId is the objectId of the service principal that is married to the Azure AD app. 
        # resourceId is the id of the service principal of Azure AD API e.g. Windows Azure Active Directory or Microsoft Graph
          
        $CreateOAuth2PermissionGrantsBody.clientId = $azureADAppSP.ObjectId
        $CreateOAuth2PermissionGrantsBody.resourceId = $oAuth2ServicePrincipal.value.objectId
        $CreateOAuth2PermissionGrantsBody.scope = $scope.trim()

      # $url = "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$azureAppId/Consent?onBehalfOfAll=true"
      $url = 'https://graph.windows.net/myorganization/oauth2PermissionGrants?api-version=1.6'
      $response = Invoke-RestMethod -Uri $url -Method Post -ErrorAction Stop -Headers $headers -Body ( $CreateOAuth2PermissionGrantsBody | ConvertTo-Json)
      

      foreach($appRoleId in $appRoleIdScopeArray){
        New-AzureADServiceAppRoleAssignment -ObjectId $azureADAppSP.ObjectId -Id $appRoleId  -ResourceId $oAuth2ServicePrincipal.value.objectId -PrincipalId $azureADAppSP.ObjectId
      }
    }
}






# function Get-AzureADAPIServicePrincipal {
#   param (
#     $token,

#   )
#   $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
#   $headers.Add("Authorization", $token)
#   $headers.Add("Content-Type", "application/json")
#   $url = ("https://graph.windows.net/myorganization/servicePrincipals?api-version=1.6&`$filter=appId+eq+'{0}'" -f "00000002-0000-0000-c000-000000000000")
#   Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop -Headers $headers
# }


    