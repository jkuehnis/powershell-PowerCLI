<#
With the command Get-VMHost you can read values ​​such as the current memory consumption or the total number memory of a host. But I didn’t find a way to read out the value of the allocated memory of the subobjects (the VMs).

Here is an example of how this can be done. The script outputs a list of all hosts. In the attribute “AllocatedVMMemoryGB” you can see how much memory has been over-provisioned or it shows how much memory you could still use.
#>

#by J.Kühnis 20.08.2019

#Class
Class VMHost{
    [string]$Name
    [string]$ConnectionState
    [string]$PowerState
    [int]$NumCpu
    [int]$MemoryUsageGB
    [int]$AllocatedVMMemoryGB
    [int]$MemoryTotalGB
    [string]$ParentCluster
    [string]$Id
    [string]$ProcessorType
}

#Vars
$VmHostArray =@()

#MainScript
Foreach($server in Get-VMHost){
    $a = (($server | get-vm).MemoryGB | Measure-Object -sum).sum
    $server = Get-vmHost -name $server.name
    $a = ("{0:N0}" -f $server.MemoryTotalGB) - ("{0:N0}" -f $a);

    $vmhost = New-Object VMHost -Property @{Name=$server.name;ConnectionState=$server.ConnectionState;Powerstate=$server.ConnectionState;NumCpu=$server.NumCpu;MemoryUsageGB=$server.MemoryUsageGB;AllocatedVMMemoryGB=$a;MemoryTotalGB=$server.MemoryTotalGB;ParentCluster=$server.parent;ID=$server.Id;ProcessorType=$server.ProcessorType}
    
    $VmHostArray += $vmhost

    Clear-Variable -Name a,vmhost
}

#output
$VmHostArray | Format-Table

            
