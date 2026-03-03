
# Creates either a Linked or Full clone of a VM and assigns it to a specified network.
function New-VMClone {

    param (
        [string]$CloneType,          # "Linked" or "Full"
        [string]$SourceVM,           # Name of source VM
        [string]$SnapshotName,       # Snapshot to clone from
        [string]$VMHostName,         # Target ESXi host
        [string]$DatastoreName,      # Target datastore
        [string]$NetworkName,        # Network to attach to VM
        [string]$CloneName           # Name of new VM
    )
    
    # Retrieve required VMware objects
    # Get source VM object
    $vm = Get-VM -Name $SourceVM -ErrorAction Stop
    
    # Get snapshot object from source vm
    $snapshot = Get-Snapshot -VM $vm -Name $SnapshotName -ErrorAction Stop
    
    # Get target ESXI host
    $vmhost = Get-VMHost -Name $VMHostName -ErrorAction Stop

    # Get datastore object
    $ds = Get-Datastore -Name $DatastoreName -ErrorAction Stop
    
    #validation checks
    # Prevent duplicate VM names
    if (Get-VM -Name $CloneName -ErrorAction SilentlyContinue) {
        throw "A VM named '$CloneName' already exists."
    }
    # Validate Clone type param
     if ($CloneType -ne "Linked" -and $CloneType -ne "Full") {
        throw "CloneType must be 'Linked' or 'Full'."
    }


    
    # Linked Clone creation

    if ($CloneType -eq "Linked") {

        $newVM = New-VM `
            -Name $CloneName `
            -VM $vm `
            -ReferenceSnapshot $snapshot `
            -VMHost $vmhost `
            -Datastore $ds `
            -LinkedClone
    }

    # Full Clone creation from temporary linked clone

    elseif ($CloneType -eq "Full") {

        #temp vm name to convert the linked clone to a full clone
        $tempName = "$CloneName-temp"

        # Step 1: Create a temporary linked clone
        $tempVM = New-VM `
            -Name $tempName `
            -VM $vm `
            -ReferenceSnapshot $snapshot `
            -VMHost $vmhost `
            -Datastore $ds `
            -LinkedClone

        # Step 2: Create full clone from temporary VM
        $newVM = New-VM `
            -Name $CloneName `
            -VM $tempVM `
            -VMHost $vmhost `
            -Datastore $ds

        # Step 3: Remove temporary VM
        Remove-VM -VM $tempVM -DeletePermanently -Confirm:$false

        # Step 4: Create/ Take baseline snapshot
        New-Snapshot -VM $newVM -Name "baseline" -Description "Initial snapshot"
    }

    # Assign Network
    # Attach all network adapters on the new VM to the specified network
    Get-NetworkAdapter -VM $newVM |
        Set-NetworkAdapter -NetworkName $NetworkName -Confirm:$false

    # Return created VM object for future use in functions
    return $newVM
}


function New-Network {

    param (
        [string]$SwitchName,
        [string]$PortGroupName,
        [string]$VMHostName
    )

    # Get ESXi host
    $vmhost = Get-VMHost -Name $VMHostName -ErrorAction Stop

    # prevent a duplicate switch from being created
if (Get-VirtualSwitch -VMHost $vmhost -Name $SwitchName -ErrorAction SilentlyContinue) {
    throw "Virtual Switch '$SwitchName' already exists."
}

    # Create Virtual Switch
    $vSwitch = New-VirtualSwitch `
        -VMHost $vmhost `
        -Name $SwitchName

    # Create Portgroup
    $portGroup = New-VirtualPortGroup `
        -VirtualSwitch $vSwitch `
        -Name $PortGroupName
        
    # Returns structured data
[PSCustomObject]@{
    VMHost    = $VMHostName
    Switch    = $SwitchName
    PortGroup = $PortGroupName
    Status    = "Created"
}
}

# gets the  vm name, IPv4 address, and the MAC address

function Get-IP {

    param (
        [string]$VMName
    )
    # get vm object
    $vm = Get-VM -Name $VMName -ErrorAction Stop

    # Get first network adapter
    $adapter = Get-NetworkAdapter -VM $vm | Select-Object -First 1

    $mac = $adapter.MacAddress

    # Get first IPv4 addresses only (not ipv6)
    
   $ip = $vm.Guest.IPAddress |
      Where-Object { $_ -match '\.' } |
      Select-Object -First 1
    # return structured output
    [PSCustomObject]@{
        VMName = $VMName
        IP     = $ip
        MAC    = $mac
    }
}
# Export all functions for use in driver

Export-ModuleMember -Function New-VMClone, New-Network, Get-IP
