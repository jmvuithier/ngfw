# PAN-OS Certificate Automation (Root & Issuing CA)

This repository provides automation scripts for maintaining **Root CA** and **Issuing CA** certificates on **Palo Alto Networks (PAN-OS) 11.x** and later. 

These tools are inspired by and based on the logic found in the official [PaloAltoNetworks/pan-chainguard-content](https://github.com/PaloAltoNetworks/pan-chainguard-content) repository, adapted for streamlined deployment via Linux and Windows environments.

---

## 🚀 Overview

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

---

## 📖 Usage
