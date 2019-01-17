function Set-AzureADResourceAccess {
    [CmdletBinding()]
    param (
        [String] 
        [Parameter(Mandatory)]
        $AzureADAppNameServer,
        [String] 
        [Parameter(Mandatory)]
        $AzureADAppNameClinet
    )
    
    begin {
        # Server app, app that needs to be accessed e.g. hearings API
        $AzureADAppThatNeedsToBeAccessed = (Get-AzureADApplication -SearchString $AzureADAppNameServer)[0]
        # Client app, app that will be accessing Server app e.g. book a hearing API
        $AzureADAppClient = (Get-AzureADApplication -SearchString $AzureADAppNameClinet)[0]
    }
    
    process {
        # book-hearing-api -> hearings-api
        # check if app has required resource access

        if ($AzureADAppClient.RequiredResourceAccess.ResourceAppId -notcontains $AzureADAppThatNeedsToBeAccessed.AppId -and `
                $AzureADAppClient.RequiredResourceAccess.ResourceAccess.Id -notcontains $AzureADAppThatNeedsToBeAccessed.Oauth2Permissions.id
        ) {
            # new object for setting RequiredResourceAccess for client app
            $ReqAccessObject = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"

            # oauth2Permission ID, Used for configuring the client App's "requiredResourceAccess" permissions. This is the id of Oauth2Permissions from server app e.g. hearings API 
            $ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $AzureADAppThatNeedsToBeAccessed.Oauth2Permissions.id, "Scope"

            # add values to object
            $ReqAccessObject.ResourceAccess = $ResourceAccess
            $ReqAccessObject.ResourceAppId = $AzureADAppThatNeedsToBeAccessed.AppID

            $AZureADAppExistingRequiredResourceAccess = $AzureADAppClient.RequiredResourceAccess
            $AZureADAppExistingRequiredResourceAccess.add($ReqAccessObject)

            Set-AzureADApplication -ObjectId $AzureADAppClient.ObjectId -RequiredResourceAccess $AZureADAppExistingRequiredResourceAccess

        }

    }
    
    end {
    }
}