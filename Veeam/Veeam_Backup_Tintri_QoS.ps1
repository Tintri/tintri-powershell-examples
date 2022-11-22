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
.SYNOPSIS
    Changes a VM's QoS during a Veeam backup.
.DESCRIPTION
    Scans for running Veeam jobs with tasks. Each task represents a VM being
    backed up. When a VM is identified, the VM's QoS is set to infinite during
    the backup; and reset to previous values when the backup is done.
.EXAMPLE
    Veeam_Backup_Tintri_QoS $veeamServer $tgcServer $veeamUser $tgcUser
.INPUTS
    Veeam server name or IP address
    TGC server or IP address
    Veeam user name
    TGC user name
    Optional debug parameter.  Default is false.
.OUTPUTS
    Status to standard out and a log file, VeeamTintri.log.
.ASSUMPTIONS
    Assumes that the Veeam PowerShell Module and the Tintri PowerShell Toolkit
    are install. PowerShell 3.0 and above and .NET 4.5 and above are required.
#>

# Veeam_Backup_Tintri_QoS input parameters
[cmdletbinding()]
param([Parameter(Mandatory=$true, ValueFromPipeline=$false)]
      [String]$veeamServer,
      [Parameter(ValueFromPipeline=$false)]
      [String]$veeamUser="administrator",
      [Parameter(ValueFromPipeline=$false)]
      [String]$veeamPassword=$null,
      [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
      [String]$tgc,
      [Parameter(ValueFromPipeline=$false)]
      [String]$tgcUser="admin",
      [Parameter(ValueFromPipeline=$false)]
      [String]$tgcPassword=$null,
      [Parameter(ValueFromPipeline=$false)]
      [switch]$inDebug=$False)



# import the tintri toolkit 
if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Write-Host "Importing the Tintri Powershell Toolkit module [TintriPS$($tpsEdition)Toolkit]."
Import-Module -force "${ENV:ProgramFiles}\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


Write-Host "Importing the veeam module Veeam.Backup.PowerShell."
Import-Module -force Veeam.Backup.PowerShell


# Needs to be modified for current environment, if not passed in
if ($null -eq $veeamPassword) { $veeamPassword = "Veeam_Password"}
if ($null -eq $tgcPassword) { $tgcPassword = "TGC_Password" }

# Standard log file name
$logFile = "VeeamTintri.log"

# Writes a time stamped and typed string to the host and a log file.
function Print-It
{
    param([String]$type,
          [String]$output)

    $formattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $text = "$formattedDate [${type}] $output"
    Write-Host $text
    $text | Out-File $logFile -Append
}


# Writes an info typed string.
function Print-Info
{
    param([String]$output)

    Print-It "Info " $output
}


# Writes an error typed sting.
function Print-Error
{
    param([String]$output)

    Print-It "ERROR" $output
}


# Writes a debug typed string if in debug mode.
function Print-Debug
{
    param([String]$output)

    If ($inDebug)
    {
        Print-It "DEBUG" $output
    }
}


<#
.SYNOPSIS
    Renames the log file to log file with date and time.
.DESCRIPTION
    Adds the the date and time to the end of the log file name.
.EXAMPLE
    Rename-Log-File $logfile
.INPUTS
    log file name.
.OUTPUTS
    None.
#>
Function Rename-Log-File
{
    [cmdletbinding()]
    param([String]$logfile)

    $now = Get-Date
    $nowStr = $now.ToString("yyyyMMddHHmm")

    $logfileParts = $logfile.Split(".")

    $newLogfile = $logfileParts[0] + "_" + $nowStr + "." + $logfileParts[1]
    Rename-Item -path $logfile -NewName $newLogfile
}


<#
.SYNOPSIS
    Initializes the specified log file.
.DESCRIPTION
    Initializes the specified log file. If it already exists, rename
    the file with a data suffix.
.EXAMPLE
    Initial-Logfile $logfile
.INPUTS
    The name of a log file
    
#>
function Initial-Logfile {
    [cmdletbinding()]
    param([String] $logfile)

    # Rename log file is already exists.
    If (Test-Path $logFile) {
        Rename-Log-File $logfile
    }

    # Clear log file
    "" | Out-File $logFile
}

    
<#
.SYNOPSIS
    Connect to a specified Tintri server.
.DESCRIPTION
    Connects to a Tintri server and verifies product type and API version.
    If it fails, an exception is thrown.
    Password will be prompted for.
.EXAMPLE
    Connect-Titnri $server $user $password $product)
.INPUTS
    Tintri server name.
    Tritri server user name.
    Tintri server user password.
    Tintri server product.
.OUTPUTS
    Tintri session connection object.
#>
Function Connect-Tintri-Server
{
    [cmdletbinding()]
    param([String]$tintriServer,
          [String]$tintriUser,
          [String]$tintriPassword,
          [String]$tintriProduct)
    
    Print-Info "Attempting $tintriServer with $tintriUser"
    $conn = Connect-TintriServer -Server $tintriServer -UserName $tintriUser -Password $tintriPassword
    if (! $conn) {
        Throw "$tintriServer Connection Failure"
    }
    
    $myHost = $conn.ApplianceHostName

    $productName = $conn.ApiInfo.ProductName
    if ($productName -ne $tintriProduct) {
        Throw "Server needs to be $($tintriProduct), not $productName"
    }
    $majorVersion = $conn.ApiMajorVersion
    $minorVersion = $conn.ApiMinorVersion
    if ($majorVersion -ne "v310") {
        Throw "Incorrect major version $majorVersion.  Should be v310."
    }
    if ($minorVersion -lt 41) {
        Throw "Incorrect minor version $minorVersion.  Should be 41 or greater."
    }

    Print-Info "Connected to $myHost with $($majorVersion).$($minorVersion)"
    return $conn
}

<#
.SYNOPSIS
    Connect to a specified TGC server.
.DESCRIPTION
    Connects to a TGC server and verifies if server is a TGC and verifies the
    API version.  An exception will be thrown if error.
    Password will be prompted.
.EXAMPLE
    Connect-Tgc $server $user
.INPUTS
    TGC server name.
    TGC user name.
    TGC user password.
.OUTPUTS
    TGC session connection object.
#>
Function Connect-Tgc
{
    [cmdletbinding()]
    param(
        [String]$tgcServer,
        [String]$tgcUser,
        [String]$tgcPassword)
    
    $conn = Connect-Tintri-Server $tgcServer $tgcUser $tgcPassword "Tintri Global Center"
    
    return $conn
}


<#
.SYNOPSIS
    Manages a running Veeam job
.DESCRIPTION
    
.EXAMPLE
    Manage-Running-Job $job
.INPUTS
    Veeam job to manage.
.OUTPUTS
    The job session's tasks.
#>
function Manage-Running-Job
{
    [cmdletbinding()]
    param([Object]$job)

    $jobName = $job.Name
    $jobId = $job.Id.Guid
    Print-Info "Managing running job: $jobName - $jobId"

    If (-not $jobsRunning.ContainsKey($jobId))
    {
        Print-Info "Find last Session for $jobName"
        $session = $job.FindLastSession()
        If ($session -eq $Null)
        {
            Throw "Last Session for $jobName is null"
        }

        $jobsRunning.Add($jobId, $session)
        Print-Info "$jobName - $jobId added to the jobs running list"
    }
    Else
    {
        Print-Debug "$jobName already present"
        $session = $jobsRunning.Get_Item($jobId)       
    }

    # Obtain the last task information    
    $taskSessions = $session.GetTaskSessions()
    If ($taskSessions -eq $Null)
    {
        Print-Error "Null tasks in last session for job $jobName"
        Return $Null
    }
        
    If ($taskSessions.Count -eq 0)
    {
        Print-Info "$jobName has no tasks yet"
        Return $Null
    }
    
    Print-Debug "Returning task sessions"
    Return $taskSessions    
}


<#
.SYNOPSIS
    Manages a stopped Veeam job
.DESCRIPTION
    
.EXAMPLE
    Manage-Stopped-Job $job
.INPUTS
    Veeam job to manage.
.OUTPUTS
    The last job session's tasks or null which indicates no tasks to process.
#>
function Manage-Stopped-Job
{
    [cmdletbinding()]
    param([Object]$job)

    $jobName = $job.Name
    $jobId = $job.Id.Guid
    
    If ($jobsRunning.ContainsKey($jobId))
    {
        Print-Info "Managing stopped job: $jobName - $jobId"
        $session = $jobsRunning.Get_Item($jobId)
        $jobsRunning.Remove($jobId)
        Print-Info "Job $jobName is stopped ($($jobId))"

        $taskSessions = $session.GetTaskSessions()
        If ($taskSessions -eq $Null)
        {
            Print-Error "Null tasks in last session for job $jobName"
            Return $Null
        }
        
        If ($taskSessions.Count -eq 0)
        {
            Print-Info "$jobName has no more tasks"
            Return $Null
        }
        Return $taskSessions
    }

    Return $null
}

<#
.SYNOPSIS
    Set QoS on a VM
.DESCRIPTION
    Set VM QoS to the specified input values. 
.EXAMPLE
    Set-Qos $tgcConn $vm $minIops $maxIops
.INPUTS
    TGC server connection.
    The Tintri VM object to set the QoS on.
    Minimum IOPS to set
    Maximum IOPS to set
.OUTPUTS
    
#>
function Set-Qos
{
    [cmdletbinding()]
        param([Object]$tgcConn,
              [Object]$vm)

    $minIops = $vm.QosConfig.MinNormalizedIops
    $maxIops = $vm.QosConfig.MaxNormalizedIops

    If (($minIops -gt 0) -and ($maxIops -gt 0))
    {
        Set-TintriVMQos -VM $vm -MaxNormalizedIops $maxIops -MinNormalizedIops $minIops
        Print-Info "   Set $($vm.VMware.Name) QoS to $minIops, $maxIops"
    }
    ElseIf ($maxIops -gt 0)
    {
        Set-TintriVMQos -VM $vm -MaxNormalizedIops $maxIops
        Print-Info "   Set $($vm.VMware.Name) max QoS to $maxIops"
    }
    ElseIf ($minIops -gt 0)
    {
        Set-TintriVMQos -VM $vm -MinNormalizedIops $minIops
        Print-Info "   Set $($vm.VMware.Name) min QoS to $minIops"
    }
    Else
    {
        Print-info "   Not setting QoS for $($vm.VMware.Name)"
    }
}


<#
.SYNOPSIS
    Set back-up QoS on a VM.
.DESCRIPTION
    Set the QoS when the VM is being backed-up.  Currently, which is unrestrained.
.EXAMPLE
    Set-Backup-Qos $tgcConn $vm
.INPUTS
    TGC server connection.
    The Tintri VM object to set the QoS on.
.OUTPUTS
    
#>
function Set-Backup-Qos
{
    [cmdletbinding()]
    param([Object]$tgcConn,
          [Object]$vm)

    # If QoS is not set, don't do anything.
    If (($vm.QosConfig.MinNormalizedIops -eq 0) -and ($vm.QosConfig.MaxNormalizedIops -eq 0))
    {
        Print-Info "   Not clearing $($vm.VMware.Name) for back-up"
        Return
    }

    Set-TintriVMQos -VM $vm -ClearMinNormalizedIops -ClearMaxNormalizedIops
    Print-Info "   Clearing QoS $($vm.VMware.Name) for back-up from $($vm.QosConfig.MinNormalizedIops), $($vm.QosConfig.MaxNormalizedIops)"
}


<#
.SYNOPSIS
    Manage tasks within a session.
.DESCRIPTION
    Tasks are with a session which is an execution of a job.
    This function manages the tasks which map to VMs.
.EXAMPLE
    Manage-Running-Tasks $taskSessions $tgcConn
.INPUTS
    A list of tasks from a Veeam session.
    TGC server connection.
    
#>
function Manage-Running-Tasks
{
    [cmdletbinding()]
    param([Object[]]$taskSessions,
          [Object]$tgcConn)

$runningTasks = $taskSessions.Count   
Print-Info "Manage $runningTasks running tasks"

    # Loop through all the tasks in the list.
    ForEach ($taskSession in $taskSessions)
    {
        # Veeam task name is the VM name.
        $taskName = $taskSession.Name
        $taskStatus = $taskSession.Status
        $taskId = $taskSession.Id.Guid

        if ($taskName -eq $null)
        {
            Print-Error "taskName is null???"
            Print-Error $taskSession
            Return
        }
        if ($taskStatus -eq $null)
        {
            Print-Error "$taskName has null status"
            Return
        }
        
        Print-Info "   $taskName - $taskStatus - $taskId"

        If ($taskStatus -eq "InProgress")
        {
            If (-not ($vmsRunning.ContainsKey($taskName)))
            {
                # Get the VM information. If no information, assume VM is
                # not attached to Tintri storage and carry on.
                $vm = Get-TintriVM -TintriServer $tgcConn -Name $taskName
                If ($vm -eq $null)
                {
                    Print-Error "$taskName is not associated with TGC"
                    Continue
                }

                # Add the VM to the list of running VMs.
                $vmsRunning.Add($taskName, $vm)

                # Set the back-up QoS values.
                Set-Backup-QoS $tgcConn $vm
                Print-Debug "   $taskName is in progress" 
            }
        }
        Else
        {
            If ($vmsRunning.ContainsKey($taskName))
            {
                # Task is now stopped, but was running due to the fact
                # that the VM is present in the vmsRunning list.
                # Obtain VM informaiton
                $vm = $vmsRunning.Get_Item($taskName)

                # Set VM QoS back to original values.
                # Remove from VMs running list.
                Set-Qos $tgcConn $vm
                $vmsRunning.Remove($taskName)
                Print-Info "   $taskName is stopped"
            }
        }   
    }
}


# Main

# Global variables
$sleepSeconds = 10
$tgcConn = $null
$tgcConnected = $false
$veeamConnected = $false

# Global hashes to keep cached information.
$jobsRunning = @{}
$vmsRunning = @{}

# Initial log file
Initial-Logfile $logfile
Print-Info "Veeam Tintri VM Monitor"

Try
{
	Disconnect-VBRServer -ea SilentlyContinue
	
    # Connect to the Veeam server.
    Connect-VBRServer -Server $veeamServer -User $veeamUser -Password $veeamPassword
    $veeamConnected = $true
    Print-Info "Veeam server connected"

    # Connect to the TGC server.
    $tgcConn = Connect-Tgc $tgc $tgcUser $tgcPassword
    $tgcConnected = $true
    Print-Info "TGC connected"

    $aliveCount = 0  # Represents ~10 seconds
    $tgcConnectCount = 0  # Represents 1 minute

    While ($true)
    {
        # Sleep 10 seconds
        Start-Sleep $sleepSeconds 

        # Get the Veeam jobs
        $veeamJobs = Get-VBRJob
        $numVeeamJobs = $($veeamJobs.Count)
        Print-Debug "Number of Veeam Jobs: $numVeeamJobs"

        # Look for Veeam jobs running.
        ForEach ($job in $veeamJobs)
        {
            $jobRunning = $job.IsRunning
            $jobRunString = If ($jobRunning) {"Running"} Else {"Stopped"}          
            Print-Debug "$($job.Name): $jobRunString ($($job.Id))"

            If ($jobRunning)
            {
                # Job is running, so manage the running job's tasks.
                $taskSessions = Manage-Running-Job $job
                if ($taskSessions -eq $null)
                {
                    Continue
                }

                Manage-Running-Tasks $taskSessions $tgcConn
            }
            Else
            {
                # Job is stopped, so manage any tasks we think are still
                # running.  If any task sessions are returned, then
                # take care of them.
                $taskSessions = Manage-Stopped-Job $job
                If ($taskSessions -ne $null)
                {
                    Manage-Running-Tasks $taskSessions $tgcConn
                }
            }
        }

        # This is the alive message which is printed approximately
        # every minute. 
        If (($aliveCount % 6) -eq 0) {
            Print-It "Alive" "$($jobsRunning.Count) out of $numVeeamJobs jobs with $($vmsRunning.Count) active"

            # Reconnect the TGC after an hour if no VMs are VMs are running.
            if (($tgcConnectCount -ge 60) -and ($vmsRunning.Count -eq 0)) {
                Disconnect-TintriServer -TintriServer $tgcConn
                $tgcConnected = $false
                $tgcConn = Connect-Tgc $tgc $tgcUser $tgcPassword
                $tgcConnected = $true
                Print-Info "TGC re-connected"
                $tgcConnectCount = -1 # Start the hour over
            }
            $tgcConnectCount += 1

            # Change logfile approximately every day.
            # 8,640 is the number of 10 seconds in a day.
            if (($aliveCount -ge 8640) -and ($vmsRunning.Count -eq 0)) {
                Initial-Logfile $logFile
                $aliveCount = -1;  # Start the day over
            }
        }
        
        $aliveCount += 1
    }
}
Catch
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.Source
    $line = $_.InvocationInfo.ScriptLineNumber
    Print-Error "Failure at line $line : $FailedItem with error: $errorMessage"
    Print-Error $_.Exception | format-list -force
}

Finally
{
    If ($veeamConnected)
    {
        Disconnect-VBRServer
        $veeamConnected = $false
        Print-Info "Disconnected from Veeam Server"
    }

    If ($tgcConnected)
    {
        Disconnect-TintriServer -TintriServer $tgcConn
        $tgcConnected = $false
        Print-Info "Disconnected from Tintri Server"
    }
}
