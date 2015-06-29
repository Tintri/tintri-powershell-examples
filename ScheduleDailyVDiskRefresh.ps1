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

    # Connect to the VMstore, will prompt for credentials
    Write-Host "Connecting to the VMstore $tintriServer"
    $ts = Connect-TintriServer -Server $tintriServer -Credential $credentials 

    if ($ts -eq $null)
    {
        Write-Host "Could not connect to $tintriServer"
        return
    }

    # Get the source VM (whose latest snapshot's disk will be used for refresh)
    Write-Host "Getting the source VM $sourceVmName on $tintriServer"
    $sourceVm = Get-TintriVM -Name $sourceVmName

    # Get the latest snapshot
    Write-Host "Getting the latest snapshot of the VM $sourceVmName"
    $snapshot = Get-TintriVMSnapshot -VM $sourceVm -GetLatestSnapshot

    Write-Host "The disks of this snapshot will be used to refresh the destination VMs"

    # Get the destination VMs
    Write-Host "Getting the destination VMs whose name matches the pattern $destinationVmNamePattern"
    $destinationVms = Get-TintriVM -Name $destinationVmNamePattern

    # Sync (refresh) vDisks of the destination VMs with the source snapshot disks
    Write-Host "All disks except the first (which is typically the OS disk) will be refreshed"

    # Using the 'Force' option because this script is run in a schedule, not interactively.
    # Make sure you test this action before you schedule it.
    Sync-TintriVDisk -VM $destinationVms -SourceSnapshot $snapshot -AllButFirstVDisk -Force

    # Disconnecting from all the Tintri servers
    Disconnect-TintriServer -All
}

# Trigger to determine when the script will be executed
Write-Host "Creating a new trigger for the job - run daily at 3 am."
$trigger = New-JobTrigger -Daily -At "3:00 AM"

# Schedule the refresh disk script on the machine, specifying the trigger that starts the job.
Write-Host "Scheduling the 'refresh disks' job to run "
Register-ScheduledJob -Name Refresh-Disks `
    -ScriptBlock { Refresh-Disks $tintriServer $sourceVmName $destinationVmNamePattern $credentials } `
    -Trigger $trigger

# To unregister, try UnRegister-ScheduledJob -Name Refresh-Disks