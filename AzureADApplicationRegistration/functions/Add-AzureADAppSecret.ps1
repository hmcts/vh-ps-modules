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
        Write-Output ("Adding {0} secret to key vault" -f ($FullAppName + $h.Name))
        $EncryptedSecret = ConvertTo-SecureString -String $h.value -AsPlainText -Force
        Set-AzureKeyVaultSecret -VaultName $AzureKeyVaultName -Name ($FullAppName + $h.Name) -SecretValue $EncryptedSecret | Out-Null
    }
}