#23.12.2019 by J.Kühnis Set VMWare ESXi Host Tag
$mytag = Get-Tag -Name 'MyTagName' | ? {$_.Uid -match 'vCenterName'}
Get-vmHost | %{
    New-TagAssignment -Tag $myTag -Entity $_
}
Clear-Variable mytag
