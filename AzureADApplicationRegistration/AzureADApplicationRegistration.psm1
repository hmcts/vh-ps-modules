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

#Export-ModuleMember -Function 'Invoke-AzureADApplicationRegistration', 'Invoke-AzureConnection', 'Set-AzureADResourceAccess', 'New-IdentifierUris', 'Set-AzureADApplicationReplyUrls'
