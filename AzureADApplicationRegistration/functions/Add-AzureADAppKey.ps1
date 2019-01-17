function Add-AzureADAppKey {
    param (
        [String]
        [Parameter(Mandatory)]
        $AADAppName
    )
    # Get AAD App
    $AADAppName = $AADAppName.ToLower() -replace '-', '_'
    $AADApp = Get-AzureADApplication -SearchString $AADAppName

    # Set key's name
    $AADAppKeyIdentifier = Get-Date -Format ddMMyyyyHHmmss    

    # Add AAD password
    $AADAppKey = New-AzureADApplicationPasswordCredential -ObjectId $AADApp.ObjectId -CustomKeyIdentifier $AADAppKeyIdentifier
    $Key = $AADAppKey.Value.ToString()
    return $Key
}