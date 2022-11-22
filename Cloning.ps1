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

#
# This script demonstrates various Tintri VM clone workflows.

Param(
  [string] $tintriserver,
  [string] $tsusername,
  [string] $tspassword,
  [string] $vmname,
  [string] $new_vmclonename,
  [string] $base_vmname,
  [string] $destination_directory
)

if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Write-Output ">>> Import the Tintri Powershell Toolkit module [TintriPS$($tpsEdition)Toolkit].`n"

Import-Module -force "${ENV:ProgramFiles}\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


Write-Output ">>> Connect to a tintri storage server $tintriserver.`n"

($conn = Connect-TintriServer -Server $tintriserver -UserName $tsusername -Password $tspassword -SetDefaultServer) | fl *
if ($conn -eq $null) {
    Write-Error "Connection to storage server:$tintriserver failed."
    return
}


Write-Output ">>> Get all the VMs on the tintri server.`n"

Get-TintriVM


Write-Output ">>> Get the virtual host resource of type ComputeResource.`n"

$vm = Get-TintriVM -name $vmname
($hr = Get-TintriVirtualHostResource -VirtualHostResourceType ComputeResource -TintriVMObject $vm -TintriServer $conn) | fl *


Write-Output ">>> Create a crash consistent clone for VM $vmname.`n"

New-TintriVMClone -SourceVMName $vmname -NewVMCloneName $new_vmclonename -VMHostResource $hr -SnapshotConsistency CRASH_CONSISTENT -TintriServer $conn


Write-Output ">>> Create 2 clones for VM $vmname.`n"

New-TintriVMCloneMany -SourceVMName $vmname -CloneCount 2 -VMHostResource $hr -BaseVMName $base_vmname


Write-Output ">>> Restore VM $vmname and add that to the datastore directory $destination_directory. Restore won't add the VM to inventory.`n"

Restore-TintriVM -Name $vmname -DestinationDirectory $destination_directory -UseLatestSnapshot -TintriServer $conn


Write-Output "Disconnect from $tintriserver."

Disconnect-TintriServer -TintriServer $conn

