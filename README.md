# Tools for Palo Alto Networks (PANOS)

# This repository provides automation scripts for:

### Maintaining **Root CA** and **Issuing CA** certificates on **Palo Alto Networks (PAN-OS) 11.x** and later. 
These tools are inspired by and based on the logic found in the official [PaloAltoNetworks/pan-chainguard-content](https://github.com/PaloAltoNetworks/pan-chainguard-content) repository, adapted for streamlined deployment via Linux and Windows environments.

### Backup Firewall with cron in Debian 12 for non customer with **Panorama or Strata Cloud Manager** 

### Create Objects like** host name with ip addresses** on **Snippet** in **Strata Cloud Manager** commonly used for migration from other vendor


---

## 🚀 PANOS update Trusted Root CA

Managing certificate chains manually can be error-prone, especially when dealing with multiple firewalls. These scripts automate the entire lifecycle of certificate deployment:

1.  **Authentication**: Connects to the firewall to generate a secure API key.
2.  **Upload**: Transfers multiple certificate files (Root and Intermediate/Issuing) to the firewall.
3.  **Activation**: Executes a `commit` to move the certificates into the running configuration.


## 🛠 Features

* **Cross-Platform**: Includes a Bash script for **Linux/macOS** and a PowerShell script for **Windows**.
* **PAN-OS 11.x Optimized**: Built to handle the specific API requirements of the 11.x and later software branch.
* **Batch Upload**: Designed to handle multiple certificate files in a single run.
* **Secure**: Uses API keys rather than passing raw credentials for subsequent calls.

---

## 📋 Prerequisites

| Requirement | Description |
| :--- | :--- |
| **Connectivity** | HTTPS access to the Firewall Management IP (Port 443). |
| **Permissions** | Admin account with XML API and Commit privileges. |
| **Files** | Root and Issuing CA files in `.pem` format. |
| **Dependencies** | `curl` (for Linux) or PowerShell 5.1+ (for Windows). |



## 🚀 PANOS Automated Backup (Debian 12)

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



## 🚀 Strata Cloud Manager  Automated objects creation Objects like** host name with ip addresses** on **Snippet** in **Strata Cloud Manager** commonly used for migration from other vendor
## ✨ Features

* **Automated creation of objects in Strata Cloud Manager:** Import Objects in SCM Snippet from CSV file
---

## 📋 Prerequisites
* **Strata Cloud Manager API service account
* **OS:** No OS design to work with Python (Min Version 3.11).
* **Python Libraries:** The following library need to be install "import requests, import csv, import sys,import os).



