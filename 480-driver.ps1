# Driver script to call utility functions
# Import module

Import-Module ./480-utils.psm1 -Force

# Connect to vCenter only if not connected

$vcenter = "vcenter.ina.local"

if (-not (Get-VIServer -ErrorAction SilentlyContinue)) {
    Connect-VIServer -Server $vcenter                          # Prompts for credentials, if not already connected
}

# Define Clone Parameters (Edit these values as needed)

$CloneType     = "Linked"         # "Linked" or "Full"
$SourceVM      = "Base-VM"        # target clone
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
    -CloneName $CloneName
