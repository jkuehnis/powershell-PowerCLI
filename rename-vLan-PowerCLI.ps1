<#
This script changes the vLan name of each network adapter within a vCenter.
The script works with PowerCLI (tested with version 6.0 /6.5).

The following variables should be adjusted in the script.
$vcserver = “Specify FQDN.of.vcenter.”.
$VPGName = “Specify the current vLan name”.
$VPGNameNew = “Specify the new vLan name”.

#>

# by Jeremias Kühnis
#check if vmware modules are loaded
function checkmodule {

    If (!(Get-PSSnapin * | where { $_.Name -eq 'VMware.VimAutomation.Core'})) {Add-PSSnapin *}


        if (-not (Get-PSSnapin -Name 'VMware.VimAutomation.Core')) {
            write-host "VMWare PSSnapin is not loaded - PSSession/Windows will be closed in 10 seconds" -backgroundcolor "Yellow" -ForegroundColor "red"
            sleep 10
            exit
            }
        else{
        Write-Host "VMWare PSSnapin loaded" -ForegroundColor "Green"
        }
}

# VCenter you are connecting too
function connectserver{

    $vcserver= 'any.vCenter.FQDN'
    Connect-VIServer $vcserver
}

function renamevpg{
# Change VirtualPortGroup / VLANS
    $VPGName = 'XD_2011' # Variable Vlan
    $NewVPGName ='XD_2011_new'#Variable new VLAN Name

    #Set the name of the "Standard-Virtual Switch"
    $VPG = Get-VirtualPortGroup -Name $VPGName
    Set-VirtualPortGroup -VirtualPortGroup $VPG -Name $NewVPGName
    Start-Sleep 30
   # Loop to make changes to new Network Adapter

    ForEach ($adapter in (Get-NetworkAdapter * | where {$_.NetworkName -eq $VPGName})){
    Set-NetworkAdapter -NetworkAdapter $adapter -NetworkName "$NewVPGName" -Confirm:$false
    Write-Host $adapter
    }
}

checkmodule
connectserver
renamevpg
