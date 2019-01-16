
. .\secrets.ps1

Param(
   [string]$vstsAccount = "hmctsreform",
   [string]$projectName = "VirtualHearings",
   [string]$user = "PAT",
   [string]$token = ""
)

Write-Verbose "Parameter Values"
foreach($key in $PSBoundParameters.Keys)
{
     Write-Verbose ("  $($key)" + ' = ' + $PSBoundParameters[$key])
}
 
# Base64-encodes the Personal Access Token (PAT) appropriately
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
 
# Construct the REST URL to obtain Release Definition
$baseUri = "https://vsrm.dev.azure.com/$($vstsAccount)/$($projectName)/_apis"
 
# Invoke the REST call and capture the results
$result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}


function Get-ADOReleaseDefinitions
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        [string]$resource = "/release/definitions/?api-version=5.0"
    )

    Begin
    {
    $uri = $baseUri + $resource
    }
    Process
    {
    Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
    }
    End
    {
    $result.value.name
    }
}

#$result = Get-ADOReleaseDefinitions
#$result.value.name



function Get-ADOReleaseDefinition
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        [string]$resource,
        [string]$definitionId = "24"
    )

    Begin
    {
    $uri = $baseUri + "/release/definitions/$($definitionId)?api-version=5.1-preview.3"
    }
    Process
    {
    Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
    }
    End
    {
    $result.value.name
    }
}


$result = Get-ADOReleaseDefinition

$Environments =  $result.environments

$Environments.name

$Environments.deployPhases.workflowTasks | where $Environments.name -EQ Test