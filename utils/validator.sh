#!/bin/bash

validate_ip_or_host() {
  if [[ -z "$1" ]]; then
    echo "[ERROR] Target IP or hostname is required."
    return 1
  fi
  return 0
}

validate_domain() {
  if [[ -z "$1" ]]; then
    echo "[ERROR] Domain name is required."
    return 1
  fi
  return 0
}
check_dependencies() {
  local missing=()
  local required=("curl" "jq" "dig" "arp" "hostname" "ip" "nmap")

  for cmd in "${required[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "[ERROR] Missing required dependencies:"
    for m in "${missing[@]}"; do echo "  - $m"; done
    echo "Please install them manually or run 'sudo ./setup.sh'."
    return 1
  fi

  return 0
}
