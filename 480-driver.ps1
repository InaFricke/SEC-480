# Driver script to call utility functions
# Import module

Import-Module ./480-utils.psm1 -Force

# Connect to vCenter only if not connected
#Disconnect-VIServer -Server * -Force -Confirm:$false -ErrorAction SilentlyContinue
#Connect-VIServer -Server "vcenter.ina.local" -User "fricke-adm" -Password "RoxiRules32" # Prompts for credentials, if not already connected


# Define Clone Parameters (Edit these values as needed)

$CloneType     = "Linked"         # "Linked" or "Full"
$SourceVM      = "ubuntu.base.server"        # target clone
$SnapshotName  = "baseline"       # Always baseline
$VMHostName    = "192.168.3.208"  # 192.168.3.208
$DatastoreName = "datastore2"     # Always datastore2
$NetworkName   = "Blue1-Network"   # for network connectivity blue, 480-internal or VM
$CloneName     = "ubuntu-2"

$SwitchName    = "Blue1-Switch"
$PortGroupName = "Blue1-Network"

$Network1       = "Blue1-Network"       # Adapter 1 network (VM Network, 480-internal, Managment Network, Blue1-Network)
$Network2       = "480-internal"       # Adapter 2 network

# Execute Clone Function

New-VMClone `
    -CloneType $CloneType `
    -SourceVM $SourceVM `
    -SnapshotName $SnapshotName `
    -VMHostName $VMHostName `
    -DatastoreName $DatastoreName `
    -NetworkName $NetworkName `
    -CloneName $CloneName `

# Create Blue1 Network
 <#New-Network `
    -SwitchName "Blue1-Switch" `
    -PortGroupName "Blue1-Network" `
    -VMHostName "192.168.3.208"
#>
# Start VM
Start-LabVM -VMName $CloneName

<# Add second adapter if necessary
$adapters = Get-NetworkAdapter -VM $CloneName
if ($adapters.Count -lt 2) {
    # Add second adapter for adapter 2
    New-NetworkAdapter -VM $CloneName -NetworkName $Network2 -StartConnected
}

# Set networks
$networks = @($Network1, $Network2)
$adapters = Get-NetworkAdapter -VM $CloneName  # Refresh adapters list

for ($i = 0; $i -lt $adapters.Count; $i++) {
    Set-Network -VMName $CloneName -AdapterNumber ($i + 1) -NetworkName $networks[$i]
}
#>
# Test Get-IP (and MAC when powered on)
Get-IP -VMName $CloneName

# Stop VM
#Stop-LabVM -VMName $CloneName

