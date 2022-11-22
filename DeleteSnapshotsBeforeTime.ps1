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
    Deletes Snapshots before a specified Date, Time, and midday
#>
param([Parameter(Mandatory=$true)]
      [String]$tintriServer,

      [Parameter(Mandatory=$false)]
      [String]$username="admin",
	  
      [Parameter(Mandatory=$true)]
      [String]$password,

      [Parameter(Mandatory=$false)]
      [String]$date=(get-date -format "MM/dd/yyy"),

      [Parameter(Mandatory=$false)]
      [String]$time="00:00:01",

      [Parameter(Mandatory=$false)]
      [String]$midday="PM"
     )

# import the tintri toolkit 
Write-Host ">>> Import the Tintri Powershell Toolkit module.`n"
if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Import-Module -force "C:\Program Files\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


# Delete snapshots before a specified time.
Function Process-Snapshots {
    param([Object]$snapshots,
          [String]$dateTimeBefore)

    $numDeleted = 0

    ForEach ($snapshot in $snapshots) {
        Write-Host("$($snapshot.CreateTime) - $($snapshot.Description)")
        $ssCreateTime = Get-Date $snapshot.CreateTime
        if ($ssCreateTime -le $dateTimeBefore) {
            Write-Host("    Removing $ssCreateTime - $($snapshot.Description)")
            Remove-TintriVMSnapshot -Snapshot $snapshot -Force -WarningAction SilentlyContinue
            $numDeleted += 1
        }
    }

    return $numDeleted
}


# Main

# Verify input date.
$inputDateTime = $date + " " + $time + " " + $midday
Try
{
    $dateTime = Get-Date $inputDatetime
}
Catch
{
    Write-Host "Date Input error.  Date must be dd/mm/yyyy. Time must be HH:MM:SS."
    Write-Host "AM/PM is optional with AM as the default"
    Exit
}
Write-Host "Will delete Snapshots before $datetime"
    
# Connect to the Tintri server.
$conn = Connect-TintriServer -Server $tintriserver -UserName $username -Password $password -SetDefaultServer -ErrorVariable connError
if ($conn -eq $null) {
    Write-Error "Connection to storage server:$tintriserver failed Error:$connError."
    return
}

$myHost = $conn.ApplianceHostName
Write-Host "Connected to $myHost."

$numDeleted = 0
$stopwatch = [system.diagnostics.stopwatch]::startNew()
Try
{
    $vms = Get-TintriVM -TintriServer $conn

    ForEach ($vm in $vms) {
        Write-Host ""
        Write-Host "Processing $($vm.Vmware.Name)"
        
        $snapshots = Get-TintriVMSnapshot -VM $vm
        $numDeleted += Process-Snapshots $snapshots $dateTime
    }
    
}
Catch
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.Source
    if ($_.Exception.Source) {
        Write-Error "$FailedItem with error: $errorMessage"
    }
    Else {
        Write-Error "$errorMessage"
    }
}
$stopwatch.Stop()

# Disconnect from the Tintri server.
Disconnect-TintriServer -TintriServer $conn

Write-Host ""
Write-Host "Deleted $numDeleted snapshots in $($stopwatch.Elapsed)"
Write-Host ""
Write-Host "Disconnected from $myHost."

