
#Connect to vcenter and validate it works

do {
    $vcenter = Read-Host "Enter vCenter Server"

    try {
        Connect-VIServer -Server $vcenter -ErrorAction Stop | Out-Null
        $connected = $true
        Write-Host "Connected successfully to $vcenter" 
    }
    catch {
        Write-Host "Connection failed. Please try again." 
        $connected = $false
    }

} while (-not $connected)

# Select clone type
Write-Host "Select Clone Type: 1 (Linked clone) 2 (Full clone)"

$cloneType = Read-Host "Enter selection 1 or 2"

if ($cloneType -ne "1" -and $cloneType -ne "2") {
    Write-Host "Invalid selection. Please run the script again and select 1 or 2."
    return
}

if ($cloneType -eq "1") {
    Write-Host "You are creating a Linked Clone." 
}

if ($cloneType -eq "2") {
    Write-Host "You are creating a Full Clone." 
}

# Select source VM to clone

Write-Host "Choose target source VM from options below:" 
Get-VM | Select-Object -ExpandProperty Name

$SourceVM = Read-Host "Enter Source VM Name"

$vm = Get-VM -Name $SourceVM -ErrorAction SilentlyContinue

if (-not $vm) {
    Write-Host "Invalid VM name. Available VMs:" 
    Get-VM | Select-Object Name
    return
}

# Select snapshot 
Write-Host "Available Snapshots for $SourceVM:"
Get-Snapshot -VM $vm | Select-Object -ExpandProperty Name

$SnapshotName = Read-Host "Enter Snapshot Name (Press Enter for 'Base')"

if (-not $SnapshotName) {
    $SnapshotName = "Base"
}

$snapshot = Get-Snapshot -VM $vm -Name $SnapshotName -ErrorAction SilentlyContinue

if (-not $snapshot) {
    Write-Host "Invalid snapshot name. Available snapshots:" 
    Get-Snapshot -VM $vm | Select-Object -ExpandProperty Name
    return
}

# ESXi Host selection
Write-Host "Available ESXi Hosts:"
Get-VMHost | Select-Object Name

$VMHostName = Read-Host "Enter ESXi Host Name"

$vmhost = Get-VMHost -Name $VMHostName -ErrorAction SilentlyContinue

if (-not $vmhost) {
    Write-Host "Invalid ESXi host. Available hosts:" 
    Get-VMHost | Select-Object Name
    return
}

# Datastore selection
Write-Host "Available Datastores:"
Get-Datastore | Select-Object Name
$DatastoreName = Read-Host "Enter Datastore Name"

$ds = Get-Datastore -Name $DatastoreName -ErrorAction SilentlyContinue

if (-not $ds) {
    Write-Host "Invalid datastore. Available datastores:"
    Get-Datastore | Select-Object Name
    return
}

# Network selection
Write-Host "Available Networks"
Get-VirtualPortGroup | Select-Object Name

$NetworkName = Read-Host "Enter Network Name"

$network = Get-VirtualPortGroup -Name $NetworkName -ErrorAction SilentlyContinue

if (-not $network) {
    Write-Host "Invalid network. Available networks:" 
    Get-VirtualPortGroup | Select-Object Name
    return
}

# Clone Name + redundancy check

$CloneName = Read-Host "Enter Name of New Clone"

if (-not $CloneName) {
    Write-Host "Clone name cannot be blank." 
    return
}

$existingVM = Get-VM -Name $CloneName -ErrorAction SilentlyContinue

if ($existingVM) {
    Write-Host "A VM with this name already exists. Please choose a different name." 
    return
}


# Create the clone

if ($cloneType -eq "1") {
# Linked clone
    $newVM = New-VM -Name $CloneName `
           -VM $vm `
           -ReferenceSnapshot $snapshot `
           -VMHost $vmhost `
           -Datastore $ds `
           -LinkedClone
    New-Snapshot -VM $newVM -Name "baseline" -Description "Initial snapshot."
    Write-Host "Linked clone '$CloneName' created successfully with new snapshot named baseline."
}


if ($cloneType -eq "2") {
# Full clone - create temp linked clone first, then clone from it
    $tempName = "$CloneName-temp"
    $tempVM = New-VM -Name $tempName `
                     -VM $vm `
                     -ReferenceSnapshot $snapshot `
                     -VMHost $vmhost `
                     -Datastore $ds `
                     -LinkedClone

    $newVM = New-VM -Name $CloneName `
           -VM $tempVM `
           -VMHost $vmhost `
           -Datastore $ds
    Remove-VM -VM $tempVM -DeletePermanently -Confirm:$false
    New-Snapshot -VM $newVM -Name "baseline" -Description "Initial snapshot"
    Write-Host "Full clone '$CloneName' created successfully with new snapshot named baseline." 
}
