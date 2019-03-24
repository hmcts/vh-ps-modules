# Based on https://gitlab.com/Lieben/assortedFunctions/blob/master/Grant-OAuth2PermissionsToApp.ps1
Function Grant-OAuth2PermissionsToApp {
    Param(
        [Parameter(Mandatory)]
        [Alias("AppName", "AzureADApplicationName")]
        $azureAdAppName,
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateScript( {
                try {
                    [System.Guid]::Parse($_) | Out-Null
                    $true
                } 
                catch {
                    $false
                }
            })]
        [String]
        [Alias("AzureTenantIdSecondary")]
        $AzureTenantId,
        [string]
        [Parameter(Mandatory)]
        [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})]
        [Alias("AzureAdAppCertificateThumbprintSecondary")]
        $AzureAdAppCertificateThumbprint,
        [Parameter(Mandatory)]
        [Alias("AzureAdAppIdSecondary")]
        $AzureAdAppId
    )

    Write-Output "###############################"
    Write-Output "       Grant Permissions"
    Write-Output "###############################"

    # Search for an existing AAD app
    Write-Output ("Searching for Azure AD App {0}" -f $azureAdAppName)
    $azureADAppClient = Search-AzureADApp -azureAdAppName $azureAdAppName

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

    Write-Output ("Acquiring bearer token")
    $token = $null

    Write-Output ("Trying to get cert from cert:\LocalMachine\My\{0}" -f $AzureAdAppCertificateThumbprint)

    $token = Get-AADToken -AzureTenantId $AzureTenantId -AzureAdAppId $AzureAdAppId -AzureAdAppCertificateThumbprint $AzureAdAppCertificateThumbprint

    # Main logic for granting permissions
    foreach ($requiredResourceAccess in $azureADAppClient.RequiredResourceAccess) {
        # Clean scope variable
        $scope = $null

        # Builds header that will be used in all API requests
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", $token)
        $headers.Add("Content-Type", "application/json")

        # Gets the service principal of Azure AD API e.g. Windows Azure Active Directory or Microsoft Graph. The app ID's of these Service Principals are well known!!! 
        $url = ("https://graph.windows.net/myorganization/servicePrincipals?api-version=1.6&`$filter=appId+eq+'{0}'" -f $RequiredResourceAccess.ResourceAppId)
        $oauth2ServicePrincipal = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop -Headers $headers

        # Get existing OAuth2 Permission Grants for Azure AD app
        $url = ("https://graph.windows.net/myorganization/oauth2PermissionGrants?api-version=1.6&`$filter=clientId+eq+'{0}'" -f $azureADAppSP.ObjectId)
        $existingOAuth2PermissionGrants = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop -Headers $headers

        foreach ($resourceAccess in $RequiredResourceAccess.ResourceAccess) {
      
            # Set scope variable by searching Azure AD apps resource access scope ID's in $oauth2ServicePrincipal appRoles ID's and adding to scop variable 
            foreach ($appRoles in $oauth2ServicePrincipal.value.appRoles) {
                if ($appRoles.id -eq $resourceAccess.Id) {
                    $scope += ($appRoles.value + " ")
                }
            }

            foreach ($oauth2Permissions in $oauth2ServicePrincipal.value.oauth2Permissions) {
                if ($oauth2Permissions.id -eq $resourceAccess.Id) {
                    $scope += ($oauth2Permissions.value + " ")
                }
            }
        }

        # If exiting Granted Resource Access has been set on a Azure AD App's Service Principal we might want to patch them if new permissions have been set on Azure AD app 
        # if not we want to grant new Resource Access permissions. This will create new object in "oauth2PermissionGrants".
        if ($existingOAuth2PermissionGrants.value.resourceId -contains $oauth2ServicePrincipal.value.objectId) {

            Write-Output ("There are {0} exiting permission grants" -f $existingOAuth2PermissionGrants.value.resourceId.Count)
            Write-Output ("Checking permission scope for {0} resource" -f $oauth2ServicePrincipal.value.appDisplayName)

            # Compare existing scope to required scope,
            # patch if scope needs updating
            foreach ($existingPermissionGrant in $existingOAuth2PermissionGrants.value) {

                # Compare existing and required scopes for a particular Resource Access. If the scopes are different then patch the existing resource access scope,
                # skip if the scopes are the same of the required and existing Resource Access
                Write-Output "Checking if new permission scope has changed"

                if ($existingPermissionGrant.resourceId -eq $oauth2ServicePrincipal.value.objectId) {
                    if ($existingPermissionGrant.scope -ne $scope.trim()) {
                      
                        Write-Output "Permission scope has changed. Updating now..."
                        # body for patching existing permission grants
                        $patchExistingPermissionGrantsBody = @{
                            "scope" = "PERMISSION NAME OF THE SERVICE PRINCIPAL REPRESENTING AZURE AD APPLICATION IN YOUR TENANT"
                        }
                  
                        # Replace the scope value in the body that will be used to patch the Granted Resource Access permissions
                        $patchExistingPermissionGrantsBody.scope = $scope.trim()

                        $url = ("https://graph.windows.net/myorganization/oauth2PermissionGrants/{0}?api-version=1.6" -f $existingPermissionGrant.objectId)
                        $response = Invoke-RestMethod -Uri $url -Method Patch -ErrorAction Stop -Headers $headers -Body ( $patchExistingPermissionGrantsBody | ConvertTo-Json)
                        $response | select *
                    }
                }
            }
        }

        # Run this block if new Azure AD API has been selected as Required Access
        elseif ($existingOAuth2PermissionGrants.value.resourceId -notcontains $oauth2ServicePrincipal.value.objectId) {
            # Update the request body with relative details. 
            # clientId is the objectId of the service principal that is married to the Azure AD app. 
            # resourceId is the id of the service principal of Azure AD API e.g. Windows Azure Active Directory or Microsoft Graph
            Write-Output ("Granting permissions for {0} with {1} resource" -f $azureADAppClient.DisplayName, $oauth2ServicePrincipal.value.appDisplayName)

            $createOAuth2PermissionGrantsBody = @{
                "clientId"    = "YOUR APPLICATION’S SERVICE PRINCIPAL OBJECT ID";
                "consentType" = "AllPrincipals";
                "resourceId"  = "OBJECT ID OF THE SERVICE PRINCIPAL REPRESENTING AZURE AD APPLICATION IN YOUR TENANT";
                "scope"       = "PERMISSION NAME OF THE SERVICE PRINCIPAL REPRESENTING AZURE AD APPLICATION IN YOUR TENANT";
                "startTime"   = "0001-01-01T00:00:00";
                "expiryTime"  = "9000-01-01T00:00:00"
            }

            # Update the request body
            $CreateOAuth2PermissionGrantsBody.clientId = $azureADAppSP.ObjectId
            $CreateOAuth2PermissionGrantsBody.resourceId = $oAuth2ServicePrincipal.value.objectId
            $CreateOAuth2PermissionGrantsBody.scope = $scope.trim()

            $url = 'https://graph.windows.net/myorganization/oauth2PermissionGrants?api-version=1.6'
            $response = Invoke-RestMethod -Uri $url -Method Post -ErrorAction Stop -Headers $headers -Body ( $CreateOAuth2PermissionGrantsBody | ConvertTo-Json)
          
        }
        else {
            Write-Output "Noting to grant or update."
        }
    }
}
