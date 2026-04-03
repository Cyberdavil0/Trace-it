#!/bin/bash

source utils/validator.sh
check_dependencies || exit 1

clear
echo "[Trace-it] Tracing your device..."
echo "----------------------------------------"

# Get local and public IP
local_ip=$(hostname -I | awk '{print $1}')
hostname=$(hostname)
public_ip=$(curl -s ifconfig.me)

# Get MAC address for local IP
mac_address=$(ip link show | awk '/ether/ {print $2; exit}')

# Trace public IP
info=$(curl -s "http://ip-api.com/json/$public_ip")
status=$(echo "$info" | jq -r '.status')
if [[ "$status" != "success" ]]; then
  echo "❌ Failed to trace public IP (status: $status)"
  exit 1
fi

# Display results
echo "Hostname:       $hostname"
echo "Local IP:       $local_ip"
echo "MAC Address:    $mac_address"
echo "Public IP:      $public_ip"
echo "Country:        $(echo "$info" | jq -r '.country')"
echo "Region:         $(echo "$info" | jq -r '.regionName')"
echo "City:           $(echo "$info" | jq -r '.city')"
echo "ISP:            $(echo "$info" | jq -r '.isp')"
echo "Organization:   $(echo "$info" | jq -r '.org // "N/A"')"
echo "Latitude:       $(echo "$info" | jq -r '.lat')"
echo "Longitude:      $(echo "$info" | jq -r '.lon')"
echo "Timezone:       $(echo "$info" | jq -r '.timezone')"
echo "ASN:            $(echo "$info" | jq -r '.as')"

echo -e "\n⏳ Press Enter or Ctrl+C to clear screen..."
read -r
clear
