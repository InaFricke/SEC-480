# Propmt for variables

$SourceVM = Read-Host "Enter source VM Name"
$SnapshotName = Read-Host "Enter snapshot name: baseline"
$VMHostName = Read-Host "Enter VMHost name: 192.168.3.208"
$DatastoreName = Read-Host "enter datastore name: datastore2"
$WANNetwork = Read-Host "enter wan name: 480-internal"
$FullCloneName = Read-Host "Enter name of full clone"

#Connect
Connect-VIServer -Server $vcenter

# Choose source vm
$vm = Get-VM -Name $SourceVM
$snapshot = Get-Snapshot -VM $vm -Name $SnapshotName
$vmhost = Get-VMHost -Name $VMHostName
$ds = Get-Datastore -Name $DatastoreName

# Linked Clone Name

$linkedClone = "{0}.linked" -f $vm.name

# Creating temp linked clone

$linkedvm = New-VM `
	-LinkedClone `
	-Name $linkedClone `
	-VM $vm `
	-ReferenceSnapshot $snapshot `
	-VMHost $vmhost `
	-Datastore $ds `
# Join WAN

Get-NetworkAdapter -VM $linkedvm | Set-NetworkAdapter -NetworkName $WANNetwork -Confirm:$false
