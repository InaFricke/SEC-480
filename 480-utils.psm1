
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

function Get-IPs {
    param (
        [string[]]$VMNames
    )
    foreach ($name in $VMNames) {
        Get-IP -VMName $name
    }
}


# Function to start a VM by name
function Start-LabVM {

    param (
        [string]$VMName
    )

    # Retrieve VM object
    $vm = Get-VM -Name $VMName -ErrorAction Stop

    # Start the VM
    Start-VM -VM $vm -Confirm:$false | Out-Null

    # Return updated VM object
    return (Get-VM -Name $VMName)
}

# Function to stop a VM by name
function Stop-LabVM {

    param (
        [string]$VMName
    )

    # Retrieve VM object
    $vm = Get-VM -Name $VMName -ErrorAction Stop

    # Stop the VM
    Stop-VM -VM $vm -Confirm:$false | Out-Null

    # Return updated VM object
    return (Get-VM -Name $VMName)
}

# Adds a network adapter
function Add-NetworkAdapter {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VM,                  # Name of the VM

        [Parameter(Mandatory = $true)]
        [string]$NetworkName,         # Target portgroup/network to connect to

        [bool]$StartConnected = $true # Whether the adapter should start connected
    )

    # Get the VM object
    $vmObject = Get-VM -Name $VM -ErrorAction Stop

    # Check if the network exists on the host
    $network = Get-VirtualNetwork -Name $NetworkName -ErrorAction Stop

    # Add the new network adapter
    $newAdapter = New-NetworkAdapter `
        -VM $vmObject `
        -NetworkName $NetworkName `
        -StartConnected:$StartConnected

    # Return the new adapter object
    return $newAdapter
}

#  Sets a specific network adapter on a VM to a new network 
function Set-Network {

    param (
        [string]$VMName,        # Name of VM
        [int]$AdapterNumber,    # Adapter number (1 = eth0, 2 = eth1, etc.)
        [string]$NetworkName    # Target network / portgroup
    )

    # Retrieve VM object
    $vm = Get-VM -Name $VMName -ErrorAction Stop

    # Retrieve target network object (ensures it exists)
    $network = Get-VirtualNetwork -Name $NetworkName -ErrorAction Stop

    # Retrieve specific network adapter
    $adapter = Get-NetworkAdapter -VM $vm |
               Where-Object { $_.Name -eq "Network adapter $AdapterNumber" }

    if (-not $adapter) {
        throw "Network adapter $AdapterNumber not found on VM '$VMName'."
    }

    # Set adapter to new network
    Set-NetworkAdapter `
        -NetworkAdapter $adapter `
        -NetworkName $NetworkName `
        -Confirm:$false | Out-Null

    # Return updated adapter information
    return (Get-NetworkAdapter -VM $VMName |
            Where-Object { $_.Name -eq "Network adapter $AdapterNumber" })
}

# Sets a static IP configuration on a Windows VM using Invoke-VMScript and netsh
function Set-WindowsIP {

    param (
        [string]$VMName,          # Name of the VM
        [string]$IPAddress,       # Static IP address
        [string]$SubnetMask,      # Subnet mask
        [string]$Gateway,         # Default gateway
        [string]$DNS,             # DNS server
        [string]$GuestUser,       # Guest OS username
        [string]$GuestPassword,   # Guest OS password
        [string]$Interface        # Network interface name
    )

    # Build netsh commands to set static IP and DNS
    $script = @"
netsh interface ip set address name="$Interface" static $IPAddress $SubnetMask $Gateway
netsh interface ip set dns servers name="$Interface" static $DNS
"@

    # Execute script inside the guest OS
    Invoke-VMScript `
        -VM $VMName `
        -ScriptText $script `
        -GuestUser $GuestUser `
        -GuestPassword $GuestPassword `
        -ScriptType Bat
}

# Export all functions for use in driver

Export-ModuleMember -Function New-VMClone, New-Network, Get-IP, Get-IPs, Start-LabVM, Stop-LabVM, Add-NetworkAdapter, Set-Network, Set-WindowsIP
