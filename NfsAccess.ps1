<#
The MIT License (MIT)

Copyright © 2023 Tintri by DDN, Inc. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

<#
  This script demonstrates configurtion of NFS access on vmstore shares.
  
  The code example/script provided here is for reference only to illustrate
  sample workflows and may not be appropriate for use in actual operating
  environments. 
#> 
Param(
  [string] $tsvr1_name,     # source tintri server (e.g. ts814.acme.com )
  [string] $tsvr1_username, #  source tintri server web user (e.g. admin)
  [string] $tsvr1_password, #  source tintri server password (e.g. Passw0rd!)
  [string] $tsvr2_name,     # second tintri server (e.g. ts882.acme.com )
  [string] $tsvr2_username, #  second tintri server web user (e.g. admin)
  [string] $tsvr2_password  #  second tintri server password (e.g. Passw0rd!)
)

write-output "--------------------------------------------------------------------------"
write-output ">>> Input parameters"
write-output "--------------------------------------------------------------------------"

write-output "Tintri Servers src:$tsvr1_name second:$tsvr2_name"


write-output "--------------------------------------------------------------------------"
write-output ">>> Connect to Tintri storage servers"
write-output "--------------------------------------------------------------------------"

Write-Output ">>> Import the Tintri Powershell Toolkit module.`n"
if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


Write-Output ">>> Connect to initial tintri server $source_tsvr_name"
disconnect-TintriServer -all -ea SilentlyContinue | out-null
($srv1 = Connect-TintriServer -Server $tsvr1_name -UserName $tsvr1_username -Password $tsvr1_password -wa:SilentlyContinue) | fl

Write-Output ">>> Connect to second tintri server $second_tsvr_name.`n"
($svr2 = Connect-TintriServer -Server $tsvr2_name -UserName $tsvr2_username -Password $tsvr2_password -wa:SilentlyContinue) | fl



write-output "--------------------------------------------------------------------------"
write-output ">>> Set specific access with multiple NFS mount points at once"
write-output "--------------------------------------------------------------------------"

Set-TintriDatastoreNfsAccess -svr $srv1 -ClientIpHigh 172.255.255.255,200.200.100.252,172.255.255.255 -ClientIpLow 172.0.0.0,10.0.0.0,172.0.0.0 `
          -UseAllVmstoreDataIps -SubMount /tintri,/tintri,/tintri/dssub-nfs100
Get-TintriDatastoreNfsAccess -svr $srv1  | select IsEnabled -expand Configs | fl


write-output "--------------------------------------------------------------------------"
write-output ">>> Reconfigure access on existing datastore IP range"
write-output "--------------------------------------------------------------------------"

$ds = Get-TintriDatastore -TintriServer $srv1
$ds.NfsAccesses.Configs[0].ClientIpHigh = "200.200.100.252"
$ds | Set-TintriDatastoreNfsAccess
Get-TintriDatastoreNfsAccess -svr $srv1  | select IsEnabled -expand Configs | fl


write-output "--------------------------------------------------------------------------"
write-output ">>> Add specific NFS access"
write-output "--------------------------------------------------------------------------"

Set-TintriDatastoreNfsAccess -AccessTask Add -ClientIpHigh 10.205.82.254 -ClientIpLow 10.205.82.100 -UseAllVmstoreDataIps -SubMount /tintri
Get-TintriDatastoreNfsAccess | select IsEnabled -expand Configs | fl


write-output "--------------------------------------------------------------------------"
write-output ">>> Remove specific NFS access"
write-output "--------------------------------------------------------------------------"

$n = Set-TintriDatastoreNfsAccess -AccessTask Remove -ClientIpHigh 10.205.82.254,200.200.100.252 -ClientIpLow 10.205.82.100,10.0.0.0  `
                    -VmstoreIpHigh 255.255.255.255,255.255.255.255  -VmstoreIpLow 0.0.0.0,0.0.0.0  -SubMount /tintri,/tintri
Get-TintriDatastoreNfsAccess | select IsEnabled -expand Configs | fl


write-output "--------------------------------------------------------------------------"
write-output ">>> Mangage NFS access on multiple servers (using first server as a NFS access template)"
write-output "--------------------------------------------------------------------------"

$nfsTemplate = Set-TintriDatastoreNfsAccess -svr $srv1 -ClientIpHigh 172.255.255.255,200.200.100.252,172.255.255.255 -ClientIpLow 172.0.0.0,10.0.0.0,172.0.0.0 `
          -UseAllVmstoreDataIps -SubMount /tintri,/tintri,/tintri/dssub-nfs100

Get-TintriServerSession -all | Set-TintriDatastoreNfsAccess -NfsAccess $nfsTemplate
Get-TintriDatastoreNfsAccess -SearchAllTintriServers  | select ApplianceHostName,IsEnabled -expand Configs | select ApplianceHostName,IsEnabled,Submount,ClientIpLow,ClientIpHigh,VmstoreIpLow,VmstoreIpHigh | ft

write-output "--------------------------------------------------------------------------"
write-output ">>> Disable specific IP range NFS access on each server (i.e. allow all IPs to access)"
write-output "--------------------------------------------------------------------------"

foreach ($svr in Get-TintriServerSession -all)
{
	Set-TintriDatastoreNfsAccess -TintriServer $svr -NfsIpAccessEnabled $false | out-null
}
Get-TintriDatastoreNfsAccess -SearchAllTintriServers | fl 



