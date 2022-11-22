﻿<#
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

param([String]$tgcServer,
      [String]$tsusername,
	  [String]$tspassword,
      [String]$csv_file)


# import the tintri toolkit 
if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


# Main

Try
{

	# connect to the tintri storage server, use user and password arguments to connect
	($conn = Connect-TintriServer -Server $tgcServer -UserName $tsusername -Password $tspassword -SetDefaultServer) | fl *
	if ($conn -eq $null) {
        Throw "Connection failure to $tgcServer"
	}
	
}
Catch
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.Source
    Write-Error "Tintri connect failure: $FailedItem with error: $errorMessage"
    Exit
}

Try
{
    $myHost = $conn.ApplianceHostName
    Write-Host "Connected to $myHost."

    $productName = $conn.ApiInfo.ProductName
    if ($productName -ne "Tintri Global Center")
    {
        Throw "Server needs to be Tintri Global Center, not $productName"
    }

    # Create an expression for Select-Object.
    $ex = @{Expression={$_.vmware.name};label="VM Name"},
          @{Expression={$_.stat.sortedstats.LatencyTotalMs};label="Total Latency"},
          @{Expression={$_.stat.sortedstats.LatencyNetworkMs};label="Network Latency"},
          @{Expression={$_.stat.sortedstats.LatencyStorageMs};label="Storage Latency"},
          @{Expression={$_.stat.sortedstats.LatencyDiskMs};label="Disk Latency"}
    $result = Get-TintriVM -TintriServer $conn | Select-Object $ex

    $result | Export-Csv $csv_file
	
	Write-Host "`nPerformance statistics staved to: $csv_file"
	get-content $csv_file
    
}
Catch
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.Source
    Write-Error "Tintri cmdlet failure: $FailedItem with error: $errorMessage"
    Write-Error "$_.Exception.StackTrace"
}

# Disconnect from the Tintri server.
Disconnect-TintriServer -TintriServer $conn

Write-Host "Disconnected from $myHost."

