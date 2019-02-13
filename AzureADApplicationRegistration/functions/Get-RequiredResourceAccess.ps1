function Get-RequiredResourceAccess {
    [CmdletBinding()]
    param (
        [String] 
        [Parameter(Mandatory)]
        $AppName
    )

    # Get the app registration by name
    $Application = Get-AzureADApplication -SearchString $AppName
    $ResourceAccess = $Application.RequiredResourceAccess

    # Create a new list for the output since the output has different properties than the source objects
    $ResultResourceList = @()
    foreach ($Resource in $ResourceAccess) {
        # Find the resource that we require access to
        $ResourceObj = Get-AzureADServicePrincipal -All $true | Where-Object AppId -eq $Resource.ResourceAppId | Select-Object -first 1 -Property AppDisplayName, Oauth2Permissions
        $ResultResourceObject = New-Object PSObject
        $ResultResourceObject | Add-Member -NotePropertyName ResourceAppName -NotePropertyValue $ResourceObj.AppDisplayName
        $ResultResourceObject | Add-Member -NotePropertyName ResourceAppId -NotePropertyValue $ResourceObj.ResourceAppId

        $ResultResourceAccesses = @()
        foreach ($RequiredResource in $Resource.ResourceAccess) {
            # For each required permission, find the permission object and get the name of it
            $Permission = $ResourceObj.Oauth2Permissions | Where-Object Id -eq $RequiredResource.Id | Select-Object -first 1
            $NewResourceAccessObj = New-Object PsObject
            $NewResourceAccessObj | Add-Member -NotePropertyName "ResourceAccessName" -NotePropertyValue $Permission.AdminConsentDisplayName
            $NewResourceAccessObj | Add-Member -NotePropertyName "Id" -NotePropertyValue $RequiredResource.Id
            $NewResourceAccessObj | Add-Member -NotePropertyName "Type" -NotePropertyValue $RequiredResource.Type
            $ResultResourceAccesses += $NewResourceAccessObj
        }
        $ResultResourceObject | Add-Member -NotePropertyName ResourceAccess -NotePropertyValue $ResultResourceAccesses
        $ResultResourceList += $ResultResourceObject
    }

    return $ResultResourceList
}