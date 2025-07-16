#!/bin/bash
set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

REPO_URL="https://github.com/calganaygun/yet-another-homelab-os.git"
REPO_DIR="yet-another-homelab-os"

info() {
    echo -e "${GREEN}[INFO] ${1}${NC}"
}

error() {
    echo -e "${RED}[ERROR] ${1}${NC}"
    exit 1
}

# Function to check for git and install if missing
check_and_install_git() {
    if command -v git &> /dev/null; then
        info "Git is already installed."
        return
    fi

    info "Git is not installed. Attempting to install..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
    else
        error "Could not detect OS to install Git. Please install it manually and re-run this script."
    fi

    case "$OS" in
        "Ubuntu" | "Debian")
            sudo apt-get update
            sudo apt-get install -y git
            ;;
        "CentOS" | "Fedora" | "Red Hat Enterprise Linux")
            sudo yum install -y git
            ;;
        *)
            error "Unsupported OS: $OS. Please install Git manually and re-run this script."
            ;;
    esac
    info "Git installed successfully."
}

main() {
    info "Starting yethos deployment..."
    
    check_and_install_git

    if [ -d "$REPO_DIR" ]; then
        info "Repository directory '$REPO_DIR' already exists. Skipping clone."
    else
        info "Cloning yethos repository from $REPO_URL..."
        git clone "$REPO_URL"
    fi

    cd "$REPO_DIR"
    info "Changed directory to $REPO_DIR."

    info "Executing the main installation script..."
    sudo bash install.sh

    info "Deployment script finished."
}

main "$@"
