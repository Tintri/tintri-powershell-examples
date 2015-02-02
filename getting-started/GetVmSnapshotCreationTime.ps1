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

Import-Module 'C:\Program Files\TintriPSToolkit\TintriPSToolkit.psd1'

# Connect to the Tintri server.
# Password will be requested in a Windows pop-up.
$conn = Connect-TintriServer -Server $tintriServer -UserName $user
if ($conn -eq $null) {
    Write-Host "Connection Error"
    return
}

# Show the appliance version
$myHost = $conn.ApplianceHostName
$myApiVersion = $conn.ApiVersion
Write-Verbose "Connected to $myHost at $myApiVersion."

# Obtain all the VMs associated with this Tintri server.
Write-Verbose "Collecting VM information."
$vms = Get-TintriVM
Write-Verbose "VM information collected."

# Go through all the VMs and find the latest Snapshot create time.
$vms | ForEach-Object -Process {
    $vmName = $($_.vmware.name)

    $ss = Get-TintriVmSnapshot -VM $_
    if ($ss -eq $null) {
        Write-Verbose "No Snapshot for $vmName"
    }
    else {
        $createDate = $ss[-1].CreateDate
        Write-Verbose "$vmName : $createDate"

        $ssObj = New-Object -TypeName PSObject
        $ssObj | Add-Member -MemberType NoteProperty -Name VmName -Value ($vmName)
        $ssObj | Add-Member -MemberType NoteProperty -Name latestSnapshotTime -Value ($createDate)
        Write-Output $ssObj     
    }
}

# Disconnect from the Tintri server.
Disconnect-TintriServer -TintriServer $conn

Write-Verbose "Disconnected from $myHost."

