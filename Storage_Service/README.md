## Tintri PowerShell example for System Center Orchestrator ##

This directory contains an example piece of PowerShell code that is designed to be called as a .NET Script activity in System Center Orchestrator (tested against SCO 2016).

Following Microsoft best practices, it creates a child session to escape the shackles of PowerShell 2.0 built into System Center, and then uses the Tintri Automation Toolkit to sync two data vDisks of a developer VM from the latest snapshot of a production VM. This allows many developers to work against copies of production data without the need for expensive dump/restore operations.

In addition to the comments in the script itself, the use case and the specific details of the script and its use are covered in a blog series located here:

https://tintrihyperv.wordpress.com/2017/04/12/orchestration-for-enterprise-cloud/

