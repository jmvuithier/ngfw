import requests
import csv
import sys
import os

# --- Configuration ---
CLIENT_ID = "xxx.iam.panserviceaccount.com"
CLIENT_SECRET = "xxxxx"
TSG_ID = "xxxx"

# Target Configuration
SNIPPET_NAME = "test"  # Replace with your Snippet name
CSV_FILE_PATH = "/Path/addresses.csv" # Path to your CSV file

# SCM API Endpoints
AUTH_URL = "https://auth.apps.paloaltonetworks.com/auth/v1/oauth2/access_token" 
ADDRESS_API_URL = "https://api.strata.paloaltonetworks.com/config/objects/v1/addresses"

# ==========================================
# 1. Get OAuth2 Access Token
# ==========================================
def get_access_token():
    print("Authenticating with Strata Cloud Manager")
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    payload = {"grant_type": "client_credentials", "scope": f"tsg_id:{TSG_ID}"}
    
    response = requests.post(AUTH_URL, headers=headers, data=payload, auth=(CLIENT_ID, CLIENT_SECRET))
    
    if response.status_code in (200, 201):
        return response.json().get("access_token")
    else:
        print(f"Authentication failed! Status: {response.status_code}")
        print(response.text)
        sys.exit(1)

# ==========================================
# 2. Parse CSV and Create Objects
# ==========================================
def bulk_create_address_objects(token):
    if not os.path.exists(CSV_FILE_PATH):
        print(f"Error: The file '{CSV_FILE_PATH}' does not exist.")
        sys.exit(1)

    print(f"Reading data from '{CSV_FILE_PATH}'...\n")
    print("-" * 50)

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

    # Route the objects to your snippet
    params = {
        "snippet": SNIPPET_NAME 
    }

    with open(CSV_FILE_PATH, mode='r', encoding='utf-8-sig') as csv_file:
        csv_reader = csv.DictReader(csv_file)
        
        for row_num, row in enumerate(csv_reader, start=2):
            obj_name = row.get('name', '').strip()
            hostname = row.get('hostname', '').strip()
            ip_address = row.get('ip address', '').strip()
            description = row.get('description', '').strip() # <-- Added description reading

            # Skip empty rows or rows without a name
            if not obj_name:
                print(f"  [!] Skipping Row {row_num}: Missing 'name'.")
                continue

            # Build the base payload
            payload = {
                "name": obj_name
            }
            
            # Add description if it exists in the CSV
            if description:
                payload["description"] = description

            # Determine if it's an IP object or an FQDN object
            if ip_address:
                # SCM requires CIDR notation (e.g., /32 for single IPs)
                if "/" not in ip_address:
                    ip_address += "/32"
                payload["ip_netmask"] = ip_address
                obj_type_str = f"IP: {ip_address}"
                
            elif hostname:
                payload["fqdn"] = hostname
                obj_type_str = f"FQDN: {hostname}"
                
            else:
                print(f"  [!] Skipping '{obj_name}': Missing both IP and Hostname.")
                continue

            print(f"Processing: '{obj_name}' ({obj_type_str}) -> Snippet: '{SNIPPET_NAME}'...")

            # Make the API call
            response = requests.post(
                ADDRESS_API_URL, 
                headers=headers, 
                params=params, 
                json=payload 
            )

            # Check result
            if response.status_code in (200, 201):
                object_id = response.json().get('id', 'Unknown ID')
                print(f"  [+] SUCCESS! Object ID: {object_id}")
            else:
                print(f"  [-] FAILED! Status: {response.status_code}")
                try:
                    error_msg = response.json().get('_errors', [{}])[0].get('details', {}).get('message', response.text)
                    print(f"  [-] Error Details: {error_msg}")
                except:
                    print(f"  [-] Error Details: {response.text}")
                    
            print("-" * 50)

# ==========================================
# 3. Execute Script
# ==========================================
if __name__ == "__main__":
    access_token = get_access_token()
    bulk_create_address_objects(access_token)
    print("\nBulk address object creation finished!")