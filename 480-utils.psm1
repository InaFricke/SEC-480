
# Utility functions for cloning VMs: Creates either a Linked or Full clone of a VM and assigns it to a specified network.
function New-VMClone {

    param (
        [string]$CloneType,          # "Linked" or "Full"
        [string]$SourceVM,           # Name of source VM
        [string]$SnapshotName,       # Snapshot to clone from
        [string]$VMHostName,         # Target ESXi host
        [string]$DatastoreName,      # Target datastore
        [string]$NetworkName,        # Network to attach
        [string]$CloneName           # Name of new VM
    )
    
    # Retrieve required objects
    # Get source VM object
    $vm = Get-VM -Name $SourceVM -ErrorAction Stop
    
    # Get snapshot object
    $snapshot = Get-Snapshot -VM $vm -Name $SnapshotName -ErrorAction Stop
    
    # Get host and datastore
    $vmhost = Get-VMHost -Name $VMHostName -ErrorAction Stop
    $ds = Get-Datastore -Name $DatastoreName -ErrorAction Stop
    
    # Prevent duplicate VM names
    if (Get-VM -Name $CloneName -ErrorAction SilentlyContinue) {
        throw "A VM named '$CloneName' already exists."
    }

    # Create Linked Clone

    if ($CloneType -eq "Linked") {

        $newVM = New-VM `
            -Name $CloneName `
            -VM $vm `
            -ReferenceSnapshot $snapshot `
            -VMHost $vmhost `
            -Datastore $ds `
            -LinkedClone
    }

    # Create Full Clone from a temporary linked clone

    elseif ($CloneType -eq "Full") {

        $tempName = "$CloneName-temp"

        # Step 1: Create a temporary linked clone
        $tempVM = New-VM `
            -Name $tempName `
            -VM $vm `
            -ReferenceSnapshot $snapshot `
            -VMHost $vmhost `
            -Datastore $ds `
            -LinkedClone

        # Step 2: Clone from temp to create full clone
        $newVM = New-VM `
            -Name $CloneName `
            -VM $tempVM `
            -VMHost $vmhost `
            -Datastore $ds

        # Step 3: Remove temporary VM
        Remove-VM -VM $tempVM -DeletePermanently -Confirm:$false

        # Step 4: Create baseline snapshot
        New-Snapshot -VM $newVM -Name "baseline" -Description "Initial snapshot"
    }

    # Assign Network

    Get-NetworkAdapter -VM $newVM |
        Set-NetworkAdapter -NetworkName $NetworkName -Confirm:$false

    # Return created VM object
    return $newVM
}

# Export function for use in driver

Export-ModuleMember -Function New-VMClone
