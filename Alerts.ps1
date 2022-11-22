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
  This script demonstrates enumerating and modifying Tintri Storage Server alerts.
#>
Param(
  [string] $tintriserver,
  [string] $tsusername,
  [string] $tspassword
)


# import the tintri toolkit 
if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Write-Output ">>> Importing the Tintri Powershell Toolkit module [TintriPS$($tpsEdition)Toolkit].`n"
Import-Module -force "${ENV:ProgramFiles}\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


Write-Output ">>> Connect to a tintri server $tintriserver.`n"
($conn = Connect-TintriServer -Server $tintriserver -UserName $tsusername -Password $tspassword -SetDefaultServer) | fl *
if ($conn -eq $null) {
    Write-Error "Connection to storage server:$tintriserver failed."
    return
}


Write-Output ">>> Get all the alerts as a summary.`n"

$a = Get-TintriAlerts -IncludeAll 
$a | Select Source,Message -expand Uuid | Select Uuid,Source,Message | ft -autosize


Write-Output ">>> Get all the inbox alerts.`n"

Get-TintriAlerts -InboxAlerts | Select Source,Message -expand Uuid | Select Uuid,Source,Message | ft -autosize


Write-Output ">>> Get all the archived alerts.`n"

Get-TintriAlerts -ArchivedAlerts | Select Source,Message -expand Uuid | Select Uuid,Source,Message | ft -autosize


Write-Output ">>> Get all the alerts on the tintri server: $tintriserver.`n"

$a = Get-TintriAlerts -IncludeAll -TintriServer $conn
$a | Select Source,Message -expand Uuid | Select Uuid,Source,Message | ft -autosize


Write-Output ">>> Get a specific alert by uuid.`n"

Get-TintriAlerts -uuid $a[0].Uuid.uuid


Write-Output ">>> Mark last alert with a comment.`n"

$comment = ("Last alert updated on this date-time: " + (get-date -Format "yymmdd-HHmmss"))
$a = (get-TintriAlerts)[-1] 
$a = $a | Update-TintriAlert -Comment $comment
get-TintriAlerts | where {$_.comment -like $comment}


Write-Output ">>> Mark last inbox alert with a comment and set archived.`n"

$comment = ("Archiving last INBOX alert on this date-time: " + (get-date -Format "yymmdd-HHmmss"))
(get-TintriAlerts -InboxAlerts)[-1] | Update-TintriAlert -Comment $comment | out-null
get-TintriAlerts | where {$_.comment -like $comment} | Update-TintriAlert -State ARCHIVED


