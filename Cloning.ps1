# The MIT License (MIT)
#
# Copyright (c) 2015 Tintri, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
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

ipmo 'C:\Program Files\TintriPSToolkit\TintriPSToolkit.psd1'

Write-Verbose ">>> Connect to a Tintri server $tintriserver.`n"

$conn = Connect-TintriServer -Server $tintriserver -UserName $tsusername -Password $tspassword

Write-Verbose ">>> Get all the VMs on the Tintri server.`n"

Get-TintriVM

Write-Verbose ">>> Get the virtual host resource of type ComputeResource.`n"

$hr = Get-TintriVirtualHostResource -VirtualHostResourceType ComputeResource

$hr

Write-Verbose ">>> Create a crash consistent clone for VM $vmname.`n"

New-TintriVMClone -SourceVMName $vmname -NewVMCloneName $new_vmclonename -VMHostResource $hr -SnapshotConsistency CRASH_CONSISTENT

Write-Verbose ">>> Create 3 clones for VM $vmname.`n"

New-TintriVMCloneMany -SourceVMName $vmname -CloneCount 3 -VMHostResource $hr -BaseVMName $base_vmname

Write-Verbose ">>> Restore VM $vmname and add that to the datastore directory $destination_directory."
Write-Verbose ">>> Restore won't add the VM to inventory.`n"

Restore-TintriVM -Name $vmname -DestinationDirectory $destination_directory -UseLatestSnapshot

Disconnect-TintriServer -TintriServer $conn

Write-Verbose "Disconnected from $myHost."
