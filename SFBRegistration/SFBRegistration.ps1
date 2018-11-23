$SFBUserName = ""
$AADAppName = ""
$AADAppID = ""
$SIPAddress = ""

$SkyepSession = New-CsOnlineSession -UserName $SFBUserName

Import-PSSession $SkyepSession

New-CsOnlineApplicationEndpoint -Uri $SIPAddress -ApplicationId $AADAppID -Name $AADAppName
