
$appNames = "website","client"
$keyVaultName = "vcoreinfra"
$environments =  "pilot"

foreach ($environment in $environments)
{
    
    $resourceGroupName = "vh-core-infra-" + $environment
    $realKeyVaultName = ($keyVaultName + $environment).Replace("-","").Replace("_","")

    Set-AzureRmKeyVaultAccessPolicy -VaultName $realKeyVaultName -ResourceGroupName $resourceGroupName -UserPrincipalName janis.berzins@hmcts.net -PermissionsToSecrets set, get, list

    foreach ($appName in $appNames)
    {
        $realAppName = ($appName + "_" + $environment).Replace("-","_")
        $realSecretName = $appName.Replace("_","-") + "-" + "IdentifierUris"

        $aadApp = Get-AzureADApplication -SearchString $realAppName | where DisplayName -EQ $realAppName
        $Secret = ConvertTo-SecureString -String ($aadApp.IdentifierUris[0]) -AsPlainText -Force
        Set-AzureKeyVaultSecret -VaultName $realKeyVaultName -Name $realSecretName -SecretValue $Secret

    }
}
