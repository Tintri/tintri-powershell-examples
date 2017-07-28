# The MIT License (MIT)
#
# Copyright (c) 2017 Tintri, Inc.
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

<#
.SYNOPSIS
    Manages system properties.
    
.DESCRIPTION
    Lists, gets, sets, or resets system properties.

.PARAMETER Server
    The VMstore name or IP address.
.PARAMETER Username
    The user name to login into the VMstore.
.PARAMETER Password
    The user name's password.  If Password or Credential are not specified, then a
    password will be requested in a standard Windows Credential window.
.PARAMETER Credential
    Window Credentials. If Credential or Password are not specified, then a 
    password will be requested in a standard Windows Credential window.
.PARAMETER List
    Obtains all the system properties' names, custom values, default values, and
    associated metrics. This is the default if no verb specified.
.PARAMETER Get
    Obtains the specified system property's name, custom value, default value, 
    and associated metric.
    Format: -Get <system property>
.PARAMETER Set
    Sets the specified system property's custom value. System property details
    are available in the SystemProperty API documentation
    Format: -Set <system property>, <value>
.PARAMETER Reset
    Resets the specified system property to the default value.
    Format: -Reset <system property>
.PARAMETER Force
    Forces a 'Set' or 'Reset' values to be set.  This is only valid when an error message is
    returned that states that '-Force' can be used.

.INPUTS
    Only one verb can be specified: -List, -Get, -Set, or -Reset. -Force is valid with with -Set
    and -Reset.

    Current system properties are:
        "com.tintri.space.usedPercentAlertLowThreshold"
        "com.tintri.space.usedPercentAlertHighThreshold"
        "com.tintri.performance.reservesUsedPercentAlertThreshold"
        "com.tintri.space.usedPercentDisableSnapshotsThreshold"
        "com.tintri.space.usedPercentDisableReplicationThreshold"

    System property names can be shorted.  For example, space.usedPercentAlertHighThreshold 
    is equivalent to com.tintri.space.usedPercentAlertHighThreshold.

.OUTPUTS
    The script has the following output:

    System Property                                          Custom Value Default Value Metric
    ---------------                                          ------------ ------------- ------
    com.tintri.space.usedPercentAlertLowThreshold                ---          90%        42%   
    com.tintri.space.usedPercentAlertHighThreshold               ---          98%        42%   
    com.tintri.performance.reservesUsedPercentAlertThreshold     20%          100%       27%   
    com.tintri.space.usedPercentDisableReplicationThreshold      ---          95%        42%   
    com.tintri.space.usedPercentDisableSnapshotsThreshold        23%          98%        42%   

    Where:
        System Property  the full name of the system property.
        Custom Value     the custom value of the system property. "---" means that a
                         custom value is not set.
        Default Value    the default value of the system property.  The default value is
                         used if "---" is in the custom value.
        Metric           the current metric value related to the system property. This metric
                         is useful when determining a custom threshold.

    More details on the system properties are available in the SystemProperty API documentation.

    All commands and outputs are logged to TintriThreshold.log in the directory running the
    script. The log file is renamed after a size of 1 MB is reached.

.EXAMPLE
    --------------------------  EXAMPLE 1  --------------------------

    > .\SysPropertyManager.ps1 tintri42 admin
    
    Lists all the system properties names, custom values, default values, and
    associated metrics.


    --------------------------  EXAMPLE 2  --------------------------

    > .\SysPropertyManager.ps1 tintri42 admin -List

    Lists all the system properties names, custom values, default values, and
    associated metrics.


    --------------------------  EXAMPLE 3  --------------------------

    > .\SysPropertyManager.ps1 tintri42 admin -Password pass23 -Get com.tintri.space.usedPercentAlertHighThreshold

    Get the system property com.tintri.space.usedPercentAlertHighThreshold's custom value,
    default value, and associated metric.


    --------------------------  EXAMPLE 4  --------------------------

    > .\SysPropertyManager.ps1 tintri42 admin -Set com.tintri.space.usedPercentAlertHighThreshold,85

    Set the system property com.tintri.space.usedPercentAlertHighThreshold's custom value to 85.


    --------------------------  EXAMPLE 5  --------------------------

    > .\SysPropertyManager.ps1 tintri42 admin -Reset com.tintri.space.usedPercentAlertHighThreshold

    Reset the system property com.tintri.space.usedPercentAlertHighThreshold's to the default value.


    --------------------------  EXAMPLE 6  --------------------------

    > .\SysPropertyManager.ps1 tintri42 admin -Set space.usedPercentAlertHighThreshold,66 -Force

    Set the system property com.tintri.space.usedPercentAlertHighThreshold's custom value to 66,
    after an error occurred that recommended the use of -Force option to set the value.

        --------------------------  EXAMPLE 7  --------------------------

    > $cred = Get-Credential -UserName $user -Message "Please enter password for $user"
    > .\SysPropertyManager.ps1 tintri42 admin -Credential $cred -Set space.usedPercentAlertHighThreshold,90
    > .\SysPropertyManager.ps1 tintri42 admin -Credential $cred -Set space.usedPercentAlertLowThreshold,85
    > .\SysPropertyManager.ps1 tintri42 admin -Credential $cred -List

    Obtain a credential for a specified user, and use those credentials as input to multiple
    SysPropertyManager cmdlets. Set the system property com.tintri.space.usedPercentAlertHighThreshold's
    custom values to 90, and com.tintri.space.usedPercentAlertLowThreshhold's custom value to 85, and
    list the system properties.
    
#>


[cmdletbinding()]
Param([parameter(Mandatory=$true, Position=1)]
      [String]$Server,

      [parameter(Mandatory=$true, Position=2)]
      [String]$Username="admin",

      [parameter(Mandatory=$false)]
      [String]$Password,

      [parameter(Mandatory=$false)]
      [PSCredential]$Credential,

      [parameter(Mandatory=$false)]
      [switch]$List,

      [parameter(Mandatory=$false)]
      [String]$Get,

      [parameter(Mandatory=$false)]
      [String[]]$Set,

      [parameter(Mandatory=$false)]
      [String]$Reset,

      [parameter(Mandatory=$false)]
      [switch]$Force
     )

Import-Module 'C:\Program Files\TintriPSToolkit\TintriPSToolkit.psd1'

Set-Variable JSON_CONTENT "application/json; charset=utf-8"
Set-Variable DATASTORE_URL "/api/v310/datastore/default"

# Log file name.
$logFile = "TintriThreshold.log"

# Current mapping of system properties to metric functions.
# If a system property has an associated metric, configure here with
# the appropriate function.  Currently, all functions use datastore statistics.
$sysPropertyToMetricFunc = @{
    "com.tintri.space.usedPercentAlertLowThreshold" =            "getUsedSpacePercent";
    "com.tintri.space.usedPercentAlertHighThreshold" =           "getUsedSpacePercent";
    "com.tintri.performance.reservesUsedPercentAlertThreshold" = "getUsedPerfReservePercent";
    "com.tintri.space.usedPercentDisableSnapshotsThreshold" =    "getUsedSpacePercent";
    "com.tintri.space.usedPercentDisableReplicationThreshold" =  "getUsedSpacePercent"};


# Log text with a time stamp to a pre-defined file.
function Log-It
{
    param([String]$text)

    $formattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logText = "$formattedDate $text"
    $logText | Out-File $logFile -Append
}


# Writes a typed string to the host and a log file.
function Print-It
{
    param([String]$type,
          [String]$itText,
          [parameter(Mandatory=$false)]
          [String]$color)

    $text = "[${type}] $itText"

    if ($color -eq $null) {
        Write-Host $text
    }
    else {
        Write-Host $text -ForegroundColor $color
    }
    Log-It $text
}


# Logs the text, and prints to the console if the -Verbose switch is set.
function Print-Verbose
{
    param([String]$text)

    Write-Verbose $text
    Log-It $text
}


# Writes an error typed sting.
function Print-Error
{
    param([String]$text)

    Print-It "Error" $text "Red"
}


# Renames the log file to a log file with a time stamp.
Function RenameLogFile
{
    param([String]$logfile)

    $now = Get-Date
    $nowStr = $now.ToString("yyyyMMddHHmm")

    $newLogfile = $logfile + "_" + $nowStr
    Rename-Item -path $logfile -NewName $newLogfile
}


# Initialized the log file.
function InitialLogfile {
    param([String] $logfile)

    # Rename log file if already exists and is larger that 1 megabyte.
    If ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 1MB)) {
        Rename-Log-File $logfile
    }
}


# Gets the tintri API version.
function tintriVersion
{
    param([String]$server)

    $versionUri = "https://$server/api/info"
    Write-Verbose "Version URI: $($versionUri)"

    $resp = Invoke-RestMethod -Method Get -Uri $versionUri -ContentType $JSON_CONTENT

    return $resp
}


# Logins into a Tintri server.
function tintriLogin
{
    param([String]$server,
          [String]$user,
          [String]$password)

    $loginUri = "https://$server/api/v310/session/login"
    Print-Verbose "Login URI: $($loginUri)"

    $loginDict = @{typeId="com.tintri.api.rest.vcommon.dto.rbac.RestApiCredentials";
                   username=$user; 
                   password=$password
                  } 

    $loginBody = $loginDict | ConvertTo-Json
    $resp = Invoke-RestMethod -sessionVariable session -Method Post -Uri $loginUri -Body $loginBody -ContentType $JSON_CONTENT

    return $session
}


# Logs out of a specified Tintri server.
function tintriLogout
{
    param([String]$server,
          [Object]$session)

    # Logout
    $logoutUri = "https://$($server)/api/v310/session/logout"
    Print-Verbose "Logout URI: $($logoutUri)"
    $resp = Invoke-RestMethod -WebSession $session -Method Get -Uri $logoutUri -ContentType $JSON_CONTENT
}


# Returns all system property values.
function listSystemProperties
{
    param([String]$server,
          [Object]$session)

    $url = "https://$($server)$($DATASTORE_URL)/systemProperty"
    Print-Verbose "List system property: $($url)"
    $resp = Invoke-RestMethod -Uri $url -Method Get -WebSession $session -ContentType $JSON_CONTENT
    
    return $resp
}


# Returns the specified system property values.
function getSystemProperty
{
    param([String]$server,
          [String]$sysPropName,
          [Object]$session)

    $url = "https://$($server)$($DATASTORE_URL)/systemProperty/$sysPropName"
    Print-Verbose "Get system property: $($url)"
    $resp = Invoke-RestMethod -Uri $url -Method Get -WebSession $session -ContentType $JSON_CONTENT
    
    return $resp
}


# Modifies a specified system property with the specifed value.  At this point the
# system property becomes a custom value. A force option is available to force the
# setting of the value in a warning condition. All error checking is done in the API.
function putSystemProperty
{
    param([String]$server,
          [String]$sysPropName,
          [String]$sysPropValue,
          [bool]$force,
          [Object]$session)

    # Fill in Request
    $newSysPropValues = @{typeId = "com.tintri.api.rest.v310.dto.domain.SystemProperty";
                          name = $sysPropName;
                          value = $sysPropValue
                        }

    # Create JSON payload.
    $requestPayload = $newSysPropValues | ConvertTo-Json -Depth 8
    
    $url = "https://$($server)$($DATASTORE_URL)/systemProperty"
    if ($force) {
        $url += "?force=true"
    }
    Print-Verbose "Put system property: $($url) with payload:"
    Print-Verbose $requestPayload | Format-Table

    $resp = Invoke-RestMethod -Uri $url -Method Put -WebSession $session -Body $requestPayload -ContentType $JSON_CONTENT
   
    return $resp
}


# Sets the specified system property with the specified value.
function setSystemProperty
{
    param([String]$server,
          [String]$sysPropName,
          [String]$sysPropValue,
          [Object]$session)

    putSystemProperty $server $sysPropName $sysPropValue $false $session
}


# Forces the setting of the specified system property with the specified value.
function forceSetSystemProperty
{
    param([String]$server,
          [String]$sysPropName,
          [String]$sysPropValue,
          [Object]$session)

    putSystemProperty $server $sysPropName $sysPropValue $true $session
}


# Resets the specified system property to the system default value.
function resetSystemProperty
{
    param([String]$server,
          [String]$sysPropName,
          [Object]$session)

    $url = "https://$($server)$($DATASTORE_URL)/systemProperty/$sysPropName"
    Print-Verbose "Reset system property: $($url)"
    $resp = Invoke-RestMethod -Uri $url -Method Delete -WebSession $session -ContentType $JSON_CONTENT
    
    return $resp
}


# Forces the resetting of the specified system property to the system default value.
function ForceResetSystemProperty
{
    param([String]$server,
          [String]$sysPropName,
          [Object]$session)

    $url = "https://$($server)$($DATASTORE_URL)/systemProperty/$sysPropName"
    Write-Verbose "Force Reset system property: $($url)"
    $resp = Invoke-RestMethod -Uri $url -Method Delete -WebSession $session -ContentType $JSON_CONTENT
    
    return $resp
}


# Fetch the Datastore statistics.
function getDatastoreStats
{
   param([String]$server,
         [Object]$session)

    # Get the datastore realtime statistics.
    $url = "https://$($server)$($DATASTORE_URL)/statsRealtime"
    Print-Verbose "Get realtime datastore stats: $($url)"
    $resp = Invoke-RestMethod -Uri $url -Method Get -WebSession $session -ContentType $JSON_CONTENT
    
    $items = $resp.items
    $stats = $items.sortedStats[0]

    # Unfortunately, the datastore realtime statistics obtained earlier do not include spaceTotalGiB,
    # which is only avalilable from the datastore API.
    $url = "https://$($server)$($DATASTORE_URL)"
    Print-Verbose "Get datastore information: $($url)"
    $resp = Invoke-RestMethod -Uri $url -Method Get -WebSession $session -ContentType $JSON_CONTENT
    
    # Extract spaceTotalGiB and put it in the datastore stat object.
    $spaceTotalGiB = $resp.stat.spaceTotalGiB
    $stats | Add-Member -MemberType NoteProperty -Name spaceTotalGiB -Value $spaceTotalGiB

    return $stats
}

# The next 2 functions are invoked via the $sysPropertyToMetricFunc dictionary or hash
# to obtain a metric from datastore statistics.
# New functions require only one paramenter and must be $datastoreStats.

# Returns the used space percentage.
function getUsedSpacePercent
{
    param([Object]$datastoreStats)

    $spaceUsed = $datastoreStats.spaceUsedPhysicalGiB
    $spaceTotal = $datastoreStats.spaceTotalGiB
    if ($spaceTotal -eq 0) {
        return 0
    }

    return ($spaceUsed / $spaceTotal) * 100

}


# Returns the performance reserve percentage.
function getUsedPerfReservePercent
{
    param([Object]$datastoreStats)

    return $datastoreStats.performanceReserveUsed

}


# Obtains a metric based on the system property.
# Uses the $sysPropertyToMetricFunc hash.
function getSysPropertyMetric
{
    param([Object]$sysProp,
          [Object]$datastoreStats)

    $metric = 0

    if (-not $sysPropertyToMetricFunc.ContainsKey($sysProp)) {
        return "---"
    }

    # Get the metric function name
    $metricFunc = $sysPropertyToMetricFunc.Get_Item($sysProp)

    # Call the metric function.
    $metric = & $metricFunc -datastoreStats $datastoreStats

    # Display only 3 decimals in length.
    $metric = ([math]::Truncate($metric * 10)) / 10
    return ($metric -as [String])
}


# Checks a system property name to start with "com.tintri."
# If it doesn't, it is added to the property name.
function checkSysPropName
{
    param([String]$propName)

    if ($propName.StartsWith("com.tintri.")) {
        return $propName
    }

    return "com.tintri." + $propName
}


# Log a system property object.
function logSysPropObject
{
    param([Object]$sysPropObj)

    $name = $sysPropObj.'System Property'
    $value = $sysPropObj.'Custom Value'
    $defValue = $sysPropObj.'Default Value'
    $metric = $sysPropObj.Metric

    Log-It "$name : $value : $defValue : $metric"
}


# Create system property objects for Format-Table output.
function forgeSysPropObjects
{
    param([Object[]]$sysProps,
          [Object]$datastoreStats)

    $sysPropObjects = [System.Collections.ArrayList]@()

    # For each system property, obtain the datastore metric and build the object
    # with the system property value and metric.
    foreach ($sysProp in $sysProps) {
        $metric = getSysPropertyMetric $sysProp.name $datastoreStats

        $sysPropObject = New-Object -TypeName PSObject
        $sysPropObject | Add-Member -MemberType NoteProperty -Name "System Property" -Value $sysProp.name
        if ($sysProp.custom) {
            $sysPropObject | Add-Member -MemberType NoteProperty -Name "Custom Value" -Value ("    "+$sysProp.value+"%")
        }
        else {
            $sysPropObject | Add-Member -MemberType NoteProperty -Name "Custom Value" -Value "    ---"
        }
        $sysPropObject | Add-Member -MemberType NoteProperty -Name "Default Value" -Value ("    "+$sysProp.defaultValue+"%")
        $sysPropObject | Add-Member -MemberType NoteProperty -Name "Metric" -Value (" " + $metric+"%")
        
        $sysPropObjects.Add($sysPropObject) | Out-Null
        
        #logSysPropObject $sysPropObject
        Print-Verbose $sysPropObject | Format-Table
    }

    return $sysPropObjects
}


# Main
$verbSpecified = $false
$verb = "List"  # Default

# Initialize the log file.
InitialLogfile $logFile

# Using self-signed certificates. See:
# http://stackoverflow.com/questions/12187634/powershell-invoke-restmethod-using-self-signed-certificates-and-basic-authentica
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;

        public class IDontCarePolicy : ICertificatePolicy {
        public IDontCarePolicy() {}
        public bool CheckValidationResult(
            ServicePoint sPoint, X509Certificate cert,
            WebRequest wRequest, int certProb) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = new-object IDontCarePolicy

# Process cmdlet parameters.
$numParms = $PSBoundParameters.Count
Write-Verbose("Input parameters = $numParms")

If ($PSBoundParameters.ContainsKey('List')) {
   $verbSpecified = $true
   Write-Verbose("Parsed: List")
}

If ($PSBoundParameters.ContainsKey('Get')) {
    if ($verbSpecified) {
        Write-Error "Get cannot be specified with another verb.  Use Get-Help for details"
        Exit
    }

    $verbSpecified = $true
    $verb = "Get"
    $sysPropName = checkSysPropName $Get
    Write-Verbose("Parsed: Get $sysPropName")
}

If ($PSBoundParameters.ContainsKey('Set')) {
    if ($VerbSpecified) {
        Write-Error "Set cannot be specified with another verb.  Use Get-Help for details"
        Exit
    }

    if ($Set.Count -ne 2) {
        Print-Error "The Set option requires 2 values, system property and system property value"
        Exit
    }
    
    $verbSpecified = $true
    $verb = "Set"
    $sysPropName = checkSysPropName $Set[0]
    $sysPropValue = $Set[1]
    Write-Verbose("Parsed: Set $sysPropName $sysPropValue")
}

If ($PSBoundParameters.ContainsKey('Reset')) {
    if ($VerbSpecified) {
        Print-Error "Reset cannot be specified with another verb.  Use Get-Help for details"
        Exit
    }

    $verbSpecified = $true
    $verb = "Reset"
    $sysPropName = checkSysPropName $Reset
    Write-Verbose("Parsed: Reset $sysPropName")
}

If ($PSBoundParameters.ContainsKey('Force')) {
    if ($verb -eq "Set") {
        $verb = "Force_Set"
        Write-Verbose("Parsed: Force Set $sysPropName $sysPropValue")
    }
    Elseif ($verb -eq "Reset") {
        $verb = "Force_Reset"
        Write-Verbose("Parsed: Force Reset $sysPropName")
    }
    Else {
        Print-Error "Force option is not valid with $(verb)." 
        Exit
    }
    
}

Try
{
    # Get the product in the version information.
    $versionInfo = tintriVersion $server
    $productName = $versionInfo.productName
    if ($productName -ne "Tintri VMstore") {
        Print-Error "$Server is not a VMstore, but a $productName."
        Exit
    }

    # Get the password for the server.
    if ($PSBoundParameters.ContainsKey('Password')) {
        $pass = $Password
    }
    elseif ($PSBoundParameters.ContainsKey('Credential')) {
        $pass = $Credential.GetNetworkCredential().Password
    }
    else {     
        $cred = Get-Credential -Username $Username -Message "Enter valid password for $Server"
        $pass = $cred.GetNetworkCredential().Password
    }
    
    # Login to the VMstore.
    $session = tintriLogin $Server $Username $pass
    Log-It "Connected to $Server"

    # Collect the datastore statistics
    $stats = getDatastoreStats $server $session

    # Initialize the system property object array.
    $sysPropertyObjects = [System.Collections.ArrayList]@()

    # Process the verb.
    switch ($verb) {
        "List" {
            Log-It "List all system properties"
            $sysProps = listSystemProperties $Server $session         
            }
        "Get" {
            Log-It "Get $sysPropName"
            $sysProps = getSystemProperty $Server $sysPropName $session        
            }
        "Set" {
            Log-It "Set $sysPropName at $sysPropValue"
            $result = setSystemProperty $Server $sysPropName $sysPropValue $session
            $sysProps = getSystemProperty $Server $sysPropName $session
            }
        "Force_Set" {
            Log-It "Set with Force $sysPropName at $sysPropVale"
            $result = forceSetSystemProperty $Server $sysPropName $sysPropValue $session
            $sysProps = getSystemProperty $Server $sysPropName $session
            }
        "Reset" {
            Log-It "Reset $sysPropName"
            $result = resetSystemProperty $Server $sysPropName $session         
            $sysProps = getSystemProperty $Server $sysPropName $session
            }
        "Force_Reset" {
            Log-It "Reset with Force $sysPropName"
            $result = forceResetSystemProperty $Server $sysPropName $session         
            $sysProps = getSystemProperty $Server $sysPropName $session
            }
   }
   
   # Put system property in objects for table output.
   $sysPropertyObjects = forgeSysPropObjects $sysProps $stats
   $sysPropertyObjects | Format-Table -AutoSize
}
Catch
{
    # Obtain some information
    $expMessage = $_.Exception.Message
    $failedItem = $_.Exception.Source
    $line = $_.InvocationInfo.ScriptLineNumber

    # Check if there is a response.
    if ($_.Exception.Response -eq $null) {
        Write-Error "At $($line):`r`n$expMessage"
    }
    else {
        # Get the response body with more error detail.
        $respStream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($respStream)
        $respBody = $reader.ReadToEnd() | ConvertFrom-Json
        $errorCode = $respBody.code
        $errorMessage = $respBody.message
        $causeDetails = $respBody.causeDetails
        Write-Host "At line $($line):`r`n$expMessage`r`n$($errorCode): $errorMessage`n`r   $causeDetails" -ForegroundColor Red
    } 
}

# Disconnect from the Tintri server.
tintriLogout $Server $session
