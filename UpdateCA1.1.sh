
################################################################################
# Script written by: Jean-Marc Vuithier jvuithier@paloaltonetworks.com (with assistance from Google Gemini)
#
# IMPORTANT NOTE:
# If the script fails during the package download phase, please consider 
# temporarily disabling your local AV/EDR and removing SSL inspection/security 
# profiles on your firewall, as they may aggressively block the installations.
#
# Based on https://github.com/PaloAltoNetworks/pan-chainguard-content
################################################################################
#!/bin/bash

# Exit script immediately if a command exits with a non-zero status
set -e

# Define a cleanup function that will run upon exit or abort
cleanup() {
    echo ""
    echo "--------------------------------------------------"
    echo "Performing cleanup..."
    echo "--------------------------------------------------"
    
    # Remove the credentials file if it exists
    if [ -f ~/.panrc ]; then
        rm -f ~/.panrc
        echo "Deleted ~/.panrc credentials file."
    fi
    
    # Remove the downloaded certificate package if it exists
    if [ -f certificates-new.tgz ]; then
        rm -f certificates-new.tgz
        echo "Deleted downloaded certificates-new.tgz file."
    fi
    
    echo "Process complete or aborted safely!"
}

# Trap Ctrl+C (INT), termination (TERM), and normal exits (EXIT) to trigger the cleanup
trap cleanup EXIT INT TERM

# Prompt the user for the variables
read -p "Enter the device name (e.g., PA-440): " DEVICE_NAME
read -p "Enter the IP address (e.g., 192.168.1.1): " IP_ADDRESS
read -p "Enter the username (e.g., admin): " USERNAME

echo "--------------------------------------------------"
echo "Setting up Python virtual environment..."
echo "--------------------------------------------------"
# Create a virtual environment named 'pan_venv'
python3 -m venv pan_venv

# Activate the virtual environment
source pan_venv/bin/activate

echo "--------------------------------------------------"
echo "Installing pan-chainguard..."
echo "--------------------------------------------------"
python3 -m pip install --upgrade pip
python3 -m pip install pan-chainguard

echo "--------------------------------------------------"
echo "Configuring Device Profile in ~/.panrc..."
echo "--------------------------------------------------"
# The -k flag will pause here and prompt you to enter the firewall password
panxapi.py -t "$DEVICE_NAME" -h "$IP_ADDRESS" -l "$USERNAME" -k >> ~/.panrc

echo "--------------------------------------------------"
echo "Checking Clock..."
echo "--------------------------------------------------"
panxapi.py -t "$DEVICE_NAME" -Xxo 'show clock'

echo "--------------------------------------------------"
echo "Downloading new certificates..."
echo "--------------------------------------------------"
curl -sLO https://raw.githubusercontent.com/PaloAltoNetworks/pan-chainguard-content/main/latest-certs/certificates-new.tgz

echo "--------------------------------------------------"
echo "Executing Guard.py Actions..."
echo "--------------------------------------------------"
echo "1. Showing current certs..."
guard.py -t "$DEVICE_NAME" --show

echo "2. Running Dry-Run for Root Cert update..."
guard.py -t "$DEVICE_NAME" --admin "$USERNAME" --certs certificates-new.tgz --update --type root --dry-run

echo "--------------------------------------------------"
# Safety pause 
read -p "Press Enter to confirm install or Ctrl+C to abort..."
echo "--------------------------------------------------"

echo "3. Running Actual Root Cert update..."
guard.py -t "$DEVICE_NAME" --admin "$USERNAME" --certs certificates-new.tgz --update --type root

echo "4. Committing changes to the firewall..."
guard.py -t "$DEVICE_NAME" --admin "$USERNAME" --commit

# Once this command finishes, the script exits normally and automatically triggers the trap cleanup!