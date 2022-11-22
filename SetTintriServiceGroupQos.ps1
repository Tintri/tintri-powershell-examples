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

A Service Group is a logical collection of VMs in a Tintri Global Center (TGC). 
Administrators can use service groups to manage a group of VMs 
(apply protection policies and other settings) as they would manage a single VM.

The following code snippet shows how to  apply a QoS policy to all VMs in a 
TGC service group using the Tintri Automation Toolkit 2.0.0.1.

More specifically, we'll apply a config that sets the minimum normalized IOPS.

* This script assumes that all the VMs that are part of the service group belong to
exactly one VMstore (not multiple VMstores).
#>

Param(
    [string] $tgcTintriServer,
    [string] $tintriserver,
    [string] $serviceGroupName,
    [int] $minNormalizedIops    
)

# Connect to the TGC, will prompt for credentials
Write-Host "Connecting to the Tintri Global Center $tgcTintriServer"
$tgc = Connect-TintriServer -Server $tgcTintriServer -SetDefaultServer -ErrorVariable connError
if ($tgc -eq $null)
{
    Write-Error "Could not connect to $tgcTintriServer."
    return
}

# Get the service group on the TGC
Write-Host "Getting the service group $serviceGroupName on $tgcTintriServer"
$serviceGroup = Get-TintriServiceGroup -Name $serviceGroupName

# Fetch all the VMs of the service group
Write-Host "Getting the VMs that are members of the service group $serviceGroupName"
$serviceGroupVmsOnTgc = $serviceGroup | Get-TintriVM

# Resolve the corresponding VM objects on the VMstore.
# Connect to the VMstore, will prompt for credentials
Write-Host "Connecting to the VMstore $tintriserver"
$ts = Connect-TintriServer $tintriserver -SetDefaultServer -ErrorVariable connError
if ($ts -eq $null)
{
    Write-Error "Could not connect to $tintriserver. Error: $connError"
    return
}

Write-Host "Resolving the corresponding VMs on $tintriserver"
$serviceGroupVmsOnVmstore = $serviceGroupVmsOnTgc | Get-TintriVM -Uuid { $_.Uuid.UuId } -TintriServer $ts

# We can apply QoS policies only on live VMs. Filter them.
$liveVms = $serviceGroupVmsOnVmstore | Where { $_.IsLive }

# Update the QoS setting for these VMs.
Write-Host "Updating the QoS setting (min normalized IOPS) for these VMs"
$liveVms | Set-TintriVMQos -MinNormalizedIops $minNormalizedIops

# Disconnecting from the TGC and VMstore.
Disconnect-TintriServer -All