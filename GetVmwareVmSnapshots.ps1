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

The following code snippet shows how the Tintri Automation Toolkit interoperates with VMware PowerCLI.

We can pass PowerCLI VM objects as input to Tintri cmdlets.

#>

Param(
    [string] $tintriServer,
    [string] $vCenter,
    [string] $vmwareVmName    
)

# Import the VMware PowerCLI snap-in
Write-Host "Loading the PowerCLI snapin"
Add-PSSnapin VMware.VimAutomation.Core

# Connect to a vCenter (may prompt for credentials)
Write-Host "Connecting to the vCenter $vCenter (may prompt for credentials)"
Connect-VIServer -Server $vCenter

# Get VMware VM(s) with the given name using PowerCLI.
Write-Host "Fetching the VM $vmwareVmName from vCenter"
$vmwareVm = Get-VM -Name $vmwareVmName

# Connect to the VMstore, will prompt for credentials
Write-Host "Connecting to the Tintri server $tintriServer (will prompt for credentials)"
Connect-TintriServer -Server $tintriServer

# Resolve the corresponding Tintri VM object from VMstore
Write-Host "Resolving the corresponding TintriVM object for $vmwareVmName from VMstore"
Get-TintriVM -VM $vmwareVm
 
# Pass the VMware VM object as input to the Tintri 'Get Snapshots' cmdlet.
Write-Host "Passing the VMware VM as input to fetch its VMstore snapshots"
$vmwareVm | Get-TintriVMSnapshot