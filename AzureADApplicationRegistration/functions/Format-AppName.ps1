function Format-AppName {
    [CmdletBinding()]
    param (
        [String]
        [Parameter(Mandatory)]
        $AADAppName
    )
    
    begin {
    }
    
    process {
        $AADAppName = $AADAppName.ToLower() -replace '-', '_'
    }
    
    end {
        return $AADAppName
    }
}
