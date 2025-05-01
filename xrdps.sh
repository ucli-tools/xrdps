#!/bin/bash

# Tool name
tool_name="xrdps"

# Use tput for portable color codes
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NC=$(tput sgr0)

# Logging function
log() {
    local level="$1"
    local message="$2"
    local color=""
    case "$level" in
        INFO)  color="$GREEN";;
        WARN)  color="$YELLOW";;
        ERROR) color="$RED";;
        *)     color="";;
    esac
    echo -e "${color}[${level}]${NC} $message" >&2
}

# Install the script itself
install() {
    install_dir="/usr/local/bin"
    if ! sudo mkdir -p "$install_dir" 2>/dev/null; then
        log ERROR "Error creating directory $install_dir. Ensure you have sudo privileges."
        return 1
    fi
    if ! sudo chown "$USER":"$USER" "$install_dir"; then
        log ERROR "Error setting ownership of $install_dir. Ensure you have sudo privileges."
        return 1
    fi
    install_path="$install_dir/$tool_name"
    if ! sudo cp "$0" "$install_path" 2>/dev/null; then
        log ERROR "Error copying $tool_name to $install_path. Ensure you have sudo privileges."
        return 1
    fi
    if ! sudo chmod +x "$install_path"; then
        log ERROR "Error setting permissions for $install_path. Ensure you have sudo privileges."
        return 1
    fi
    log INFO "$tool_name installed to $install_path."
}

# Uninstall the script
uninstall() {
    uninstall_path="/usr/local/bin/$tool_name"
    if [[ -f "$uninstall_path" ]]; then
        if ! sudo rm "$uninstall_path"; then
            log ERROR "Error uninstalling $tool_name. Ensure you have sudo privileges."
            return 1
        fi
        log INFO "$tool_name successfully uninstalled."
    else
        log WARN "$tool_name is not installed in /usr/local/bin."
    fi
}

# Function to provide client-side connection instructions
xrdp_info() {
    echo
    echo "The setup is now complete. To connect remotely:"
    echo
    echo "1. Find the VM IP address (e.g., using 'ip addr show' or 'tailscale ip' with Tailscale)."
    echo "2. Install a Remote Desktop Client:"
    echo "   * Windows: Download the Microsoft Remote Desktop app from the Microsoft Store"
    echo "   * macOS: Download the Microsoft Remote Desktop app from the Mac App Store"
    echo "   * Linux: Download the Remmina client"
    echo "3. Open the Remote Desktop Client and enter:"
    echo "   * Computer: VM IP address"
    echo "   * Username: $USER"
    echo "   * Password: $USER's password"
    echo "4. Connect!"
    echo
}

# Unified XRDP setup function
setup_xrdp() {
    local desktop_env="$1"
    if [[ -z "$desktop_env" || ("$desktop_env" != "xfce" && "$desktop_env" != "ubuntu") ]]; then
        log ERROR "Invalid desktop environment specified. Choose 'xfce' or 'ubuntu'."
        return 1
    fi

    log INFO "Updating package list..."
    if ! sudo apt update -y; then
        log ERROR "Failed to update package list."
        return 1
    fi

    # Function to check if a package is installed
    is_installed() {
        dpkg -l "$1" 2>/dev/null | grep -q "^ii"
    }

    if [[ "$desktop_env" == "xfce" ]]; then
        if ! is_installed "xrdp" || ! is_installed "xfce4" || ! is_installed "xfce4-goodies"; then
            log INFO "Attempting to install missing XFCE components..."
            sudo apt install -y xrdp xfce4 xfce4-goodies || log WARN "Package installation failed, continuing anyway..."
        fi
        session="xfce4-session"
    elif [[ "$desktop_env" == "ubuntu" ]]; then
        if ! is_installed "xrdp" || ! is_installed "ubuntu-desktop"; then
            log INFO "Attempting to install missing Ubuntu Desktop components..."
            sudo apt install -y xrdp ubuntu-desktop || log WARN "Package installation failed, continuing anyway..."
        fi
        session="gnome-session"
    fi

    log INFO "Enabling and starting the XRDP service..."
    if ! sudo systemctl enable xrdp --now || ! sudo systemctl is-active xrdp; then
        log ERROR "Failed to enable/start XRDP service. Check your systemd logs for details."
        return 1
    fi

    log INFO "Creating ${desktop_env^^} session for $USER..."
    if ! sudo sh -c "echo '$session' > /home/$USER/.xsession" || ! sudo chown "$USER":"$USER" "/home/$USER/.xsession"; then
        log ERROR "Failed to create ${desktop_env^^} session. Please manually create /home/$USER/.xsession and add the line '$session'."
        return 1
    fi

    log INFO "Checking XRDP status..."
    status=$(sudo systemctl status xrdp | grep 'Active: ')
    log INFO "XRDP daemon is: ${status##*Active: }"
    log INFO "XRDP setup is complete for user $USER. You can now connect to this machine via RDP using its IP address and username '$USER'."
    xrdp_info
}

interactive_menu() {
    while true; do
        echo
        printf "${GREEN}Welcome to the XRDP Setup Tool!${NC}\n\n"
        echo "What would you like to do?"
        echo
        echo "1. Set up XRDP with XFCE GUI"
        echo "2. Set up XRDP with Ubuntu GUI"
        echo "3. Show XRDP client connection steps"
        echo "4. Exit"
        read -p "Please enter your choice [1-4]: " choice

        case $choice in
            1) 
                setup_xrdp xfce
                break
                ;;
            2)  
                setup_xrdp ubuntu
                break
                ;;
            3) 
                xrdp_info 
                read -n 1 -s -r -p "Press ENTER to return to main menu..."
                ;;
            4) log INFO "Exiting interactive menu..."; break ;;
            *) log WARN "Invalid choice. Please enter a number between 1 and 4." ;;
        esac
    done
}

# Main execution
case "$1" in
    install) install ;;
    uninstall) uninstall ;;
    *) interactive_menu ;;
esac