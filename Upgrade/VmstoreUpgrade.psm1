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
    Upgrades a Tintri VMstore.

    .DESCRIPTION
    Given the VMstore hostname, administrator credentials and an upgrade package location, this script upgrades the VMstore to the package version.

    .PARAMETER VmstoreName
    The host name/FQDN/IP address of the VMstore to be upgraded.

    .PARAMETER Username
    Username for the VMstore administrator.

    .PARAMETER Password
    Password for the above user.

    .PARAMETER UpgradeFile
    Location of the upgrade package (RPM file).

    .EXAMPLE
    Import-Module .\VmstoreUpgrade.psm1
    Update-Vmstore -VmstoreName "vmstore1.mycompany.com" -Username "myadminuser" -Password "mypassword" -UpgradeFile ".\Path\To\UpgradeFile.rpm"


    Sample output:

    ##########################################################
    Attempting to upgrade vmstore1
    Username provided: myadminuser
    Upgrade file : C:\Users\TestUser\Path\To\UpgradeFile.rpm
    Connecting to the VMstore vmstore1
    Starting the appliance upgrade on vmstore1
    A request to upgrade the appliance 'vmstore1' has been sent.
    Use the Get-TintriApplianceUpgradeStatus cmdlet to monitor the upgrade process.
    Waiting for the upgrade to start. This will take about 20 seconds.
    Monitoring the upgrade process.

    Upgrade State       : Upgrade in Progress
    Current Version     : 3.2.0.1-5032.26860.13006
    Message             : An upgrade operation is in progress.
    Controller Versions : 3.2.0.1-5032.26860.13006
    Upgrade Alerts      : LOG-UPGRADE-0001: Controller starting platform software upgrade for txos-4.0.0.1-5549.29512.14386.x86_64.rpm.

    Upgrade State       : Upgrade in Progress
    Current Version     : 3.2.0.1-5032.26860.13006
    Message             : An upgrade operation is in progress.
    Controller Versions : 3.2.0.1-5032.26860.13006
    Upgrade Alerts      : LOG-UPGRADE-0001: Controller starting platform software upgrade for txos-4.0.0.1-5549.29512.14386.x86_64.rpm.

    Disconnected from vmstore1
    Attempting to reconnect...
    Waiting...
    Attempting to reconnect...
    Waiting...
    Attempting to reconnect...
    Waiting...
    Attempting to reconnect...
    Waiting...
    Attempting to reconnect...
    Waiting...
    Attempting to reconnect...
    Monitoring the upgrade process.
    Upgrade attempt complete.
    UPGRADE COMPLETE

#>

Function Update-Vmstore
{
    param(
        [string]$VmstoreName,
        [string]$Username,
        [string]$Password,
        [string]$UpgradeFile
        )

    Try
    {
        # Helper function to display the elapsed time, given a start time, end time and a message.
        Function Display-TimeTaken( $startTime, $endTime, $message)
        {
            [string]$h = ($endTime -  $startTime).Hours
            [string]$m = ($endTime -  $startTime).Minutes
            [string]$s = ($endTime -  $startTime).Seconds
            [string]$ms = ($endTime -  $startTime).Milliseconds

            Write-Host "$message [${h}:${m}:${s}.${ms}]"
        }

        # Helper function to re-connect to the Tintri server.
        function Reconnect
        {
            $connected = $false
            $retryIntervalSec = 15 # Retry every 15 sec.
            $maxAttempts = 80 # Wait 20 minutes before giving up.

            $attempts = 0

            while (-not $connected)
            {
                $attempts += 1
                Write-Output "Attempting to reconnect... (#$attempts)"

                $script:tintriServer = Connect-TintriServer -Server $VmstoreName `
                             -Credential $credentials -ErrorAction SilentlyContinue -WarningAction Ignore

                if ($script:tintriServer -eq $null)
                {
                    if ($attempts -ge $maxAttempts )
                    {
                       Throw "Unable to reconnect to the VMstore."
                    }

                    Write-Output "Waiting..."
                    Start-Sleep -Seconds $retryIntervalSec
                }
                else
                {
                    $connected = $true
                }
            }
        }

        # Log the start time
        $startTime = Get-Date

        Write-Output "`n`n##########################################################"

        Write-Output "Attempting to upgrade the VMstore $VmstoreName"
        Write-Output "Username: $Username "
        Write-Output "Upgrade file location: $UpgradeFile"

        # Import the Tintri Automation toolkit, assuming it is installed at the conventional location.
		if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
		$TINTRI_POWERSHELL_TOOLKIT="${ENV:ProgramFiles}\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"
		Write-Output "Importing the Tintri Powershell Toolkit module [TintriPS$($tpsEdition)Toolkit]."
        Import-Module -force $TINTRI_POWERSHELL_TOOLKIT

        # Create a PSCredential object
        $pass = $Password | ConvertTo-SecureString -AsPlainText -Force
        $credentials = New-Object System.Management.Automation.PSCredential($Username, $pass)

        # Script variable to hold the Tintri server session object
        $script:tintriServer

        # Connect to the VMstore, will prompt for credentials
        Write-Output "Connecting to the VMstore $VmstoreName"
        $script:tintriServer = Connect-TintriServer -Server $VmstoreName -Credential $credentials -WarningAction Ignore -SetDefaultServer
        if ($script:tintriServer -eq $null)
        {
            Throw "Could not connect to $VmstoreName."
        }

        if (Test-Path $UpgradeFile)
        {
            # Resolve the full path.
            $UpgradeFile = Resolve-Path $UpgradeFile
        }
        else
        {
            Throw "The file $UpgradeFile does not exist."
        }

        # Store the OS version before the upgrade.
        $appInfo = Get-TintriAppliance -TintriServer $script:tintriServer
        $osVersionBeforeUpgrade = $appInfo.info.OsVersion
        Write-Output "The current OS version is $osVersionBeforeUpgrade."

        # Start the upgrade process.
        Write-Output "Starting the appliance upgrade on $VmstoreName"
        Update-TintriAppliance -UpgradeFile $UpgradeFile -AdminPassword $Password -Force -Erroraction SilentlyContinue `
                -ErrorVariable uploadError -TintriServer $script:tintriServer -WarningAction Ignore
        if ($uploadError)
        {
            # Throw an exception in case of upload errors, and abort.
            Throw $uploadError
        }

        # Sleep for 20 seconds so the server's upgrade status changes from GOODFILE to UPGRADEINPROGRESS.
        Write-Output "Waiting for the upgrade to start. This will take about 20 seconds."
        Start-Sleep -Seconds 20

        # Track the upgrade
        Write-Output "Monitoring the upgrade process."

        Try
        {
            Get-TintriApplianceUpgradeStatus -TintriServer $script:tintriServer -Monitor -UpdateInterval EveryMinute `
                    -ErrorVariable upgradeError -ErrorAction SilentlyContinue
        }
        Catch
        {
            # Log any uncaught exceptions.
            Write-Output $_
        }

        # During the upgrade, the appliance is restarted and we lose our session.
        # Check if we got an error about a lost connection.
        # Reconnect and restart the monitoring.

        if ($upgradeError.Count -gt 0)
        {
            $errorCode = $upgradeError[0].FullyQualifiedErrorId.Split(",")[0]

            if ($errorCode -in "ERR-API-0104", "ConnectFailure", `
            "NameResolutionFailure", "ProxyNameResolutionFailure", "ProtocolError", "TimeoutException")
            {
                Write-Output "Disconnected from $VmstoreName."
                Reconnect

                Write-Output "Monitoring the upgrade process."
                Get-TintriApplianceUpgradeStatus -Monitor -UpdateInterval EveryMinute -TintriServer $script:tintriServer
            }
            else
            {
                Write-Output "The following error was encountered while monitoring the upgrade: $upgradeError."
            }
        }
        else
        {
             # Sometimes, the server changes into a 'completed' state before a restart.
             # Reconnect in those cases.
             Reconnect
        }

        # Uprade (be it success or failure) completed.
        Write-Output "Upgrade attempt complete."

        # Compare the OS versions before and after upgrade to determine if the upgrade completed.
        $appInfo = Get-TintriAppliance -TintriServer $script:tintriServer
        $osVersionAfterUpgrade = $appInfo.info.OsVersion

        Write-Output "The OS version after the upgrade attempt is $osVersionAfterUpgrade."

        if ($osVersionBeforeUpgrade -eq $osVersionAfterUpgrade)
        {
            Throw "The upgrade was not successful."
        }
        else
        {
            Write-Output "UPGRADE COMPLETE"
        }

        Write-Output "`n##########################################################"

        # Disconnecting from the TintriServer
        Disconnect-TintriServer -TintriServer $script:tintriServer

        # Log the end time and display the time taken.
        $endTime = Get-Date
        Display-TimeTaken  $startTime $endTime “Time taken for the upgrade:"
    }
    Catch [Exception]
    {
        Write-Output "An error was encountered."
        # Log the exception
        Write-Error ($_.Exception)
        Write-Error ($_.InvocationInfo.PositionMessage)

        # An exception might occur when disconnecting with an invalid/null session object.
        Try
        {
            Write-Output "Disconnecting from the VMstore."
            Disconnect-TintriServer -TintriServer $script:tintriServer
        }
        Catch [Exception]
        {
            # Nothing to do.
        }
    }
}

Export-ModuleMember -Function Update-Vmstore