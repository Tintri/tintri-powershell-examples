<#
The MIT License (MIT)

Copyright © 2023 Tintri by DDN, Inc. All rights reserved.

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
  This script demonstrates the Virtual Machine vMotion migration workflow.
  It moves VMs between VMStores that share a vcenter and ESX Host.
  
  The code example/script provided here is for reference only to illustrate
  sample workflows and may not be appropriate for use in actual operating
  environments. 
#> 
Param(
  [string] $source_tsvr_name,     # source tintri server (e.g. ts814.acme.com )
  [string] $source_tsvr_username, # source tintri server web user (e.g. admin)
  [string] $source_tsvr_password, # source tintri server password (e.g. Passw0rd!)
  [string] $target_tsvr_name,     # target tintri server (e.g. ts882.acme.com )
  [string] $target_tsvr_username, # target tintri server web user (e.g. admin)
  [string] $target_tsvr_password, # target tintri server password (e.g. Passw0rd!)
  [string] $vc_viserver,          # vcenter server (e.g. vc001.acme.com)
  [string] $vc_viusername,        # vcenter user (e.g. administrator@vsphere.loca)
  [string] $vc_vipassword,        # vcetner password (e.g. Passw0rd!)
  [string] $source_datastore,     # source tintri server datastore dispaly name (e.g. ds814)
  [string] $target_datastore,     # target tintri server datastore dispaly name (e.g. ds882)
  [string] $source_esx_host,      # source tintri server-vcenter esx host (e.g. esxhost109.acme.com)
  [string] $output_dir            # log file directory (e.g. c:\temp\vm_migrate)
)

write-output "--------------------------------------------------------------------------"
write-output ">>> Input parameters"
write-output "--------------------------------------------------------------------------"

$vmw_pfx = "vmw_VMotionMigrate"
$vm_max = 10
write-output "Tintri Servers src:$source_tsvr_name dst:$target_tsvr_name"
write-output "Datastores:    src:$source_datastore dst:$target_datastore"
write-output "Esx Host:      $source_esx_host"
write-output "V-Center:      $vc_viserver"
write-output "Output:        $output_dir"
write-output "VM prefix:     $vmw_pfx"
write-output "VM count:      $vm_max"


write-output "--------------------------------------------------------------------------"
write-output ">>> Connect to servers (source-destination-vcenter)"
write-output "--------------------------------------------------------------------------"

Write-Output ">>> Import the vmware powercli module.`n"
import-module VMware.VimAutomation.Core

Write-Output ">>> Import the Tintri Powershell Toolkit module.`n"
if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"

Write-Output ">>> Connect to source tintri server $source_tsvr_name"
($src = Connect-TintriServer -Server $source_tsvr_name -UserName $source_tsvr_username -Password $source_tsvr_password -wa:SilentlyContinue) | fl

Write-Output ">>> Connect to target tintri server $target_tsvr_name.`n"
($dst = Connect-TintriServer -Server $target_tsvr_name -UserName $target_tsvr_username -Password $target_tsvr_password -wa:SilentlyContinue) | fl

Write-Output ">>> Connect to a VI vc-server $vc_viserver.`n"
if ($global:DefaultVIServers) { Disconnect-VIServer * -Force -confirm:$false -ea SilentlyContinue | out-null }
($vc_srv = Connect-VIServer -Server $vc_viserver -User $vc_viusername -Password $vc_vipassword) | Format-List

Write-Output ">>> Create output dir and clean previous test run.`n"
new-item -path $output_dir -type directory -ea SilentlyContinue | out-null
Remove-Item "$output_dir\*.log" -ea SilentlyContinue -confirm:$false | out-null



write-output "--------------------------------------------------------------------------"
write-Output ">>> Removing previous test virtual machines on $($src.HostNameOrIp) with prefix[$vmw_pfx]"
write-output "--------------------------------------------------------------------------"

$vmList = New-Object System.Collections.ArrayList
for ($vmIdx = 1; $vmIdx -le $vm_max; $vmIdx++)
{
    $vmName= $vmw_pfx + '_{0:X3}' -f $vmidx
    write-output "Removing pre-existing test virtual machine:$vmName"
    $vmw = Get-VM -Name $vmname -ea SilentlyContinue -ev errMsg 
    if ($vmw)
    {
        Remove-VM -DeletePermanently -VM $vmw -Confirm:$false -ea Continue
        Write-Output "Removed vm:$($vmw.name)"
    }
}
#start from clean slate on VMs, this will remove synthetic VM snapshots
write-output "Remove existing snapshots to start from clean slate on vms: [$vmw_pfx] `n"
Get-Tintrivm -Refresh -searchall | Where {$_.vmware.name -like $vmw_pfx+"*"} | Remove-TintriVMSnapshot -Force -ea SilentlyContinue | Out-Null
Get-Tintrivm -Refresh -searchall | Out-Null


write-output "--------------------------------------------------------------------------"
write-Output ">>> Creating virtual machines on $($src.HostNameOrIp) with prefix[$vmw_pfx]"
write-output "--------------------------------------------------------------------------"

for ($vmIdx = 1; $vmIdx -le $vm_max; $vmIdx++)
{
    $vmName=$vmw_pfx + '_{0:X3}' -f $vmidx
    write-output "Adding vm:$vmName"
    ($vmW = New-VM -Name $vmName -Datastore $source_datastore -VMHost $source_esx_host -DiskMB 512 -MemoryMB 512 -DiskStorageFormat Thin -ea SilentlyContinue -ev errMsg) | out-null
    if ($vmW)
    {
        $vmList.Add($vmW) | out-null
        write-output "Added vm:$($vmW.name)"
    }
    else 
    {
        Write-Error "Failed to create VM:$vmname. Error:$errMsg"
    }
}


write-output "--------------------------------------------------------------------------"
write-output ">>> Get source virtual machines on $($src.HostNameOrIp) with prefix[$vmw_pfx]"
write-output "--------------------------------------------------------------------------"
$vms = Get-Tintrivm -Refresh -svr $src | Where {$_.islive -and $_.vmware.name -like $vmw_pfx+"*"} | Sort-Object -property @{Expression={$_.vmware.name}} 
$vms | select-object -expand vmware | Select-Object name,storagecontainers | Format-Table -autosize
if ($vms.count -ne $vm_max)
{
    throw "Failed to find expected number of virtual machines [$($vms.count) out of $vm_max]"
}


write-output "--------------------------------------------------------------------------"
write-output ">>> Generate new source VM snapshots"
write-output "--------------------------------------------------------------------------"
$vms = Get-Tintrivm -Refresh -svr $src | Where {$_.islive -and $_.vmware.name -like $vmw_pfx+"*"} | Sort-Object -property @{Expression={$_.vmware.name}} 
$snaps = $vms | Get-TintriVMSnapshot
$snaps | Select-Object Description,consistency,createtime,vmname | Format-Table -autosize


write-output "--------------------------------------------------------------------------"
write-output ">>> Starting vmotion virtual machine migration on $($src.HostNameOrIp)"
write-output "  vm.count: $($vms.Count)"
write-output "--------------------------------------------------------------------------"

$jobs = @()
$command = { param($vmSrc, $vmDst, $vmName, $destDs)
                import-module TintriPsCoreToolkit
                $srcCmd = Connect-TintriServer $vmSrc.HostNameOrIp $using:source_tsvr_username $using:source_tsvr_password -wa:SilentlyContinue
                $dstCmd = Connect-TintriServer $vmDst.HostNameOrIp $using:target_tsvr_username $using:target_tsvr_password -wa:SilentlyContinue
                $outfile = ($using:output_dir+"\$vmName-"+(get-date).ToString("yyyyMMddTHHmmss")+".log")
                write-host ">>> Start-TintriVMMigration -svr $($vmSrc.HostNameOrIp) -svrdst $($vmDst.HostNameOrIp) -Name $vmName -datastore $destDs -confirm:$false -out $outfile"
                # NOTE: for greater diagnostic detail you can add -verbose and -debug to output to the log files
                Start-TintriVMMigration -svr $srcCmd -svrdst $dstCmd -Name $vmName -datastore $destDs -passThru -confirm:$false *> $outfile
            }
$jobs = $vms | ForEach-Object { start-ThreadJob -name ($_.vmware.name+"-migrate-job") -scriptblock $command -ThrottleLimit 7 -ArgumentList $src, $dst, $_.vmware.name,$target_datastore}


write-output "--------------------------------------------------------------------------"
write-output ">>> Wait for JOBS(RELOCATE_VM) started on $($src.HostNameOrIp)"
write-output "  Started job.Count:[$($jobs.Count)] $($jobs[-1].name)"
write-output "--------------------------------------------------------------------------"
$jobs | Format-Table -autosize
$jobs | Receive-Job -wait

    
write-output "--------------------------------------------------------------------------"
write-output ">>> Show tasks(RELOCATE_VM) on source $($src.HostNameOrIp):"
write-output "--------------------------------------------------------------------------"
$tasks = Get-TintriTaskStatus -SearchAllTintriServers | Where {$_.Type -eq "RELOCATE_VM" } | sort-object -property LastUpdatedTime
$tasks | Select-Object state,Type,JobDone,ProgressDescription,ProgressPercent -expand Uuid | select Type,JobDone,Uuid,ProgressDescription,ProgressPercent,State | Format-Table -autosize    


write-output "--------------------------------------------------------------------------"
write-output ">>> Show start-VMMigration output captured in logs:"
write-output "--------------------------------------------------------------------------"
Get-ChildItem $output_dir | Get-Content
