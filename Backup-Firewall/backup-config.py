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
