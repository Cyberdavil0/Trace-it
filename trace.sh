#!/bin/bash
# ===========================================================
# Trace-it CLI Controller (with --upgrade and --uninstall)
# ===========================================================

# Determine base directory of trace.sh
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$BASE_DIR/core"

# Color codes
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
RESET="\e[0m"

# ========================
# HELP FUNCTION
# ========================
show_help() {
  echo -e "${RED}
┌──────────────────────────────────────────────────┐
│ ░█▀▀░█░█░█▀▀▄░█▀▀░█▀▄░ :: █▀▄░█░█░█▀▀▄░█▀▄░█▀▀█░ │
│ ░█░░░░█░░█▀▀▄░█▀▀░█▀▄░ :: █▀▄░█░█░█  █░█▀▄░█▀▀█░ │
│ ░▀▀▀░░▀░░▀▀▀░░▀▀▀░▀░▀░ :: ▀░▀░▀▀▀░▀▀▀ ░▀░▀░▀░░▀░ │
└──────────────────────────────────────────────────┘${RESET}
"
  echo -e "${GREEN}Hello everyone${RESET}"
  echo -e "${BLUE}Welcome to the world of cybersecurity 🌎${RESET}"
  echo ""
  echo -e "${YELLOW}Usage:${RESET}"
  echo "  trace -me               → Trace your own IP and device info"
  echo "  trace -t <target>       → Trace target IP or hostname"
  echo "  trace -net              → Scan nearby network devices"
  echo "  trace -w <domain>       → Resolve domain to IP"
  echo "  trace --upgrade         → Update Trace-it from GitHub"
  echo "  trace --uninstall       → Remove Trace-it"
  echo "  trace -help             → Show this help message"
  echo ""
}

# ========================
# ERROR FUNCTION
# ========================
error_exit() {
  echo -e "${RED}[ERROR] $1${RESET}"
  exit 1
}

# ========================
# SETUP.SH PATH DETECTION
# ========================
find_setup() {
  # Check if setup.sh exists in same dir or parent dir
  if [[ -f "$BASE_DIR/setup.sh" ]]; then
    echo "$BASE_DIR/setup.sh"
  elif [[ -f "$BASE_DIR/../setup.sh" ]]; then
    echo "$BASE_DIR/../setup.sh"
  else
    error_exit "setup.sh not found. Cannot perform this operation."
  fi
}

# ========================
# ARGUMENT HANDLING
# ========================
case "$1" in

  -me)
    bash "$CORE_DIR/trace_me.sh"
    ;;

  -t)
    [[ -z "$2" ]] && error_exit "Please provide target IP or hostname."
    bash "$CORE_DIR/trace_target.sh" "$2"
    ;;

  -net)
    bash "$CORE_DIR/trace_network.sh"
    ;;

  -w)
    [[ -z "$2" ]] && error_exit "Please provide domain name."
    bash "$CORE_DIR/trace_web.sh" "$2"
    ;;

  --upgrade)
    SETUP_SCRIPT=$(find_setup)
    bash "$SETUP_SCRIPT" --update
    ;;

  --uninstall)
    SETUP_SCRIPT=$(find_setup)
    bash "$SETUP_SCRIPT" --uninstall
    ;;

  -help|"")
    show_help
    ;;

  *)
    error_exit "Invalid option. Use -help to see available commands."
    ;;

esac
