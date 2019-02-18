# Example usage
#  Get-RequiredResourceAccess -AppName vh_book_hearing_client_preview | ConvertTo-Json -Depth 4
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
        $ResultResourceObject | Add-Member -NotePropertyName "resourceAppName" -NotePropertyValue $ResourceObj.AppDisplayName
        $ResultResourceObject | Add-Member -NotePropertyName "resourceAppId" -NotePropertyValue $Resource.ResourceAppId

        $ResultResourceAccesses = @()
        foreach ($RequiredResource in $Resource.ResourceAccess) {
            # For each required permission, find the permission object and get the name of it
            $Permission = $ResourceObj.Oauth2Permissions | Where-Object Id -eq $RequiredResource.Id | Select-Object -first 1
            $NewResourceAccessObj = New-Object PsObject
            $NewResourceAccessObj | Add-Member -NotePropertyName "resourceAccessName" -NotePropertyValue $Permission.AdminConsentDisplayName
            $NewResourceAccessObj | Add-Member -NotePropertyName "id" -NotePropertyValue $RequiredResource.Id
            $NewResourceAccessObj | Add-Member -NotePropertyName "type" -NotePropertyValue $RequiredResource.Type
            $ResultResourceAccesses += $NewResourceAccessObj
        }
        $ResultResourceObject | Add-Member -NotePropertyName "resourceAccess" -NotePropertyValue $ResultResourceAccesses
        $ResultResourceList += $ResultResourceObject
    }

    $Result = New-Object PSObject
    $Result | Add-Member -NotePropertyName "requiredResourceAccess" -NotePropertyValue $ResultResourceList
    return $Result
}