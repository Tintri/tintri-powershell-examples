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
  This script demonstrates setting the snapshot schedule for a VM.
  
  The code example/script provided here is for reference only to illustrate
  sample workflows and may not be appropriate for use in actual operating
  environments. 
#>
Param(
  [string] $tintriserver,
  [string] $tsusername,
  [string] $tspassword,
  [string] $vmname,
  [string] $timeofday
)


Write-Output ">>> Import the Tintri Powershell Toolkit module.`n"

if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


Write-Output ">>> Connect to a tintri server $tintriserver.`n"

Connect-TintriServer -Server $tintriserver -UserName $tsusername -Password $tspassword -SetDefaultServer


Write-Output ">>> Get the VM: $vmname.`n"

$vm = Get-TintriVM -Name $vmname
$vm


Write-Output ">>> Get the snapshot schedule for the VM: $vmname.`n"

Get-TintriVMSnapshotSchedule -VM $vm


Write-Output ">>> Set the daily snapshot schedule for the VM: $vmname.`n"

New-TintriVMSnapshotSchedule -VM $vm -SnapshotScheduleType DAILY -TimeOfDay $timeofday | Set-TintriVMSnapshotSchedule


Write-Output ">>> Get the snapshot schedule for the VM: $vmname.`n"

Get-TintriVMSnapshotSchedule -VM $vm





