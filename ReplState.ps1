# The MIT License (MIT)
#
# Copyright (c) 2017 Tintri, Inc.
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

[cmdletbinding()]
Param([parameter(Mandatory=$false)]
      [String]$TintriServer,

      [parameter(Mandatory=$false)]
      [String]$User="admin",

      [parameter(Mandatory=$false)]
      [String]$ServiceGroup,

      [parameter(Mandatory=$false)]
      [String[]]$VMs,

      [parameter(Mandatory=$false)]
      [String]$VMName,

      [parameter(Mandatory=$false)]
      [String]$State="PAUSED",

      [parameter(Mandatory=$false)]
      [String]$NotState="Running",

      [parameter(Mandatory=$false)]
      [switch]$All,

      [parameter(Mandatory=$false)]
      [switch]$Help
     )

Import-Module 'C:\Program Files\TintriPSToolkit\TintriPSToolkit.psd1'

# Global variables
$ruleVms = New-Object System.Collections.ArrayList


# Add VM objects from a service group to ruleVms.
Function Get-VMs-By-ServiceGroup {
    param([String]$sgName)

    $sg = Get-TintriServiceGroup -Name $sgName
    If ($sg -eq $null) {
        Write-Host -ForegroundColor red "Service group $sgName does not exist"
        Return
    }

    $vms = Get-TintriVM -ServiceGroup $sg
    $ruleVms.AddRange($vms)
}


# Add VM objects from a list of VM names to ruleVms.
Function Get-VMs-By-VM-List {
    param([String[]] $vmNames)

    $nameToVm = @{}
    
    $vmList = Get-TintriVM

    # Build a hash of VM name to VM UUID.
    ForEach ($vm in $vmList) {
        $nameToVM.Add($vm.vmware.Name, $vm)
    }

    # Get VM UUIDs from VM names
    ForEach ($name in $vmNames) {
        If ($nameToVM.ContainsKey($name)) {
            $null = $ruleVms.Add($nameToVm.Get_Item($name))
        }
        Else {
            Write-Host -ForegroundColor Red "VM $name is unknown to TGC"
        }
    }
}


# Add VM objects from a VM name pattern to ruleVms.
Function Get-VMs-By-VM-Name {
    param([String] $pattern)

    $vmList = Get-TintriVM -Name $pattern

    ForEach ($vm in $vmList) {
        $null = $ruleVms.Add($vm)
    }
}


Function Is-State-Valid {
    param([String] $state)

    $valid_states = "PARTIALLY_RUNNING", "INCOMING", "NOT_CONFIGURED", "UP_TO_DATE",
                    "RUNNING", "SCHEDULED", "PAUSED", "EXCEEDS_RPO"

    return ($valid_states -contains $state)
}


Function Write-Name-State {
    param([string] $vmName,
          [string] $replState
         )

   $nameState = New-Object -TypeName PSObject
   $nameState | Add-Member -MemberType NoteProperty -Name VMName -Value $vmName
   $nameState | Add-Member -MemberType NoteProperty -Name ReplicationState -Value $replState
   Write-Output $nameState
}


Function Write-Help {
   Write-Host "Writes piped ouput of VM's that match the specified replication state."
   Write-Host ""
   Write-Host "ReplicationStatus.ps1 -TintriServer server [-ServiceGroup service_group_name] [-VMs list of VMs]"
   Write-Host "                      [-VMname VM name pattern] [-State state] [-NotState state] [-All]"
   Write-Host ""
   Write-Host "State is matched with the VM's replication state, while NotState matches all states except"
   Write-Host "the specified state."
   Write-Host "Possible States are: 'PARTIALLY_RUNNING', 'INCOMING', 'NOT_CONFIGURED', 'UP_TO_DATE'"
   Write-Host "                      'RUNNING', 'SCHEDULED', 'PAUSED', and 'EXCEEDS_RPO'."
   Write-Host "Only one can be specified. Default NotState is 'RUNNING'.  There is no default for State."
   Write-Host ""
   Write-Host "VMs can be specifed by -ServiceGroup, a list of -VMs, and a -VMname pattern."
   Write-Host "All VMs are collected in no VMs are specified."
   Write-Host ""
   Write-Host "The -All option will display all VMs with the replication state, and take precedence"
   Write-Host "over the -State option.  This output is not piped."
   Write-Host ""
   Exit
}


# Main 
$vmOptionSelected = $false
$stateToMatch = "no"
$stateNotToMatch = "RUNNING"
$displayStatus = $false

If (($PSBoundParameters.Count -eq 0) -or ($PSBoundParameters.ContainsKey('Help'))) {
    Write-Help
    Exit
}

If (-not $PSBoundParameters.ContainsKey('TintriServer')) {
    Write-Error "-TintriServer needs to be specified. Use -Help for details."
    Exit
}

If ($PSBoundParameters.ContainsKey('State') -and $PSBoundParameters.ContainsKey('NotState')) {
    Write-Error "Both State and NotState can be specified.  Use -Help for details."
    Exit
}

If ($PSBoundParameters.ContainsKey('ServiceGroup')) {
    $vmOptionSelected = $true
    $sgName = $ServiceGroup
    Write-Host "ServiceGroup: $sgName"
}

If ($PSBoundParameters.ContainsKey('VMs')) {
    $vmOptionSelected = $true
    $vmNames = $VMs
    Write-Host "VMs: $vmNames"
}

If ($PSBoundParameters.ContainsKey('VMName')) {
    $vmOptionSelected = $true
    $name = $VMName
    Write-Host "Name: $name"
}

If ($PSBoundParameters.ContainsKey('State')) {
    If (-not (Is-State-Valid $State)) {
       Write-Error "State specified not valid.  Use -Help for details."
       Exit
    } 
    $stateToMatch = $State
}

If ($PSBoundParameters.ContainsKey('NotState')) {
    If (-not (Is-State-Valid $NotState)) {
        Write-Error "NotState specified not valid.  Use -Help for details."
        Exit
    } 
    $stateNotToMatch = $NotState
}

If ($PSBoundParameters.ContainsKey('All')) {
    $displayStatus = $true
}

If ($displayStatus) {
    Write-Host "Display VMs and replication state"
}
Elseif ($stateToMatch -ne "no") {
    Write-Host "Checking for replication state: $stateToMatch"
}
Else {
    Write-Host "Check for replication state not: $stateNotToMatch"
}

# Connect to the Tintri server.
# Password will be requested in a Windows pop-up.
$conn = Connect-TintriServer -Server $tintriServer -UserName $user -ErrorVariable connError
if (!$conn)
{
    Write-Error "Connection Error on $tintriServer - $connError"
    Exit
}

$myHost = $conn.ApplianceHostName
Write-Host "Connected to $myHost."

Try
{
    If ($conn.ServerType -ne "TintriGlobalCenter") {
        Throw "Tintri Server is not Tintri Global Center"
    } 

    If ($vmOptionSelected) {
        # Get VM objects from the Service Group.
        If ($PSBoundParameters.ContainsKey('ServiceGroup')) {
            Get-VMs-By-ServiceGroup $sgName
        }

        # Get VM objects from a list of VM names.
        If ($PSBoundParameters.ContainsKey('VMs')) {
           Get-VMs-By-VM-List $vmNames
        }

        # Get VM objects by VM name pattern
        If ($PSBoundParameters.ContainsKey('VMName')) {
            $pattern = "*" + $name + "*"
            Write-Host "Pattern: $pattern"

            Get-VMs-By-VM-Name $pattern
        }
    }
    Else {
        $ruleVms = Get-TintriVM
    }

    Write-Host "Checking $($ruleVms.Count) VMs"
    foreach ($vm in $ruleVms) {
        $vm_repl_config = Get-TintriVMReplConfiguration -VM $vm
        If ($displayStatus) {
            Write-Name-State $vm.Vmware.Name $vm_repl_config.ReplicationState
        }
        Else {
            If ($stateToMatch -ne "no") {
                If ($vm_repl_config.ReplicationState -eq $stateToMatch) {
                    Write-Name-State $vm.Vmware.Name $vm_repl_config.ReplicationState
                }
            }
            Else {
                If ($vm_repl_config.ReplicationState -ne $stateNotToMatch) {
                    Write-Name-State $vm.Vmware.Name $vm_repl_config.ReplicationState
                }
            }
        }    
    }

}
Catch
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.Source
    $line = $_.InvocationInfo.ScriptLineNumber
    Write-Error "Line $line -`r`n$FailedItem with error: $errorMessage"
    Disconnect-TintriServer -TintriServer $conn
}

Disconnect-TintriServer $conn
