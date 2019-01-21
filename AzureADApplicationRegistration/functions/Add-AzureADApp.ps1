function Add-AzureADApp {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [String]
        [Parameter(Mandatory)]
        $AADAppName,
        [String]
        $identifierUrisPrefix,
        [String]
        [Parameter(Mandatory)]
        $AzureKeyVaultName

    )
    # Add ID and Replay urls
    $AADAppName = $AADAppName.ToLower() -replace '-', '_'
    $AADAppNameForId = $AADAppName.ToLower() -replace '_', '-'
    $AADAppIdentifierUris = "https://" + $identifierUrisPrefix + (([Guid]::NewGuid()).guid)
    $AADAppReplyUrls = $AADAppIdentifierUris
    # Create empty hash table
    $HashTable = @{}

    ## Register Azure AD App
    # Check if the app already exists by comparing name and app ID URI stored in Azure Key vault.
    if ($AADAppName -eq (Get-AzureADApplication -SearchString $AADAppName).DisplayName `
     -and (Get-AzureADApplication -SearchString $AADAppName).IdentifierUris `
     -contains (Get-AzureKeyVaultSecret -VaultName $AzureKeyVaultName `
     -Name ((Remove-EnvFromString -StringWithEnv $AADAppNameForId) + "IdentifierUris") -ErrorAction Stop).SecretValueText) {
        Write-Verbose "Application $AADAppName found"
        # Get App and App's SP
        $AADApp = Get-AzureADApplication -SearchString $AADAppName
        $AADAppSP = Get-AzureADServicePrincipal -SearchString $AADAppName
        # Add details to hash table
        $HashTable.Add("AppName", $AADAppNameForId)
        # Add App's ID to hash table
        $HashTable.Add("AppID", $AADApp.AppId)
        # Add App's IdentifierUris to hash table
        $HashTable.Add("IdentifierUris", $AADApp.IdentifierUris[0])
        # Add AD App's SP to hash table
        $HashTable.Add("AppSPObjectID", $AADAppSP.ObjectId)
    }
    else {
        # Create AAD App
        $AADApp = New-AzureADApplication -DisplayName $AADAppName -IdentifierUris $AADAppIdentifierUris -ReplyUrls $AADAppReplyUrls
        # Add App name to hash table
        $HashTable.Add("AppName", $AADAppNameForId)
        # Add App's ID to hast table
        $HashTable.Add("AppID", $AADApp.AppId)
        # Add App's IdentifierUris to hash table
        $HashTable.Add("IdentifierUris", $AADApp.IdentifierUris[0])
        # Create SP for AAD App
        $AADAppSP = New-AzureADServicePrincipal -AppId $AADApp.AppId
        # Add AD App's SP to hash table
        $HashTable.Add("AppSPObjectID", $AADAppSP.ObjectId)
        # Create key for AAD App
        $AADAppKey = Add-AzureADAppKey -AADAppName $AADAppNameForId
        $HashTable.Add("Key", $AADAppKey)
    }
    return $HashTable
}