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

Starting Tintri OS 3.2, VMs can be protected using high-frequency snapshots,
which have an RPO of 1 minute. These can be enabled only when replication is 
configured for the VM.

The following code snippet shows how to enable high-frequency snapshots on a
VM using the Tintri Automation Toolkit 2.0.0.1.

#>

Param(
    [string] $tintriServer,
	[string] $tsusername,
	[string] $tspassword,
    [string] $vmName
)


# import the tintri toolkit 
Write-Output ">>> Import the Tintri Powershell Toolkit module.`n"

if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


# connect to the tintri storage server
Write-Output ">>> Connect to a tintri server $tintriserver.`n"

($conn = Connect-TintriServer -Server $tintriserver -UserName $tsusername -Password $tspassword -SetDefaultServer) | fl *
if ($conn -eq $null) {
    Write-Error "Connection to storage server:$tintriserver failed."
    return
}


# Get the VM
Write-Output ">>> Getting the VMware VM $vmName on $tintriServer"
($vm = Get-TintriVM -Name $vmName) | fl *


# Create a high-frequency snapshot schedule
Write-Output ">>> Creating a high-frequency (one minute) snapshot schedule"
($schedule = New-TintriVMSnapshotSchedule -SnapshotScheduleType EveryMinute) | fl *


# Apply the schedule to the VM
Write-Output ">>> Applying the schedule to the VM $vmName"
Set-TintriVMSnapshotSchedule -VM $vm -SnapshotSchedule $schedule


# Verify if the schedule was applied
# Re-fetch the VM object from server.
Write-Output ">>> High-frequency snapshots being enabled for the VM: $hfEnabled"
$vm = Get-TintriVM -VM $vm
($hfEnabled = $vm.Snapshot.HighFrequencySnapshotConfig.IsEnabled) | fl *


# Clear the applied schedule
Write-Output ">>> Clearing the high-frequency snapshot schedule"
Clear-TintriVMSnapshotSchedule -VM $vm -SnapshotScheduleType EveryMinute


# Disconnecting from all Tintri servers
Write-Output ">>> Disconnecting server $tintriServer connection"
Disconnect-TintriServer -All