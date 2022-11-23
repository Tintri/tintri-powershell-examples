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
Reads a configuration file for storage service QoS information.
  Collects VMs from VMstore.
   Foreach VM, gets the VMware tag which maps to the storage service QoS
   information, and sets the VM QoS if not already set to the values.
  
 This scripts requires vmware PowerCli module to already be installed.
 This assumes the following has been setup previously:
    New-TagCategory -Name "Storage-QOS" -Cardinality "single" -EntityType "VirtualMachine" -Description "Gold,Silver,Bronze level of storage IOPs Quality Of Service(QOS)"
    New-Tag -Name gold   -Category Storage-QOS -Description "Gold level of storage IOPs Quality Of Service(QOS)"
    New-Tag -Name silver -Category Storage-QOS -Description "Silver level of storage IOPs Quality Of Service(QOS)"
    New-Tag -Name bronze -Category Storage-QOS -Description "Bronze level of storage IOPs Quality Of Service(QOS)"
    Get-VM -Name vm*gold | New-TagAssignment -Tag "gold"
    Get-VM -Name vm*silver | New-TagAssignment -Tag "silver"
    Get-VM -Name vm*bronze | New-TagAssignment -Tag "bronze"
#>

param([String]$tintriServer="192.168.1.1",
      [String]$tsusername="admin",
      [String]$tspassword="password",
      [String]$storageServiceConfigFile="StorageServiceConfig.txt",
      [String]$vCenterUser="Administrator@vsphere.local")


# import the tintri toolkit 
Write-Host "Import the Tintri Powershell Toolkit module."
if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"

# import the vmware powershell module 
import-module VMware.VimAutomation.Core


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
    $services = Get-Content $storageServiceConfigFile
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


# connect to the tintri storage server
Write-Host "Connecting to a tintri storage server $tintriserver."
($conn = Connect-TintriServer -Server $tintriserver -UserName $tsusername -Password $tspassword -SetDefaultServer) | fl *
if ($conn -eq $null) {
    Throw "Connection to storage server:$tintriserver failed."
    return
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
            if ($minIOPs -ne 0 -or $maxIOPs -ne 0)
            {
                Write-Host -ForegroundColor Yellow "  No tag name, clear QOS, setting to infinity and beyond, on VM: $vmName."
                Set-TintriVMQOS -VM $_ -ClearMinNormalizedIops -ClearMaxNormalizedIops
            }
            else 
            {
                Write-Host -ForegroundColor Yellow "  No tag name, on VM: $vmname"
            }
        }
        elseif (!$ss[$tagName])
        {
            Write-Host -ForegroundColor Yellow "  No storage service named $tagName on VM: $vmName, no setting QOS"
        }
        elseif ($ss[$tagName].MinIOPs -ne $minIOPs -or $ss[$tagName].MaxIOPs -ne $maxIOPs)
        {
           Write-Host "  Setting VM $vmName to $($ss[$tagName].MinIOPs, $ss[$tagName].MaxIOPs)"
           Set-TintriVMQOS -VM $_ -MaxNormalizedIops $ss[$tagName].MaxIOPs -MinNormalizedIops $ss[$tagName].MinIOPs
        }
        elseif ($ss[$tagName].MinIOPs -eq $minIOPs -and $ss[$tagName].MaxIOPs -eq $maxIOPs)
        {
           Write-Host -ForegroundColor Green "  VM $vmName already set to IOPs $($ss[$tagName].MinIOPs, $ss[$tagName].MaxIOPs)"
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
    Disconnect-VIServer -Server $($vcenter.Value) -Force -confirm:$false
}

# Disconnect from the Tintri server.
Disconnect-TintriServer -TintriServer $conn

Write-Host "Disconnected from $myHost."

