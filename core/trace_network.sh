#!/bin/bash

# ======================================================
#  Trace-it : Universal Wireless Device Scanner v2.0
#  File: trace_network.sh
#  Usage: ./trace_network.sh [options]
#  Options: -quick    Quick scan (30 seconds)
#           -deep     Deep scan (2 minutes)
#           -export   Export results to file
#           -json     JSON format output
# ======================================================

# Version
VERSION="2.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Initialize variables
SCAN_MODE="quick"
EXPORT=false
JSON_OUTPUT=false
OS=$(uname -s)
HOSTNAME=$(hostname)
SCAN_START=$(date +%s)

# Parse arguments
for arg in "$@"; do
    case $arg in
        -quick) SCAN_MODE="quick" ;;
        -deep) SCAN_MODE="deep" ;;
        -export) EXPORT=true ;;
        -json) JSON_OUTPUT=true ;;
        -h|--help)
            echo "Usage: ./trace_network.sh [options]"
            echo "Options:"
            echo "  -quick    Quick scan (30 seconds) [default]"
            echo "  -deep     Deep scan (2 minutes)"
            echo "  -export   Export results to file"
            echo "  -json     JSON format output"
            exit 0
            ;;
    esac
done

# Create output directory
OUTPUT_DIR="$HOME/trace-it-scans"
mkdir -p "$OUTPUT_DIR" 2>/dev/null
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
LOG_FILE="$OUTPUT_DIR/scan_$TIMESTAMP.log"
JSON_FILE="$OUTPUT_DIR/scan_$TIMESTAMP.json"

# Arrays for discovered devices
declare -a wifi_networks=()
declare -a bluetooth_devices=()
declare -a arp_devices=()
declare -a wireless_interfaces=()
declare -a bt_interfaces=()

# Function to log and display
log() {
    echo -e "$1"
    if [[ "$EXPORT" == true ]]; then
        echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}

# Function to show progress
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    local bar_size=40
    local filled=$((percent * bar_size / 100))
    local empty=$((bar_size - filled))
    
    printf "\r${CYAN}[${NC}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${CYAN}]${NC} %3d%% %s" "$percent" "$message"
}

# Function to check command availability
check_command() {
    if command -v "$1" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to detect wireless interfaces
detect_interfaces() {
    log "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
    log "${GREEN}🔍 DETECTING WIRELESS INTERFACES${NC}"
    log "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    # WiFi interfaces
    if [[ -d /sys/class/net ]]; then
        for iface in $(ls /sys/class/net 2>/dev/null); do
            # Check if wireless interface
            if [[ -d "/sys/class/net/$iface/wireless" ]] || [[ "$iface" =~ ^wl[a-z0-9]+ ]] || [[ "$iface" =~ ^wlan[0-9]+ ]]; then
                wireless_interfaces+=("$iface")
                # Get MAC address
                if [[ -f "/sys/class/net/$iface/address" ]]; then
                    mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null)
                    log "${GREEN}✓ WiFi:${NC} $iface ${BLUE}(MAC: $mac)${NC}"
                else
                    log "${GREEN}✓ WiFi:${NC} $iface"
                fi
            fi
        done
    fi
    
    # macOS interfaces
    if [[ "$OS" == "Darwin" ]]; then
        if check_command networksetup; then
            wifi_iface=$(networksetup -listallhardwareports 2>/dev/null | grep -A1 "Wi-Fi\|AirPort" | grep "Device" | awk '{print $2}')
            if [[ -n "$wifi_iface" ]]; then
                wireless_interfaces+=("$wifi_iface")
                log "${GREEN}✓ macOS WiFi:${NC} $wifi_iface"
            fi
        fi
    fi
    
    # Bluetooth interfaces
    if check_command hciconfig; then
        while read -r line; do
            if [[ "$line" =~ ^hci[0-9] ]]; then
                bt_interface=$(echo "$line" | awk '{print $1}')
                bt_interfaces+=("$bt_interface")
                log "${GREEN}✓ Bluetooth:${NC} $bt_interface"
            fi
        done < <(hciconfig 2>/dev/null)
    fi
    
    # Termux Android
    if check_command termux-wifi-connectioninfo; then
        wireless_interfaces+=("wlan0")
        log "${GREEN}✓ Termux WiFi detected${NC}"
    fi
    
    if [[ ${#wireless_interfaces[@]} -eq 0 ]]; then
        log "${YELLOW}⚠ No wireless interfaces detected${NC}"
    fi
}

# Function to get interface IP
get_interface_ip() {
    local iface=$1
    
    if [[ "$OS" == "Darwin" ]]; then
        ipconfig getifaddr "$iface" 2>/dev/null
    else
        ip -o -4 addr show "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1
    fi
}

# Function to scan WiFi networks
scan_wifi() {
    log "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
    log "${GREEN}📡 SCANNING WI-FI NETWORKS${NC}"
    log "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    local wifi_count=0
    local scan_duration=10
    
    if [[ "$SCAN_MODE" == "deep" ]]; then
        scan_duration=20
    fi
    
    # Method 1: nmcli (Linux)
    if check_command nmcli; then
        log "${BLUE}Using nmcli scanner...${NC}"
        log "\n${PURPLE}WI-FI NETWORKS FOUND:${NC}"
        log "${WHITE}SSID                          BSSID              CH   SECURITY       SIGNAL  TYPE${NC}"
        
        while IFS= read -r line; do
            if [[ ! "$line" =~ ^SSID|^-- ]]; then
                wifi_networks+=("$line")
                log " $line"
                ((wifi_count++))
            fi
        done < <(nmcli -f SSID,BSSID,CHAN,SECURITY,SIGNAL,MODE device wifi list 2>/dev/null | head -20)
    fi
    
    # Method 2: iwlist (Linux)
    if [[ $wifi_count -eq 0 ]] && check_command iwlist; then
        for iface in "${wireless_interfaces[@]}"; do
            if [[ -n "$iface" ]]; then
                log "${BLUE}Scanning on $iface...${NC}"
                
                # Show progress
                for ((i=1; i<=scan_duration; i++)); do
                    show_progress "$i" "$scan_duration" "Scanning WiFi..."
                    sleep 1
                done
                echo ""
                
                log "\n${PURPLE}WI-FI NETWORKS FOUND:${NC}"
                log "${WHITE}SSID                          BSSID              CH   QUALITY  ENCRYPTION${NC}"
                
                # Use sudo for iwlist if needed
                if sudo -n true 2>/dev/null; then
                    scan_cmd="sudo iwlist $iface scan"
                else
                    scan_cmd="iwlist $iface scan 2>/dev/null"
                fi
                
                eval "$scan_cmd" 2>/dev/null | awk '
                    /ESSID/ {
                        gsub(/"/,"", $0)
                        ssid = substr($0, index($0,":")+1)
                        if (ssid == "") ssid = "Hidden Network"
                    }
                    /Address/ {
                        bssid = $5
                    }
                    /Channel/ {
                        channel = $2
                    }
                    /Quality/ {
                        split($1, qual, "=")
                        quality = qual[2]
                    }
                    /Encryption key/ {
                        enc = ($3 == "on") ? "Yes" : "No"
                        if (ssid && bssid) {
                            printf "%-30s %-20s %-5s %-8s %s\n", 
                                   substr(ssid,1,28), bssid, channel, quality, enc
                            ssid = ""; bssid = ""; channel = ""; quality = ""
                            wifi_count++
                        }
                    }' | while read -r line; do
                        wifi_networks+=("$line")
                        log " $line"
                    done
            fi
        done
    fi
    
    # Method 3: Termux WiFi
    if [[ $wifi_count -eq 0 ]] && check_command termux-wifi-scaninfo; then
        log "${BLUE}Using Termux scanner...${NC}"
        
        for ((i=1; i<=scan_duration; i++)); do
            show_progress "$i" "$scan_duration" "Scanning WiFi..."
            sleep 1
        done
        echo ""
        
        scan_result=$(termux-wifi-scaninfo 2>/dev/null)
        
        if [[ -n "$scan_result" ]] && [[ "$scan_result" != "[]" ]]; then
            log "\n${PURPLE}WI-FI NETWORKS FOUND:${NC}"
            log "${WHITE}SSID                          BSSID              CH   SECURITY  SIGNAL${NC}"
            
            echo "$scan_result" | python3 2>/dev/null << 'PYCODE' | while read -r line; do
import json, sys
try:
    nets = json.load(sys.stdin)
    for n in sorted(nets, key=lambda x: x.get('rssi', -100), reverse=True):
        ssid = n.get('ssid', 'Hidden')[:28]
        bssid = n.get('bssid', 'Unknown')[:17]
        freq = n.get('frequency', 0)
        if 2412 <= freq <= 2484:
            ch = int((freq - 2412) / 5 + 1)
        elif 5180 <= freq <= 5825:
            ch = int((freq - 5180) / 5 + 36)
        else:
            ch = freq
        caps = n.get('capabilities', '')
        if 'WPA3' in caps: sec = 'WPA3'
        elif 'WPA2' in caps: sec = 'WPA2'
        elif 'WPA' in caps: sec = 'WPA'
        elif 'WEP' in caps: sec = 'WEP'
        else: sec = 'OPEN'
        rssi = n.get('rssi', -100)
        signal = min(100, max(0, (rssi + 100) * 2))
        print(f"{ssid:<30} {bssid}  {ch:3}  {sec:<8} {signal:3}%")
        wifi_count+=1
except: pass
PYCODE
                wifi_networks+=("$line")
                log " $line"
            done
        fi
    fi
    
    # Method 4: macOS airport
    if [[ $wifi_count -eq 0 ]] && [[ "$OS" == "Darwin" ]] && check_command airport; then
        log "${BLUE}Using macOS airport scanner...${NC}"
        log "\n${PURPLE}WI-FI NETWORKS FOUND:${NC}"
        
        airport -s 2>/dev/null | head -20 | while read -r line; do
            wifi_networks+=("$line")
            log " $line"
            ((wifi_count++))
        done
    fi
    
    if [[ $wifi_count -eq 0 ]]; then
        log "${YELLOW}⚠ No WiFi networks detected${NC}"
    else
        log "\n${GREEN}✓ Found $wifi_count WiFi network(s)${NC}"
    fi
}

# Function to scan Bluetooth devices
scan_bluetooth() {
    log "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
    log "${GREEN}📱 SCANNING BLUETOOTH DEVICES${NC}"
    log "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    local bt_count=0
    local scan_duration=8
    
    if [[ "$SCAN_MODE" == "deep" ]]; then
        scan_duration=15
    fi
    
    # Method 1: bluetoothctl (Linux)
    if check_command bluetoothctl; then
        log "${BLUE}Scanning for Bluetooth devices (${scan_duration}s)...${NC}"
        
        # Start scan
        bluetoothctl --timeout "$scan_duration" scan on >/dev/null 2>&1 &
        scan_pid=$!
        
        # Show progress
        for ((i=1; i<=scan_duration; i++)); do
            show_progress "$i" "$scan_duration" "Scanning Bluetooth..."
            sleep 1
        done
        echo -e "\r${GREEN}✓ Scan complete!${NC}          "
        
        # Get devices
        log "\n${PURPLE}BLUETOOTH DEVICES FOUND:${NC}"
        log "${WHITE}MAC Address       Device Name                    Type      RSSI   Paired${NC}"
        
        while read -r line; do
            if [[ "$line" =~ ^Device ]]; then
                mac=$(echo "$line" | awk '{print $2}')
                name=$(echo "$line" | cut -d' ' -f3-)
                
                # Get device details
                if check_command bluetoothctl; then
                    info=$(bluetoothctl info "$mac" 2>/dev/null)
                    rssi=$(echo "$info" | grep "RSSI" | awk '{print $2}')
                    paired=$(echo "$info" | grep "Paired" | awk '{print $2}')
                    trusted=$(echo "$info" | grep "Trusted" | awk '{print $2}')
                    type=$(echo "$info" | grep "Icon" | awk '{print $2}')
                fi
                
                rssi=${rssi:-"N/A"}
                paired=${paired:-"no"}
                type=${type:-"Unknown"}
                
                printf "%-18s %-28s %-8s %-6s %s\n" "$mac" "${name:0:27}" "$type" "$rssi" "$paired"
                bluetooth_devices+=("$mac|$name|$type|$rssi|$paired")
                ((bt_count++))
            fi
        done < <(bluetoothctl devices 2>/dev/null)
        
        # Turn off scan
        bluetoothctl scan off >/dev/null 2>&1
    fi
    
    # Method 2: hcitool (Linux alternative)
    if [[ $bt_count -eq 0 ]] && check_command hcitool; then
        log "${BLUE}Using hcitool scanner...${NC}"
        
        for ((i=1; i<=scan_duration; i++)); do
            show_progress "$i" "$scan_duration" "Scanning Bluetooth..."
            sleep 1
        done
        echo ""
        
        log "\n${PURPLE}BLUETOOTH DEVICES FOUND:${NC}"
        log "${WHITE}MAC Address       Device Name${NC}"
        
        while read -r line; do
            if [[ "$line" =~ ^[[:xdigit:]]{2}: ]]; then
                mac=$(echo "$line" | awk '{print $1}')
                name=$(echo "$line" | cut -d' ' -f2-)
                printf "%-18s %s\n" "$mac" "$name"
                bluetooth_devices+=("$mac|$name")
                ((bt_count++))
            fi
        done < <(hcitool scan 2>/dev/null)
    fi
    
    # Method 3: Termux Bluetooth
    if [[ $bt_count -eq 0 ]] && check_command termux-bluetooth-scan; then
        log "${BLUE}Using Termux Bluetooth scanner...${NC}"
        
        scan_result=$(termux-bluetooth-scan 2>/dev/null)
        if [[ -n "$scan_result" ]]; then
            log "\n${PURPLE}BLUETOOTH DEVICES FOUND:${NC}"
            echo "$scan_result" | while read -r line; do
                bluetooth_devices+=("$line")
                log " $line"
                ((bt_count++))
            done
        fi
    fi
    
    if [[ $bt_count -eq 0 ]]; then
        log "${YELLOW}⚠ No Bluetooth devices detected${NC}"
    else
        log "\n${GREEN}✓ Found $bt_count Bluetooth device(s)${NC}"
    fi
}

# Function to scan ARP table (connected devices)
scan_arp() {
    log "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
    log "${GREEN}🌐 SCANNING NETWORK DEVICES (ARP)${NC}"
    log "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    local arp_count=0
    
    # Try multiple ARP commands
    if check_command arp; then
        log "${PURPLE}ACTIVE NETWORK DEVICES:${NC}"
        log "${WHITE}IP Address        MAC Address       Vendor              Interface${NC}"
        
        # Get ARP table
        while read -r line; do
            # Parse different ARP output formats
            if [[ "$line" =~ ^[^\(].*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
                ip=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
                mac=$(echo "$line" | grep -oE '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | head -1)
                
                if [[ -n "$ip" && -n "$mac" ]]; then
                    # Try to get vendor from MAC
                    vendor=$(get_vendor_from_mac "$mac")
                    
                    # Try to get interface
                    iface=$(echo "$line" | grep -oE 'on [^ ]+' | cut -d' ' -f2)
                    
                    printf "%-16s %-18s %-18s %s\n" "$ip" "$mac" "$vendor" "${iface:-N/A}"
                    arp_devices+=("$ip|$mac|$vendor")
                    ((arp_count++))
                fi
            fi
        done < <(arp -a 2>/dev/null | head -30)
    fi
    
    # Alternative: ip neigh
    if [[ $arp_count -eq 0 ]] && check_command ip; then
        log "${PURPLE}ACTIVE NETWORK DEVICES:${NC}"
        log "${WHITE}IP Address        MAC Address       State     Device${NC}"
        
        while read -r line; do
            if [[ "$line" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
                ip=$(echo "$line" | awk '{print $1}')
                mac=$(echo "$line" | awk '{print $5}')
                state=$(echo "$line" | awk '{print $6}')
                dev=$(echo "$line" | awk '{print $3}')
                
                if [[ -n "$ip" && -n "$mac" && "$mac" != "00:00:00:00:00:00" ]]; then
                    printf "%-16s %-18s %-10s %s\n" "$ip" "$mac" "$state" "$dev"
                    arp_devices+=("$ip|$mac|$state")
                    ((arp_count++))
                fi
            fi
        done < <(ip neigh show 2>/dev/null)
    fi
    
    if [[ $arp_count -eq 0 ]]; then
        log "${YELLOW}⚠ No active network devices found${NC}"
    else
        log "\n${GREEN}✓ Found $arp_count active device(s) on network${NC}"
    fi
}

# Function to get vendor from MAC address
get_vendor_from_mac() {
    local mac="$1"
    local oui=$(echo "$mac" | tr '[:lower:]' '[:upper:]' | sed 's/[ :-]//g' | cut -c1-6)
    
    # Common vendors database
    case "$oui" in
        "00037F") echo "Atheros" ;;
        "001377") echo "Samsung" ;;
        "001EC9") echo "Apple" ;;
        "001E52") echo "Apple" ;;
        "0017F2") echo "HTC" ;;
        "0022D6") echo "LG" ;;
        "00248C") echo "Motorola" ;;
        "0050F2") echo "Microsoft" ;;
        "00A0C9") echo "Intel" ;;
        "08002B") echo "DEC" ;;
        "0C9D56") echo "Xiaomi" ;;
        "10A5D0") echo "Huawei" ;;
        "10C5E9") echo "OnePlus" ;;
        "18AF8F") echo "Xiaomi" ;;
        "1C6F65") echo "TP-Link" ;;
        "24DA33") echo "Samsung" ;;
        "2C27D7") echo "Huawei" ;;
        "30B5C2") echo "Google" ;;
        "34A843") echo "ASUS" ;;
        "38229D") echo "Cisco" ;;
        "3C2C30") echo "Amazon" ;;
        "404022") echo "Roku" ;;
        "446655") echo "D-Link" ;;
        "50C58D") echo "Sony" ;;
        "54E6FC") echo "Netgear" ;;
        "5C696D") echo "Nest" ;;
        "649A12") echo "Apple" ;;
        "7054D2") echo "Fitbit" ;;
        "80B289") echo "Belkin" ;;
        "8400D2") echo "Xiaomi" ;;
        "882593") echo "Intel" ;;
        "8C856B") echo "HTC" ;;
        "8CB82C") echo "Microsoft" ;;
        "902B34") echo "NVIDIA" ;;
        "94E711") echo "Canon" ;;
        "9C1A82") echo "Raspberry Pi" ;;
        "A49B13") echo "LG" ;;
        "ACF1DF") echo "TP-Link" ;;
        "B0C554") echo "Netgear" ;;
        "B8797E") echo "Apple" ;;
        "C4E984") echo "Amazon" ;;
        "CCF3A5") echo "D-Link" ;;
        "D0EBE1") echo "Acer" ;;
        "D8D1CB") echo "Intel" ;;
        "E04F43") echo "Nintendo" ;;
        "E8D0FC") echo "HP" ;;
        "F02765") echo "TP-Link" ;;
        "F80CF3") echo "Samsung" ;;
        "FC1FC0") echo "Apple" ;;
        *) echo "Unknown" ;;
    esac
}

# Function to detect device types
detect_device_types() {
    log "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
    log "${GREEN}📊 DEVICE CLASSIFICATION${NC}"
    log "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    local smartphone=0
    local laptop=0
    local tablet=0
    local iot=0
    local router=0
    local printer=0
    local tv=0
    local gaming=0
    local other=0
    
    # Classify based on MAC OUI and naming patterns
    for device in "${arp_devices[@]}"; do
        IFS='|' read -r ip mac vendor <<< "$device"
        
        # Classify by vendor
        case "$vendor" in
            *Apple*|*Samsung*|*HTC*|*LG*|*Motorola*|*Xiaomi*|*Huawei*|*OnePlus*|*Google*)
                ((smartphone++)) ;;
            *Intel*|*Dell*|*HP*|*Acer*|*Microsoft*)
                ((laptop++)) ;;
            *iPad*|*Kindle*|*Fire*)
                ((tablet++)) ;;
            *Amazon*|*Google*|*Nest*|*Belkin*|*TP-Link*|*D-Link*|*Netgear*|*Linksys*)
                ((iot++)) ;;
            *Cisco*|*Router*|*Ubiquiti*)
                ((router++)) ;;
            *Canon*|*Brother*|*Epson*|*HP*)
                ((printer++)) ;;
            *Sony*|*Samsung*|*LG*|*Roku*|*AppleTV*)
                ((tv++)) ;;
            *NVIDIA*|*Nintendo*|*Sony*|*Microsoft*|*Xbox*)
                ((gaming++)) ;;
            *)
                ((other++)) ;;
        esac
    done
    
    log "${BLUE}Classification Results:${NC}"
    log "  📱 Smartphones: $smartphone"
    log "  💻 Laptops: $laptop"
    log "  📟 Tablets: $tablet"
    log "  🏠 IoT Devices: $iot"
    log "  📡 Routers: $router"
    log "  🖨️  Printers: $printer"
    log "  📺 TVs/Media: $tv"
    log "  🎮 Gaming: $gaming"
    log "  ❓ Other: $other"
}

# Function to analyze wireless environment
analyze_wireless() {
    log "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
    log "${GREEN}📊 WIRELESS ENVIRONMENT ANALYSIS${NC}"
    log "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    # Channel usage
    log "${BLUE}WiFi Channel Usage:${NC}"
    declare -A channels
    
    for network in "${wifi_networks[@]}"; do
        # Extract channel number (crude but works)
        channel=$(echo "$network" | grep -oE '[0-9]{1,2}' | head -1)
        if [[ -n "$channel" ]]; then
            channels[$channel]=$((channels[$channel] + 1))
        fi
    done
    
    for channel in "${!channels[@]}"; do
        log "  Channel $channel: ${channels[$channel]} networks"
    done
    
    # Signal strength distribution
    log "\n${BLUE}Signal Strength Distribution:${NC}"
    local strong=0
    local medium=0
    local weak=0
    
    for network in "${wifi_networks[@]}"; do
        if [[ "$network" =~ ([0-9]{1,3})% ]]; then
            signal="${BASH_REMATCH[1]}"
            if (( signal >= 70 )); then
                ((strong++))
            elif (( signal >= 40 )); then
                ((medium++))
            else
                ((weak++))
            fi
        fi
    done
    
    log "  📶 Strong (70-100%): $strong"
    log "  📶 Medium (40-69%): $medium"
    log "  📶 Weak (0-39%): $weak"
}

# Function to export results
export_results() {
    if [[ "$EXPORT" == true ]]; then
        log "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        log "${GREEN}💾 EXPORTING RESULTS${NC}"
        log "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        
        # Create JSON if requested
        if [[ "$JSON_OUTPUT" == true ]]; then
            {
                echo "{"
                echo "  \"scan_info\": {"
                echo "    \"timestamp\": \"$(date -Iseconds)\","
                echo "    \"hostname\": \"$HOSTNAME\","
                echo "    \"os\": \"$OS\","
                echo "    \"mode\": \"$SCAN_MODE\""
                echo "  },"
                echo "  \"interfaces\": {"
                echo "    \"wifi\": [\"$(printf '%s' "${wireless_interfaces[*]}" | sed 's/ /","/g')\"],"
                echo "    \"bluetooth\": [\"$(printf '%s' "${bt_interfaces[*]}" | sed 's/ /","/g')\"]"
                echo "  },"
                echo "  \"statistics\": {"
                echo "    \"wifi_networks\": ${#wifi_networks[@]},"
                echo "    \"bluetooth_devices\": ${#bluetooth_devices[@]},"
                echo "    \"network_devices\": ${#arp_devices[@]}"
                echo "  }"
                echo "}"
            } > "$JSON_FILE"
            log "${GREEN}✓ JSON export:${NC} $JSON_FILE"
        fi
        
        log "${GREEN}✓ Log file:${NC} $LOG_FILE"
    fi
}

# Function to show summary
show_summary() {
    local scan_end=$(date +%s)
    local scan_duration=$((scan_end - SCAN_START))
    
    log "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
    log "${GREEN}📋 SCAN SUMMARY${NC}"
    log "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    log "  🕒 Duration: ${scan_duration}s"
    log "  📡 WiFi Networks: ${#wifi_networks[@]}"
    log "  📱 Bluetooth Devices: ${#bluetooth_devices[@]}"
    log "  🌐 Network Devices: ${#arp_devices[@]}"
    
    if [[ "$EXPORT" == true ]]; then
        log "  💾 Export Directory: $OUTPUT_DIR"
    fi
}

# Function to show banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     TRACE-IT WIRELESS DEVICE SCANNER v$VERSION                      ║"
    echo "║     Universal Cross-Platform Discovery Tool                  ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${WHITE}Host:${NC} $HOSTNAME"
    echo -e "${WHITE}OS:${NC} $OS"
    echo -e "${WHITE}Mode:${NC} $SCAN_MODE scan"
    echo -e "${WHITE}Date:${NC} $(date)"
    echo ""
}

# ======================================================
#  MAIN EXECUTION
# ======================================================

# Show banner
show_banner

# Run all scans
detect_interfaces
scan_wifi
scan_bluetooth
scan_arp
detect_device_types
analyze_wireless
export_results
show_summary

# Final message
log "\n${GREEN}✓ Scan completed successfully!${NC}"
if [[ "$EXPORT" == true ]]; then
    log "${BLUE}Results saved to:${NC} $LOG_FILE"
fi

echo ""
read -p "Press Enter to exit..."
clear
exit 0