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
  This script demonstrates the restore of a tintri VM.
  
  The code example/script provided here is for reference only to illustrate
  sample workflows and may not be appropriate for use in actual operating
  environments. 
#>  
Param(
  [string] $tintriserver,
  [string] $tsusername,
  [string] $tspassword,
  [string] $vmname,
  [string] $snapshot_description,
  [string] $destination_directory1,
  [string] $destination_directory2
)


Write-Output ">>> Import the Tintri Powershell Toolkit module.`n"

if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


Write-Output ">>> Connect to a tintri server $tintriserver.`n"

$conn = Connect-TintriServer -Server $tintriserver -UserName $tsusername -Password $tspassword -SetDefaultServer
$conn

Write-Output ">>> Get all the VMs on the tintri server.`n"

Get-TintriVM


Write-Output ">>> Get all the snapshots of vm $vmname on the tintri server.`n"

Get-TintriVMSnapshot -Name $vmname


Write-Output ">>> Create a new snapshot for VM $vmname, with snapshot description $snapshot_description.`n"

New-TintriVMSnapshot -vmname $vmname -SnapshotDescription $snapshot_description


Write-Output ">>> Get all the snapshots of vm $vmname on the tintri server.`n"

$vmSnaps = Get-TintriVMSnapshot -Name $vmname
$vmSnaps

Write-Output ">>> Backup the VM $vmname to destination directory $destination_directory1.`n"

Restore-TintriVM -Name $vmname -DestinationDirectory $destination_directory1 -UseLatestSnapshot


Write-Output ">>> Backup the VM $vmname to destination directory $destination_directory2, with source snapshot Id of last snapshot.`n"

$vmsnaps | select vmname,Description -ExpandProperty uuid
Restore-TintriVM -Name $vmname -DestinationDirectory $destination_directory2 -SourceSnapshotId $vmSnaps[-1].uuid.uuid




