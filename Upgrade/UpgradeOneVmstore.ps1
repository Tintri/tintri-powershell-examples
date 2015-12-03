<#
The MIT License (MIT)
Copyright (c) 2015 Tintri, Inc.
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

The following code demonstrates how you can perform a VMstore upgrade using the
PowerShell module VmstoreUpgrade.psm1 (located in the same directory).

# Note: Make sure that the Script Execution Policy on your system is set to run external scripts.
# See https://technet.microsoft.com/en-us/library/ee176961.aspx for details.

#>

Import-Module .\VmstoreUpgrade.psm1

Update-Vmstore -VmstoreName "vmstore1.mycompany.com" -Username "myadminuser" -Password "mypassword" -UpgradeFile ".\Path\To\UpgradeFile.rpm"
