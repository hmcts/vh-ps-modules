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