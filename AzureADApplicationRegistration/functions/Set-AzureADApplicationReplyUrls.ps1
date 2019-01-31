function Set-AzureADApplicationReplyUrls {
    [CmdletBinding()]
    param (
        [String] 
        [Parameter(Mandatory)]
        [Alias("AzureTenantIdSecondary")]
        $AzureTenantId,
        [String]
        [Parameter(Mandatory)]
        [Alias("AzureAdAppIdSecondary")]
        $AzureAdAppId,
        [string]
        [Parameter(Mandatory)]
        [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})]
        [Alias("AzureAdAppCertificateThumbprintSecondary")]
        $AzureAdAppCertificateThumbprint,
        [String]
        [Parameter(Mandatory)]
        $AADAppName,
        [String]
        [Parameter(Mandatory)]
        $AADAppReplyUrls
    )

    Invoke-AzureADConnection -AzureTenantId $AzureTenantId -AzureAdAppId $AzureAdAppId -AzureAdAppCertificateThumbprint $AzureAdAppCertificateThumbprint
    # Format app name
    $AADAppName = Format-AppName -AADAppName $AADAppName
    
    # Cleanup reply urls and create array
    [string]$AADAppReplyUrlsNoSpace = $AADAppReplyUrls -replace " ", ""
    [array]$AADAppReplyUrls = $AADAppReplyUrlsNoSpace.Split(",")

    # Get amd existing app
    $ExistingAADApp = Get-AzureADApplication -SearchString $AADAppName | where DisplayName -EQ $AADAppName


    if ($null -eq $ExistingAADApp) {
        Write-Error ("Unable to find app {0}. Check if you are connected to the correct AAD tenant." -f $AADAppName) -ErrorAction Stop
    }

    # Add existing Replay URLs to array
    $ExistingReplyURLS = $ExistingAADApp.ReplyUrls

    # Filter out existing URLs
    foreach ($AADAppReplyUrl in $AADAppReplyUrls) {
        if ($existingReplyURLS -contains $AADAppReplyUrl) {
            Write-Host ("Replay URL {0} already has been set" -f $AADAppReplyUrl)
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