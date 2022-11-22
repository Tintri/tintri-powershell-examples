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

The following code demonstrates how you can schedule a daily job that uses
the Sync-TintriVDisk cmdlet in Tintri Automation Toolkit 2.0.0.1 to refresh
selected disks of VMs with a master (source) VM snapshot. This is useful in
"test and dev" environments to sync, for instance, test databases with the 
latest production data.

For a more advanced usage of the Sync-TintriVDisk cmdlet, run:
Get-Help Sync-TintriVDisk -Full

Notes:

To create a PSCredential object to supply to the script, do the following:
> $password = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
> $credentials = New-Object System.Management.Automation.PSCredential("UserNameString", $password)

To schedule a job in Windows, you require administrative privileges.
#>
param
(
    [string] $tintriServer,
    [string] $sourceVmName,
    [string] $destinationVmNamePattern,
    [PSCredential] $credentials
)


function validateDiskLists( $snapDisks, $vmdisks )
{
	
    Write-Host ""
	Write-Host "Now validating snapshot and destination disk lists for the VM: $sourceVmName"
    if (!$snapDisks -or !$vmdisks)
    {
        throw "Source disk (snapDisks) count [$($snapdisks.count)] or destination (vmDisk) disk count [$($vmdisks.count)] is zero, can not continue till disks added. This script will filter boot (* 0:0), synthetic and non VM disks.  Please check disk lists and script if it will work for your situation."
    }
    if ($snapdisks.Count -ne $vmdisks.Count)
    {
        throw "Source disk (snapDisks) count [$($snapdisks.count)] does not equal the destination (vmDisk) disk count [$($vmdisks.count)], syncing to mismatch of disks is not supported by this script, due to the risk of data mismatch on a partial synchronize. Please check disk lists and script if it will work for your situation."
    }
    
    #NOTE: you can provide your own mapping here, this might not be the case for all customers, but is the normal mapping
    foreach ($snapDisk in $snapdisks)
    {
         if (! ($vmdisks | where { $_.Name -eq $snapDisk.Name }) )
         {
            throw "Source disk [$snapDisk] was not found in the destination disks this script must have a one to one matching. Please check disk lists and script if it will work for your situation."
         }
    }
}

function filterDiskList( $disks, $includeBootDisk, $description )
{
    write-host ""
	Write-Host "Filtering $description disks [includeBoot:$includeBootDisk] for the VM: $sourceVmName to target: $destinationVmNamePattern"
    write-host ""
    write-host "Original all-unfiltered $description disks:"
    write-host "-----------------------------------------------"
    $disks | ft -AutoSize -Force | out-host

    write-host ""
    write-host "Filtered $description disks:"
    write-host "-----------------------------------------------"
    $disks = $disks |  sort -property Name | where {(! $_.IsSynthetic) -and ($_.IsDiskdrive) }
	if ($includeBootDisk -eq $false)
	{
		$disks = $disks |  sort -property Name | where { ($_.Name -notlike "* 0:0") }
	}
    $disks | Select-Object Name, Path, VmName | FT -AutoSize | out-host

    return $disks
}

function Refresh-Disks
{
    <#
    .SYNOPSIS
        Refresh destination VM disks with the latest snapshot of source VM.

    .DESCRIPTION
        Script to refresh the destination VM vDisks with the latest snapshot of the source VM.
        This will executed daily, once scheduled.
        All disks except the first (which is typically the OS disk) will be refreshed.

    .EXAMPLE
        Refresh-Disks "vmstore01" "master_vm_1" "child_vm_*"
    #>
    param(
        [string] $tintriServer,
        [string] $sourceVmName,
        [string] $destinationVmNamePattern,
        [PSCredential] $credentials
    )

    # import the tintri toolkit 
    if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
    Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


    # Connect to the Tintri server, can prompt for credentials
    Write-Host "Connecting to the VMstore $tintriServer"
    $conn = Connect-TintriServer -Server $tintriserver -Credential $credentials -SetDefaultServer -ErrorVariable connError
    if ($conn -eq $null) {
        Write-Error "Connection to storage server:$tintriserver failed Error:$connError."
        return
    }
    

    # Get the source VM (whose latest snapshot's disk will be used for refresh)
    Write-Host "Getting the source VM $sourceVmName on $tintriServer"
    $sourceVm = (Get-TintriVM -Name $sourceVmName)[-1]


    # Get the latest snapshot
    Write-Host "Getting the latest snapshot of the VM $sourceVmName"
    ($snapshot = Get-TintriVMSnapshot -VM $sourceVm -GetLatestSnapshot) | fl *

	
	Write-Host "Getting the virtual disks contained in the latest snapshot of the VM $sourceVmName"
    Write-Host "The disks of this snapshot will be used to refresh the destination VMs"
    ($vmDisksSourceSnapshot = Get-TintriVDisk -Snapshot $snapshot) | fl *


    # Get the destination VMs
    Write-Host "Getting the destination VMs whose name matches the pattern $destinationVmNamePattern"
    ($destinationVms = Get-TintriVM -Name $destinationVmNamePattern) | fl *


    foreach ($destinationVm in $destinationVms)
	{
		Write-Host "Getting the destination VMs $($destinationVm.Vmware.Name) virtual disks	"
		($vmdisksDestination = Get-TintriVDisk -VM $destinationVm) | fl *

		Write-Host "Filter disks to match the destination VMs $($destinationVm.Vmware.Name) virtual disks"
		Write-Host "Please verify the disk mapping matches your desired synchronization lists (boot disk 0:0 filtered by default)"
		Write-Host "Make sure you test verify this mapping before you schedule it."
		$vmDisksSourceSnapshot = filterDiskList $vmDisksSourceSnapshot $false "Snapshot VM Source"
		$vmdisksDestination = filterDiskList $vmdisksDestination $false "VM Destination"

		# validate disk lists are not empty and have a one to one matching of data disks, throw if invalid
		validateDiskLists $vmDisksSourceSnapshot $vmdisksDestination

		# Sync (refresh) vDisks of the destination VMs with the source snapshot disks
		# Using the 'Force' option because this script is run in a schedule, not interactively.
		Write-Host "Typically all disks except the first which is the OS disk are often refreshed"
		Sync-TintriVDisk -VM $destinationVm -SourceSnapshot $snapshot -SnapshotDisk $vmDisksSourceSnapshot -VMDisk $vmdisksDestination -Force
	}
	
    # Disconnecting from all the Tintri servers
    Disconnect-TintriServer -All
}

$doSchedule = $false
if ($doSchedule -eq $true)
{
# Trigger to determine when the script will be executed
Write-Host "Creating a new trigger for the job - run daily at 3 am."
$trigger = New-JobTrigger -Daily -At "3:00 AM"

# Schedule the refresh disk script on the machine, specifying the trigger that starts the job.
Write-Host "Scheduling the 'refresh disks' job to run "
Register-ScheduledJob -Name Refresh-Disks `
    -ScriptBlock { Refresh-Disks $tintriServer $sourceVmName $destinationVmNamePattern $credentials } `
    -Trigger $trigger

# To unregister, try UnRegister-ScheduledJob -Name Refresh-Disks
}
else
{
    Refresh-Disks $tintriServer $sourceVmName $destinationVmNamePattern $credentials
}   