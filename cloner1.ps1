# Propmt for variables

$SourceVM = Read-Host "Enter source VM Name"
$SnapshotName = Read-Host "baseline"
$VMHostName = Read-Host "Enter VMHost name"
$DatastoreName = Read-Host "datastore2"
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

# Create seperate clone
$newvm = New-VM `
	-Name $FullCloneName `
	-VM $linkedvm `
	-VMHost $vmhost `
	-Datastore $ds `

# Snapshot full clone
$newvm | New-Snapshot -Name $SnapshotName

# Remove Temp linked clone

$linkedvm | Remove-VM -DeletePermanently -Confirm:$false
