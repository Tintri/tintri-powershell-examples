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

#
# Pipes an object with the VM name and its latest snapshot
# creation time stamp.
#
# Input positional parameters:
#    1. Tintri server name or IP address
#    2. Optional user name which defaults to "admin"
# Will prompt for password.

[CmdletBinding()]
param([String]$tintriServer,
      [String]$user="admin")


if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Write-Verbose "Import the Tintri Powershell Toolkit module [TintriPS$($tpsEdition)Toolkit].`n"
Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


Write-Verbose "Connecting to a tintri server $tintriserver.`n"
$conn = Connect-TintriServer -Server $tintriserver -UserName $tsusername -Password $tspassword -SetDefaultServer
if ($conn -eq $null) {
    Write-Error "Connection Error"
    return
}


$myHost = $conn.ApplianceHostName
$myApiVersion = $conn.ApiVersion
Write-Verbose "Connected to $myHost at $myApiVersion."

# Obtain all the VMs associated with this Tintri server.
Write-Verbose "Collecting VM information."
$vms = Get-TintriVM
Write-Verbose "VM information collected."

# Go through all the VMs and find the lastest Snapshot create time.
$vms | ForEach-Object -Process {

    if (!$_.Snapshot) 
	{
        Write-Verbose "No Snapshot for $($_.Vmware.Name)"
    }
    else 
	{
        Write-Verbose "$($_.Vmware.Name) : $($_.Snapshot.Latest.CreateTime)"

        $snapObject = New-Object -TypeName PSObject
        $snapObject | Add-Member -MemberType NoteProperty -Name VmName -Value $_.Vmware.Name
        $snapObject | Add-Member -MemberType NoteProperty -Name latestSnapshotTime -Value $_.Snapshot.Latest.CreateTime
        Write-Output $snapObject     
    }
}


Write-Verbose "Disconnecting from $myHost."

# Disconnect from the Tintri server.
Disconnect-TintriServer -TintriServer $conn

