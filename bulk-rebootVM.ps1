<#
Tested with PowerClI Version 6.5

This script allows you to restart an array of servers trough PowerCLI.
You will be prompted to specify your ESXi-Host /vCenter Environment. Ensure that you enther the FQDN.

The script will reboot your servers without confirmation.
#>

#13.11.2018 Restart a list/array of Servers through vCenter/Powercli
 
IF(!(Get-Module vm* | where { $_.Name -eq 'VMware.VimAutomation.Core'})){
       (Get-Module –ListAvailable VMware.VimAutomation.Core | Import-Module)
         if (-not (Get-Module -Name 'VMware.VimAutomation.Core')){
               Write-Warning "Could not find/load 'PowerCLI Module.  Ensure that you are running this Script on Server with PowerCLI."
               return
         }
}

 
Write-Host "####################################" -ForegroundColor Yellow
$vCenter = Read-Host -prompt "Please enter the Name of your ESXi Host or vCenter" 

Connect-VIServer $vCenter
$server = @(
# Enter Servernames here -> Equivalent to the Name of the VM-Target                   
"Hostname-Server1"
"Hostname-Server2"
"Hostname-Server3"
)
 
 
foreach ($server in $server){
    try{
        Restart-VM -VM $server -Confirm:$false
        write-host "Reboot OK $server" -ForegroundColor Green
    }catch{
        write-host "Reboot NOT OK $server" -ForegroundColor yellow
          }
}

Disconnect-VIServer -Server $vCenter -Confirm:$false
