<#
The MIT License (MIT)

Copyright (c) 2015 Tintri, Inc.

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
using the Tintri Automation Toolkit 1.5.0.1.

#>

Param(
    [string] $tintriServer,
    [string] $vmName    
)

# Connect to the VMstore, will prompt for credentials
Write-Host "Connecting to the Tintri server $tintriServer"
Connect-TintriServer -Server $tintriServer

# Get the Tintri VM with the given name
Write-Host "Fetching the VM by name $vmName"
$vm = Get-TintriVM -Name $vmName

# Create a couple of snapshots of the VM
Write-Host "Creating a snapshot on the VM"
New-TintriVMSnapshot -VM $vm -SnapshotDescription "Snapshot from PowerShell"

# Get all the snapshots belonging to the VM
Write-Host "Fetching all the snapshots of the VM $vmName"
$snapshots = Get-TintriVMSnapshot -VM $vm

# Remove the latest snapshot (will ask for confirmation, use -Force to suppress)
Write-Host "Deleting the last created snapshot"
Remove-TintriVMSnapshot -Snapshot $snapshots[-1]

# Create a couple of snapshots with a specific description
$description1 = "Snapshot 1 to delete"
$description2 = "Snapshot 2 to delete"
Write-Host 'Creating a couple of snapshots containing the description "to delete"'
New-TintriVMSnapshot -VM $vm -SnapshotDescription $description1
New-TintriVMSnapshot -VM $vm -SnapshotDescription $description2

# Remove all the snapshots that contain the text "delete" in their description
Write-Host 'Removing all the snapshots of the VM that contain the description "to delete"'
$snapshots = Get-TintriVMSnapshot -VM $vm
$snapshots | where { $_.Description -match "to delete" } | Remove-TintriVMSnapshot