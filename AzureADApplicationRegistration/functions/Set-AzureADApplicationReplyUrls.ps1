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