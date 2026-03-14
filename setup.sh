#!/usr/bin/env bash
# ===========================================================
# Trace-it Universal Installer
# Works on: Linux / WSL / Termux / macOS
# ===========================================================

set -e

APP_NAME="Trace-it"
REPO_URL="https://github.com/Cyberdavil0/Trace-it.git"

# ===========================================================
# Detect OS
# ===========================================================

OS_TYPE="$(uname -s)"

if [[ "$OS_TYPE" == "Linux" ]]; then

    if grep -qi microsoft /proc/version 2>/dev/null; then
        OS="wsl"

    elif [[ -n "$PREFIX" ]] && [[ "$PREFIX" == "/data/data/com.termux/files/usr" ]]; then
        OS="termux"

    else
        OS="linux"
    fi

elif [[ "$OS_TYPE" == "Darwin" ]]; then
    OS="macos"

else
    OS="unknown"
fi


# ===========================================================
# Detect install location
# ===========================================================

if [[ "$EUID" -eq 0 ]]; then
    INSTALL_DIR="/usr/bin/Trace-it"
    BIN_PATH="/usr/bin/trace"
    MODE="global"
else
    INSTALL_DIR="$HOME/.local/bin/Trace-it"
    BIN_PATH="$HOME/.local/bin/trace"
    MODE="local"
fi


# ===========================================================
# Detect package manager
# ===========================================================

detect_pkg_manager() {

    if [[ "$OS" == "termux" ]]; then
        PKG="pkg"

    elif command -v apt-get >/dev/null; then
        PKG="apt"

    elif command -v pacman >/dev/null; then
        PKG="pacman"

    elif command -v yum >/dev/null; then
        PKG="yum"

    elif command -v dnf >/dev/null; then
        PKG="dnf"

    elif command -v brew >/dev/null; then
        PKG="brew"

    else
        PKG="unknown"
    fi
}


# ===========================================================
# Dependency checker
# ===========================================================

check_dependencies() {

    detect_pkg_manager

    REQUIRED_TOOLS=(bash curl jq unzip wget git nmap hostname)

    case "$OS" in
        linux|wsl|termux)
            REQUIRED_TOOLS+=(dig ip arp)
        ;;
        macos)
            REQUIRED_TOOLS+=(dig ifconfig arp)
        ;;
    esac


    MISSING=()
    INSTALL_PKGS=()

    for tool in "${REQUIRED_TOOLS[@]}"; do

        if ! command -v "$tool" >/dev/null 2>&1; then

            MISSING+=("$tool")

            case "$tool" in

                dig|nslookup)

                    case "$PKG" in
                        apt) INSTALL_PKGS+=("dnsutils") ;;
                        pacman) INSTALL_PKGS+=("bind") ;;
                        yum|dnf) INSTALL_PKGS+=("bind-utils") ;;
                        brew) INSTALL_PKGS+=("bind") ;;
                        pkg) INSTALL_PKGS+=("dnsutils") ;;
                    esac
                ;;

                arp)
                    INSTALL_PKGS+=("net-tools")
                ;;

                ip)
                    case "$PKG" in
                        apt) INSTALL_PKGS+=("iproute2") ;;
                        pacman) INSTALL_PKGS+=("iproute2") ;;
                        yum|dnf) INSTALL_PKGS+=("iproute") ;;
                        pkg) INSTALL_PKGS+=("iproute2") ;;
                    esac
                ;;

                *)
                    INSTALL_PKGS+=("$tool")
                ;;

            esac
        fi
    done


    if [[ ${#MISSING[@]} -gt 0 ]]; then

        echo "[!] Missing tools: ${MISSING[*]}"

        INSTALL_PKGS=($(printf "%s\n" "${INSTALL_PKGS[@]}" | sort -u))

        if [[ "$PKG" == "unknown" ]]; then
            echo "[!] Unknown package manager. Install manually:"
            echo "${INSTALL_PKGS[*]}"
            exit 1
        fi

        read -rp "Install dependencies now? [Y/n]: " choice
        choice=${choice:-Y}

        if [[ "$choice" =~ ^[Yy]$ ]]; then

            case "$PKG" in

                apt)
                    sudo apt update
                    sudo apt install -y "${INSTALL_PKGS[@]}"
                ;;

                pacman)
                    sudo pacman -Sy --noconfirm "${INSTALL_PKGS[@]}"
                ;;

                yum)
                    sudo yum install -y "${INSTALL_PKGS[@]}"
                ;;

                dnf)
                    sudo dnf install -y "${INSTALL_PKGS[@]}"
                ;;

                pkg)
                    pkg update -y
                    pkg install -y "${INSTALL_PKGS[@]}"
                ;;

                brew)
                    brew install "${INSTALL_PKGS[@]}"
                ;;

            esac
        else
            echo "[!] Dependencies required. Exiting."
            exit 1
        fi
    fi
}


# ===========================================================
# Install
# ===========================================================

install_app() {

    echo "[+] Installing $APP_NAME ($MODE mode)..."

    check_dependencies

    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"

    cp -r "$(pwd)"/* "$INSTALL_DIR/"
    cp -r "$(pwd)"/core "$INSTALL_DIR"/
    cp -r "$(pwd)"/utils "$INSTALL_DIR"/

    mkdir -p "$(dirname "$BIN_PATH")"

    cat <<EOF > "$BIN_PATH"
#!/usr/bin/env bash

if [[ -d "/usr/bin/Trace-it" ]]; then
TRACE_DIR="/usr/bin/Trace-it"
elif [[ -d "\$HOME/.local/bin/Trace-it" ]]; then
TRACE_DIR="\$HOME/.local/bin/Trace-it"
else
echo "[!] Trace-it not installed"
exit 1
fi

exec bash "\$TRACE_DIR/trace.sh" "\$@"
EOF

    chmod +x "$BIN_PATH"
    chmod +x "$INSTALL_DIR/trace.sh"

    if [[ "$MODE" == "local" ]]; then

        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then

            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

            echo "[+] Added ~/.local/bin to PATH"
        fi
    fi

    echo
    echo "[✓] Installation complete!"
    echo "Run command: trace"
}


# ===========================================================
# Uninstall
# ===========================================================

uninstall_app() {

    echo "[+] Removing $APP_NAME..."

    rm -rf "$INSTALL_DIR"
    rm -f "$BIN_PATH"

    echo "[✓] Uninstalled successfully."
}


# ===========================================================
# Update
# ===========================================================

update_app() {

    echo "[+] Updating $APP_NAME..."

    TMP_DIR="/tmp/trace_update"

    rm -rf "$TMP_DIR"

    git clone "$REPO_URL" "$TMP_DIR"

    rm -rf "$INSTALL_DIR"

    mkdir -p "$INSTALL_DIR"

    cp -r "$TMP_DIR"/* "$INSTALL_DIR/"

    chmod +x "$INSTALL_DIR/trace.sh"

    echo "[✓] Update complete!"
}


# ===========================================================
# Help
# ===========================================================

show_help() {

echo "Trace-it Universal Installer"

echo
echo "./setup.sh             → Install"
echo "./setup.sh --update    → Update"
echo "./setup.sh --uninstall → Remove tool"

}


# ===========================================================
# Main
# ===========================================================

case "$1" in

--update)
update_app
;;

--uninstall)
uninstall_app
;;

"")
install_app
;;

*)
show_help
;;

esac
