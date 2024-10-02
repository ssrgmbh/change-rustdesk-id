# Function to generate random alphanumeric string
function Get-RandomAlphanumericString {
    param (
        [int] $length = 12
    )
    return -join ((65..90) + (97..122) + (48..57) | Get-Random -Count $length | % {[char]$_})
}

# Function to generate random 9-digit number
function Get-Random9DigitNumber {
    return Get-Random -Minimum 100000000 -Maximum 999999999
}

function Test-RustDeskInstalled {
    $serviceExists = Get-Service -Name "RustDesk" -ErrorAction SilentlyContinue

    if (-not $serviceExists) {
        return $false
    }
    return $true
}

# Function to check if Bitwarden CLI is installed
function Test-BitwardenCLI {
    try {
        $null = Get-Command bw -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Function to install Bitwarden CLI using winget
function Install-BitwardenCLI {
    try {
        Write-Host "Installing Bitwarden CLI..."
        winget install Bitwarden.CLI
        Write-Host "Bitwarden CLI installed successfully."
        return $true
    }
    catch {
        Write-Host "Failed to install Bitwarden CLI. Error: $_"
        return $false
    }
}

# Function for improved Read-Host with Yes as default
function Read-HostWithDefault {
    param (
        [string]$prompt
    )
    $response = Read-Host "$prompt [Y]/n"
    return ($response -eq '' -or $response -eq 'y' -or $response -eq 'Y')
}

# Function to save RustDesk info to Bitwarden
function Save-ToBitwarden {
    param (
        [string]$hostname,
        [string]$newId,
        [string]$password,
        [string]$serverUrl
    )
    
    # Check if Bitwarden CLI is installed
    if (-not (Test-BitwardenCLI)) {
        if (Read-HostWithDefault "Bitwarden CLI is not installed. Do you want to install it now?") {
            if (-not (Install-BitwardenCLI)) {
                Write-Host "Unable to proceed without Bitwarden CLI."
                return
            }
        }
        else {
            Write-Host "Unable to proceed without Bitwarden CLI."
            return
        }
    }
    
    $currentServerUrl = bw config server
    if ($currentServerUrl) {
        if (Read-HostWithDefault "Current Bitwarden server is set to $currentServerUrl. Do you want to use this server?") {
            $serverUrl = $currentServerUrl
        }
        else {
            $serverUrl = Read-Host "Enter your Bitwarden server URL (e.g., https://bitwarden.example.net)"
        }
    }
    else {
        $serverUrl = Read-Host "Enter your Bitwarden server URL (e.g., https://bitwarden.example.net)"
    }

    # Check if already logged in
    $status = bw status | ConvertFrom-Json
    if ($status.status -eq "unauthenticated") {
        Write-Host "Please log in to Bitwarden..."
        $env:BW_SESSION = (bw login --raw)
    }
    else {
        # Unlock the vault
        Write-Host "Unlocking Bitwarden vault..."
        $env:BW_SESSION = (bw unlock --raw)

    }


    if (-not $env:BW_SESSION) {
        Write-Host "Failed to unlock Bitwarden vault."
        return
    }

    # Check if item already exists
    $itemName = "RustDesk - $hostname"
    $existingItem = bw list items --search $itemName | ConvertFrom-Json | Where-Object { $_.name -eq $itemName }

    $itemJson = @{
        type = 1  # 1 represents login
        name = $itemName
        notes = "RustDesk information for $hostname`nID: $newId"
        login = @{
            username = $newId
            password = $password
        }
    } | ConvertTo-Json -Compress

    if ($existingItem) {
        # Update existing item
        try {
            $result = $itemJson | bw encode | bw edit item $existingItem.id
            Write-Host "Updated existing Bitwarden entry for $hostname"
        }
        catch {
            Write-Host "Failed to update Bitwarden entry. Error: $_"
        }
    }
    else {
        # Create new item in Bitwarden
        try {
            $result = $itemJson | bw encode | bw create item
            Write-Host "Created new Bitwarden entry for $hostname"
        }
        catch {
            Write-Host "Failed to create Bitwarden entry. Error: $_"
        }
    }

    # Force a full sync
    try {
        Write-Host "Performing full sync with Bitwarden..."
        bw sync --force
        Write-Host ""
    }
    catch {
        Write-Host "Failed to sync with Bitwarden. Error: $_"
    }

    # Lock the vault
    bw lock

    # Clear the session
    $env:BW_SESSION = $null
}

# Main script starts here
if (-not (Test-RustDeskInstalled)) {
    Write-Host "RustDesk is not installed or not configured properly on this system."
    Write-Host "Please install RustDesk and run this script again."
    exit
}
Write-Host "Stopping RustDesk service..."
Stop-Service -Name "RustDesk" -ErrorAction SilentlyContinue

$id = Get-Content C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml | Select -Index 0
Write-Host "Current ID: $id"

$hostname = hostname
Write-Host "Hostname: $hostname"

# Prompt user for new ID option
Write-Host "Choose an option for the new RustDesk ID:"
Write-Host "1. Use the hostname ($hostname)"
Write-Host "2. Use a random 9-digit number"
Write-Host "3. Enter a custom value"
$idChoice = Read-Host "Enter your choice (1-3)"

switch ($idChoice) {
    "1" { $newIdValue = $hostname }
    "2" { $newIdValue = Get-Random9DigitNumber }
    "3" { $newIdValue = Read-Host "Enter your custom RustDesk ID" }
    default { 
        Write-Host "Invalid choice. Using hostname as default."
        $newIdValue = $hostname 
    }
}

$newId = "id = '$newIdValue'"
Write-Host "New ID: $newId"

$filecontent = Get-Content -Path C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml -Raw
Write-Host "Current file content:"
Write-Host $filecontent

Write-Host "Replacing ID..."
$filecontent = $filecontent.Replace("$id","$newId")

$password = Get-Content C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml | Select -Index 1
Write-Host "Current password line: $password"

$randomPassword = Get-RandomAlphanumericString -length 16
$newPassword = "password = '$randomPassword'"
Write-Host "New password line: $newPassword"

Write-Host "Replacing password..."
$filecontent = $filecontent.Replace("$password","$newPassword")

$filecontent | Set-Content -Path C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml

Write-Host "Final file content:"
Write-Host $filecontent 

Write-Host "Starting RustDesk service..."
Start-Service -Name "RustDesk" -ErrorAction SilentlyContinue

Write-Host "RustDesk ID has been changed to: $newId"
Write-Host "RustDesk password has been changed to a random 16-character string."
Write-Host "New password: $randomPassword"

# Prompt to save RustDesk info to Bitwarden
if (Read-HostWithDefault "Do you want to save the RustDesk information to Bitwarden?") {
    Save-ToBitwarden -hostname $hostname -newId $newIdValue -password $randomPassword -serverUrl $serverUrl
}
else {
    Write-Host "RustDesk information not saved to Bitwarden. Please make sure to securely store the ID and password."
}
