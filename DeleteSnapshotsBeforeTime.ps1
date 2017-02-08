# The MIT License (MIT)
#
# Copyright (c) 2016 Tintri, Inc.
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

#------------------------------------------------------------------------------
# Deletes Snapshots before a specified Date, Time, and midday
#------------------------------------------------------------------------------

param([Parameter(Mandatory=$true)]
      [String]$tintriServer="ttha21",

      [Parameter(Mandatory=$true)]
      [String]$user="admin",

      [Parameter(Mandatory=$true)]
      [String]$date="1/1/2000",

      [Parameter(Mandatory=$true)]
      [String]$time="00:00:01",

      [Parameter(Mandatory=$false)]
      [String]$midday="AM"
     )

Import-Module 'C:\Program Files\TintriPSToolkit\TintriPSToolkit.psd1'


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
# Password will be requested in a Windows pop-up.
$conn = Connect-TintriServer -Server $tintriServer -UserName $user -ErrorVariable connError
if (!$conn)
{
    Write-Error "Connection Error on $tintriServer - $connError"
    Exit
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

