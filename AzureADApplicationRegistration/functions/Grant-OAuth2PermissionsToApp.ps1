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
        [ValidateScript( { Test-Path ("Cert:\LocalMachine\My\" + "$_") })]
        [Alias("AzureAdAppCertificateThumbprintSecondary")]
        $AzureAdAppCertificateThumbprint,
        [Parameter(Mandatory)]
        [Alias("AzureAdAppIdSecondary")]
        $AzureAdAppId
    )

    Write-Output "###############################"
    Write-Output "       Grant Permissions       "
    Write-Output "###############################"

    # Search for an existing AAD app
    Write-Output ("Searching for Azure AD App {0}" -f $azureAdAppName)
    $azureADAppClient = Search-AzureADApp -azureAdAppName $azureAdAppName

    if ($null -eq $azureADAppClient) {
        Write-Error ("Unable to find app {0}. Check if you are connected to the correct AAD tenant." -f $azureADAppClient) -ErrorAction Stop
    }

    # Find Azure AD App's Service Principal
    $azureADAppSP = Get-AzureADServicePrincipal -SearchString  $azureADAppClient.DisplayName | Where-Object DisplayName -eq $azureADAppClient.DisplayName | Where-Object AppId -eq $azureADAppClient.AppId 

    # Check if a SP exists for the Azure AD app and create one if it doesn't
    if ($azureADAppSP) {
        Write-Output ("Service Principal with ID {0} for Azure AD app {1} has been found." -f $azureADAppSP.ObjectId, $azureADAppClient.DisplayName)
    }
    else {
        Write-Output ("Creating new Service Principal for Azure AD app {0}." -f $azureADAppClient.DisplayName)
        $azureADAppSP = New-AzureADServicePrincipal -AppId $azureADAppClient.AppId

        # $i = 0
        # do {
        #     Write-Host (".") -NoNewline
        #     $i++
        #     Start-Sleep 1
        # }while ($i -lt 10)
    }

    # Get bearer token

    Write-Output ("Acquiring bearer token")
    $token = $null
    $token = Get-AADToken -AzureTenantId $AzureTenantId -AzureAdAppId $AzureAdAppId -AzureAdAppCertificateThumbprint $AzureAdAppCertificateThumbprint

    # Main logic for granting permissions
    foreach ($requiredResourceAccess in $azureADAppClient.RequiredResourceAccess) {
        # Clean scope variable
        $delegatedPermissionsScope = $null
        $applicationPermissionsScope = @()

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

        # Get all application permissions for the current service principal
        #$spApplicationPermissions = Get-AzureADServiceAppRoleAssignedTo -ObjectId $azureADAppSP.ObjectId -All $true | Where-Object { $_.PrincipalType -eq "ServicePrincipal" }

        $url = ("https://graph.windows.net/myorganization/servicePrincipals/{0}/appRoleAssignedTo?api-version=1.6&`$filter=principalDisplayName+eq+'vh_example_api_preview'" -f $oauth2ServicePrincipal.value.objectId, $azureADAppClient.DisplayName)
        $spApplicationPermissions = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop -Headers $headers

        # Splits out App roles and delegated permissions in separate objects
        foreach ($resourceAccess in $RequiredResourceAccess.ResourceAccess) {

            foreach ($appRoles in $oauth2ServicePrincipal.value.appRoles) {
                if ($appRoles.id -eq $resourceAccess.Id -and $resourceAccess.Type -eq "Role") {
                    $applicationPermissionsScope += $appRoles.id
                }
            }

            foreach ($oauth2Permissions in $oauth2ServicePrincipal.value.oauth2Permissions) {
                if ($oauth2Permissions.id -eq $resourceAccess.Id -and $resourceAccess.Type -eq "Scope") {
                    $delegatedPermissionsScope += ($oauth2Permissions.value + " ")
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

                    if ($delegatedPermissionsScope) {
                        if ($existingPermissionGrant.scope -ne $delegatedPermissionsScope.trim()) {
                      
                            Write-Output "Permission scope has changed. Updating now..."
                            # body for patching existing permission grants
                            $patchExistingPermissionGrantsBody = @{
                                "scope" = "PERMISSION NAME OF THE SERVICE PRINCIPAL REPRESENTING AZURE AD APPLICATION IN YOUR TENANT"
                            }
                            
                            # Replace the scope value in the body that will be used to patch the Granted Resource Access permissions
                            $patchExistingPermissionGrantsBody.scope = $delegatedPermissionsScope.trim()


                            $url = ("https://graph.windows.net/myorganization/oauth2PermissionGrants/{0}?api-version=1.6" -f $existingPermissionGrant.objectId)
                            Invoke-RestMethod -Uri $url -Method Patch -ErrorAction Stop -Headers $headers -Body ( $patchExistingPermissionGrantsBody | ConvertTo-Json)
                        }
                        else {
                            Write-Output "Permission scope has not changed"
                        }
                    }
                    else {
                        Write-Output ("Removing existing permission grant {0} with ID {1}" -f $oauth2ServicePrincipal.value.appDisplayName, $existingPermissionGrant.objectId)
                        Remove-AzureADOAuth2PermissionGrant -ObjectId $existingPermissionGrant.objectId
                    }

                    # If application permissions are present they might need to be either added or removed
                    if ($applicationPermissionsScope) {
                        # Iterates through each App permission ID and if it is NOT part of existing application permissions the add new.
                        foreach ($appRoleId in $applicationPermissionsScope) {
                            if ($spApplicationPermissions.value.Id -notcontains $appRoleId ) {

                                Write-Output ("Granting application permission {0} with id {1}" -f $oAuth2ServicePrincipal.value.DisplayName, $appRoleId)
                                # !!! Error action has been set to continue silently because there is a know issue when the command returns Bad Requested but in fact it applies the permissions (https://github.com/MicrosoftDocs/azure-docs/issues/22700)
                                $OriginalErrorActionPreference = $ErrorActionPreference
                                $ErrorActionPreference = 'silentlycontinue' 
                                New-AzureADServiceAppRoleAssignment -ObjectId $azureADAppSP.ObjectId -Id $appRoleId  -ResourceId $oAuth2ServicePrincipal.value.objectId -PrincipalId $azureADAppSP.ObjectId
                                $ErrorActionPreference = $OriginalErrorActionPreference
                            }
                        }
                        foreach ($permission in $spApplicationPermissions.value ) {
                            if ($applicationPermissionsScope -notcontains $permission.id) {
                                Write-Output ("Removing application permission {0} with id {1}" -f $oAuth2ServicePrincipal.value.DisplayName, $permission.ObjectId)
                                Remove-AzureADServiceAppRoleAssignment -ObjectId $azureADAppSP.ObjectId -AppRoleAssignmentId $permission.ObjectId
                            }

                        }
                    }
                    # if there are no application permission ids present in $applicationPermissionsScope it means they have been removed from the app itself.
                    else {
                        foreach ($permission in $spApplicationPermissions) {
                            Write-Output ("Removing application permission {0} with id {1}" -f $oAuth2ServicePrincipal.value.DisplayName, $permission.ObjectId)
                            Remove-AzureADServiceAppRoleAssignment -ObjectId $azureADAppSP.ObjectId -AppRoleAssignmentId $permission.ObjectId
                        }
                    }
                }
            }
        }
        # Run this block if new Azure AD API has been selected as Required Access
        elseif ($existingOAuth2PermissionGrants.value.resourceId -notcontains $oauth2ServicePrincipal.value.objectId) {
            if ($delegatedPermissionsScope) {
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
                $CreateOAuth2PermissionGrantsBody.scope = $delegatedPermissionsScope.trim()

                $url = 'https://graph.windows.net/myorganization/oauth2PermissionGrants?api-version=1.6'
                Invoke-RestMethod -Uri $url -Method Post -ErrorAction Stop -Headers $headers -Body ( $CreateOAuth2PermissionGrantsBody | ConvertTo-Json)
            }

            # If application permissions are present the need to be either added or removed
            if ($applicationPermissionsScope) {
                # Iterates through each App permission ID and if it is NOT part of existing application permissions the add new.
                foreach ($appRoleId in $applicationPermissionsScope) {
                    if ($spApplicationPermissions -notcontains $appRoleId ) {
            
                        # !!! Error action has been set to continue silently because there is a know issue when the command returns Bad Requested but in fact it applies the permissions (https://github.com/MicrosoftDocs/azure-docs/issues/22700)
                        $OriginalErrorActionPreference = $ErrorActionPreference
                        $ErrorActionPreference = 'silentlycontinue' 
                        New-AzureADServiceAppRoleAssignment -ObjectId $azureADAppSP.ObjectId -Id $appRoleId  -ResourceId $oAuth2ServicePrincipal.value.objectId -PrincipalId $azureADAppSP.ObjectId
                        $ErrorActionPreference = $OriginalErrorActionPreference
                    }
                }
            }
            # if there are no application permission ids present in $applicationPermissionsScope it means they have been removed from the app itself.
            else {
                foreach ($permission in $spApplicationPermissions) {
                    Write-Output ("Removing application permission {0} with id {1}" -f $oAuth2ServicePrincipal.value.DisplayName, $permission.ObjectId)
                    Remove-AzureADServiceAppRoleAssignment -ObjectId $azureADAppSP.ObjectId -AppRoleAssignmentId $permission.ObjectId
                }
            }
        }
        else {
            Write-Output "Noting to grant or update."
        }
    }
}
