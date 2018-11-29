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
        $HashTable.Add("AppSPObjectID", $AADAppSP.ObjectId)
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
        $HashTable.Add("AppSPObjectID", $AADAppSP.ObjectId)

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
        $FullAppName = Remove-EnvFromString -StringWithEnv $AADAppAsHashTable.AppName
        if ($h.Value -eq (Get-AzureKeyVaultSecret -VaultName $AzureKeyVaultName -Name ($FullAppName + $h.Name)).SecretValueText) {
            Write-Output "Key/Value pair exists"
        }
        else {
            Write-Output ("Adding {0} secret to key vault" -f ($FullAppName + $h.Name))
            $EncryptedSecret = ConvertTo-SecureString -String $h.value -AsPlainText -Force
            Set-AzureKeyVaultSecret -VaultName $AzureKeyVaultName -Name ($FullAppName + $h.Name) -SecretValue $EncryptedSecret
        }
    }
}

function Set-VSTSVariables {
    param (
        [Parameter(Mandatory)]
        $AADAppAsHashTable
    )
    foreach ($h in $AADAppAsHashTable.GetEnumerator()) {
        $FullAppName = Remove-EnvFromString -StringWithEnv $AADAppAsHashTable.AppName
        Write-Output ("##vso[task.setvariable variable={0};]{1}" -f ($FullAppName + $h.Name), $h.Value)
        Write-Output ("Created variable for {0}" -f ($FullAppName + $h.Name))
    }    
}

function Remove-EnvFromString {
    param (
        [String] 
        [Parameter(Mandatory)]
        $StringWithEnv
    )
    $EnvToBeRemoved = $StringWithEnv.Split("-")[-1]
    $FullAppName = $StringWithEnv -replace "$EnvToBeRemoved", ""
    return $FullAppName

}

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

# Function to connect to Azure AD using certificate (private key) stored in VM's certificate store
function Invoke-AzureADConnection {
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
}


function Format-AppName {
    [CmdletBinding()]
    param (
        [String]
        [Parameter(Mandatory)]
        $AADAppName
    )
    
    begin {
    }
    
    process {
        $AADAppName = $AADAppName.ToLower() -replace '-', '_'
    }
    
    end {
        return $AADAppName
    }
}


function Set-AzureADApplicationReplyUrls {
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
        $AADAppName,
        [String]
        [Parameter(Mandatory)]
        $AADAppReplyUrls 
    )

    Connect-AzureAD -TenantId $AzureTenantId -ApplicationId $AzureAdAppId -CertificateThumbprint $AzureAdAppCertificateThumbprint -ErrorAction Stop
    # Format app name
    $AADAppName = Format-AppName -AADAppName $AADAppName
    
    # Cleanup reply urls and create array
    [string]$AADAppReplyUrlsNoSpace = $AADAppReplyUrls -replace " ", ""
    [array]$AADAppReplyUrls = $AADAppReplyUrlsNoSpace.Split(",")

    # Get amd existing app
    $ExistingAADApp = Get-AzureADApplication -SearchString $AADAppName

    # Add existing Replay URLs to array
    $ExistingReplyURLS = $ExistingAADApp.ReplyUrls

    # Filter out existing URLs
    foreach ($AADAppReplyUrl in $AADAppReplyUrls) {
        if ($existingReplyURLS -contains $AADAppReplyUrl) {
            Write-Host ("Replay URL {0} arleady ahs been set" -f $AADAppReplyUrl)
        }
        else {
            Write-Host ("Adding new reply URL {0}" -f $AADAppReplyUrl)
            $existingReplyURLS.add($AADAppReplyUrl)
        } 
    }

    # Check if there are new urls to set 
    if ($AADAppReplyUrls -le 1 ) {
        Write-Host "No reply URLs provided..."
    }
    else {
        Set-AzureADApplication -ObjectId $ExistingAADApp.ObjectId -ReplyUrls $ExistingReplyURLS 
    }
}

Export-ModuleMember -Function 'Invoke-AzureADApplicationRegistration', 'Invoke-AzureConnection', 'Set-AzureADResourceAccess', 'New-IdentifierUris', 'Set-AzureADApplicationReplyUrls'
