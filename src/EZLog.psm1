﻿#Requires -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @"
    public enum MsgCategory
    {
       INF   = 0,
       WAR   = 1,
       ERR   = 2
    }
"@

Function Write-EZLog
{
<#
.Synopsis
   Utility cmdlet to write logs to disk in an easy and pragmatic way.

.DESCRIPTION
   This cmdlet allows to write timestamped and nice formatted logs with a header and footer. 
   It also allows to specify if the log entry being written is an info, a warning or an error.
   
   The header contains the following information :
       - full script path of the caller, 
       - account under the script was run,
       - computer name of the machine whose executed the script,
       - and more...
   The footer contains the elapsed time from the beginning of the log session.

.PARAMETER Header
    Mandatory switch to start a log session.

.PARAMETER Category
    Category can be one of the following value : INF, WAR, ERR

.PARAMETER Message 
    Specify the content of the data to log.

.PARAMETER Footer
    Mandatory switch to end a log session. If you omit to close your log session, you won't know how much time 
    your script was running.

.EXAMPLE
   First thing to do is write a header and define a log file where the data will be written.

   PS > Write-EZLog -Header -LogFile C:\logs\mylogfile.log
   
   Next, anywhere in your script when you need to write a log, do one of the folowing command:

   PS > Write-EZLog -Category INF -Message 'This is an info to be written in the log file'
   PS > Write-EZLog -Category WAR -Message 'This is a warning to be written in the log file'
   PS > Write-EZLog -Category ERR -Message 'This is an error to be written in the log file'

   Finaly, to close your logfile you need to write a footer, just do that:

   PS > Write-EZLog -Footer

.EXAMPLE
   If you want to see the logs in the PowerShell console whereas they are still written to disk, 
   you can specify the -ToScreen switch.
   Info entries will be written in cyan color, Yellow for warnings, and Red for the errors.

   PS > Write-EZLog -Category WAR -Message 'This is a warning to be written in the log file' -ToScreen

.NOTES
   AUTHOR: Arnaud PETITJEAN - arnaud@powershell-scripting.com
   VERSION: 1.3.0
   LASTEDIT: 2016/09/14

#>
    [cmdletBinding(DefaultParameterSetName="set1", SupportsShouldProcess=$False)]
    PARAM (
        [parameter(Mandatory=$true, ParameterSetName="set1", ValueFromPipeline=$false, position=0)]
        [MsgCategory]$Category,
       
        [parameter(Mandatory=$true, ParameterSetName="set1", ValueFromPipeline=$false, position=1)]
        [Alias("Msg")]
        [String]$Message,
       
        [parameter(Mandatory=$true, ParameterSetName="set2", ValueFromPipeline=$false)]
        [Switch]$Header,
       
        [parameter(Mandatory=$true, ParameterSetName="set3", ValueFromPipeline=$false)]
        [Switch]$Footer,

        [parameter(Mandatory=$true, ParameterSetName="set2", ValueFromPipeline=$false)]
        [String]$LogFile,
       
        [parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [Switch]$ToScreen=$false
    )
   
    $Color = 'Cyan'
        
    Switch ($PsCmdlet.ParameterSetName)
    {
       "set1"
       {
           $date = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
           switch ($Category)
           {
               INF  { $Message = "$date; INF; $Message"; $Color = 'Cyan'   ; break }
               WAR  { $Message = "$date; WAR; $Message"; $Color = 'Yellow' ; break }
               ERR  { $Message = "$date; ERR; $Message"; $Color = 'Red'    ; break }
           }
            
           Add-Content -Path $Global:LogFile -Value $Message
           break
       }
         
       "set2"
       {
          New-Variable -Name LogFile -Value $LogFile -Option ReadOnly -Visibility Public -Scope Global -force
          $currentScriptName = $myinvocation.ScriptName
          $currentUser       = $ENV:USERDOMAIN + '\' + $ENV:USERNAME
          $currentComputer   = $ENV:COMPUTERNAME
          $StartDate_str     = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
          $WmiInfos          = Get-WmiObject win32_operatingsystem
          $OSName            = $WmiInfos.caption
          $OSSP              = $WmiInfos.csdversion
          $OSArchi           = $WmiInfos.OSArchitecture
          $Message           = @"
+----------------------------------------------------------------------------------------+
Script fullname          : $currentScriptName
When generated           : $StartDate_str
Current user             : $currentUser
Current computer         : $currentComputer
Operating System         : $OSName $OSSP
OS Architecture          : $OSArchi
+----------------------------------------------------------------------------------------+

"@
          # Log file creation
          [VOID] (New-Item -ItemType File -Path $LogFile -Force)
          Add-Content -Path $LogFile -Value $Message
          break
       }
                  
       "set3"
       {
          # Extracting start date from the file header
          [VOID]( (Get-Content $Global:logFile -TotalCount 3)[-1] -match '^When generated\s*: (?<date>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})$' )
          if ($Matches.date -eq $null)
          {
             throw "Cannot get the start date from the header. Please check if the file header is correctly formatted."
          }
          $StartDate   = [DateTime]$Matches.date
          $EndDate     = Get-Date
          $EndDate_str = Get-Date $EndDate -UFormat "%Y-%m-%d %H:%M:%S"

          $duration_TotalSeconds = [int](New-TimeSpan -Start $StartDate -End $EndDate | Select-Object -ExpandProperty TotalSeconds)
          $duration_TotalMinutes = (New-TimeSpan -Start $StartDate -End $EndDate | Select-Object -ExpandProperty TotalMinutes)
          $duration_TotalMinutes = [MATH]::Round($duration_TotalMinutes, 2)
          $Message = @"

+----------------------------------------------------------------------------------------+
End time                 : $EndDate_str
Total duration (seconds) : $duration_TotalSeconds
Total duration (minutes) : $duration_TotalMinutes
+----------------------------------------------------------------------------------------+
"@
          # Append the footer to the log file
          Add-Content -Path $Global:LogFile -Value $Message
          break
       }
   } # End switch

   if ($ToScreen)
   {
       Write-Host $Message -ForegroundColor $Color
   }
}