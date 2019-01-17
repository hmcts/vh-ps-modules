function Remove-EnvFromString {
    param (
        [String] 
        [Parameter(Mandatory)]
        $StringWithEnv
    )
    $EnvToBeRemoved = $StringWithEnv.Split("-")[-1]
    $FullAppName = $StringWithEnv -replace "$EnvToBeRemoved", ""
    return $FullAppName

}