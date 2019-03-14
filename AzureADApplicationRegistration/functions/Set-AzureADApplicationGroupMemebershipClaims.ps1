function Set-AzureADApplicationGroupMemebershipClaims {
    [CmdletBinding()]
    param (
        [String] 
        [Parameter(Mandatory)]
        [Alias("AzureADApplicationName")]
        $AzureAdAppName,

        [String] 
        [Parameter(Mandatory)]
        [ValidateSet('SecurityGroup','All')]
        $GroupMembershipClaims
    )
    
    begin {
        # Change the app name with '_'
        $azureAdAppName = Format-AppName -AADAppName $azureAdAppName

        # Search for an existing AAD app
        $azureADAppClient = Search-AzureADApp -azureAdAppName $azureAdAppName
    }
    
    process {
        # Sets group membership claims for Azure AD Application
        Set-AzureADApplication -ObjectId $azureADAppClient.ObjectID -GroupMembershipClaims $groupMembershipClaims
    }    
    end {
        Write-Output ("Group membership claims for {0} set to {1}" -f $azureADAppClient.DisplayName,$groupMembershipClaims)
        Disconnect-AzureAD
    }
}