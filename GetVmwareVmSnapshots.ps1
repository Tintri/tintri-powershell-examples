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

The following code snippet shows how the Tintri Automation Toolkit interoperates with VMware PowerCLI.

We can pass PowerCLI VM objects as input to Tintri cmdlets.

#>

Param(
    [string] $tintriServer,
    [string] $tsusername,
    [string] $tspassword,
    [string] $viServerVCenter,
	[string] $viusername,
	[string] $vipassword,
    [string] $vmname    
)


# import the vmware powercli toolkit
Write-Output ">>> Import the powercli module.`n"
import-module VMware.VimAutomation.Core

# import the tintri toolkit 
Write-Output ">>> Import the Tintri Powershell Toolkit module.`n"
if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


# connect to the tintri storage server
Write-Output ">>> Connect to a tintri server $tintriserver.`n"
Connect-TintriServer -Server $tintriserver -UserName $tsusername -Password $tspassword -SetDefaultServer


# Connect to a vCenter
Write-Output ">>> Connecting to the vCenter $viServerVCenter"
Connect-VIServer -Server $viServerVCenter -user $viusername -password $vipassword 


# Get VMware VM(s) with the given name using PowerCLI.
Write-Output ">>> Fetching the VMware VM $vmname from vCenter"
($vmwareVm = Get-VM -Name $vmname) | fl *


# Resolve the corresponding Tintri VM object from VMstore
Write-Output ">>> Resolving the corresponding TintriVM object for $VmName from VMstore"
Get-TintriVM -VM $vmwareVm


# Pass the VMware VM object as input to the Tintri 'Get Snapshots' cmdlet.
Write-Output ">>> Passing the VMware VM as input to fetch its VMstore snapshots"
$vmwareVm | Get-TintriVMSnapshot