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
  Gets and sets the VMstore appliance maintenance mode.  The PowerShell Toolkit
  is not used due to a bug in obtaining the maintenance mode with Get-TintriAppliance.
#>  

param([String]$tintriServer="ttxx",
      [String]$user="admin",
      [String]$password="password"
     )

# import the tintri toolkit 
if ($psEdition -ne "Core") { $tpsEdition = "" } else { $tpsEdition = $psEdition }
$moduleName = "TintriPS$($tpsEdition)Toolkit"
Import-Module -force "C:\Program Files\$moduleName\$moduleName.psd1"

# verify the version is appropriate
$currentVersion =  (get-module $moduleName | select version).Version
if ([Version]"$currentVersion" -ge [Version]"3.0.0.0")
{
	throw "This script is meant as an example for earlier versions (prior to 3.x) of the Tintri Powershell Toolkit (current version: $currentVersion). Please use the Enable-TintriApplianceMaintenanceMode and Disable-TintriApplianceMaintenanceMode cmdlets instead."
}

Set-Variable JSON_CONTENT "application/json; charset=utf-8"
Set-Variable APPLIANCE_URL "/api/v310/appliance/default"


function setupCertificateHandling( )
{
	# # Using self-signed certificates. See also
	# # http://stackoverflow.com/questions/12187634/powershell-invoke-restmethod-using-self-signed-certificates-and-basic-authentica
	# # https://blog.kmsigma.com/2015/12/07/powershell-function-to-suppress-https-self-signed-certificate-errors/
    $global:SKIP_CERTIFICATE_CHECK = $true
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

function tintriVersion
{
    param([String]$server)

    $versionUri = "https://$($server)/api/info"
    Write-Verbose "Login URI: $($loginUri)"

    if ($psEdition -eq "Core") {
		$resp = Invoke-RestMethod -Method Get -Uri $versionUri -ContentType $JSON_CONTENT -SkipCertificateCheck:$SKIP_CERTIFICATE_CHECK
	} else {
		$resp = Invoke-RestMethod -Method Get -Uri $versionUri -ContentType $JSON_CONTENT
	}

    return $resp
}


function tintriLogin
{
    param([String]$server)

    $loginUri = "https://$($server)/api/v310/session/login"
    Write-Verbose "Login URI: $($loginUri)"

    $loginDict = @{typeId="com.tintri.api.rest.vcommon.dto.rbac.RestApiCredentials";
                   username=$user; 
                   password=$password
                  } 

    $loginBody = $loginDict | ConvertTo-Json
    if ($psEdition -eq "Core") {
		$resp = Invoke-RestMethod -sessionVariable session -Method Post -Uri $loginUri -Body $loginBody -ContentType $JSON_CONTENT -SkipCertificateCheck:$SKIP_CERTIFICATE_CHECK
	} else {
		$resp = Invoke-RestMethod -sessionVariable session -Method Post -Uri $loginUri -Body $loginBody -ContentType $JSON_CONTENT
	}

    return $session
}


function getMaintenanceMode
{
    param([String]$server,
          [Object]$session)

    $url = "https://$($server)$($APPLIANCE_URL)/maintenanceMode"
    Write-Host "Get maintenance mode: $($url)"
    if ($psEdition -eq "Core") {
		$resp = Invoke-RestMethod -Uri $url -Method Get -WebSession $session -ContentType $JSON_CONTENT -SkipCertificateCheck:$SKIP_CERTIFICATE_CHECK
	} else {
		$resp = Invoke-RestMethod -Uri $url -Method Get -WebSession $session -ContentType $JSON_CONTENT
	}
    
    return $resp
}


function setMaintenanceMode
{
    param([Object]$maintMode,
          [String]$server,
          [Object]$session)

    $isEnabled = $maintMode.isEnabled
    $newIsEnabled = -not $isEnabled

    # Verify the user wants to set the maintenance mode.
    $pline = "Set maintenance mode from $($isEnabled) to $($newIsEnabled)? (y/n) "
    $line = Read-Host -prompt $pline
    if ($line -ne "y") {
        return
    }
    
    # Get current time in ISO format. 6 hours is the delta the GUI uses.
    $now = Get-Date
    $add6 = $now.AddHours(6)
    $nowStr = $now.ToString("yyyy-MM-ddTHH:mmzzz")
    $add6Str = $add6.ToString("yyyy-MM-ddTHH:mmzzz")

    if ($newIsEnabled) {
        # Create the maintenance mode object for enabling.
        $newMaintModeInfo = @{typeId = "com.tintri.api.rest.v310.dto.domain.beans.hardware.ApplianceMaintenanceMode";
                              endTime = $add6Str;
                              isEnabled = $newIsEnabled;
                              startTime = $nowStr
                             }
    }
    else {
        # Create the maintenance mode object for disabling.
        $newMaintModeInfo = @{typeId = "com.tintri.api.rest.v310.dto.domain.beans.hardware.ApplianceMaintenanceMode";                           
                              isEnabled = $newIsEnabled
                             }
    }

    # Create the Appliance object with the new maintenance mode object.
    $newAppliance = @{typeId = "com.tintri.api.rest.v310.dto.domain.Appliance";
                      maintenanceMode = $newMaintModeInfo
                     }

    # Create the Request object with the new object values and property to update.
    $Request = @{typeId = "com.tintri.api.rest.v310.dto.Request";
                 objectsWithNewValues = @($newAppliance);
                 propertiesToBeUpdated = @("maintenanceMode")
                }

    # Create JSON payload.
    $requestPayload = $Request | ConvertTo-Json -Depth 8

    # Set the maintenance mode.
    $url = "https://$($server)$($APPLIANCE_URL)"
    Write-Verbose "Set maintenance mode: $($url)"
	
    if ($psEdition -eq "Core") {
		$resp = Invoke-RestMethod -Uri $url -Method Put -WebSession $session -Body $requestPayload -ContentType $JSON_CONTENT -SkipCertificateCheck:$SKIP_CERTIFICATE_CHECK
	} else {
		$resp = Invoke-RestMethod -Uri $url -Method Put -WebSession $session -Body $requestPayload -ContentType $JSON_CONTENT
	}
}

function tintriLogout
{
    param([String]$server,
          [Object]$session)

    # Logout
    $logoutUri = "https://$($server)/api/v310/session/logout"
    Write-Verbose "Logout URI: $($logoutUri)"
    if ($psEdition -eq "Core") {
		$resp = Invoke-RestMethod -WebSession $session -Method Get -Uri $logoutUri -ContentType $JSON_CONTENT -SkipCertificateCheck:$SKIP_CERTIFICATE_CHECK
	} else {
		$resp = Invoke-RestMethod -WebSession $session -Method Get -Uri $logoutUri -ContentType $JSON_CONTENT
	}
}


function printMaintenanceMode
{
    param([Object]$maintenanceMode)

    $isEnabled = $maintenanceMode.isEnabled
    Write-Host "Current Maintenance Mode: $($isEnabled)"
    if ($isEnabled) {
        Write-Host "From: $($maintenanceMode.startTime)"
        Write-Host "To  : $($maintenanceMode.endTime)"
    }
    Write-Host""
}


# Main
Write-Host "Set Maintenance Mode"

Try
{
	# set how we handle certificates, tls, etc.
	setupCertificateHandling
	
	
    # Get the preferred version.
    $versionInfo = tintriVersion $tintriServer
    $productName = $versionInfo.productName
    if ($productName -ne "Tintri VMstore") {
        Throw "Tintri Server is not Tintri VMstore"
    }
	
    # Connect to the Tintri server.
    $session = tintriLogin $tintriServer  $user  $password

    # Get the VMstore maintenance mode.
    $maintMode = getMaintenanceMode $tintriServer $session

    printMaintenanceMode $maintMode

    # Now set the maintenance mode.
    setMaintenanceMode $maintMode $tintriServer $session

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

# Disconnect from the Tintri server.
if ($session)
{
	tintriLogout $tintriServer $session
}
