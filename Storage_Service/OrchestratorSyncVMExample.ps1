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
    This code excerpt is designed to be executed from within System Center
    Orchestrator as a .NET Script Activity. It can be run from within the
    PowerShell ISE as an easy way to develop and debug it. To run from within
    Orchestrator, set the $standalone variable to $false below. Set the
    $standalone variable to $true to allow execution within PowerShell ISE.

    This code sets up input and output variables to allow it to be called from
    System Center Orchestrator Runbooks as a .NET Script (PowerShell). It
    creates a child PowerShell process per Microsoft recommendations and then
    calls a number of Tintri-specific PowerShell cmdlets from the Tintri
    Automation Toolkit (PowerShell language bindings).

    For a more detailed explanation of how this works and how to use it, visit:

        https://tintrihyperv.wordpress.com/2017/04/12/orchestration-for-enterprise-cloud/

#>

# Set this variable to $false when running under System Center Orchestrator to
# allow Orchestrator calling semantics. To run from within a PowerShell session
# or under PowerShell ISE, set this to be $true.
$standalone = $true

# environment-specific constants defined here.

$ProductionVMName = "vmlevel-app-prod"
$DeveloperVMName = "vmlevel-app-dev1"
$TintriVMstoreName = "vmstore01.vmlevel.com"

if(-not $standalone) {
    # Input parameters from previous activities in Orchestrator. This
    # subscribes us to a variable called 'VMname' that comes from the previous
    # activity in our Orchestrator workflow.
    $param = "{VMname from Initialize Data}"
} else {
    # Use pre-defined test constant when running under ISE.
    $param = $DeveloperVMName
}
if ($PSEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $PSEdition }


# Variables to hold status information to be returned
$ResultStatus = $true
$ErrorMessage = ""
$TraceLog = ""

# Arguments passed in that we'll pass on to our script block below
$ArgsList = @()
$ArgsList += $param
$ArgsList += $ProductionVMName
$ArgsList += $TintriVMstoreName
$ArgsList += $tpsEdition

# Orchestrator runs 32-bit PowerShell 2.0, which isn't good for a lot in this
# modern age. We'll start a new PowerShell session as a workaround. Once we're
# running inside that child PowerShell session, we're going to want to use
# Kerberos single-sign on to connect to the Tintri VMstore.
#
# Under PowerShell ISE, this will bring up a dialogue box prompting for a set
# of credentials. This doesn't happen under Orchestrator, but in the ISE case,
# you can add the -EnableNetworkAccess option to have SSO work.
$Session = New-PSSession -ComputerName $ENV:COMPUTERNAME

$TraceLog += "{$(Get-Date -Format o)}: Starting PowerShell Session`r`n"

# The meat of our Orchestration code is within the Script Block being passed
# to our PowerShell session for execution.
#
# This script block uses the Tintri Automation Toolkit to connect to a Tintri
# VMstore's management interface and synchronise two vDisks in a snapshot of a
# production VM to a developer VM. This makes the data on those two vDisks
# available to the guest in the developer VM.
$Results = Invoke-Command -Session $Session -ArgumentList $ArgsList -ScriptBlock {
    Param(
        [ValidateNotNullOrEmpty()][string]$VMname,
        [ValidateNotNullOrEmpty()][string]$ProdVMName,
        [ValidateNotNullOrEmpty()][string]$VMstore,
        [ValidateNotNullOrEmpty()][string]$tpsEdition
    )

    # variables returned below
    $status = $true
    $errmsg = "Success"
    $trace = ""

    # Simple function to handle consistent formatting and appending of our trace log.
    function Write-Trace(){
        [CmdletBinding()]
        param([parameter(Mandatory=$true)][String]$msg)

        $time = $(Get-Date -Format o)
        $script:trace += "{$time}: $msg`r`n"
    }

	function filterDiskList( $disks, $includeBootDisk, $description )
	{
		$disks = $disks |  sort -property Name | where {(! $_.IsSynthetic) -and ($_.IsDiskdrive) }
		if ($includeBootDisk -eq $false)
		{
			$disks = $disks |  sort -property Name | where { ($_.Name -notlike "* 0:0") }
		}
		return $disks
	}

    Write-Trace "Inside Advanced PowerShell Session"

    # Here's where we start doing Tintri-specifics
    # First, we load the Tintri Automation Toolkit
    try {
		# import the tintri toolkit 
		Write-Trace "Import the Tintri Powershell Toolkit module (TintriPS$($tpsEdition)Toolkit)."
		Import-Module -force "${ENV:ProgramFiles}\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"		
    } catch {
        # Store Error status information to be returned to Orchestrator
        $e = $error[0].Exception.Message
        Write-Trace "Tintri PST load failed on ${ENV:ComputerName} with: $e"
        $errmsg = "Failed to load Tintri Automation Toolkit on Runbook Server ${ENV:ComputerName}"
        $status = $false
    }
    # We establish a session to the Tintri VMstore
    if($status) {
        try {
            Write-Trace "Connecting to Tintri VMstore $VMstore as $(whoami)"
            $ts = Connect-TintriServer -UseCurrentUserCredentials -IgnoreCertificateWarnings -ErrorAction Stop -Server $VMstore
        } catch {
            $e = $error[0].Exception.Message
            Write-Trace "Failed to connect to $VMstore from ${ENV:ComputerName}: $e"
            $errmsg = "Failed to connect to backend storage from ${ENV:ComputerName}"
            $status = $false
        }
    }

    # We first retrieve the destination (developer) VM object
    if($status) {
        try {
            Write-Trace "Retrieving VM object for VM '$VMName'"
            $devvm = Get-TintriVM -TintriServer $ts -Name $VMName
        } catch {
            $e = $error[0].Exception.Message
            Write-Trace "Failed to retrieve VM info for ${$VMName}: $e"
            $errmsg = "Failed to retrieve information for VM $VMname"
            $status = $false
        }
    }

    # And now the source snapshot from the production VM
    if($status) {
        try {
            Write-Trace "Retrieving production VM ($ProdVMName) object"
            $prodvm = Get-TintriVM -TintriServer $ts -Name $ProdVMName
            
			Write-Trace "Retrieving snapshot for last production snapshot on VM: $ProdVMName"
            $prodsnap = Get-TintriVMSnapshot -GetLatestSnapshot -VM $prodvm
			
			$snapDescription = "$($prodsnap.Consistency) $($prodsnap.CreateTime) $($prodsnap.Description)"
            Write-Trace "Retrieving vdisks from snapshot [$snapDescription] on VM: $ProdVMName"
            $snapDisks = Get-TintriVDisk -Snapshot $prodsnap 
			
            Write-Trace "Retrieving vdisks from target development VM: $VMname"
			$vmDisks = Get-TintriVDisk -VM $DevVM
			
			$snapDisks = filterDiskList $snapDisks $false "Snapshot VM Source"
			$vmDisks = filterDiskList $vmDisks $false "VM Destination"
        } catch {
            $e = $error[0].Exception.Message
            Write-Trace "Failed to retrieve VM information for ${$VMname}: $e"
            $errmsg = "Failed to retrieve production VM info"
            $status = $false
        }
    }

    # And we finally synchronise the second and third virtual disks
    if($status) {
        try {
			$snapDisksName = $snapDisks | Select-Object Name, Path, VmName | out-string
			$vmDisksName = $vmDisks | Select-Object Name, Path, VmName | out-string
			
            Write-Trace "Syncronising virtual disks to VM: $VMname"
            Write-Trace " snapshot disks $snapDisksName."
            Write-Trace " vm disks $vmDisksName."
            $sync = Sync-TintriVDisk -VM $DevVM -SourceSnapshot $prodsnap -SnapshotDisk $snapDisks -VMDisk $vmDisks -Force
            if ($sync.State -ne 'SUCCESS') {
                throw "Sync returned ${$sync.State}"
            }
        } catch {
            $e = $error[0].Exception.Message
            Write-Trace "Failed to synchronise disks from production to ${$VMname}: $e"
            $errmsg = "Failed to synchronise data disks to $VMname"
            $status = $false
        }
    }
    
    # Close the session
    Write-Trace "Disconnecting session to Tintri VMstore"
    if ($ts) { Disconnect-TintriServer -TintriServer $ts }

    # End of Tintri-specifics

    $resultsArray = @()
    $resultsArray += $status
    $resultsArray += $errmsg
    $resultsArray += $trace
    return $resultsArray
# End of the Script Block
}

# Retrieve returned values from child PowerShell Session
$ResultStatus = $Results[0]
$ErrorMessage = $Results[1]
$TraceLog += $Results[2]

# Clean up our child PowerShell session
$TraceLog += "{$(Get-Date -Format o)}: Ending PowerShell Session`r`n"
Remove-PSSession -Session $Session

$TraceLog += "{$(Get-Date -Format o)}: PowerShell Script Activity Ending`r`n"

if($standalone) {
    # The next activity in the Orchestrator runbook should be configured to
    # subscribe to these declared variables. In the case of running standalone,
    # we simply display them to the PowerShell terminal.
    Write-Output $TraceLog
    Write-Output $ResultStatus
    Write-Output $ErrorMessage
}
