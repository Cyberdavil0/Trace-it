#!/bin/bash

source utils/validator.sh
check_dependencies || exit 1
validate_ip_or_host "$1" || exit 1

target="$1"
clear
echo "[Trace-it] Tracing target: $target"
echo "----------------------------------------"

# Function to check if IP is private or loopback
is_private_ip() {
  local ip="$1"
  # Check for private IP ranges: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, and loopback 127.0.0.0/8
  if [[ "$ip" =~ ^10\. ]] || [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$ip" =~ ^192\.168\. ]] || [[ "$ip" =~ ^127\. ]]; then
    return 0
  else
    return 1
  fi
}

# Resolve hostname to IP if necessary
if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  resolved_ip="$target"
else
  resolved_ip=$(dig +short "$target" | head -n1)
  if [[ -z "$resolved_ip" ]]; then
    echo "❌ Failed to resolve hostname $target"
    exit 1
  fi
fi

if is_private_ip "$resolved_ip"; then
  # For local/private IPs, get device info from ARP table or nmap scan
  echo "IP Address:     $resolved_ip"

  # Ping the IP to populate ARP cache if not present
  ping -c 1 -W 1 "$resolved_ip" &>/dev/null

  # Get ARP entry for the IP
  arp_entry=$(arp -a | grep "$resolved_ip")
  if [[ -n "$arp_entry" ]]; then
    # Parse ARP output: format is typically "device (ip) at mac [ether] on interface"
    device=$(echo "$arp_entry" | awk '{print $1}')
    mac=$(echo "$arp_entry" | awk '{print $4}')
    echo "Device Name:    $device"
    echo "MAC Address:    $mac"
  else
    # If not in ARP, try nmap for device info
    echo "Scanning with nmap for device info..."
    nmap_output=$(nmap -sn "$resolved_ip" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
      hostname=$(echo "$nmap_output" | grep -oP 'Nmap scan report for \K[^\(]+' | head -n1)
      mac=$(echo "$nmap_output" | grep -oP 'MAC Address: \K[^ ]+' | head -n1)
      if [[ -n "$hostname" ]]; then
        echo "Device Name:    $hostname"
      else
        echo "Device Name:    Unknown"
      fi
      if [[ -n "$mac" ]]; then
        echo "MAC Address:    $mac"
      else
        echo "MAC Address:    Not found (device may not be reachable)"
      fi
    else
      echo "Device Name:    Unknown"
      echo "MAC Address:    Not found (device may not be reachable)"
    fi
  fi
else
  # For public IPs, use geolocation
  info=$(curl -s "http://ip-api.com/json/$resolved_ip")
  status=$(echo "$info" | jq -r '.status')
  if [[ "$status" != "success" ]]; then
    echo "❌ Failed to trace $target (status: $status)"
    exit 1
  fi

  echo "IP Address:     $(echo "$info" | jq -r '.query')"
  echo "Country:        $(echo "$info" | jq -r '.country')"
  echo "Region:         $(echo "$info" | jq -r '.regionName')"
  echo "City:           $(echo "$info" | jq -r '.city')"
  echo "ISP:            $(echo "$info" | jq -r '.isp')"
  echo "Organization:   $(echo "$info" | jq -r '.org // "N/A"')"
  echo "Latitude:       $(echo "$info" | jq -r '.lat')"
  echo "Longitude:      $(echo "$info" | jq -r '.lon')"
  echo "Timezone:       $(echo "$info" | jq -r '.timezone')"
  echo "ASN:            $(echo "$info" | jq -r '.as')"
fi

echo -e "\n⏳ Press Enter or Ctrl+C to clear screen..."
read -r
clear
