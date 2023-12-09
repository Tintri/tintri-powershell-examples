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
  This script demonstrates configurtion of notification-alert policies and thresholds.
  
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
Disconnect-TintriServer -all -ea SilentlyContinue | Out-Null
($srv1 = Connect-TintriServer -Server $tsvr1_name -UserName $tsvr1_username -Password $tsvr1_password -wa:SilentlyContinue) | fl

Write-Output ">>> Connect to second tintri server $second_tsvr_name.`n"
($svr2 = Connect-TintriServer -Server $tsvr2_name -UserName $tsvr2_username -Password $tsvr2_password -wa:SilentlyContinue) | fl



write-output "--------------------------------------------------------------------------"
write-output ">>> Create new notification policies"
write-output "--------------------------------------------------------------------------"

Get-TintriServerSession -all | Get-TintriNotifyPolicy | Remove-TintriNotifyPolicy  -confirm:$false -ea SilentlyContinue | Out-Null
($np = New-TintriNotifyPolicy -Name policy1 -Description policy1-description -alertid LOG-ARPING-0001,LOG-FREESPACE-0001 -NotificationEnable) | fl 
($np2 = New-TintriNotifyPolicy -Name policy2 -Description policy2-description -alertid LOG-HYPERV-0035 -NotificationEnable -EmailNotification -SnmpTrapEnable) | fl 
($np3 = New-TintriNotifyPolicy -svrHost $tsvr2_name -Name policy3 -Description policy3-description -alertid LOG-SMB-2112) | fl 

write-output "--------------------------------------------------------------------------"
write-output ">>> Get notificaiton policies by AlertIds(all servers), by policy object, and by UUID"
write-output "--------------------------------------------------------------------------"

Get-TintriNotifyPolicy -SearchAllTintriServers -alertid LOG-ARPING-0001,LOG-FREESPACE-0001,LOG-SMB-2112
$np | Get-TintriNotifyPolicy
Get-TintriNotifyPolicy -Uuid $np.Uuid.UuId -TintriServer $svr2

write-output "--------------------------------------------------------------------------"
write-output ">>> Remove notification policy by AlertId, by notify object, and by UUID"
write-output "--------------------------------------------------------------------------"

Remove-TintriNotifyPolicy -alertid LOG-ARPING-0001,LOG-FREESPACE-0001 -confirm:$false
$np2 | Remove-TintriNotifyPolicy -confirm:$false
$svr2 | Remove-TintriNotifyPolicy -Uuid $np3.Uuid.Uuid -confirm:$false


write-output "--------------------------------------------------------------------------"
write-output ">>> Manage multiple servers, set the same policy on each server"
write-output "--------------------------------------------------------------------------"

$npTemplate = New-TintriNotifyPolicy -Name policyMaster -Description policyMaster-description -alertid LOG-ARPING-0001,LOG-FREESPACE-0001,LOG-CERT-0002 -NotificationEnable
foreach ($svr in Get-TintriServerSession -all)
{
	Get-TintriNotifyPolicy -TintriServer $svr | Remove-TintriNotifyPolicy -TintriServer $svr -confirm:$false -ea SilentlyContinue | Out-Null
	$npTemplate | New-TintriNotifyPolicy -TintriServer $svr | fl
}



write-output "--------------------------------------------------------------------------"
write-output ">>> Set alert thresholds, by type, and by threshold"
write-output "--------------------------------------------------------------------------"

Set-TintriAlertThreshold -ThresholdType UsedPercentAlertLowThreshold -Value 80
$thold = Get-TintriAlertThreshold -ThresholdType ReservesUsedPercentAlertThreshold
$thold.Value = 50
$thold | Set-TintriAlertThreshold
 

write-output "--------------------------------------------------------------------------"
write-output ">>> Get alert thresholds, by type, and by threshold"
write-output "--------------------------------------------------------------------------"

Get-TintriAlertThreshold -ThresholdType UsedPercentAlertLowThreshold
$thold | Get-TintriAlertThreshold
Get-TintriAlertThreshold -Threshold $thold

write-output "--------------------------------------------------------------------------"
write-output ">>> Clear alert thresholds to their default values"
write-output "--------------------------------------------------------------------------"

Clear-TintriAlertThreshold -ThresholdType UsedPercentAlertLowThreshold
Clear-TintriAlertThreshold -Threshold $thold

write-output "--------------------------------------------------------------------------"
write-output ">>> Manage mutlple servers with a template threshold"
write-output "--------------------------------------------------------------------------"

$tholdTemplate = Set-TintriAlertThreshold -ThresholdType UsedPercentAlertLowThreshold -Value 75
Get-TintriServerSession -all | Clear-TintriAlertThreshold -Threshold $tholdTemplate
Get-TintriServerSession -all | Set-TintriAlertThreshold -Threshold $tholdTemplate


