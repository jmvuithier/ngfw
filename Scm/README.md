# SCM Bulk Address Creator 🚀

A Python-based automation tool to bulk-import Address Objects into **Palo Alto Networks Strata Cloud Manager (SCM)**. This script streamlines the process of migrating or creating multiple IP/FQDN objects by reading from a CSV file and utilizing the SCM REST API.



## 📌 Overview

Manually entering hundreds of address objects into a web interface is error-prone and time-consuming. This script automates the workflow:
- **Authenticates** with Palo Alto's OAuth2 service.
- **Parses** a local CSV file.
- **Normalizes** IP data (automatically adding `/32` for host IPs).
- **Pushes** objects into a specific **Configuration Snippet** in SCM.

---

## 🛠️ Prerequisites

* **Python 3.8+**
* **PIP Packages**:
  ```bash
  pip install requests