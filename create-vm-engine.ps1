<#
Here is an example of how to make automated VM’s with PowerCLI. You can customize the vLAN, DiskType, etc.

If you reuse the Script below, I would recommend to look at the parameters and adapt them to your environment, e.g. network/storage config like the vLan,ESXI Hosts or the adapter type you are using its VMWare.

example:
Create-CustomVirtualMachine -Hostname 'MyServer' -NumCPU 6 -DiskSize 80 -RAMinGB 12 -OS Srv2016


Ensure you are using this script with PowerCLI or with the PowerCLI Module / Assemblys.

The script can also be saved and imported as a module (.psm1).

Import-Module "Path:\to\your\module\share\Create-VM_onFreeDatastore.psm1" -Verbose
below is the module to create VMs on Hypervisor with enough free ressources
#>

#by J.Kühnis 06.11.2019
    $VmHostArray = @()

    Class VMHost {
        [string]$Name
        [string]$State
        [string]$Parent
        [Array]$DatastoreIdList
        [int]$MemoryTotalGB
        [int]$MemoryUsageGB
        [int]$FreetoUseMemory
        [int]$ReservedVMmemory
        [String]$VMCreationState
        [String]$VMCacheDiskState
        [String]$ESXiHost
        [String]$PVSCollectionState
        [String]$CTXStudioState
        [String]$CTXMaintState
    }

Function Get-VMHostVirtualMachineVMs {
 
    [CmdletBinding()]
    Param(
        #[Parameter(Mandatory=$true)][string[]]$ServerName
        [Parameter(Mandatory = $true)][String] $VMhost,
        [bool]$ExtendedProperties
    )
      
    IF ($ExtendedProperties -eq $true) {
        IF ($global:VMhostsVM = (Get-VMHost -Name $VMhost | Get-VM | select MemoryGB, VMHost, Name)) {
            return $global:VMhostsVM
        }
                
    }
    Else {
        IF ($global:VMhostsVM = ((Get-VMHost -Name $VMhost | Get-VM).Name | sort)) {
            return $global:VMhostsVM
        }
    }
    return $false
}
Function Get-vmHostDataStore {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String[]]$DatastoreIDList
    )
    $global:DatastoreID = (get-datastore -Id $DatastoreIDList)           
    return  $global:DatastoreID
    
}
  
Function Create-VMEngine {
    
    
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$VMName,
        [string]$EsxiHost,
        [string]$Datastore,
        [int]$NumCPUCore,
        [int]$MemoryGB,
        [int]$DiskSize,
        $Vlan,
        $HDFormat,
        [int]$TotalCPU,
        $OS
    )

    write-host "Hypervisor Parameters:" $VMName $EsxiHost $Datastore $MemoryGB $Vlan
    write-host (get-date -f HH:mm:ss)"Start VM Creation $VmName, please wait..."
    If (Get-VM *$VMName*) {
        Write-Host "VM $VMName already exists!!!, Skip this Hostname." -ForegroundColor RED -BackgroundColor Black
        break
    }

    IF ($OS -eq 'Win10') {
        New-VM -Name $VmName -ResourcePool $EsxiHost -Datastore $Datastore -NumCPU $NumCPUCore -MemoryGB $MemoryGB -NetworkName $Vlan -GuestID windows9_64Guest -DiskGB $DiskSize -DiskStorageFormat $HDFormat
    }
    Else {
        New-VM -Name $VmName -ResourcePool $EsxiHost -Datastore $Datastore -NumCPU $NumCPUCore -MemoryGB $MemoryGB -NetworkName $Vlan -GuestID windows9Server64Guest -DiskGB $DiskSize -DiskStorageFormat $HDFormat
    }

    # Set SCSI Controller
    Get-ScsiController -VM $VmName | Set-ScsiController -Type VirtualLsiLogicSAS >$NULL -WarningAction SilentlyContinue
    Write-host "Configure VM $VMName"
       
    # Configure vCPU &amp; Core
    $VmName = Get-VM -name $VmName
    set-vm -vm $VmName -numcpu $TotalCpu -Confirm:$false >$NULL

    # Configure MAC-Address and Adapter Type
    $vm = Get-VM -Name $vmName
    $nic = Get-NetworkAdapter -VM $vm
    $global:spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $devSpec = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $devSpec.Device = $nic.ExtensionData
    $devSpec.operation = "edit"
    $spec.DeviceChange += $devSpec
    $vm.ExtensionData.ReconfigVM($spec)
    Set-NetworkAdapter -NetworkAdapter $nic -Type Vmxnet3 -Confirm:$false >$NULL

    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.Firmware = [VMware.Vim.GuestOsDescriptorFirmwareType]::bios
    try {
        $VmName.ExtensionData.ReconfigVM($spec)
    }
    catch {
    }


    #special Parameters
    New-AdvancedSetting -Entity $vm -Name ethernet0.pciSlotNumber -Value 192 -Confirm:$false -Force:$true >$NULL -WarningAction SilentlyContinue
    Write-host "VM Config finished"
    write-host (get-date -f HH:mm:ss)"VM Creation $VmName finished!" -ForegroundColor "Green"

}


Function Create-CustomVirtualMachine {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Hostname,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateRange(1, 16)][int]$NumCPU,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateRange(1, 250)][int]$DiskSize,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateRange(1, 32)][int]$RAMinGB,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateSet('Win10', 'Srv2016')][string]$OS
    )

    Write-host "------------------------"`n"| Start VmWare Section |"`n"------------------------"  -ForegroundColor WHITE
    
    (get-vmhost HYPERVISORFQDN1.corp.ads.migros.ch, HYPERVISORFQDN2.corp.ads.migros.ch | select Name, State, Parent, DatastoreIdList, MemoryTotalGB, MemoryUsageGB) | % {
        #$FreetoUseMemory = ("{0:N0}" -f $_.MemoryTotalGB) - ("{0:N0}" -f $_.MemoryUsageGB)
        $myhost = New-Object VMhost -Property @{Name = $_.Name; State = $_.State; Parent = $_.Parent; DatastoreIdList = $_.DatastoreIdList; MemoryTotalGB = $_.MemoryTotalGB; MemoryUsageGB = $_.MemoryUsageGB; }
        $VmHostArray += $myhost
    }
    
    Foreach ($VmWareHost in $VmHostArray) {
        $VmWareHost.ReservedVMmemory = ((Get-VMHostVirtualMachineVMs $VmWareHost.Name -ExtendedProperties $true).MemoryGB | Measure-Object -sum).sum
        $VmWareHost.FreetoUseMemory = ("{0:N0}" -f $VmWareHost.MemoryTotalGB) - ("{0:N0}" -f $VmWareHost.ReservedVMmemory);
    }

    $VmHostArray = $VmHostArray | Sort-Object -Property FreetoUseMemory -Descending
    

    #Check RAM Space on ESXI Host with 10GB reserves on Host
    IF (($VmHostArray[0].FreetoUseMemory - 10) -ge ($RAM)) {
        #Check if Disk has 10GB Free Storage
        IF (get-vmHostDataStore -DatastoreIDList $VmHostArray[0].DatastoreIdList) {
            $specVMDatastore = (get-vmHostDataStore -DatastoreIDList $VmHostArray[0].DatastoreIdList | Sort-Object -Property FreeSpaceGB -Descending)
            [int]$a = ("{0:N0}" -f $specVMDatastore[0].FreeSpaceGB).Replace("'", "")
            
            IF ($a -ge ($DiskSize + 10) ) {
                $specVMDatastore = $specVMDatastore[0].Name
    
                #StagingParameters
            
                $VMName = $Hostname
                $EsxiHost = $VmHostArray[0].Name
                $Datastore = $specVMDatastore
                [int]$NumCPUCore = 1
                $Vlan = 'Some_VlanName'
                $HDFormat = "Thin"
                [int]$TotalCPU = $NumCPU

                # Create VM on Host
                Create-VMEngine -VMName $VMName -EsxiHost $EsxiHost -Datastore $Datastore -MemoryGB $RAMinGB -Vlan $Vlan -NumCPUCore $NumCPUCore -HDFormat $HDFormat -TotalCPU $TotalCPU -DiskSize $DiskSize -OS $OS
                Write-host "----------------------"`n"| End VmWare Section |"`n"----------------------"  -ForegroundColor WHITE
            
            }
            Else {
                Write-host $Hostname "| not enough storage on ESXI Host! Action stopped." -ForegroundColor Yellow -BackgroundColor Black
            }
            
        }
        Else {
            Write-host $Hostname "| No Datastore found. Action stopped" -ForegroundColor Yellow -BackgroundColor Black
            
        }
    }
    Else {
        Write-Host $Hostname "| not enough on ESXI Host. Action stopped" -ForegroundColor Yellow -BackgroundColor Black

    }
}
