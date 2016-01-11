# The MIT License (MIT)
#
# Copyright (c) 2016 Tintri, Inc.
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

# Reads a configuration file for storage service QoS information.
# Collects VMs from VMstore.
# Foreach VM, gets the VMware tag which maps to the storage service QoS
# information, and sets the VM QoS if not already set to the values.


param([String]$tintriServer="192.168.1.1",
      [String]$storageServiceConfig="StorageServiceConfig.txt",
      [String]$user="admin",
      [String]$vCenterUser="Administrator@vsphere.local")

Import-Module 'C:\Program Files\TintriPSToolkit\TintriPSToolkit.psd1'
Add-PSSnapin VMware.VimAutomation.Core

# Global variables
$ss = @{}
$vcenters = @{}

<#
.SYNOPSIS
    Internal function to connect to a vCenter
.DESCRIPTION
    Connects to a vCenter. If it fails, the script exits.
.EXAMPLE
    Connect-vCenter($vCenterName)
.INPUTS
    vCenter name.
.OUTPUTS
    vCenter connection object
#>
Function Connect-vCenter {
    param(
        [String]$vCenterName,
        [String]$vCenterUser
        )

    Write-Host "Attempting $vCenterName with $vCenterUser"
    $vc_conn = Connect-VIServer -Server $vCenterName -User $vCenterUser
    if (!$vc_conn) {
        Write-Error "Couldn't connect to vCenter $vCenterName."
        Exit
    }
    Write-Verbose "Connected to vCenter $vCenterName as user $vCenterUser."
    return $vc_conn
}


# Main    
# Read the storage service configuration file.
Try
{
    $services = Get-Content $storageServiceConfig
}
Catch
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.Source
    Throw "Failed to read file $FailedItem with error: $errorMessage"
}

# Parse the storage service configuraiton file data into
# storage service objects.
ForEach ($service in $services)
{
   Write-Verbose $service

   # Check for comments
   if ($service.Substring(0,1) -eq "#")
   {
       continue
   }

   # Split on 1-x spaces or tabs
   $parts = $service -split '\s+|\t+'
   if ($parts.Length -ne 3)
   {
       Write-Error "Invalid storage service"
       Break
   }

   # Parse a storage service line and create a storage service object.
   $temp_ss = New-Object -TypeName PSObject
   $temp_ss | Add-Member -MemberType NoteProperty -Name SsName -Value ($parts[0])
   $temp_ss | Add-Member -MemberType NoteProperty -Name MinIOPs -Value ($parts[1])
   $temp_ss | Add-Member -MemberType NoteProperty -Name MaxIOPs -Value ($parts[2])
   Write-Host "$($temp_ss.SsName) - ($($temp_ss.MinIOPs), $($temp_ss.MaxIOPs))"
   $ss.add($temp_ss.SsName, $temp_ss)
}

if ($ss.Count -eq 0)
{
    Throw "No storage services in configuration file"
}
Write-Host "Processed $($ss.Count) storage services."

# Connect to the Tintri server.
# Password will be requested in a Windows pop-up.
$conn = Connect-TintriServer -Server $tintriServer -UserName $user
if (!$conn)
{
    Throw "Connection Error"
}

$myHost = $conn.ApplianceHostName
Write-Verbose "Connected to $myHost."

$vms = Get-TintriVM
if (!$vms)
{
    Disconnect-TintriServer -TintriServer $conn
    Throw "No VMs"
}

Write-Host "Number of VMs = $($vms.Count)"

# For each VM get the VMware tag.  If the VM has a tag that
# matches the configured storage services, then set the QoS
# only if the min and max IOPs don't match. 
Try
{
    $vms | ForEach-Object -Process {
        $vmName = $($_.Vmware.Name)
        $vCenterName = $($_.Vmware.VcenterName)
        $minIOPs = $($_.QosConfig.MinNormalizedIops)
        $maxIOPs = $($_.QosConfig.MaxNormalizedIops)

        Write-Host "$vmName, $vCenterName, $minIOPs, $maxIOPs"

        # Connect with the vCenter if we haven't connected yet.
        if (!$vcenters[$vCenterName])
        {
            $vcenters[$vCenterName] = connect-vCenter $vCenterName $vCenterUser
        }
        $vc_conn = $vcenters[$vCenterName]

        # Get the VMware tag
        $tagName = $(Get-TagAssignment -Server $vc_conn -Category Storage-QOS -Entity $vmName).Tag.Name
        if (!$tagName)
        {
            Write-Host "No tag name, clear QoS"
            if ($minIOPs -ne 0 -or $maxIOPs -ne 0)
            {
                Write-Host "Setting to infinity and beyond."
                Set-TintriVMQOS -VM $_ -ClearMinNormalizedIops -ClearMaxNormalizedIops
            }
        }
        elseif (!$ss[$tagName])
        {
            Write-Error "No storage service named $tagName."
        }
        elseif ($ss[$tagName].MinIOPs -ne $minIOPs -or $ss[$tagName].MaxIOPs -ne $maxIOPs)
        {
           Write-Host "Setting VM $vmName to ($ss[$tagName].MinIOPs, $ss[$tagName].MaxIOPs)"
           Set-TintriVMQOS -VM $_ -MaxNormalizedIops $ss[$tagName].MaxIOPs -MinNormalizedIops $ss[$tagName].MinIOPs
        }
    }
}
Catch
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.Source
    Write-Error "Failed processing VM QoS: $FailedItem with error: $errorMessage"
}

foreach ($vcenter in $vcenters.GetEnumerator())
{
    Write-Host "Disconnecting from $($vcenter.Name)"
    Disconnect-VIServer -Server $($vcenter.Value) -Force
}

# Disconnect from the Tintri server.
Disconnect-TintriServer -TintriServer $conn

Write-Host "Disconnected from $myHost."

