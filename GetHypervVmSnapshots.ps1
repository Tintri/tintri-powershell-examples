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
  The following code snippet shows how the Tintri Automation Toolkit interoperates with  
  Microsoft Hyper-V Manager cmdlets.

  We can pass Hyper-V Manager VM objects as input to Tintri cmdlets.
  - Requires Tintri Automation Toolkit 1.5 or above.
#>  
Param(
  [string] $tintriserver,
  [string] $tsusername,
  [string] $tspassword,
  [string] $hypervHost,
  [string] $hypervVmName
)
  

# import the tintri toolkit 
if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
Write-Host "Importing the Tintri Powershell Toolkit module [TintriPS$($tpsEdition)Toolkit].`n"
Import-Module -force "${ENV:ProgramFiles}\TintriPS$($tpsEdition)Toolkit\TintriPS$($tpsEdition)Toolkit.psd1"


# connect to the tintri storage server
Write-Host "Connecting to a tintri server $tintriserver."
($conn = Connect-TintriServer -Server $tintriserver -UserName $tsusername -Password $tspassword -SetDefaultServer) | fl *
if ($conn -eq $null) {
    Write-Error "Connection to storage server:$tintriserver failed."
    return
}

# Get VMs on a Hyper-V machine

# We'll do a remote invocation of "Get-VM" on the Hyper-V host, in the case where 
# we are not part of the same domain. Note that the hypervHost needs to be in the list
# of trusted hosts, for the call to succeed. For more information on how to do this,
# see https://technet.microsoft.com/en-us/magazine/ff700227.aspx 

# This will prompt for credentials.
Write-Host "Fetching VM : $hypervVmName from the remote Hyper-V host $hypervHost (will prompt for credentials)"
$hypervVm = Invoke-Command -ComputerName $hypervHost -ScriptBlock `
{ 
    Param([string] $vmName)    
    Get-VM -Name $vmName 
} -ArgumentList $hypervVmName -Credential "" -Debug
$hypervVm

# Note:
# If we are part of the same domain, we can simply run:
# $hypervVm = Get-VM -Name $hypervVmName -ComputerName $hypervHost


# Resolve the corresponding Tintri VM object from VMstore
Write-Host "Resolving the corresponding TintriVM object for $hypervVmName from VMstore"
Get-TintriVM -VM $hypervVm
 
# Pass the Hyper-V VM object as input to the Tintri 'Get Snapshots' cmdlet.
Write-Host "Passing the Hyper-V VM as input to fetch its VMstore snapshots"
$hypervVm | Get-TintriVMSnapshot