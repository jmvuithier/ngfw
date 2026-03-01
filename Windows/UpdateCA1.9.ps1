################################################################################
# Script written by: Jean-Marc Vuithier jvuithier@paloaltonetworks.com (with assistance from Google Gemini)
#
# IMPORTANT NOTE:
# If the script fails during the package download phase, please consider 
# temporarily disabling your local AV/EDR and removing SSL inspection/security 
# profiles on your firewall, as they may aggressively block the installations.
#
# USAGE:
# To bypass Windows default execution restrictions, run this script using:
# powershell.exe -ExecutionPolicy Bypass -File .\UpdateCA1.0.ps1
################################################################################


# Exit script immediately if a command encounters an error
$ErrorActionPreference = "Stop"

Write-Host "Bypassing Windows Store fake Python aliases..."
# Temporarily remove the WindowsApps folder from the system PATH for this session only
$env:Path = ($env:Path -split ';' | Where-Object { $_ -notmatch 'WindowsApps' }) -join ';'

# Define variables for paths to ensure cross-platform compatibility
$panrcPath = Join-Path $env:USERPROFILE ".panrc"
$certFile = "certificates-new.tgz"
$pythonInstaller = "python-installer.exe"
$venvPath = "pan_venv"
$pipTempPath = "pip_temp"

try {
    # Prompt the user for the variables
    $DEVICE_NAME = Read-Host "Enter the device name (e.g., PA-440)"
    $IP_ADDRESS = Read-Host "Enter the IP address (e.g., 192.168.1.1)"
    $USERNAME = Read-Host "Enter the username (e.g., admin)"
    
    # Prompt for the password securely (masks input with asterisks)
    $SECURE_PASSWORD = Read-Host "Enter the firewall password" -AsSecureString
    # Decrypt it in memory so we can pass it to the Python script later
    $PASSWORD = [System.Net.NetworkCredential]::new("", $SECURE_PASSWORD).Password

    Write-Host "`n--------------------------------------------------"
    Write-Host "Checking for Python..."
    Write-Host "--------------------------------------------------"
    
    $realPythonInstalled = $false
    if (Get-Command "python" -ErrorAction SilentlyContinue) {
        $pyVersion = python --version 2>&1
        if ($pyVersion -match "Python") {
            $realPythonInstalled = $true
        }
    }

    if (-not $realPythonInstalled) {
        Write-Host "Python is not installed. Downloading the official installer..."
        
        $pythonUrl = "https://www.python.org/ftp/python/3.12.2/python-3.12.2-amd64.exe"
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
        
        Write-Host "Installing Python silently and adding it to PATH (this may take a minute)..."
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0" -Wait -NoNewWindow
        
        Write-Host "Python installed! Refreshing environment variables..."
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        $checkAgain = python --version 2>&1
        if (-not ($checkAgain -match "Python")) {
            Write-Host "Failed to detect Python after installation. You may need to restart PowerShell."
            exit
        }
    } else {
        Write-Host "Python is installed and ready. Moving on..."
    }

    Write-Host "`n--------------------------------------------------"
    Write-Host "Setting up Python virtual environment..."
    Write-Host "--------------------------------------------------"
    python -m venv $venvPath
    . ".\$venvPath\Scripts\Activate.ps1"

    Write-Host "`n--------------------------------------------------"
    Write-Host "Installing Packages (One-by-One Stealth Mode)..."
    Write-Host "--------------------------------------------------"
    
    # Setup custom temp variable targeting
    $env:TMPDIR = Join-Path $PWD $pipTempPath
    $env:TMP = $env:TMPDIR
    $env:TEMP = $env:TMPDIR
    if (Test-Path $env:TMPDIR) { Remove-Item -Path $env:TMPDIR -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $env:TMPDIR | Out-Null

    # Upgrade pip first
    python -m pip install --upgrade pip --trusted-host pypi.org --trusted-host files.pythonhosted.org --no-cache-dir --progress-bar off

    # We will install the heavy, problematic dependencies one at a time, followed by the main package.
    $packagesToInstall = @(
        "multidict",
        "yarl",
        "frozenlist",
        "aiohttp",
        "requests",
        "pan-os-python",
        "pan-chainguard"
    )

    foreach ($pkg in $packagesToInstall) {
        Write-Host "`n---> Installing $pkg <---" -ForegroundColor Cyan
        $maxRetries = 3
        $retryCount = 0
        $pkgSuccess = $false

        while (-not $pkgSuccess -and $retryCount -lt $maxRetries) {
            try {
                if (Test-Path $env:TMPDIR) { Remove-Item -Path $env:TMPDIR -Recurse -Force -ErrorAction SilentlyContinue }
                New-Item -ItemType Directory -Force -Path $env:TMPDIR | Out-Null

                python -m pip install $pkg --trusted-host pypi.org --trusted-host files.pythonhosted.org --no-cache-dir --progress-bar off --default-timeout=120
                
                if ($LASTEXITCODE -eq 0) {
                    $pkgSuccess = $true
                    Write-Host "Successfully installed $pkg!" -ForegroundColor Green
                    Write-Host "Pausing for 10 seconds to let the EDR/Antivirus settle before the next download if the issue persist disable temporary" -ForegroundColor Yellow
                    Start-Sleep -Seconds 10
                } else {
                    throw "Pip exit code was not 0."
                }
            } catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Host "EDR/Antivirus locked the file or proxy dropped. Retrying $pkg in 15 seconds... ($retryCount/$maxRetries)" -ForegroundColor Yellow
                    Start-Sleep -Seconds 15
                } else {
                    throw "Failed to install $pkg after $maxRetries attempts. The corporate EDR/Antivirus or firewall is permanently holding this file hostage."
                }
            }
        }
    }

    Write-Host "`n--------------------------------------------------"
    Write-Host "Configuring Device Profile in ~/.panrc..."
    Write-Host "--------------------------------------------------"
    # We pipe the password directly into the script to bypass the broken Python password prompt
    $PASSWORD | python ".\$venvPath\Scripts\panxapi.py" -t $DEVICE_NAME -h $IP_ADDRESS -l $USERNAME -k | Out-File -FilePath $panrcPath -Encoding ASCII -Append

    Write-Host "`n--------------------------------------------------"
    Write-Host "Checking Clock to validate the API Key"
    Write-Host "--------------------------------------------------"
    python ".\$venvPath\Scripts\panxapi.py" -t $DEVICE_NAME -Xxo 'show clock'

    Write-Host "`n--------------------------------------------------"
    Write-Host "Downloading new certificates..."
    Write-Host "--------------------------------------------------"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaloAltoNetworks/pan-chainguard-content/main/latest-certs/certificates-new.tgz" -OutFile $certFile

    Write-Host "`n--------------------------------------------------"
    Write-Host "Executing Guard Actions..."
    Write-Host "--------------------------------------------------"
    Write-Host "1. Showing current certs..."
    python ".\$venvPath\Scripts\guard.py" -t $DEVICE_NAME --show

    Write-Host "2. Running Dry-Run for Root Cert update..."
    python ".\$venvPath\Scripts\guard.py" -t $DEVICE_NAME --admin $USERNAME --certs $certFile --update --type root --dry-run

    Write-Host "`n--------------------------------------------------"
    Read-Host "Press Enter to confirm installation of the CA and Issuing or Ctrl+C to abort"
    Write-Host "--------------------------------------------------"

    Write-Host "3. Running Actual Root Cert update..."
    python ".\$venvPath\Scripts\guard.py" -t $DEVICE_NAME --admin $USERNAME --certs $certFile --update --type root

    Write-Host "4. Committing changes to the firewall..."
    python ".\$venvPath\Scripts\guard.py" -t $DEVICE_NAME --admin $USERNAME --commit

} catch {
    Write-Host "`n[ERROR] An error occurred during execution:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    Write-Host "`n--------------------------------------------------"
    Write-Host "Performing cleanup..."
    Write-Host "--------------------------------------------------"
    
    if (Get-Command deactivate -ErrorAction SilentlyContinue) {
        deactivate
        Write-Host "Deactivated the virtual environment."
    }

    if (Test-Path $venvPath) {
        Remove-Item -Path $venvPath -Recurse -Force
        Write-Host "Deleted the $venvPath folder."
    }

    if (Test-Path $pipTempPath) {
        Start-Sleep -Seconds 5
        Remove-Item -Path $pipTempPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted the temporary pip folder."
    }

    if (Test-Path $panrcPath) {
        Remove-Item -Path $panrcPath -Force
        Write-Host "Deleted ~/.panrc credentials file."
    }
    
    if (Test-Path $certFile) {
        Remove-Item -Path $certFile -Force
        Write-Host "Deleted downloaded $certFile file."
    }

    if (Test-Path $pythonInstaller) {
        Remove-Item -Path $pythonInstaller -Force
        Write-Host "Deleted Python installer."
    }
    
    # Clear the password variable from memory just to be extra safe
    $PASSWORD = $null
    $SECURE_PASSWORD = $null

    Write-Host "Process complete or aborted safely! Please check the certificate store of the firewall and the commit status"
}