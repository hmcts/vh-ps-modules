function Invoke-PSCodeAnalyzer {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        try {
            Write-Verbose -Message "Importing AzureAD module"
            Install-Module -Name PSScriptAnalyzer
        }
        Catch {
            Write-Verbose -Message "Trying to install AzureAD module"
            Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force 
            Import-Module -Name PSScriptAnalyzer -Force
        }

       $PSScripts = (Get-ChildItem -Recurse -Path .\ -Include "*.ps1", "*.psm1").FullName
    }
    
    process {
        foreach($PSSCript in $PSScripts){
            Invoke-ScriptAnalyzer -Path $PSSCript

        }

        

    }
    
    end {
    }
}

Export-ModuleMember -Function 'Invoke-PSCodeAnalyzer'