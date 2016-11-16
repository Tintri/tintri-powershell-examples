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

# This script sets the QoS values based on the VM's VMware storage profile
# and a file with the storage profile name QoS values.
# It assumes that the VMware storage profile name maps to a mount point, or
# mount directory in Tintri parlance, to /tintri/<VMware storage profile>.

# Posistional Inputs:
#    1. Tintri server IP or FQDN
#    2. Tintri server user name
#    3. QoS configuration file.  Location is based off the current directory 
#       where the script is executed.  The file must be in the following format:
#         storage_profile1 min_IOPs1 max_IOPs1
#         storage_profile2 min_IOPs2 max_IOPs2
#              . . .         . . .     . . .
#         storage_profileN minIOPsN  max_IOPsN

param([String]$tintriServer="192.168.107.103",
      [String]$storageServiceConfig="StorageServiceConfig.txt",
      [String]$user="admin")

Import-Module 'C:\Program Files\TintriPSToolkit\TintriPSToolkit.psd1'

# Global variables
$ss = @{}

# Main    
# Read the storage service configuration file.
Try
{
    Write-Host "Opening up $storageServiceConfig"
    $services = Get-Content $storageServiceConfig -ErrorAction Stop
}
Catch
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.Source
    Write-Error "Failed to read file $FailedItem with error: $errorMessage"
    Exit
}

# Parse the storage service configuration file data into
# storage service objects.
$i = 0
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

Write-Host "Processed $($ss.Count) storage services."
if ($ss.Count -eq 0)
{
    Throw "No storage services in configuration file"
}

# Connect to the Tintri server.
# Password will be requested in a Windows pop-up.
$conn = Connect-TintriServer -Server $tintriServer -UserName $user
if (!$conn)
{
    Throw "Connection Error"
}

$myHost = $conn.ApplianceHostName
Write-Verbose "Connected to $myHost."

$vms = Get-TintriVM -TintriServer $conn
if (!$vms)
{
    Disconnect-TintriServer -TintriServer $conn
    Throw "No VMs"
}

Write-Host "Number of VMs = $($vms.Count)"

# For each VM get the VMware storage profile and map it to a
# Tintri mount directory.  If the VM storage profile matches
# a configured storage service a, then set the QoS only if the
# min and max IOPs don't match.  If the VM doesn't have a 
# storage profile associated with, QoS is unlimited.
Try
{
    $vms | ForEach-Object -Process {
        $vmName = $($_.Vmware.Name)
        $vCenterName = $($_.Vmware.VcenterName)
        $scs = $($_.Vmware.StorageContainers)
        $minIOPs = $($_.QosConfig.MinNormalizedIops)
        $maxIOPs = $($_.QosConfig.MaxNormalizedIops)

        # Grab the hypervisor datastore in the form: /tintri/<Vmware_storage_profile>.
        $hvDatatstore = Get-TintriHypervisorDatastore -TintriServer $conn -DisplayName $scs
        $mountDirs = $hvDatatstore.mountDirectories

        # Only use the zeroth entry
        $mountDir = $mountDirs[0]

        # Here we grab the VMware storage profile.  There could be more checking here.
        # Assume storage profile maps to /tintri/<Vmware_storage_profile>.
        $vmStorageProfile = $mountDir.Substring($mountDir.LastIndexOf('/')+1)

        Write-Host "$vmName, $vmStorageProfile, $minIOPs, $maxIOPs"

        # If the storage profile is "tintri", then there are no VMware storage profiles. 
        if ($vmStorageProfile -eq "tintri")
        {
            Write-Host "  No storage profile."
            # Clear QoS is either min or max IOPs are greater than 0.
            if ($minIOPs -gt 0 -or $maxIOPs -gt 0)
            {
                Write-Host "  Setting to infinity and beyond."
                Set-TintriVMQOS -VM $_ -ClearMinNormalizedIops -ClearMaxNormalizedIops
            }
        }
        elseif (!$ss[$vmStorageProfile])
        {
            Write-Host -ForegroundColor Red "  No storage service named $vmStorageProfile."
        }
        elseif ($ss[$vmStorageProfile].MinIOPs -ne $minIOPs -or $ss[$vmStorageProfile].MaxIOPs -ne $maxIOPs)
        {
           Write-Host("  Setting VM " + $vmName + " to (" +
                      $ss[$vmStorageProfile].MinIOPs + "," + $ss[$vmStorageProfile].MaxIOPs + ")")
           Set-TintriVMQOS -VM $_ -MaxNormalizedIops $ss[$vmStorageProfile].MaxIOPs -MinNormalizedIops $ss[$vmStorageProfile].MinIOPs
        }
    }
}
Catch
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.Source
    Write-Error "Failed to read file $FailedItem with error: $errorMessage"
}

# Disconnect from the Tintri server.
Disconnect-TintriServer -TintriServer $conn

Write-Host "Disconnected from $myHost."

