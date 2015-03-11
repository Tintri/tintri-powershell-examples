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

The following code snippet shows how the Tintri Automation Toolkit interoperates with  
Microsoft Hyper-V Manager cmdlets.

We can pass Hyper-V Manager VM objects as input to Tintri cmdlets.

* Requires Tintri Automation Toolkit 1.5.
#>

Param(
    [string] $tintriServer,
    [string] $hypervHost,
    [string] $hypervVmName    
)

# Get VMs on a Hyper-V machine

# We'll do a remote invocation of "Get-VM" on the Hyper-V host, in the case where 
# we are not part of the same domain. Note that the hypervHost needs to be in the list
# of trusted hosts, for the call to succeed. For more information on how to do this,
# see https://technet.microsoft.com/en-us/magazine/ff700227.aspx 

# This will prompt for credentials.
Write-Host "Fetching VM : $hypervVmName from the remote Hyper-V host $hypervHost (will prompt for credentials)"
$hypervVm = Invoke-Command -ComputerName $hypervHost -ScriptBlock `
{ 
    Param([string] $vmName)    
    Get-VM -Name $vmName 
} -ArgumentList $hypervVmName -Credential "" -Debug

# Note:
# If we are part of the same domain, we can simply run:
# $hypervVm = Get-VM -Name $hypervVmName -ComputerName $hypervHost

# Connect to the VMstore, will prompt for credentials
Write-Host "Connecting to the Tintri server $tintriServer (will prompt for credentials)"
Connect-TintriServer -Server $tintriServer

# Resolve the corresponding Tintri VM object from VMstore
Write-Host "Resolving the corresponding TintriVM object for $hypervVmName from VMstore"
Get-TintriVM -VM $hypervVm
 
# Pass the Hyper-V VM object as input to the Tintri 'Get Snapshots' cmdlet.
Write-Host "Passing the Hyper-V VM as input to fetch its VMstore snapshots"
$hypervVm | Get-TintriVMSnapshot