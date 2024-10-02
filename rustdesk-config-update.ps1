# Function to generate random alphanumeric string
function Get-RandomAlphanumericString {
    param (
        [int] $length = 12
    )
    return -join ((65..90) + (97..122) + (48..57) | Get-Random -Count $length | ForEach-Object {[char]$_})
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
        Write-Verbose "Installing Bitwarden CLI..."
        winget install Bitwarden.CLI
        Write-Verbose "Bitwarden CLI installed successfully."
        return $true
    }
    catch {
        Write-Error "Failed to install Bitwarden CLI. Error: $_"
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
                Write-Error "Unable to proceed without Bitwarden CLI."
                return
            }
        }
        else {
            Write-Error "Unable to proceed without Bitwarden CLI."
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
	    bw config server $serverUrl
     	    Write-Output ""
        }
    }
    else {
        $serverUrl = Read-Host "Enter your Bitwarden server URL (e.g., https://bitwarden.example.net)"
	bw config server $serverUrl
     	Write-Output ""
    }

    # Check if already logged in
    $status = bw status | ConvertFrom-Json
    if ($status.status -eq "unauthenticated") {
        Write-Verbose "Please log in to Bitwarden..."
        $env:BW_SESSION = (bw login --raw)
    }
    else {
        # Unlock the vault
        Write-Verbose "Unlocking Bitwarden vault..."
        $env:BW_SESSION = (bw unlock --raw)
    }

    if (-not $env:BW_SESSION) {
        Write-Error "Failed to unlock Bitwarden vault."
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
            $itemJson | bw encode | bw edit item $existingItem.id
            Write-Output ""
            Write-Output "Updated existing Bitwarden entry for $hostname"
        }
        catch {
            Write-Error "Failed to update Bitwarden entry. Error: $_"
        }
    }
    else {
        # Create new item in Bitwarden
        try {
            $itemJson | bw encode | bw create item
            Write-Output ""
            Write-Output "Created new Bitwarden entry for $hostname"
        }
        catch {
            Write-Error "Failed to create Bitwarden entry. Error: $_"
        }
    }

    # Force a full sync
    try {
        Write-Verbose "Performing full sync with Bitwarden..."
        bw sync --force
        Write-Verbose "Sync completed successfully."
	Write-Output ""
    }
    catch {
        Write-Error "Failed to sync with Bitwarden. Error: $_"
    }

    # Lock the vault
    bw lock

    # Clear the session
    $env:BW_SESSION = $null
}

# Main script starts here
if (-not (Test-RustDeskInstalled)) {
    Write-Error "RustDesk is not installed or not configured properly on this system."
    Write-Information "Please install RustDesk and run this script again."
    exit
}
Write-Verbose "Stopping RustDesk service..."
Stop-Service -Name "RustDesk" -ErrorAction SilentlyContinue

$id = Get-Content C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml | Select-Object -Index 0
Write-Output "Current ID: $id"

$hostname = hostname
Write-Output "Hostname: $hostname"

# Prompt user for new ID option
Write-Output "Choose an option for the new RustDesk ID:"
Write-Output "1. Use the hostname ($hostname)"
Write-Output "2. Use a random 9-digit number"
Write-Output "3. Enter a custom value"
$idChoice = Read-Host "Enter your choice (1-3)"

switch ($idChoice) {
    "1" { $newIdValue = $hostname }
    "2" { $newIdValue = Get-Random9DigitNumber }
    "3" { $newIdValue = Read-Host "Enter your custom RustDesk ID" }
    default {
        Write-Warning "Invalid choice. Using hostname as default."
        $newIdValue = $hostname
    }
}

$newId = "id = '$newIdValue'"
Write-Output "New ID: $newId"

$filecontent = Get-Content -Path C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml -Raw
Write-Verbose "Current file content:"
Write-Verbose $filecontent

Write-Verbose "Replacing ID..."
$filecontent = $filecontent.Replace("$id","$newId")

$password = Get-Content C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml | Select-Object -Index 1
Write-Verbose "Current password line: $password"

$randomPassword = Get-RandomAlphanumericString -length 16
$newPassword = "password = '$randomPassword'"
Write-Verbose "New password line: $newPassword"

Write-Verbose "Replacing password..."
$filecontent = $filecontent.Replace("$password","$newPassword")

$filecontent | Set-Content -Path C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml

Write-Verbose "Final file content:"
Write-Verbose $filecontent

Write-Verbose "Starting RustDesk service..."
Start-Service -Name "RustDesk" -ErrorAction SilentlyContinue

Write-Output "RustDesk ID has been changed to: $newId"
Write-Output "RustDesk password has been changed to a random 16-character string."
Write-Output "New password: $randomPassword"

# Prompt to save RustDesk info to Bitwarden
if (Read-HostWithDefault "Do you want to save the RustDesk information to Bitwarden?") {
    Save-ToBitwarden -hostname $hostname -newId $newIdValue -password $randomPassword -serverUrl $serverUrl
}
else {
    Write-Warning "RustDesk information not saved to Bitwarden. Please make sure to securely store the ID and password."
}
