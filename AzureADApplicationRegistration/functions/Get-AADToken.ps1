Function Get-AADToken {
    [CmdletBinding()]
    [OutputType([string])]
    param (
      [Parameter(Position=0,Mandatory=$true)]
      [ValidateScript({
            try 
            {
              [System.Guid]::Parse($_) | Out-Null
              $true
            } 
            catch 
            {
              $false
            }
      })]
      [String]
      [Alias("AzureTenantIdSecondary")]
      $AzureTenantId,
      [String]
      [Alias("AzureAdAppIdSecondary")]
      [Parameter(Mandatory)]
      $AzureAdAppId,
      [string]
      [Alias("AzureAdAppCertificateThumbprintSecondary")]
      [ValidateScript( {Test-Path ("Cert:\LocalMachine\My\" + "$_")})] 
      $AzureAdAppCertificateThumbprint
    )
    begin {
      $Token = $null
      # Get the certificate form local certificate store that will e used to authenticate with Service Principal
      Write-Output "Trying to get cert from cert:\LocalMachine\My\$($AzureAdAppCertificateThumbprint)"
      If ($AzureAdAppCertificateThumbprint) {
        $sPCertificate = (Get-ChildItem -Path "cert:\LocalMachine\My\$($AzureAdAppCertificateThumbprint)")
        }
      # Set Authority to Azure AD Tenant
      $authority = ('https://login.windows.net/' + $AzureTenantId)
      # Resource App ID of the app that the bearer token is issued for
      $resourceAppIdURI = 'https://graph.windows.net/'

      # Import identity assembly
      Add-Type -Path ($env:ProgramFiles + "\WindowsPowerShell\Modules\AzureAD\*\Microsoft.IdentityModel.Clients.ActiveDirectory.dll")

    }
    process {
      Write-Output "Trying to get cert from cert:\LocalMachine\My\$($AzureAdAppCertificateThumbprint)"
      Write-Output ( "cert subject" -f $sPCertificat.subject)

      Try {
        $ClientCred = [Microsoft.IdentityModel.Clients.ActiveDirectory.ClientAssertionCertificate]::new($AzureAdAppId, $sPCertificate)
        $authContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($authority)
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $ClientCred)
        $Token = $authResult.Result.CreateAuthorizationHeader()
      }
      Catch {
        Throw $_
        $ErrorMessage = 'Failed to aquire Azure AD token.'
        Write-Error -Message 'Failed to aquire Azure AD token'
      }
    }
    end {
      return $Token
    }
  }