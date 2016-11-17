## Veeam Backup with Tintri QoS

Tintri has a QoS feature that allows the storage bandwidth to be set for each VM.  However,
when a backup occurs, QoS can slow the backup down so that it takes too long.  With the
script, Veeam_Backup_Tintri_QoS.ps1, the QoS is temporaily changed to allow the backup to
complete as quickly as possible.

### Requirements
The following is required:

1. Windows 7 and Windows Server 2008 R2 or later, x64, Microsoft PowerShell 3.0 and Microsoft .NET Framework 4.5 or later. VMstores must run Tintri OS version 3.2.1 or later. This maps to API v310.21 or later.
1. Microsoft PowerShell 3.0 and Microsoft .NET Framework 4.5 or later.
1. TGC 2.0 or later which monitoring VMstores on Tintri OS version 3.2.1 or later. This maps to API v310.21 or later.
1. Tintri Automation Toolkit 3.0 
1. VeeamPSSnapIn.  Check [here](https://www.veeam.com/kb1489) for details on how to obtain.

### Start-up

The Veeam server and TGC server passwords must be configured in the script.  Open the script in a editor, and look for
`$veeamPassword` and `$tgcPassword` and set the strings to the appropriate values.

### Executing
The first two input parameters, Veeam server and TGC server, are required. The next 
two parameters, user names,
default to "administrator" for the VeeamServer and "admin" for the TGC server.

`Veeam_Backup_Tintri_QoS.ps1 VeeamServer myTGC` 

If different users are needed, then they can be specified like this: 

   `Veeam_Backup_Tintri_QoS.ps1 VeeamServer myTGC backupAdmin tgcAdmin`

Finally there is a debug option:

   `Veeam_Backup_Tintri_QoS.ps1 VeeamServer myTGC administrator admin $True`

### Discussion
Veeam_Backup_Tintri_QoS polls the Veeam server every 10 seconds. If a Veeam backup
job has started, the script finds the VMs' associated storage.  If the associated storage is on a VMstore and has QoS set, then
the QoS is cleared and the original values are stored for use later.
When the Veeam backup job is done, the VMs' original QoS is set from the stored values.

There is a current log file, VeeamTintri.log.  Every 24 hours or when the script is started,
a new log file is created. Old log files are archived with a timestamp, for example,
VeeamTintri_201611151903.log. Everything that is logged is displayed on STDOUT.

Beacause the Veeam backups can be few and far between, the TGC connection is closed and opened 
approximately every hour so the the TGC connection does not time-out. TGC connection activity
is logged in the log file.

If by chance, the script crashes or the machine running the script crashes, some VMs
might have their QoS values cleared. Since the QoS values are not permanently
stored, an admin will have to review the log file for the original QoS values and
set those values manually. To find the values in the log file, look for a line
containing "*Clearing*" which contains the original minimum and maximum QoS for
the name VM.

