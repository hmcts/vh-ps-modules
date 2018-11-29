$WebSiteName = "vh-website"
$AzureAppServiceWebSiteDomainName = ".azurewebsites.ne"
$CNAME = $WebSiteName + $AzureAppServiceWebSiteDomainName
$AzureResourceGroupName = "vh-hearings-reform-hmcts-net-dns-zone"
$AzureDNSZoneName = "hearings.reform.hmcts.net"

Write-Host ("Searching for {0} with a CNAME of {1} in DNS Zone {2}" -f $WebSiteName, $CNAME, $AzureDNSZoneName)
$AzureDNSRecordResult = Get-AzureRmDnsRecordSet -Name $WebSiteName -ZoneName $AzureDNSZoneName  -ResourceGroupName $AzureResourceGroupName -RecordType CNAME -ErrorAction Continue

if ($null -eq $AzureDNSRecordResult) {
    Write-Host "Creating new CNAME record"
    $Records = @()
    $Records += New-AzureRmDnsRecordConfig -Cname $CNAME
    New-AzureRmDnsRecordSet -Name $WebSiteName -RecordType CNAME -ResourceGroupName $AzureResourceGroupName -TTL 3600 -ZoneName $AzureDNSZoneName -DnsRecords $Records
}
elseif ($WebSiteName -ne $AzureDNSRecordResult.Name) {
    Write-Host "Updateing CNAME record"
    $RecordSet = Set-AzureRmDnsRecordSet -ResourceGroupName $AzureResourceGroupName -ZoneName $AzureDNSZoneName -Name $WebSiteName -RecordType CNAME
    Set-AzureRmDnsRecordSet -RecordSet $RecordSet
}
else {
    Write-Host "CNAME record already exists."
}
