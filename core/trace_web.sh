#!/bin/bash

source utils/validator.sh
check_dependencies || exit 1
validate_domain "$1" || exit 1

domain="$1"
clear
echo "[Trace-it] Resolving domain: $domain"
echo "----------------------------------------"

ips=$(dig +short "$domain" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
if [[ -z "$ips" ]]; then
  echo "No IP addresses found for $domain"
  exit 1
fi

is_private_ip() {
  local ip="$1"
  # Check for private IP ranges: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, and loopback 127.0.0.0/8
  if [[ "$ip" =~ ^10\. ]] || [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$ip" =~ ^192\.168\. ]] || [[ "$ip" =~ ^127\. ]]; then
    return 0
  else
    return 1
  fi
}

for ip in $ips; do
  echo -e "\n🔍 Tracing IP: $ip"

  if is_private_ip "$ip"; then
    # For local/private IPs, get device info from ARP table or nmap scan
    echo "IP Address:     $ip"

    # Ping the IP to populate ARP cache if not present
    ping -c 1 -W 1 "$ip" &>/dev/null

    # Get ARP entry for the IP
    arp_entry=$(arp -a | grep "$ip")
    if [[ -n "$arp_entry" ]]; then
      # Parse ARP output: format is typically "device (ip) at mac [ether] on interface"
      device=$(echo "$arp_entry" | awk '{print $1}')
      mac=$(echo "$arp_entry" | awk '{print $4}')
      echo "Device Name:    $device"
      echo "MAC Address:    $mac"
    else
      # If not in ARP, try nmap for device info
      echo "Scanning with nmap for device info..."
      nmap_output=$(nmap -sn "$ip" 2>/dev/null)
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
    info=$(curl -s "http://ip-api.com/json/$ip")
    status=$(echo "$info" | jq -r '.status')
    if [[ "$status" != "success" ]]; then
      echo "❌ Failed to trace $ip (status: $status)"
      continue
    fi

    echo "IP Address:     $ip"
    echo "Country:        $(echo "$info" | jq -r '.country // "N/A"')"
    echo "Region:         $(echo "$info" | jq -r '.regionName // "N/A"')"
    echo "City:           $(echo "$info" | jq -r '.city // "N/A"')"
    echo "ISP:            $(echo "$info" | jq -r '.isp // "N/A"')"
    echo "Organization:   $(echo "$info" | jq -r '.org // "N/A"')"
    echo "Latitude:       $(echo "$info" | jq -r '.lat // "N/A"')"
    echo "Longitude:      $(echo "$info" | jq -r '.lon // "N/A"')"
    echo "Timezone:       $(echo "$info" | jq -r '.timezone // "N/A"')"
    echo "ASN:            $(echo "$info" | jq -r '.as // "N/A"')"
  fi
done

echo -e "\n⏳ Press Enter or Ctrl+C to clear screen..."
read -r
clear
