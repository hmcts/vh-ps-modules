#Requires -Version 5.0
#Requires -Module AzureAD
#Requires -Module AzureRM.KeyVault

function Invoke-AzureADApplicationRegistration {
    [CmdletBinding()]
    param (
        [String] 
        [Parameter(Mandatory)]
        $AzureTenantId,
        [String]
        [Parameter(Mandatory)]
        $AzureAdAppId,
        [string]
        [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})] 
        $AzureAdAppCertificateThumbprint,
        [String]
        [Parameter(Mandatory)]
        $AzureSubscriptionId,
        [String]
        [Parameter(Mandatory)]
        $AzureADApplicationName,
        [String]
        [Parameter(Mandatory)]
        $AzureKeyVaultName 
    )

    Invoke-AzureConnection -AzureTenantId $AzureTenantId -AzureAdAppId $AzureAdAppId -AzureAdAppCertificateThumbprint $AzureAdAppCertificateThumbprint -AzureSubscriptionId $AzureSubscriptionId

    $AADRegApp = Add-AzureADApp -AADAppName  $AzureADApplicationName

    Set-VSTSVariables -AADAppAsHashTable $AADRegApp

    if ($AADRegApp.Key) {
        Add-AzureADAppSecret -AzureKeyVaultName $AzureKeyVaultName -AADAppAsHashTable $AADRegApp -AADAppName $AzureADApplicationName
    }
}

function Invoke-AzureConnection {
    [CmdletBinding()]
    param (
        [String] 
        [Parameter(Mandatory)]
        $AzureTenantId,
        [String]
        [Parameter(Mandatory)]
        $AzureAdAppId,
        [string]
        [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})] 
        $AzureAdAppCertificateThumbprint,
        [String]
        [Parameter(Mandatory)]
        $AzureSubscriptionId 
    )
    Connect-AzureAD -TenantId $AzureTenantId -ApplicationId $AzureAdAppId -CertificateThumbprint $AzureAdAppCertificateThumbprint -ErrorAction Stop
    Connect-AzureRmAccount -ServicePrincipal -TenantId $AzureTenantId -ApplicationId $AzureAdAppId  -CertificateThumbprint $AzureAdAppCertificateThumbprint -Subscription $AzureSubscriptionId -ErrorAction Stop
}

function Add-AzureADApp {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [String]
        [Parameter(Mandatory)]
        $AADAppName

    )
    # Add ID and Replay urls
    $AADAppName = $AADAppName.ToLower() -replace '-', '_'
    $AADAppNameForId = $AADAppName.ToLower() -replace '_', '-'
    $AADAppIdentifierUris = "https://" + $AADAppNameForId + ".azurewebsites.net"
    $AADAppReplyUrls = $AADAppIdentifierUris
    # Create empty hash table
    $HashTable = @{}

    # Register Azure AD App
    if ($AADAppName -eq (Get-AzureADApplication -SearchString $AADAppName).DisplayName -and (Get-AzureADApplication -SearchString $AADAppName).IdentifierUris -contains $AADAppIdentifierUris) {
        Write-Verbose "Application $AADAppName found"
        # Get App and App's SP
        $AADApp = Get-AzureADApplication -SearchString $AADAppName
        $AADAppSP = Get-AzureADServicePrincipal -SearchString $AADAppName
        # Add details to hashtable
        $HashTable.Add("AppName", $AADAppNameForId)
        # Add App's ID to hast table
        $HashTable.Add("AppID", $AADApp.AppId)

        # Add AD App's SP to hash table
        $HashTable.Add("AppSPID", $AADAppSP.ObjectId)
    }
    else {
        # Create AAD App
        $AADApp = New-AzureADApplication -DisplayName $AADAppName -IdentifierUris $AADAppIdentifierUris -ReplyUrls $AADAppReplyUrls
        # Add App name to hash table
        $HashTable.Add("AppName", $AADAppNameForId)
        # Add App's ID to hast table
        $HashTable.Add("AppID", $AADApp.AppId)
        
        # Create SP for AAD App
        $AADAppSP = New-AzureADServicePrincipal -AppId $AADApp.AppId
        # Add AD App's SP to hash table
        $HashTable.Add("AppSPID", $AADAppSP.ObjectId)

        # Create key for AAD App
        $AADAppKey = Add-AzureADAppKey -AADAppName $AADAppNameForId
        $HashTable.Add("Key", $AADAppKey)
    }
    return $HashTable
}

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
    #Get-AzureADApplicationPasswordCredential -ObjectId $AADApp.ObjectId

    $Key = $AADAppKey.Value.ToString()
    return $Key
}

function Add-AzureADAppSecret {
    param (
        [String] 
        [Parameter(Mandatory)]
        $AzureKeyVaultName,
        [String] 
        [Parameter(Mandatory)]
        $AADAppName,
        [Parameter(Mandatory)]
        $AADAppAsHashTable
    )
    $AADAppName = $AADAppName.ToLower() -replace '_', '-'
    foreach ($h in $AADAppAsHashTable.GetEnumerator()) {
        if ($AADAppName -ne $h.Value) {
            if ($h.Value -eq (Get-AzureKeyVaultSecret -VaultName $AzureKeyVaultName -Name ($AADAppAsHashTable.AppName + $h.Name)).SecretValueText) {
                Write-Output "Key/Value pair exists"
            }
            else {
                Write-Output ("Adding {0} secret to key vault" -f ($AADAppAsHashTable.AppName + $h.Name))
                $EncryptedSecret = ConvertTo-SecureString -String $h.value -AsPlainText -Force
                Set-AzureKeyVaultSecret -VaultName $AzureKeyVaultName -Name ($AADAppAsHashTable.AppName + $h.Name) -SecretValue $EncryptedSecret
            }

        }
    }
}

function Set-VSTSVariables {
    param (
        [Parameter(Mandatory)]
        $AADAppAsHashTable
    )
    foreach ($h in $AADAppAsHashTable.GetEnumerator()) {
        Write-Output ("##vso[task.setvariable variable={0};]{1}" -f ($AADAppAsHashTable.AppName + $h.Name), $h.Value) 
    }    
}


Export-ModuleMember -Function 'Invoke-AzureADApplicationRegistration'