
function Set-AzureADResourceAccessV2 {
    [CmdletBinding()]
    param (
        [String] 
        [Parameter(Mandatory)]
        $resourceAccessDefinition,
        [String] 
        [Parameter(Mandatory)]
        $azureAdAppName
    )
    
    begin {

        # Get the permissions list form json
        $apiAccessJSON = Get-Content $resourceAccessDefinition  | ConvertFrom-Json

        # Search for an existing AAD app
        $azureADAppClient = Get-AzureADApplication -SearchString $azureAdAppName | Where-Object DisplayName -EQ $azureAdAppName

        if ($null -eq $azureADAppClient) {
            Write-Error ("Unable to find app {0}. Check if you are connected to the correct AAD tenant." -f $azureADAppClient) -ErrorAction Stop
            
        }

        # new object for setting RequiredResourceAccess for client app
        $requiredResourceAccessObject = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"

        # Create new variable with existing permissions
        $azureADAppExistingRequiredResourceAccess = $azureADAppClient.RequiredResourceAccess

    }
    
    process {
        foreach ($resource in $apiAccessJSON.requiredResourceAccess) {
            Write-Output   ("Checking if Required Resource Name '{0}' with Required Resource Id: '{1}' has been set..." -f $resource.resourceAppName, $resource.resourceAppId)

            if ($azureADAppClient.RequiredResourceAccess.ResourceAppId -notcontains $resource.resourceAppId) {

                foreach ($resourceAccess in $resource.resourceAccess) {
                    Write-Output ("Checking if Required Resource Access ID '{0}' with Required Resource Access Type: '{1}' has been set..." -f $resourceAccess.id, $resourceAccess.type)
                    if ($azureADAppClient.RequiredResourceAccess.ResourceAccess.id -notcontains $resourceAccess.id) {
                        Write-Output ("Required Resource Access ID '{0}' with Required Resource Access Type: '{1}' has not been set." -f $resourceAccess.id, $resourceAccess.type)
                        Write-Output ("Setting up now...")

                        # oauth2Permission ID, Used for configuring the client App's "requiredResourceAccess" permissions.
                        $ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $resourceAccess.id, $resourceAccess.type
        
                        # add values to object
                        $requiredResourceAccessObject.ResourceAccess += $ResourceAccess                        
                    }
                }
                # Add Required Resource App ID thats is missing to the object.
                $requiredResourceAccessObject.ResourceAppId = $resource.resourceAppId
                $azureADAppExistingRequiredResourceAccess.add($requiredResourceAccessObject)
            }
            else {
                Write-Output   ("Required Resource '{0}' with Required Resource Id: '{1}' has been set." -f $resource.resourceAppName, $resource.resourceAppId)

                foreach ($existingRequiredResource in $azureADAppExistingRequiredResourceAccess) {
                    if ($existingRequiredResource.ResourceAppId -eq $resource.resourceAppId) {

                        foreach ($resourceAccess in $resource.resourceAccess) {
                            Write-Output ("Checking if Required Resource Access ID '{0}' with Required Resource Access Type: '{1}' has been set..." -f $resourceAccess.id, $resourceAccess.type)
                            
                            if ($azureADAppClient.RequiredResourceAccess.ResourceAccess.id -notcontains $resourceAccess.id) {
                                Write-Output ("Required Resource Access ID '{0}' with Required Resource Access Type: '{1}' has not been set." -f $resourceAccess.id, $resourceAccess.type)
                                Write-Output ("Setting up now...")
    
                                # New resource access object with values
                                $ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $resourceAccess.id, $resourceAccess.type
            
                                # add values to object
                                $requiredResourceAccessObject.ResourceAccess += $ResourceAccess                        
                            }
                        }
                        # Add the new Resource Access to the Existing resource access object
                        if ($null -EQ $requiredResourceAccessObject.ResourceAccess) {
                            Write-Output "No new Resource Access permissions found to be set."
                            
                        }
                        else {
                            $existingRequiredResource.ResourceAccess += $requiredResourceAccessObject.ResourceAccess
                        }
                    }
                }
            }
        }
    }    
    end {
        Set-AzureADApplication -ObjectId $azureADAppClient.ObjectId -RequiredResourceAccess $azureADAppExistingRequiredResourceAccess
    }
}
