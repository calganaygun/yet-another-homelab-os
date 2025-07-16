#!/bin/bash
set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Helper Functions ---
info() {
    echo -e "${GREEN}[INFO] ${1}${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN] ${1}${NC}"
}

error() {
    echo -e "${RED}[ERROR] ${1}${NC}"
    exit 1
}

# --- Installation Functions ---

# Function to check for required dependencies
check_dependencies() {
    info "Checking for required tools..."
    local missing_tools=()
    local tools=("curl" "openssl" "sed")

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        error "The following required tools are not installed: ${missing_tools[*]}. Please install them and re-run the script."
    fi
    info "All required tools are present."
}

# Function to check if the script is run as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root. Please use sudo."
    fi
    info "Root privileges confirmed."
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        OS=Debian
        VER=$(cat /etc/debian_version)
    else
        # Fallback
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    info "Detected OS: $OS $VER"
}

# Function to install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        info "Docker is already installed."
        return
    fi

    info "Installing Docker..."
    case "$OS" in
        "Ubuntu" | "Debian")
            apt-get update
            apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io
            ;;
        "CentOS" | "Fedora" | "Red Hat Enterprise Linux")
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io
            ;;
        *)
            error "Unsupported OS: $OS. Please install Docker manually."
            ;;
    esac
    systemctl start docker
    systemctl enable docker
    info "Docker installed successfully."
}

# Function to install Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        info "Docker Compose is already installed."
        return
    fi

    info "Installing Docker Compose..."
    LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    if [ -z "$LATEST_COMPOSE_VERSION" ]; then
        error "Could not fetch latest Docker Compose version."
    fi
    curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    info "Docker Compose installed successfully."
}


# --- Configuration Functions ---

# Function to prompt for user configuration
prompt_for_config() {
    info "Please provide the following configuration details."
    # Load from env file if it exists
    if [ -f ".yethos.env" ]; then
        info "Loading existing configuration from .yethos.env"
        source .yethos.env
    fi

    read -p "Enter your domain name [${YETHOS_DOMAIN}]: " new_domain
    YETHOS_DOMAIN=${new_domain:-$YETHOS_DOMAIN}

    read -p "Enter your email for Let's Encrypt SSL [${YETHOS_EMAIL}]: " new_email
    YETHOS_EMAIL=${new_email:-$YETHOS_EMAIL}


    if [ -z "$YETHOS_DOMAIN" ] || [ -z "$YETHOS_EMAIL" ]; then
        error "Domain name and email are required."
    fi
}

# Function to configure TinyAuth
configure_tinyauth() {
    info "Configuring TinyAuth..."
    if [ -z "$YETHOS_TINYAUTH_SECRET" ]; then
        info "Generating new TinyAuth secret..."
        YETHOS_TINYAUTH_SECRET=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
    else
        info "Using existing TinyAuth secret."
    fi

    if [ -z "$YETHOS_TINYAUTH_USERS" ]; then
        warn "You need to create at least one TinyAuth user."
        local users_list=""
        while true; do
            read -p "Enter username for TinyAuth user: " username
            read -s -p "Enter password for $username: " password
            echo ""

            if [ -z "$username" ] || [ -z "$password" ]; then
                error "Username and password cannot be empty."
                continue
            fi

            info "Generating user hash for $username..."
            local user_hash
            user_hash=$(docker run --rm ghcr.io/steveiliop56/tinyauth:v3 user create --username "$username" --password "$password" --docker)
            
            if [ -z "$users_list" ]; then
                users_list="$user_hash"
            else
                users_list="$users_list,$user_hash"
            fi

            read -p "Do you want to add another user? (y/n): " add_another
            if [[ "$add_another" != "y" ]]; then
                break
            fi
        done
        YETHOS_TINYAUTH_USERS=$users_list
    else
        info "Using existing TinyAuth users."
        info "To add more users, run './yethos-cli.sh user create' after installation."
    fi
}

# Function to create environment file
create_env_file() {
    info "Saving configuration to .yethos.env file..."
    # Remove old file to ensure clean state
    rm -f .yethos.env
    
    echo "YETHOS_DOMAIN=${YETHOS_DOMAIN}" >> .yethos.env
    echo "YETHOS_EMAIL=${YETHOS_EMAIL}" >> .yethos.env
    echo "YETHOS_TINYAUTH_SECRET=${YETHOS_TINYAUTH_SECRET}" >> .yethos.env
    echo "YETHOS_TINYAUTH_USERS='${YETHOS_TINYAUTH_USERS}'" >> .yethos.env
    
    # Update traefik.yml with user's email
    sed -i.bak "s/email: \".*\"/email: \"$YETHOS_EMAIL\"/g" config/traefik/traefik.yml
    rm config/traefik/traefik.yml.bak

    info ".yethos.env file created and traefik.yml updated."
}


# --- Deployment Functions ---

# Function to install cloudflared
install_cloudflared() {
    if command -v cloudflared &> /dev/null; then
        info "cloudflared is already installed."
        return
    fi

    info "Installing cloudflared..."
    case "$OS" in
        "Ubuntu" | "Debian")
            curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
            echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main' | tee /etc/apt/sources.list.d/cloudflared.list
            apt-get update
            apt-get install -y cloudflared
            ;;
        *)
            warn "Automatic installation of cloudflared is not supported for $OS."
            warn "Please install it manually from https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
            return
            ;;
    esac
    info "cloudflared installed successfully."
}

# Function to deploy services
deploy_services() {
    info "Deploying Traefik and TinyAuth services..."
    # Use the env file to bring up the services
    docker-compose --env-file .yethos.env up -d
    info "Services deployed."
}

# --- Main Execution ---
main() {
    info "Starting Yet Another Homelab OS (yethos) setup..."

    check_dependencies
    check_root
    detect_distro
    install_docker
    install_docker_compose

    prompt_for_config
    configure_tinyauth
    create_env_file

    install_cloudflared
    deploy_services

    info "yethos setup complete!"
    echo ""
    warn "ACTION REQUIRED: You now need to authenticate cloudflared and create a tunnel."
    echo "1. Run 'cloudflared tunnel login' and follow the instructions."
    echo "2. Create a tunnel: 'cloudflared tunnel create yethos-tunnel'"
    echo "3. Create a CNAME record in your Cloudflare DNS for 'auth' pointing to your tunnel URL."
    echo "   Example: CNAME auth <your-tunnel-uuid>.cfargotunnel.com"
    echo ""
    info "Once the tunnel is active, your services will be available at:"
    info " - TinyAuth: https://auth.${YETHOS_DOMAIN}"
    info "To manage TinyAuth users (add more, generate TOTP, etc.), use the ./yethos-cli.sh script."
    info "To protect other services, see the 'docker-compose.whoami-example.yml' file."
}


main "$@"
