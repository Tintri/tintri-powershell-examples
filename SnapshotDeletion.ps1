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
The following code snippet shows how to delete snapshots on a Tintri VMstore
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


# Get the Tintri VM with the given name
Write-Output ">>> Fetching the VM by name $vmName"
($vm = Get-TintriVM -Name $vmName) | fl *


# Create a couple of snapshots of the VM
Write-Output ">>> Creating a snapshot on the VM"
New-TintriVMSnapshot -VM $vm -SnapshotDescription "Snapshot from PowerShell"


# Get all the snapshots belonging to the VM
Write-Output ">>> Fetching all the snapshots of the VM $vmName"
($snapshots = Get-TintriVMSnapshot -VM $vm) | fl *


# Remove replication from vm, otherwise snapshot deletion will fail
Write-Output ">>> Remove replication from the VM $vmname to prevent snapshot deletion failure"
Remove-TintriVMReplConfiguration -vmname $vmName
get-TintriVMReplConfiguration -vmname $vmName


# Remove the latest snapshot (will ask for confirmation, use -Force to suppress)
Write-Output ">>> Deleting the latest most recent snapshot"
Get-TintriVMSnapshot -VM $vm -GetLatestSnapshot 
Get-TintriVMSnapshot -VM $vm -GetLatestSnapshot | Remove-TintriVMSnapshot


# Create a couple of snapshots with a specific description
Write-Output '>>> Creating a couple of snapshots containing the description "to delete"'
$snapSuffix = " to delete " + (Get-Date -Format "yyyymmdd-hhmmss")
$description1 = "Snapshot 1" + $snapSuffix
$description2 = "Snapshot 2" + $snapSuffix
New-TintriVMSnapshot -VM $vm -SnapshotDescription $description1
New-TintriVMSnapshot -VM $vm -SnapshotDescription $description2


# Remove all the snapshots that contain the text "delete" in their description
Write-Output '>>> Removing all the snapshots of the VM that contain the description "to delete"'
$snapshots = Get-TintriVMSnapshot -VM $vm | where { $_.Description -like "*$snapSuffix*" } 
$snapshots | Remove-TintriVMSnapshot -Force
$snapshots 