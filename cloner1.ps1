
#Connect to vcenter and validate it works

do {
    $vcenter = Read-Host "Enter vCenter Server"

    try {
        Connect-VIServer -Server $vcenter -ErrorAction Stop | Out-Null
        $connected = $true
        Write-Host "Connected successfully to $vcenter" -ForegroundColor Green
    }
    catch {
        Write-Host "Connection failed. Please try again." -ForegroundColor Red
        $connected = $false
    }

} while (-not $connected)

# Select clone type
Write-Host "Select Clone Type: 1 (Linked clone) 2 (Full clone)

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


