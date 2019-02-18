

## construct variables
$propertyList = "ClientId", "ClientSecret"

$appNames = "vh-hearings-api"
$environment = "test2"

$appResourceGroupName = $appNames + "-" + $environment

#$sourceKeyVaultName = "vcoreinfra"
$destinationKeyVaultName = "vhcoreinfraht" + $environment

$coreResourceGroupName = "vh-core-infra-" + $environment

$realSourceKeyVaultName = ($appNames + $environment).Replace("-", "").Replace("_", "")


# connect to az subscription
if ($environment -eq "pilot") {
    
    Select-AzureRmSubscription 4bb049c8-33f3-4860-91b4-9ee45375cc18
}else {
    Select-AzureRmSubscription 705b2731-0e0b-4df7-8630-95f157f0a347
}

## Set permissions on key vaults
Set-AzureRmKeyVaultAccessPolicy -VaultName $realSourceKeyVaultName -ResourceGroupName $appResourceGroupName -UserPrincipalName janis.berzins@hmcts.net -PermissionsToSecrets set, get, list
Set-AzureRmKeyVaultAccessPolicy -VaultName $destinationKeyVaultName -ResourceGroupName $coreResourceGroupName -UserPrincipalName janis.berzins@hmcts.net -PermissionsToSecrets set, get, list

## read and push key vault secrets from source (app ) key vault to core HT key vault
foreach ($property in $propertyList) {

    $secret = Get-AzureKeyVaultSecret -VaultName $realSourceKeyVaultName -Name $property
    $Secret = ConvertTo-SecureString -String $secret.SecretValueText -AsPlainText -Force

    if ($property -eq "ClientId" ) {
        $newPropertyName = "-appid"
    }
    else {
        $newPropertyName = "-key"
    }

    $realSecretName = $appNames + $newPropertyName

    Set-AzureKeyVaultSecret -VaultName $destinationKeyVaultName -Name $realSecretName -SecretValue $Secret

}


## add app uri id to core HT key vault, get the uri id from HT tenant

$realAppName = ($appNames + "_" + $environment).Replace("-", "_")
$realSecretName = ($appNames.Replace("_", "-") + "-" + "IdentifierUris").ToLower()

$aadApp = Get-AzureADApplication -SearchString $realAppName | where DisplayName -EQ $realAppName

$uriID = $aadApp.IdentifierUris[0]
$Secret = ConvertTo-SecureString -String $uriID -AsPlainText -Force
Set-AzureKeyVaultSecret -VaultName $destinationKeyVaultName -Name $realSecretName -SecretValue $Secret

## add app name to the key vault as secret

$Secret = ConvertTo-SecureString -String ($appNames + "-" + $environment) -AsPlainText -Force
Set-AzureKeyVaultSecret -VaultName $destinationKeyVaultName -Name ($appNames + "-appname") -SecretValue $Secret













# if ("ClientId" -eq "ClientId" ) {$newPropertyName = "-appid"} else {$newPropertyName = "-key"}

# Get-AzureKeyVaultSecret -VaultName $realSourceKeyVaultName -Name

# if (condition) {
    
# }

# Set-AzureKeyVaultSecret -VaultName $realKeyVaultName -Name $realSecretName -SecretValue $Secret



# $realAppName = ($appName + "_" + $environment).Replace("-", "_")
# $realSecretName = $appName.Replace("_", "-") + "-" + "IdentifierUris"

# $aadApp = Get-AzureADApplication -SearchString $realAppName | where DisplayName -EQ $realAppName
# $Secret = ConvertTo-SecureString -String ($aadApp.IdentifierUris[0]) -AsPlainText -Force
