
function Set-AzureADResourceAccessV2 {
    [CmdletBinding()]
    param (
        [String] 
        [Parameter(Mandatory)]
        $resourceAccessDefinition,
        [String] 
        [Parameter(Mandatory)]
        [Alias("AzureADApplicationName")]
        $azureAdAppName
    )
    
    begin {

        # Get the permissions list form json
        $jsonFile = Get-Content $resourceAccessDefinition | ConvertFrom-Json

        # Change the app name with '_'
        $azureAdAppName = Format-AppName -AADAppName $azureAdAppName

        # Search for an existing AAD app
        $azureADAppClient = Get-AzureADApplication -SearchString $azureAdAppName | Where-Object DisplayName -EQ $azureAdAppName

        if ($null -eq $azureADAppClient) {
            Write-Error ("Unable to find app {0}. Check if you are connected to the correct AAD tenant." -f $azureADAppClient) -ErrorAction Stop
        }

        # Create new variable with existing permissions
        $currentRequiredResourceAccess = $azureADAppClient.RequiredResourceAccess

        # Input
        $requestedRequiredResourceAccess = $jsonFile.RequiredResourceAccess

    }
    process {
        # Remove resource access objects if they are no present in $requestedRequiredResourceAccess 
        foreach ($currentRequiredResourceAccessObject in $currentRequiredResourceAccess) {
            if ($requestedRequiredResourceAccess.resourceAppId -notcontains $currentRequiredResourceAccessObject.ResourceAppId) {
                $currentRequiredResourceAccess = $currentRequiredResourceAccess | Where-Object ResourceAppId -ne $currentRequiredResourceAccessObject.ResourceAppId
            }
        }
        
        foreach ($resource in $requestedRequiredResourceAccess) {
            Write-Output   ("Checking if Required Resource Name '{0}' with Required Resource Id: '{1}' has been set..." -f $resource.resourceAppName, $resource.resourceAppId)

            # new object for setting RequiredResourceAccess for client app
            $requiredResourceAccessObject = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"

            # if the currently registered required resources doesn't contain this one
            if ($azureADAppClient.RequiredResourceAccess.ResourceAppId -notcontains $resource.resourceAppId) {

                foreach ($resourceAccess in $resource.resourceAccess) {
                    Write-Output ("Checking if Required Resource Access ID '{0}' with Required Resource Access Type: '{1}' has been set..." -f $resourceAccess.id, $resourceAccess.type)
                    if ($azureADAppClient.RequiredResourceAccess.ResourceAccess.id -notcontains $resourceAccess.id) {
                        Write-Output ("Required Resource Access '{0}' ID '{1}' with Required Resource Access Type: '{2}' has not been set, adding it.." -f $resourceAccess.resourceAccessName, $resourceAccess.id, $resourceAccess.type)

                        # oauth2Permission ID, Used for configuring the client App's "requiredResourceAccess" permissions.
                        $addResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $resourceAccess.id, $resourceAccess.type
        
                        # add values to object
                        $requiredResourceAccessObject.ResourceAccess += $addResourceAccess
                    }
                    else {
                        Write-Output ("Required Resource Access ID '{0}' already defined, skipping.." -f $resourceAccess.id)
                    }
                }
                
                # if any missing permissions need to be added
                if ($requiredResourceAccessObject.ResourceAccess.Count -gt 0) {
                    $requiredResourceAccessObject.ResourceAppId = $resource.resourceAppId
                    $currentRequiredResourceAccess.add($requiredResourceAccessObject)
                    Write-Output ("New Resource with Id '{0}' to be added" -f $requiredResourceAccessObject.ResourceAppId)
                }
                else {
                    Write-Output ("New resource '{0}' was declared among required resources but did specify any resource accesses" -f $resource.resourceAppName)
                }
            }
            else {
                Write-Output   ("Required Resource '{0}' with Required Resource Id: '{1}' is already added to app registration, detecting required resource accesses.." -f $resource.resourceAppName, $resource.resourceAppId)

                # for each of the existing required resources
                foreach ($existingRequiredResource in $currentRequiredResourceAccess) {
                    # find the one resource that's matching the one we're trying to add
                    if ($existingRequiredResource.ResourceAppId -eq $resource.resourceAppId) {
                        # iterate through each required resource 
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

                            # Remove required resource access form the object if it is not present in $requestedRequiredResourceAccess
                            foreach ($existingRequiredResourceResourceAccessObject in $existingRequiredResource.ResourceAccess) {
                                if ($resource.resourceAccess.id -notcontains $existingRequiredResourceResourceAccessObject.Id) {
                                    $existingRequiredResource.ResourceAccess = $existingRequiredResource.ResourceAccess | Where-Object id -ne $existingRequiredResourceResourceAccessObject.Id
                                }
                            }
                        }
                        # Add the new Resource Access to the Existing resource access object
                        if ($null -EQ $requiredResourceAccessObject.ResourceAccess) {
                            Write-Output ("No new Resource Access permissions found to be set for '{0}'." -f $resource.resourceAppName)
                        }
                        else {
                            # iterate through current required resource access
                            foreach ($cRequiredResourceAccess in $currentRequiredResourceAccess) {
                                # if current resource access id is the same as required resource access id then amend the required resource access as per resourceAccess.json
                                if ($cRequiredResourceAccess.ResourceAppId -eq $resource.resourceAppId) {
                                    foreach ($rResourceAccess in $requiredResourceAccessObject.ResourceAccess) {
                                        if ($cRequiredResourceAccess.ResourceAccess.Id -notcontains $rResourceAccess.Id) {
                                            $cRequiredResourceAccess.ResourceAccess += $requiredResourceAccessObject.ResourceAccess
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    end {
        Set-AzureADApplication -ObjectId $azureADAppClient.ObjectId -RequiredResourceAccess $currentRequiredResourceAccess
    }
}
