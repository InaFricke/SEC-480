# Driver script to call utility functions
# Import module

Import-Module ./480-utils.psm1 -Force

# Connect to vCenter only if not connected
Disconnect-VIServer -Server * -Force -Confirm:$false -ErrorAction SilentlyContinue
Connect-VIServer -Server "vcenter.ina.local" -User "fricke-adm" -Password "RoxiRules32" # Prompts for credentials, if not already connected


# Define Clone Parameters (Edit these values as needed)

$CloneType     = "Linked"         # "Linked" or "Full"
$SourceVM      = "vyos base"        # target clone
$SnapshotName  = "baseline"       # Always baseline
$VMHostName    = "192.168.3.208"  # 192.168.3.208
$DatastoreName = "datastore2"     # Always datastore2
$NetworkName   = "480-internal"   # for connectivity 480-internal
$CloneName     = "Test-Clone-01"

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
New-Network `
    -SwitchName "Blue1-Switch" `
    -PortGroupName "Blue1-Network" `
    -VMHostName "192.168.3.208"

# Test Get-IP
Get-IP -VMName "Test-Clone-01"
