# Add additional identifierUris to Azure AD app
function New-IdentifierUris {
    param (
        [String] 
        [Parameter(Mandatory)]
        $AADAppName,
        [String]
        [ValidateScript( {[system.uri]::IsWellFormedUriString($_, [System.UriKind]::Absolute)})]
        [Parameter(Mandatory)]
        $URI
    )
    $AzureADApp = Get-AzureADApplication -SearchString $AADAppName
    if ($AzureADApp.IdentifierUris -notcontains $URI) {
        $IdentifierUris = $null
        $IdentifierUris = $AzureADApp.IdentifierUris
        $IdentifierUris.add($URI)
        Set-AzureADApplication -ObjectId $AzureADApp.ObjectId -IdentifierUris $IdentifierUris
    }
    else {
        Write-Output "Replay URI is present"
    }   
}