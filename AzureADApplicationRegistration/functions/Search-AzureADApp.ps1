function Search-AzureADApp {
    [CmdletBinding()]
    param (
        [String] 
        [Parameter(Mandatory)]
        [Alias("AzureADApplicationName")]
        $azureAdAppName
    )
    
    begin {
        # Change the app name with '_'
        $azureAdAppName = Format-AppName -AADAppName $azureAdAppName

        # Search for an existing AAD app
        $azureADAppClient = Get-AzureADApplication -SearchString $azureAdAppName | Where-Object DisplayName -EQ $azureAdAppName
    }
    
    process {
        # Checks if more than one Azure AD app with the same name has been returned
        if (($azureADAppClient).count -eq 1) {
            # Writes a message to console if only one app has been found
            Write-Output ("Azure AD application {0} with ObjectID {1} found." -f $azureAdAppName, $azureADAppClient.ObjectId)
        }
        elseif (($azureADAppClient).count -gt 1) {
            $messageText = $null
            foreach ($a in $apps) {
                $messageText += "App Name: " + $a.DisplayName + " " + "ObjectId: " + $a.ObjectId + "; "
            }
            # Will throw an error if more that one app has been found
            Throw ("Found more than one Azure AD app: {0}. Make sure you have only one Azure AD application with name of {1}" -f $messageText, $azureAdAppName)
        }
        else {
            Throw "Something is wrong! Check if the Azure AD app exists."
        }
    }    
    end {
        return  $azureADAppClient
        Disconnect-AzureAD
    }
}