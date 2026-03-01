#!/bin/bash

# 1. Check for root/sudo privileges (required for apt installation)
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run this setup script with sudo."
  echo "Example: sudo ./setup-cron.sh"
  exit 1
fi

echo "📦 Verifying and installing required Python libraries..."
# 2. Update package lists quietly and install required Python libraries
apt-get update -qq
apt-get install -y python3-requests python3-dotenv

if [ $? -eq 0 ]; then
    echo "✅ Required Python libraries are installed."
else
    echo "❌ Error: Failed to install Python libraries. Exiting."
    exit 1
fi

echo "----------------------------------------"

# 3. Define the paths
SCRIPT_PATH="/opt/pan-backup/backup-config.py"
LOG_PATH="/opt/pan-backup/backup.log"

# 4. Define the cron schedule: Minute(00) Hour(01) Day(*) Month(*) DayOfWeek(*)
CRON_SCHEDULE="00 01 * * *"
CRON_COMMAND="/usr/bin/python3 $SCRIPT_PATH >> $LOG_PATH 2>&1"
CRON_JOB="$CRON_SCHEDULE $CRON_COMMAND"

# 5. Make the Python script executable
if [ -f "$SCRIPT_PATH" ]; then
    chmod +x "$SCRIPT_PATH"
else
    echo "⚠️ Warning: $SCRIPT_PATH not found! Make sure you created the Python script."
fi

# 6. Check if the cron job already exists for the root user
crontab -l 2>/dev/null | grep -Fq "$SCRIPT_PATH"

if [ $? -eq 0 ]; then
    echo "ℹ️ The cron job for $SCRIPT_PATH already exists."
else
    # Append the new cron job to the root crontab
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "✅ Success! Cron job added."
    echo "🕒 The backup will run daily at 01:00 AM."
    echo "📝 Logs will be written to: $LOG_PATH"
fi
