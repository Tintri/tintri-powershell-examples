<#
The MIT License (MIT)

Copyright © 2022 Tintri by DDN, Inc. All rights reserved.

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
  This script demonstrates the failover and failback workflow.
  
  The code example/script provided here is for reference only to illustrate
  sample workflows and may not be appropriate for use in actual operating
  environments. 
#> 
Param(
  [string] $source_tintriserver,
  [string] $source_tsusername,
  [string] $source_tspassword,
  [string] $target_tintriserver,
  [string] $target_tsusername,
  [string] $target_tspassword,
  [string] $viserver,
  [string] $viusername,
  [string] $vipassword,
  [string] $vmname, # no FQDN
  [string] $source_destination_directory, # no '/' at the end
  [string] $target_destination_directory, # no '/' at the end
  [string] $source_esx,
  [string] $target_esx
)


Write-Output ">>> Import the powercli module.`n"

import-module VMware.VimAutomation.Core


Write-Output ">>> Import the Tintri Powershell Toolkit module.`n"

if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


Write-Output ">>> Connect to a tintri server $source_tintriserver.`n"

$source_ts = Connect-TintriServer -Server $source_tintriserver -UserName $source_tsusername -Password $source_tspassword -SetDefaultServer
$source_ts


Write-Output ">>> Connect to a tintri server $target_tintriserver.`n"

$target_ts = Connect-TintriServer -Server $target_tintriserver -UserName $target_tsusername -Password $target_tspassword
$target_ts


Write-Output ">>> Connect to a VI server $viserver.`n"

if ($global:DefaultVIServers) { Disconnect-VIServer * -Force -confirm:$false -ea SilentlyContinue | out-null }
Connect-VIServer -Server $viserver -User $viusername -Password $vipassword


Write-Output ">>> Get the tintri vm $vmname on tintri server $source_tintriserver.`n"

$source_vm = Get-TintriVM -Name $vmname -TintriServer $source_ts
$source_vm


Write-Output ">>> Get the datastore repl path for tintri server $source_tintriserver.`n"

$source_rp = Get-TintriDatastoreReplPath -HostName $source_ts.ApplianceHostName
$source_rp

Write-Output ">>> Replicate vm $vmname from tintri server $source_tintriserver to $target_tintriserver.`n"

New-TintriVMReplConfiguration -VM $source_vm -DatastoreReplPath $source_rp


Write-Output ">>> Make sure the replication is completed. Use 'Get-TintriVM' to refresh the VMStore.`n"

do {

    $vmlist = Get-TintriVM -TintriServer $source_ts

    $latest_ss = (Get-TintriVM -Name $vmname -TintriServer $source_ts).Snapshot.Latest.Uuid.UuId

    $latest_repl = (Get-TintriVM -Name $vmname -TintriServer $source_ts).Snapshot.LatestReplicated.Uuid.UuId

    $rpCfg = Get-TintriVMReplConfiguration -VM $source_vm
    
    if (($rpCfg.ReplicationState -ne "RUNNING") -or ($rpCfg.IsEnabled -eq $false))
    {
        Write-Error "Replication is not configured please do so and try again.`n"
        return
    }
	
	Start-Sleep -Seconds 1
	Write-Output "Waiting for replicaiton snapshots: $latest_ss ...to equal... $latest_repl"
}
while (($latest_ss -ne $null) -and ( $latest_ss -ne $latest_repl ))


Write-Output ">>> Remove the replication for vm $vmname on tintri server $source_tintriserver.`n"

Remove-TintriVMReplConfiguration -VM $source_vm


Write-Output ">>> Delete vm $vmname from tintri server $source_tintriserver.`n"

$vm = Get-VM -Name $vmname

Stop-VM -VM $vm -Confirm:$False


Remove-VM -DeletePermanently -VM $vm -Confirm:$false


Write-Output ">>> Run 'Get-TintriVM' to refresh the tintri server $target_tintriserver.`n"

Get-TintriVM -TintriServer $target_ts


Write-Output ">>> Restore vm $vmname on tintri server $target_tintriserver.`n"

Restore-TintriVM -Name $vmname -TintriServer $target_ts -DestinationDirectory $target_destination_directory -UseLatestSnapshot


Write-Output ">>> Add vm $vmname on tintri server $target_tintriserver to inventory.`n"

$target_vmfilepath = '[' + $target_ts.HostNameOrIp + '] ' + $target_destination_directory + '/' + $vmname + '.vmx'

New-VM -VMFilePath $target_vmfilepath -VMHost $target_esx


Write-Output ">>> Run 'Get-TintriVM' to refresh the tintri server $target_tintriserver.`n"

Get-TintriVM -TintriServer $target_ts


Write-Output ">>> Get the tintri vm $vmname on tintri server $target_tintriserver.`n"

$target_vm = Get-TintriVM -Name $vmname -TintriServer $target_ts

$target_vm


Write-Output ">>> Get the datastore repl path for tintri server $target_tintriserver.`n"

$target_rp = Get-TintriDatastoreReplPath -HostName $target_ts.ApplianceHostName

$target_rp


Write-Output ">>> Replicate vm $vmname from tintri server $target_tintriserver to $source_tintriserver.`n"

$vmrepl = New-TintriVMReplConfiguration -VM $target_vm -DatastoreReplPath $target_rp

while ( !$vmrepl ) {

    $source_vmlist = Get-TintriVM -TintriServer $source_ts

    $target_vmlist = Get-TintriVM -TintriServer $target_ts

    $vmrepl = New-TintriVMReplConfiguration -VM $target_vm -DatastoreReplPath $target_rp
    
}

$vmrepl


Write-Output ">>> Make sure the replication is completed. Use 'Get-TintriVM' to refresh the VMStore.`n"

do {

    $vmlist = Get-TintriVM -TintriServer $target_ts

    $latest_ss = (Get-TintriVM -Name $vmname -TintriServer $target_ts).Snapshot.Latest.Uuid.UuId

    $latest_repl = (Get-TintriVM -Name $vmname -TintriServer $target_ts).Snapshot.LatestReplicated.Uuid.UuId
    
}
while( $latest_ss -ne $latest_repl )


Write-Output ">>> Remove the replication for vm $vmname on tintri server $target_tintriserver.`n"

Remove-TintriVMReplConfiguration -VM $target_vm


Write-Output ">>> Delete vm $vmname from tintri server $target_tintriserver.`n"

$vm = Get-VM -Name $vmname

Stop-VM -VM $vm -Confirm:$False

Remove-VM -DeletePermanently -VM $vm -Confirm:$false


Write-Output ">>> Run 'Get-TintriVM' to refresh the tintri server $source_tintriserver.`n"

Get-TintriVM -TintriServer $source_ts


Write-Output ">>> Restore vm $vmname on tintri server $source_tintriserver.`n"

Restore-TintriVM -Name $vmname -TintriServer $source_ts -DestinationDirectory $source_destination_directory -UseLatestSnapshot


Write-Output ">>> Add vm $vmname on tintri server $source_tintriserver to inventory.`n"

$source_vmfilepath = '[' + $source_ts.HostNameOrIp + '] ' + $source_destination_directory + '/' + $vmname + '.vmx'

New-VM -VMFilePath $source_vmfilepath -VMHost $source_esx



