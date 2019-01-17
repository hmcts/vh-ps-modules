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
        $AzureKeyVaultName,
        [String]
        $identifierUrisPrefix = "hearings.reform.hmcts.net/",
        [Parameter()]
        [string]
        [switch]
        $AzureTenantIdSecondary,
        [Parameter()]
        [string]
        [switch]
        $AzureAdAppIdSecondary,
        [string]
        [switch]
        [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})] 
        $AzureAdAppCertificateThumbprintSecondary
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
    $AADAppIdentifierUris = "https://" + $identifierUrisPrefix + (([Guid]::NewGuid()).guid)
    $AADAppReplyUrls = $AADAppIdentifierUris
    # Create empty hash table
    $HashTable = @{}

    # Register Azure AD App
    if ($AADAppName -eq (Get-AzureADApplication -SearchString $AADAppName).DisplayName -and (Get-AzureADApplication -SearchString $AADAppName).IdentifierUris -contains $AADAppIdentifierUris) {
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
