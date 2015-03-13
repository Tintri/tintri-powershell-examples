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
# This script demonstrates obtaining Tintri alerts.

Param(
  [string] $tintriserver,
  [string] $tsusername
)

ipmo 'C:\Program Files\TintriPSToolkit\TintriPSToolkit.psd1'

# Connect to the Tintri server.
# Password will be requested in a Windows pop-up.
$conn = Connect-TintriServer -Server $tintriserver -UserName $tsusername
if ($conn -eq $null) {
    Write-Host "Connection Error"
    return
}

# Show the appliance host name and version
$myHost = $conn.ApplianceHostName
$myApiVersion = $conn.ApiVersion
Write-Verbose "Connected to $myHost at $myApiVersion."

Write-Output "Alerts:"
Get-TintriAlerts -TintriServer $conn

Write-Host "Inbox Alerts:"
$conn.Get-TintriAlerts -TintriServer $conn -InboxAlerts

Write-Host "Archived Alerts:"
Get-TintriAlerts -TintriServer $conn -ArchivedAlerts

Write-Host "Alerts with Severity 'ALERT'"
Get-TintriAlerts -TintriServer $conn | Where {$_.Severity -eq "ALERT"}
