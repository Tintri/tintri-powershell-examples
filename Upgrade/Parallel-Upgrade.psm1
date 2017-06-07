<#
The MIT License (MIT)
Copyright (c) 2017 Tintri, Inc.
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
  .SYNOPSIS
  This script builds on top of VmstoreUpgrade module in order to upgrade Vmstores in parallel 

  .DESCRIPTION
  The script can be used to upgrade a single Vmstore or multiple Vmstores in parallel. It accepts a JSON file for upgrading  multiple Vmstores of the following format:
  
  [
    {
        "VmstoreDnsName": "vmstore1",
        "Username": "username",
        "Password": "password",
        "UpgradePathToFile": "C:\Users\TestUser\upgrade_file.rpm"
    },
    {
        "VmstoreDnsName": "vmstore2",
        "Username": "username",
        "Password": "password",
        "UpgradePathToFile": "C:\Users\TestUser\upgrade_file.rpm"
    }
  ]

  In order to upgrade a Vmstore, the script needs the DNS name, username, password and path to upgrade rpm file which is what the JSON file contains.

  Note: For UpgradePathToFile, if file path contains backslash than it needs to be escaped as shown above. 

  It also accepts a Vmstore name, username, password and upgrade file path from the command line. The use of each parameter is explained in detail in Parameters section.  

  The script will kick off jobs in parallel for each vmstore upgrade and give the user a brief output indicating the upgrade has completed or failed. 
  There will also  be a log file created for the user for further analysis. 
  Use -Verbose to see detailed output.
   
  .PARAMETER VmstoreName
  The name of the Vmstore to be upgraded. 
  Note: Can't be used with UseJSONFile parameter. 

  .PARAMETER Username
  The username for the Vmstore
  Note: This parameter will be ignored if UseSameUsername is not used when using a JSON File for upgrade.

  .PARAMETER Password
  The password for the Vmstore.
  Note: This parameter will be ignored if UseSamePassword is not used when using a JSON File for upgrade.
  
  .PARAMETER UpgradeFile
  Note: This parameter will be ignored if UseSameUpgradeFile is not used when using a JSON File for upgrade.


  .PARAMETER UseJSONFile
  The path for JSON file to be used for upgrade.

  .PARAMETER UseSamePassword
  If used, the password in the JSON file for each vmstore will not be used. Instead, the string provided for Password parameter will be used for every Vmstore.


  .PARAMETER UseSameUsername
  If used, the username in the JSON file for each vmstore will not be used. Instead, the string provided for Username parameter will be used for every Vmstore. 


  .PARAMETER UseSameUpgradeFile
  If used, the upgrade file path present in JSON file for each vmstore will not be used. Instead, the string provided for UpgradeFile will be used for every Vmstore.

  .EXAMPLE
  Import-Module Parallel-Upgrade  
  #for upgrading one vmstore 
  Parallel-Upgrade -VmstoreName "DnsNameofVmstore"  -Password "password" -Username "username" -UpgradeFile "path_to_upgrade_file"

  

  .EXAMPLE
  Import-Module Parallel-Upgrade
  
  Parallel-Upgrade -UseJSONFile upgrade_vmstore.JSON 

  #Contents of JSON file
  [
    {
        "VmstoreDnsName": "vmstore1",
        "Username": "admin",
        "Password": "password",
        "UpgradePathToFile": "rpm_file_location"
    },
    {
        "VmstoreDnsName": "vmstore2",
        "Username": "username",
        "Password": "password",
        "UpgradePathToFile": "rpm_file_location"
    }
  
  ]

  .EXAMPLE
  Import-Module Parallel-Upgrade

  Parallel-Upgrade -UseJSONFile upgrade_vmstore.JSON -UseSamePassword -UseSameUsername -UseSameUpgradeFile

  #Contents of JSON file
  [
    {
        "VmstoreDnsName": "vmstore1"
    },
    {
        "VmstoreDnsName": "vmstore2"
    }
  
  ]

  The JSON only needs to have the VmstoreDnsName for each vmstore if the username, password and upgrade file are the same for every Vmstore. 

  Similarly, the JSON might only have VmstoreDnsname and upgrade file for each vmstore if the username and password are the same for every Vmstore. 
  The same applies for all parameters in a JSON. 

  .OUTPUTS

  Sample Output:
  
    Validating the parameters provided in the JSON file

    Starting parallel upgrade jobs
    [0:10:25.581]: Time Taken for Upgrade
    vmstore1 : UPGRADE COMPLETE
    [0:10:44.449]: Time Taken for Upgrade
    vmstore2 : UPGRADE COMPLETE
    Please inspect the file 2015-10-05-13-21-53_parallel_upgrade.log for detailed logs


#>

# This function is the one to call.
Function Parallel-Upgrade
{
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [string]$VmstoreName = $false,
	
        [ValidateNotNullOrEmpty()]
        [string]$Username = $false,

        [ValidateNotNullOrEmpty()]
        [string]$Password = $false,

        [ValidateNotNullOrEmpty()]
        [ValidateScript({Write-Output "Checking if the path given for upgrade file is valid" ; Test-Path $_})]
        [string]$UpgradeFile = $false, 

        [ValidateNotNullOrEmpty()]
        [ValidateScript({Write-Output "Checking if the path given for JSON file is valid" ; Test-Path $_ })]  #Not checking for valid JSON here; Looks messy
        [string]$UseJSONFile = $false,

        [switch]$UseSamePassword,

        [switch]$UseSameUsername,

        [switch]$UseSameUpgradeFile
   
        )

    $TINTRI_POWERSHELL_TOOLKIT='C:\Program Files\TintriPSToolKit\TintriPSToolKit.psd1'
    Import-Module $TINTRI_POWERSHELL_TOOLKIT

    Write-Verbose "the parameters provided from the command line" 
    Write-Verbose "VmstoreName : $VmstoreName"
    Write-Verbose "Username : $Username"
    Write-Verbose "UpgradeFile : $UpgradeFile"
    Write-Verbose "UseSameUsername : $UseSameUsername"
    Write-Verbose "UseSamePassword : $UseSamePassword"
    Write-Verbose "UseSameUpgradeFile : $UseSameUpgradeFile"
    Write-Verbose "UseJSONFile : $UseJSONFile "

    Write-Verbose "Trying to load the VmstoreUpgrade"

    Import-Module .\VmstoreUpgrade.psm1 -ErrorAction Stop
    Write-Verbose "VmstoreUpgrade loaded"
 

    #Validating input parameter combination
    $parameters = @($VmstoreName,$Username,$UpgradeFile,$Password)

    if ( ($UseJSONFile -eq $false) -and ($false -in $parameters)  )
    {
        write-error "If not using a JSON file for upgrade, VmstoreName, Username, Password and upgrade file is mandatory"
        return
    }
    elseif ( $false -notin @($UseJSONFile,$VmstoreName) )
    {  
        write-error "Both UseJSONFile and VmstoreName can't be used together"
        return
    }
    elseif ($UseSameUsername -and ($Username -eq $false))
    {
 
        write-error "Username is a mandatory parameter when using UseSameUsername"
        return
        
    }
    elseif ($UseSamePassword -and ($Password -eq $false) )
    {
        write-error "Password is a mandatory parameter when using UseSamePassword"
        return
    }
    elseif ($UseSameUpgradeFile -and ($UpgradeFile -eq $false) )
    {
       write-error "UpgradeFile is a mandatory parameter when using UseSameUpgradeFile"
        return
    }
    elseif ($UseJSONFile -ne $false)
    {
         try
         {
            $upgradeJSON = Get-Content -Raw -Path $UseJSONFile | ConvertFrom-JSON
         }
         catch
         {
            $_
            write-error "Error converting given JSON file to JSON"
            return
         }

    }


    # Verify if key exists and check if it is null or empty.
    Function VerifyAndCheck
    {
        param(
		        $dictionary,
                [string]$key       
	          )
        

        if(!($dictionary.$key))
        {
            Write-Verbose "$key is not present in given dictionary"
            return $false
        }

        $dictionary.$key = $dictionary.$key.Trim()

        if (!([string]::IsNullOrEmpty($dictionary.$key)) -and ($dictionary.$key -notcontains " "))
        {
           return $true
        }

        else
        {
            Write-Verbose "String contains either blank spaces or is empty"
            return $false
        }
     }


    <#
    Why is this required?
    Using PSTK module cmdlets in thread has an issue. It complains with:

        Import-Module : The current Windows PowerShell host is: 'ServerRemoteHost' (version 
        1.0.0.0). The module 'C:\Code\twin-pst15default\TintriWindowsManagement\Tintri.Windows.Powe
        rShell\Tintri.Windows.PowerShell.VMstore\bin\x64Debug\TintriPSToolkit.psd1' requires a 
        minimum Windows PowerShell host version of '3.0' to run.

    Solution: http://stackoverflow.com/questions/13146545/remote-tab-in-ise-connects-to-a-powershell-1-0-session
    #>

    Function Set-PSTKForThreading()
    {
        (Get-Content $TINTRI_POWERSHELL_TOOLKIT) | Foreach-Object {$_ -ireplace "PowerShellVersion = '3.0'", "PowerShellVersion = '1.0'"}  | Out-File $TINTRI_POWERSHELL_TOOLKIT
        (Get-Content $TINTRI_POWERSHELL_TOOLKIT) | Foreach-Object {$_ -ireplace "PowerShellHostVersion = '3.0'", "PowerShellHostVersion = '1.0'"}  | Out-File $TINTRI_POWERSHELL_TOOLKIT

    }

    Function Clear-PSTKForThreading()
    {
        (Get-Content $TINTRI_POWERSHELL_TOOLKIT) | Foreach-Object {$_ -ireplace "PowerShellVersion = '1.0'", "PowerShellVersion = '3.0'"}  | Out-File $TINTRI_POWERSHELL_TOOLKIT
        (Get-Content $TINTRI_POWERSHELL_TOOLKIT) | Foreach-Object {$_ -ireplace "PowerShellHostVersion = '1.0'", "PowerShellHostVersion = '3.0'"}  | Out-File $TINTRI_POWERSHELL_TOOLKIT

    }

    Function AddOrModifyProperty
    {
        param(
              $dictionary,
              [string]$key,
              [string]$value
              )
        
        Add-member -InputObject $dictionary -MemberType NoteProperty -Name $key -Value $value -ErrorAction SilentlyContinue -ErrorVariable addError
        if ($addError)
        {
            $dictionary.$key = $value
        }
        
        return $dictionary

    }


    # From the given JSON, we will parse and make a dictionary with all the valid fields.
    Function FindValidEntries
    {
        param(
		        [array]$upgradeJSON
	          )

        foreach ($dictionary in $upgradeJSON)
        {

            Write-Verbose "Validating the dictionary"
            Write-Verbose ($dictionary | Out-string)

            if (!(VerifyAndCheck $dictionary VmstoreDnsName))
            {
                Write-Verbose "Skipping - No valid Vmstore dns name found"
                Continue
            }

            if (!$UseSamePassword)
            {
                if (!(VerifyAndCheck $dictionary Password))
                {
                    Write-Verbose "Skipping - Valid Password not found "
                    Continue  
                }

            }

            else
            {
            
                $dictionary = AddOrModifyProperty $dictionary Password $Password 

            }

            if (!$UseSameUsername)
            {
                if (!(VerifyAndCheck $dictionary Username))
                {
                    Write-Verbose "Skipping - Valid Username not found "
                    Continue
                }
            }

            else
            {
                $dictionary = AddOrModifyProperty $dictionary Username $Username
            }

            if (!$UseSameUpgradeFile)
            {
                if (!(VerifyAndCheck $dictionary UpgradePathToFile))
                {
                    Write-Verbose "Skipping - Valid upgrade path to file not found"
                    Continue  
                }
            }

            else
            {
                $dictionary = AddOrModifyProperty $dictionary UpgradePathToFile $UpgradeFile           
            }

          $listOfValidDictionaries = $listOfValidDictionaries + $dictionary

        }

        # Now we have a list of valid dictionaries.

        # We should have at least one of these.
        Write-Verbose "Verifying if atleast one valid dictionary is present for starting the upgrade process"
        if ($listOfValidDictionaries.count -lt 1)
        {
            write-error "No valid dictionary found for upgrade process"
            exit
        }

        return $listOfValidDictionaries
    }

    
   
    #Initialize the dictionary that holds all the valid dictionaries to be used for upgrade
    $listOfValidDictionaries = @()
    
    #if upgradeJSON is present, we need to find valid dictionaries from that JSON. Otherwise, we simply create one dictionary and add it to listOfValidDictionaries
    if ($upgradeJSON)
    {
        Write-Verbose " Validating the parameters provided in the JSON file"
        $listOfValidDictionaries = FindValidEntries $upgradeJSON
    }
    else
    {
        $dict = @{}
        $dict.VmstoreDnsName = $VmstoreName
        $dict.Username = $Username
        $dict.Password = $Password
        $dict.UpgradePathToFile = $UpgradeFile

        $listOfValidDictionaries = $listOfValidDictionaries + $dict        
    }



    # At this point, we will have a list of valid dictionaries which we can parse and feed
    # to the function which actually initiates parallel upgrade and waits for it to finish.
    Function StartJobsAndGenerateLog
    {
        param(
              [array]$listOfValidDictionaries  

              )

        <# This function acceps a dicitonary and starts a job for each upgrade task in parallel.
           It then receives the job status and also create a log file for the user.
        #>

        #create an empty array to store all the jobs
        $Job = @()

        $ScriptBlock = $Function:Upgrade
    
        # create a debug file for the user 
        # yyyy-MM-dd-HH-mm-ss

        $outputFile = new-item -name "$(get-date -f yyyy-MM-dd-HH-mm-ss)_parallel_upgrade.log" -type "file"
        Write-Verbose "Created log file "

        #Set-PSTKForThreading

        Write-Verbose "Iterating over the list of dictionaries "

        Write-Output "Starting parallel upgrade jobs"
        foreach ($dictionary in $listOfValidDictionaries)
        {
      
            Write-Verbose "The current dictionary used for upgrade process is "
            Write-Verbose $dictionary


            $Username = $dictionary.Username
            $VmstoreName = $dictionary.VmstoreDnsName
            $Password = $dictionary.Password
            $UpgradeFile = $dictionary.UpgradePathToFile 

            Write-Verbose "The parameters being sent to the job $VmstoreName are"
            Write-Verbose "VmstoreName: $VmstoreName "
            Write-Verbose "Username: $Username"
            Write-Verbose "UpgradeFile :$UpgradeFile "

            $Job += start-job -ScriptBlock $ScriptBlock -ArgumentList $VmstoreName,$Username,$Password,$UpgradeFile -Name $VmstoreName
            Write-Verbose "Started a job with the name $VmstoreName"


        }

        Write-Verbose "waiting for all the jobs to complete"
        Write-Output "Waiting for all the jobs to finish execution"
        wait-job -job $Job | Out-null

        # Wait for each job to finish.
        foreach ($j in $Job)
        {    
            Receive-job -job $j -keep -outvariable output -ErrorVariable myError -ErrorAction SilentlyContinue | Out-Null
      
            if ($output)
            {
                Add-content $outputFile $output
        
                if ($output -contains "UPGRADE COMPLETE")
                {
                    Write-Output "$($j.name) : UPGRADE COMPLETE" 
                }
                else 
                {
                Write-Output "$($j.name) : UPGRADE FAILED"
                }          
            }
            Add-content $outputFile "`n`nERRORS: "
       
            if($myError)
            {
                #write-host "error exists"
                Add-Content $outputFile $myError                     
            }
            else
            {
                Add-content $outputFile "No Errors Found during the upgrade"
           
            }
           
            #Clear-PSTKForThreading

        }        
            Write-Output "Please inspect the file $($outputFile.name) for detailed logs"
     }

    # Provide the list of valid dictionaries to the function which starts the parallel upgrade jobs
 
    StartJobsAndGenerateLog $listOfValidDictionaries

}