# Palo Alto Networks Automated Backup (Debian 12)

A lightweight, fully automated solution to back up Palo Alto Networks firewall configurations using their XML API. Designed for Debian 12, this project features secure credential storage, automated cleanup of old backups, and daily email reporting via Gmail.



## ✨ Features

* **Automated Daily Backups:** Uses cron to fetch running configurations at 01:00 AM daily.
* **7-Day Retention Policy:** Automatically deletes `.xml` backup files older than 7 days to conserve disk space.
* **Email Reporting:** Sends a detailed success/failure report via Gmail upon completion.
* **Secure Credential Storage:** Uses a `.env` file to keep API keys and email passwords out of the source code.
* **Log Management:** Includes native Debian `logrotate` configuration to prevent log files from growing indefinitely.
* **Automated Setup:** Includes a Bash script to automatically install dependencies, set permissions, and configure the cron job.

---

## 📋 Prerequisites

* **OS:** Debian 12 (or similar Debian-based Linux distribution).
* **Network:** The server must be able to reach your Palo Alto firewalls on TCP port 443 (HTTPS).
* **Firewall Accounts:** Read-only (or Superuser read-only) API keys for your Palo Alto firewalls.
* **Email:** A Google account with an **App Password** generated for sending automated emails.

---

## 📂 Directory Structure

```text
/opt/pan-backup/
├── archives/               # Directory where .xml backups are saved
├── .env                    # Hidden configuration file (User created)
├── backup-config.py        # Main Python engine
├── setup-cron.sh           # Bash deployment script
└── backup.log              # Script execution log
/etc/logrotate.d/
└── pan-backup              # Logrotate configuration file

Palo Alto Networks Automated Backup Solution (Debian 12)
Directory Structure
Ensure all script files are placed in /opt/pan-backup/.

/opt/pan-backup/.env (Hidden credentials file)

/opt/pan-backup/backup-config.py (Main Python backup script)

/opt/pan-backup/setup-cron.sh (Bash deployment script)

/etc/logrotate.d/pan-backup (Log rotation configuration)

1. The Credentials File (.env)
Filepath: /opt/pan-backup/.env
Permissions: chmod 600 /opt/pan-backup/.env

Code snippet
# /opt/pan-backup/.env

# Firewall API Keys
FW1_API_KEY=YOUR_API_KEY_1
FW2_API_KEY=YOUR_API_KEY_2
FW3_API_KEY=YOUR_API_KEY_3

# Gmail App Password (16 characters, no spaces)
SMTP_PASSWORD=your_16_char_app_password
2. The Python Backup Script (backup-config.py)
Filepath: /opt/pan-backup/backup-config.py
Permissions: chmod 700 /opt/pan-backup/backup-config.py (The bash script handles this automatically).

Python
#!/usr/bin/env python3
import requests
import urllib3
import datetime
import os
import time
import smtplib
from email.message import EmailMessage
from dotenv import load_dotenv

# Disable insecure request warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Load the environment variables from the .env file
load_dotenv("/opt/pan-backup/.env")

# --- Configuration ---
BACKUP_DIR = "/opt/pan-backup/archives"
RETENTION_DAYS = 7

# Firewall list
FIREWALLS = [
    {"name": "FW-Primary", "ip": "192.168.1.10", "api_key": os.getenv("FW1_API_KEY")},
    {"name": "FW-Secondary", "ip": "192.168.1.11", "api_key": os.getenv("FW2_API_KEY")},
    {"name": "FW-Branch", "ip": "10.0.0.1", "api_key": os.getenv("FW3_API_KEY")},
]

# Email SMTP Settings (Gmail)
SMTP_SERVER = "smtp.gmail.com" 
SMTP_PORT = 587                       
SMTP_USER = "your_email@gmail.com"         # Your Gmail address
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD") # From .env file
SMTP_SENDER = "your_email@gmail.com"       # Same as SMTP_USER
SMTP_RECEIVER = "admin@yourdomain.com"     # Where you want the report sent
# ---------------------

def send_email_report(subject, body):
    msg = EmailMessage()
    msg.set_content(body)
    msg['Subject'] = subject
    msg['From'] = SMTP_SENDER
    msg['To'] = SMTP_RECEIVER

    try:
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        if SMTP_USER and SMTP_PASSWORD:
            server.login(SMTP_USER, SMTP_PASSWORD)
            
        server.send_message(msg)
        server.quit()
        print(f"[{datetime.datetime.now()}] Email report sent successfully to {SMTP_RECEIVER}.")
    except Exception as e:
        print(f"[{datetime.datetime.now()}] Error: Failed to send email report. Details: {e}")

def cleanup_old_backups(report_lines):
    now = time.time()
    deleted_count = 0
    
    if not os.path.exists(BACKUP_DIR):
        return

    for filename in os.listdir(BACKUP_DIR):
        file_path = os.path.join(BACKUP_DIR, filename)
        # Check if it's a file, ends in .xml, and is older than 7 days
        if os.path.isfile(file_path) and filename.endswith(".xml"):
            if os.stat(file_path).st_mtime < now - (RETENTION_DAYS * 86400):
                os.remove(file_path)
                deleted_count += 1
                print(f"[{datetime.datetime.now()}] Deleted old backup: {filename}")
                
    if deleted_count > 0:
        report_lines.append(f"🧹 Cleaned up {deleted_count} old backup file(s) (older than {RETENTION_DAYS} days).")

def backup_firewalls():
    if not os.path.exists(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)

    date_str = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    report_lines = [f"Palo Alto Firewall Backup Report - {date_str}\n"]
    report_lines.append("-" * 40)
    
    errors_occurred = False

    for fw in FIREWALLS:
        if not fw['api_key']:
            error_msg = f"❌ Error: API key missing for {fw['name']}. Check your .env file."
            print(f"[{datetime.datetime.now()}] {error_msg}\n")
            report_lines.append(error_msg)
            errors_occurred = True
            continue

        url = f"https://{fw['ip']}/api/?type=export&category=configuration&key={fw['api_key']}"
        
        try:
            print(f"[{datetime.datetime.now()}] Starting backup for {fw['name']}...")
            response = requests.get(url, verify=False, timeout=30)
            response.raise_for_status()

            filename = f"{BACKUP_DIR}/{fw['name']}_{date_str}.xml"
            with open(filename, 'w') as file:
                file.write(response.text)
                
            success_msg = f"✅ Success: {fw['name']} backed up."
            print(f"[{datetime.datetime.now()}] {success_msg}\n")
            report_lines.append(success_msg)
            
        except requests.exceptions.RequestException as e:
            error_msg = f"❌ Error: Failed to backup {fw['name']}. Details: {e}"
            print(f"[{datetime.datetime.now()}] {error_msg}\n")
            report_lines.append(error_msg)
            errors_occurred = True

    # Run cleanup of old backups
    cleanup_old_backups(report_lines)

    # Prepare and send the email
    report_lines.append("-" * 40)
    report_lines.append("Backup job finished.")
    
    email_body = "\n".join(report_lines)
    email_subject = "⚠️ FW Backup Error" if errors_occurred else "✅ FW Backup Successful"
    
    send_email_report(email_subject, email_body)

if __name__ == "__main__":
    backup_firewalls()
3. The Bash Installation & Cron Script (setup-cron.sh)
Filepath: /opt/pan-backup/setup-cron.sh
Usage: Must be executed with sudo ./setup-cron.sh

Bash
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

4. The Log Rotation Configuration
Filepath: /etc/logrotate.d/pan-backup
Usage: Create as root (sudo nano /etc/logrotate.d/pan-backup)

Plaintext
/opt/pan-backup/backup.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
