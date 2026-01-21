#!/bin/bash

# Xray-Edge-Tunnel - Complete Management Script with xhttp Support
# Installation, Configuration, and Management Tool

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# Configuration paths
readonly XRAY_CONFIG_DIR="/usr/local/etc/xray"
readonly XRAY_CONFIG_FILE="${XRAY_CONFIG_DIR}/config.json"
readonly CLIENTS_FILE="${XRAY_CONFIG_DIR}/clients.txt"
readonly OUTPUT_CONFIG_FILE="/root/xray-config.txt"
readonly LOG_FILE="/var/log/xray-installer.log"
readonly SCRIPT_CONFIG="/root/.xray-installer.conf"

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${LOG_FILE}"
}

# Print functions
print_msg() {
    echo -e "${GREEN}[✓]${NC} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
    log "WARNING: $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
    log "INFO: $1"
}

# Error handler
error_exit() {
    print_error "$1"
    print_error "Check log file: ${LOG_FILE}"
    echo ""
    read -p "Press Enter to continue..."
    return "${2:-1}"
}

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        echo "Please use: sudo $0"
        exit 1
    fi
}

# Print banner
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║       Xray-Edge-Tunnel Manager v2.1 xhttp        ║"
    echo "║        Complete Installation & Management        ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Main menu
show_menu() {
    print_banner
    
    # Check if Xray is installed
    if command -v xray &> /dev/null; then
        local xray_version=$(xray version 2>/dev/null | head -n1 | awk '{print $2}')
        echo -e "${GREEN}Xray Status:${NC} Installed (Version: $xray_version)"
        
        if systemctl is-active --quiet xray 2>/dev/null; then
            echo -e "${GREEN}Service Status:${NC} Running ✓"
        else
            echo -e "${RED}Service Status:${NC} Stopped ✗"
        fi
    else
        echo -e "${YELLOW}Xray Status:${NC} Not Installed"
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}1)${NC}  Install Xray (New Installation)"
    echo -e "${GREEN}2)${NC}  View Configuration"
    echo -e "${GREEN}3)${NC}  Show Connection Links"
    echo -e "${GREEN}4)${NC}  Add New Client"
    echo -e "${GREEN}5)${NC}  Remove Client"
    echo -e "${GREEN}6)${NC}  List All Clients"
    echo -e "${GREEN}7)${NC}  Service Management"
    echo -e "${GREEN}8)${NC}  View Logs"
    echo -e "${GREEN}9)${NC}  Uninstall Xray"
    echo -e "${RED}0)${NC}  Exit"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
}

# Check system compatibility
check_system() {
    print_info "Checking system compatibility..."
    
    if [[ ! -f /etc/debian_version ]] && [[ ! -f /etc/redhat-release ]]; then
        error_exit "This script only supports Debian/Ubuntu/CentOS systems" 1
        return 1
    fi
    
    if ! ping -c 1 -W 2 google.com &> /dev/null; then
        error_exit "No internet connection detected" 1
        return 1
    fi
    
    print_msg "System check passed"
}

# Install dependencies
install_dependencies() {
    print_info "Installing dependencies..."
    
    if command -v apt &> /dev/null; then
        apt update -qq >> "${LOG_FILE}" 2>&1 || true
        apt install -y curl wget socat certbot uuid-runtime psmisc net-tools dnsutils jq >> "${LOG_FILE}" 2>&1
    elif command -v yum &> /dev/null; then
        yum install -y curl wget socat certbot uuid net-tools bind-utils jq >> "${LOG_FILE}" 2>&1
    fi
    
    print_msg "Dependencies installed"
}

# Install Xray
install_xray_binary() {
    print_info "Installing Xray..."
    
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >> "${LOG_FILE}" 2>&1
    
    if ! command -v xray &> /dev/null; then
        error_exit "Failed to install Xray" 3
        return 1
    fi
    
    # Configure Xray service to run as root
    if [[ -f /etc/systemd/system/xray.service ]]; then
        sed -i 's/^User=nobody/User=root/' /etc/systemd/system/xray.service
        sed -i 's/^User=nobody/User=root/' /lib/systemd/system/xray.service 2>/dev/null || true
        systemctl daemon-reload
        print_msg "Xray service configured to run as root"
    fi
    
    print_msg "Xray installed: $(xray version | head -n1)"
}

# Get server IPs and show DNS instructions
get_server_info_and_dns() {
    echo ""
    print_info "Detecting server IP addresses..."
    
    IPV4=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || curl -4 -s --max-time 5 api.ipify.org 2>/dev/null || echo "Not detected")
    IPV6=$(curl -6 -s --max-time 5 ifconfig.me 2>/dev/null || curl -6 -s --max-time 5 api6.ipify.org 2>/dev/null || echo "Not available")
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              DNS Configuration Instructions                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Your Server IP Addresses:${NC}"
    echo -e "${GREEN}  IPv4:${NC} $IPV4"
    echo -e "${GREEN}  IPv6:${NC} $IPV6"
    echo ""
    echo -e "${YELLOW}Step-by-Step DNS Configuration:${NC}"
    echo ""
    echo -e "${BLUE}1. Login to your DNS provider (Cloudflare, Namecheap, etc.)${NC}"
    echo -e "${BLUE}2. Go to DNS Management section${NC}"
    echo -e "${BLUE}3. Add DNS records:${NC}"
    echo ""
    
    if [[ "$IPV4" != "Not detected" ]]; then
        echo -e "   ${GREEN}A Record (IPv4):${NC}"
        echo -e "   ┌─────────────────────────────────────────────┐"
        echo -e "   │ Type:    ${YELLOW}A${NC}                              │"
        echo -e "   │ Name:    ${YELLOW}@${NC} or ${YELLOW}subdomain${NC}                │"
        echo -e "   │ Value:   ${GREEN}$IPV4${NC}"
        echo -e "   │ TTL:     ${YELLOW}Auto${NC}                            │"
        echo -e "   │ Proxy:   ${YELLOW}DNS Only (Grey Cloud)${NC}          │"
        echo -e "   └─────────────────────────────────────────────┘"
        echo ""
    fi
    
    if [[ "$IPV6" != "Not available" ]]; then
        echo -e "   ${GREEN}AAAA Record (IPv6 - Optional):${NC}"
        echo -e "   ┌─────────────────────────────────────────────┐"
        echo -e "   │ Type:    ${YELLOW}AAAA${NC}                           │"
        echo -e "   │ Name:    ${YELLOW}@${NC} or ${YELLOW}subdomain${NC}                │"
        echo -e "   │ Value:   ${GREEN}$IPV6${NC}"
        echo -e "   │ TTL:     ${YELLOW}Auto${NC}                            │"
        echo -e "   └─────────────────────────────────────────────┘"
        echo ""
    fi
    
    echo -e "${BLUE}4. Save and wait 1-5 minutes for DNS propagation${NC}"
    echo ""
    echo -e "${YELLOW}Important:${NC} Start with ${YELLOW}DNS Only (Grey Cloud)${NC}, enable proxy after SSL"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    while true; do
        echo -e "${YELLOW}Choose an option:${NC}"
        echo -e "  ${GREEN}1)${NC} DNS configured - Continue"
        echo -e "  ${GREEN}2)${NC} Check DNS configuration"
        echo -e "  ${GREEN}3)${NC} Exit and configure later"
        echo ""
        read -p "$(echo -e ${YELLOW}Choice ${GREEN}[1-3]${NC}: )" DNS_CHOICE
        
        case "$DNS_CHOICE" in
            1)
                print_msg "Proceeding..."
                break
                ;;
            2)
                check_dns_config
                ;;
            3)
                return 1
                ;;
        esac
    done
}

# Check DNS configuration
check_dns_config() {
    echo ""
    print_info "Checking DNS for $DOMAIN..."
    echo ""
    
    DNS_IPV4=$(dig +short A "$DOMAIN" @8.8.8.8 2>/dev/null | tail -n1)
    if [[ -n "$DNS_IPV4" ]]; then
        if [[ "$DNS_IPV4" == "$IPV4" ]]; then
            echo -e "${GREEN}✓ IPv4:${NC} $DNS_IPV4 (Correct)"
        else
            echo -e "${YELLOW}⚠ IPv4:${NC} DNS=$DNS_IPV4, Server=$IPV4 (Mismatch)"
        fi
    else
        echo -e "${RED}✗ IPv4:${NC} Not configured"
    fi
    
    if [[ "$IPV6" != "Not available" ]]; then
        DNS_IPV6=$(dig +short AAAA "$DOMAIN" @8.8.8.8 2>/dev/null | tail -n1)
        if [[ -n "$DNS_IPV6" ]]; then
            echo -e "${GREEN}✓ IPv6:${NC} $DNS_IPV6"
        else
            echo -e "${YELLOW}⚠ IPv6:${NC} Not configured (Optional)"
        fi
    fi
    echo ""
}

# Get configuration from user
get_config() {
    echo ""
    print_info "Configuration Setup"
    echo ""
    
    # Domain
    while true; do
        read -p "$(echo -e ${YELLOW}Domain ${GREEN}\(e.g: vpn.example.com\)${NC}: )" DOMAIN
        
        if [[ -z "$DOMAIN" ]]; then
            print_error "Domain required"
            continue
        fi
        
        if [[ ! $DOMAIN =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
            print_error "Invalid domain format"
            continue
        fi
        
        print_msg "Domain: $DOMAIN"
        break
    done
    
    # Show DNS instructions
    if ! get_server_info_and_dns; then
        return 1
    fi
    
    # Transport Protocol Selection
    echo ""
    echo -e "${YELLOW}Select Transport Protocol:${NC}"
    echo -e "  ${GREEN}1)${NC} xhttp (Recommended - Modern HTTP/3)"
    echo -e "  ${GREEN}2)${NC} WebSocket (ws) - Traditional"
    echo ""
    read -p "$(echo -e ${YELLOW}Choice ${GREEN}[1-2]${NC}: )" TRANSPORT_CHOICE
    
    case "$TRANSPORT_CHOICE" in
        1)
            TRANSPORT="xhttp"
            print_msg "Transport: xhttp"
            ;;
        2)
            TRANSPORT="ws"
            print_msg "Transport: WebSocket"
            ;;
        *)
            TRANSPORT="xhttp"
            print_warning "Invalid choice, using xhttp"
            ;;
    esac
    
    # Path configuration
    echo ""
    if [[ "$TRANSPORT" == "xhttp" ]]; then
        read -p "$(echo -e ${YELLOW}Path ${GREEN}\(default: /\)${NC}: )" XHTTP_PATH
        XHTTP_PATH=${XHTTP_PATH:-/}
        [[ "$XHTTP_PATH" != /* ]] && XHTTP_PATH="/$XHTTP_PATH"
        print_msg "Path: $XHTTP_PATH"
        
        # Set WS_PATH to empty for xhttp
        WS_PATH=""
        
        # xhttp mode
        echo ""
        echo -e "${YELLOW}Select xhttp Mode:${NC}"
        echo -e "  ${GREEN}1)${NC} packet-up (Recommended)"
        echo -e "  ${GREEN}2)${NC} stream-up"
        echo -e "  ${GREEN}3)${NC} stream-one"
        echo ""
        read -p "$(echo -e ${YELLOW}Choice ${GREEN}[1-3]${NC}: )" MODE_CHOICE
        
        case "$MODE_CHOICE" in
            1) XHTTP_MODE="packet-up" ;;
            2) XHTTP_MODE="stream-up" ;;
            3) XHTTP_MODE="stream-one" ;;
            *) XHTTP_MODE="packet-up" ;;
        esac
        print_msg "Mode: $XHTTP_MODE"
    else
        read -p "$(echo -e ${YELLOW}WebSocket Path ${GREEN}\(default: /graphql\)${NC}: )" WS_PATH
        WS_PATH=${WS_PATH:-/graphql}
        [[ "$WS_PATH" != /* ]] && WS_PATH="/$WS_PATH"
        print_msg "Path: $WS_PATH"
        
        # Set xhttp variables to empty for ws
        XHTTP_PATH=""
        XHTTP_MODE=""
    fi
    
    # CDN Host
    echo ""
    read -p "$(echo -e ${YELLOW}CDN Host/Camouflage ${GREEN}\(default: chatgpt.com\)${NC}: )" CDN_HOST
    CDN_HOST=${CDN_HOST:-chatgpt.com}
    print_msg "CDN Host: $CDN_HOST"
    
    # Port
    echo ""
    echo -e "${YELLOW}Cloudflare HTTPS Ports:${NC} 443, 2053, 2083, 2087, 2096, 8443"
    read -p "$(echo -e ${YELLOW}Port ${GREEN}\(default: 443\)${NC}: )" PORT
    PORT=${PORT:-443}
    print_msg "Port: $PORT"
    
    # ALPN Configuration
    echo ""
    echo -e "${YELLOW}Select ALPN Protocol:${NC}"
    echo -e "  ${GREEN}1)${NC} h2 (HTTP/2 - Recommended)"
    echo -e "  ${GREEN}2)${NC} http/1.1"
    echo -e "  ${GREEN}3)${NC} h2,http/1.1 (Both)"
    echo ""
    read -p "$(echo -e ${YELLOW}Choice ${GREEN}[1-3]${NC}: )" ALPN_CHOICE
    
    case "$ALPN_CHOICE" in
        1) ALPN="h2" ;;
        2) ALPN="http/1.1" ;;
        3) ALPN="h2,http/1.1" ;;
        *) ALPN="h2" ;;
    esac
    print_msg "ALPN: $ALPN"
    
    # Fingerprint
    echo ""
    echo -e "${YELLOW}Select TLS Fingerprint:${NC}"
    echo -e "  ${GREEN}1)${NC} chrome (Recommended)"
    echo -e "  ${GREEN}2)${NC} firefox"
    echo -e "  ${GREEN}3)${NC} safari"
    echo -e "  ${GREEN}4)${NC} random"
    echo ""
    read -p "$(echo -e ${YELLOW}Choice ${GREEN}[1-4]${NC}: )" FP_CHOICE
    
    case "$FP_CHOICE" in
        1) FINGERPRINT="chrome" ;;
        2) FINGERPRINT="firefox" ;;
        3) FINGERPRINT="safari" ;;
        4) FINGERPRINT="random" ;;
        *) FINGERPRINT="chrome" ;;
    esac
    print_msg "Fingerprint: $FINGERPRINT"
    
    # Summary
    echo ""
    echo -e "${BLUE}Configuration Summary:${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Domain:      ${GREEN}$DOMAIN${NC}"
    echo -e "Transport:   ${GREEN}$TRANSPORT${NC}"
    if [[ "$TRANSPORT" == "xhttp" ]]; then
        echo -e "Path:        ${GREEN}$XHTTP_PATH${NC}"
        echo -e "Mode:        ${GREEN}$XHTTP_MODE${NC}"
    else
        echo -e "Path:        ${GREEN}$WS_PATH${NC}"
    fi
    echo -e "CDN Host:    ${GREEN}$CDN_HOST${NC}"
    echo -e "Port:        ${GREEN}$PORT${NC}"
    echo -e "ALPN:        ${GREEN}$ALPN${NC}"
    echo -e "Fingerprint: ${GREEN}$FINGERPRINT${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Proceed? ${GREEN}\(y/n\)${NC}: )" PROCEED
    [[ ! "$PROCEED" =~ ^[yY]$ ]] && return 1
    
    # Save configuration
    cat > "$SCRIPT_CONFIG" <<EOF
DOMAIN="$DOMAIN"
TRANSPORT="$TRANSPORT"
WS_PATH="${WS_PATH:-}"
XHTTP_PATH="${XHTTP_PATH:-}"
XHTTP_MODE="${XHTTP_MODE:-}"
CDN_HOST="$CDN_HOST"
PORT="$PORT"
ALPN="$ALPN"
FINGERPRINT="$FINGERPRINT"
IPV4="$IPV4"
IPV6="$IPV6"
EOF
    chmod 600 "$SCRIPT_CONFIG"
}

# Stop conflicting services
stop_services() {
    print_info "Stopping services on port 80..."
    
    for service in nginx apache2 httpd; do
        systemctl stop "$service" 2>/dev/null || true
    done
    
    fuser -k 80/tcp 2>/dev/null || true
    sleep 2
    print_msg "Port 80 ready"
}

# Get SSL certificate with improved handling
get_ssl() {
    print_info "SSL Certificate Configuration for $DOMAIN..."
    echo ""
    
    # Check if domain is .ir
    IS_IR_DOMAIN=false
    if [[ "$DOMAIN" =~ \.ir$ ]]; then
        IS_IR_DOMAIN=true
        print_warning "Detected .ir domain - Special handling required"
    fi
    
    echo -e "${YELLOW}SSL Certificate Options:${NC}"
    echo -e "  ${GREEN}1)${NC} Auto-obtain certificate with Certbot (Let's Encrypt)"
    echo -e "  ${GREEN}2)${NC} I already have certificates (provide paths)"
    echo -e "  ${GREEN}3)${NC} Skip SSL (not recommended)"
    echo ""
    read -p "$(echo -e ${YELLOW}Choice ${GREEN}[1-3]${NC}: )" SSL_CHOICE
    
    case "$SSL_CHOICE" in
        1)
            # Auto-obtain certificate
            obtain_ssl_auto
            SSL_METHOD="auto"
            ;;
        2)
            # Use existing certificates
            obtain_ssl_manual
            SSL_METHOD="manual"
            ;;
        3)
            print_warning "Proceeding without SSL (insecure!)"
            SSL_METHOD="none"
            return 0
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
}

# Auto-obtain SSL certificate
obtain_ssl_auto() {
    print_info "Obtaining SSL certificate for $DOMAIN..."
    
    stop_services
    
    if certbot certonly --standalone --non-interactive --agree-tos \
        --register-unsafely-without-email -d "$DOMAIN" \
        --preferred-challenges http >> "${LOG_FILE}" 2>&1; then
        
        if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
            print_msg "SSL certificate obtained"
            
            CERT_FILE="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
            KEY_FILE="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
            
            # Fix permissions
            setup_cert_permissions
        else
            error_exit "Certificate files not found" 4
            return 1
        fi
    else
        error_exit "Failed to obtain SSL certificate. Check DNS and port 80" 4
        return 1
    fi
}

# Use existing SSL certificates
obtain_ssl_manual() {
    echo ""
    print_info "Please provide your certificate paths"
    echo ""
    
    while true; do
        read -p "$(echo -e ${YELLOW}Full certificate path ${GREEN}\(fullchain.pem\)${NC}: )" CERT_FILE
        
        if [[ ! -f "$CERT_FILE" ]]; then
            print_error "Certificate file not found: $CERT_FILE"
            continue
        fi
        
        if ! openssl x509 -in "$CERT_FILE" -noout 2>/dev/null; then
            print_error "Invalid certificate file"
            continue
        fi
        
        print_msg "Certificate: $CERT_FILE"
        break
    done
    
    while true; do
        read -p "$(echo -e ${YELLOW}Private key path ${GREEN}\(privkey.pem\)${NC}: )" KEY_FILE
        
        if [[ ! -f "$KEY_FILE" ]]; then
            print_error "Private key file not found: $KEY_FILE"
            continue
        fi
        
        if ! openssl rsa -in "$KEY_FILE" -check -noout 2>/dev/null; then
            print_error "Invalid private key file"
            continue
        fi
        
        print_msg "Private Key: $KEY_FILE"
        break
    done
    
    # Verify certificate and key match
    CERT_MODULUS=$(openssl x509 -noout -modulus -in "$CERT_FILE" 2>/dev/null | openssl md5)
    KEY_MODULUS=$(openssl rsa -noout -modulus -in "$KEY_FILE" 2>/dev/null | openssl md5)
    
    if [[ "$CERT_MODULUS" != "$KEY_MODULUS" ]]; then
        error_exit "Certificate and private key do not match!" 4
        return 1
    fi
    
    print_msg "Certificate and key validated"
    
    # Copy certificates to standard location
    CERT_DIR="/etc/xray-ssl/$DOMAIN"
    mkdir -p "$CERT_DIR"
    cp "$CERT_FILE" "$CERT_DIR/fullchain.pem"
    cp "$KEY_FILE" "$CERT_DIR/privkey.pem"
    
    CERT_FILE="$CERT_DIR/fullchain.pem"
    KEY_FILE="$CERT_DIR/privkey.pem"
    
    setup_cert_permissions
}

# Setup certificate permissions
setup_cert_permissions() {
    print_info "Setting certificate permissions..."
    
    # Set permissions for Xray to read certificates
    chmod 755 "$(dirname "$(dirname "$CERT_FILE")")" 2>/dev/null || true
    chmod 755 "$(dirname "$CERT_FILE")"
    chmod 644 "$CERT_FILE"
    chmod 644 "$KEY_FILE"
    
    # If using Let's Encrypt, also set archive permissions
    if [[ "$CERT_FILE" == *"letsencrypt"* ]]; then
        chmod 755 /etc/letsencrypt
        chmod 755 /etc/letsencrypt/live
        chmod 755 /etc/letsencrypt/archive
        if [[ -d "/etc/letsencrypt/live/$DOMAIN" ]]; then
            chmod 755 "/etc/letsencrypt/live/$DOMAIN"
        fi
        if [[ -d "/etc/letsencrypt/archive/$DOMAIN" ]]; then
            chmod 755 "/etc/letsencrypt/archive/$DOMAIN"
            chmod 644 "/etc/letsencrypt/archive/$DOMAIN"/*.pem 2>/dev/null || true
        fi
    fi
    
    print_msg "Certificate permissions configured"
}

# Generate Xray configuration
generate_config() {
    print_info "Generating configuration..."
    
    UUID=$(uuidgen)
    [[ -z "$UUID" ]] && { error_exit "Failed to generate UUID" 5; return 1; }
    
    print_msg "UUID: $UUID"
    
    mkdir -p "$XRAY_CONFIG_DIR"
    [[ -f "$XRAY_CONFIG_FILE" ]] && cp "$XRAY_CONFIG_FILE" "${XRAY_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Build ALPN array
    IFS=',' read -ra ALPN_ARRAY <<< "$ALPN"
    ALPN_JSON=$(printf '%s\n' "${ALPN_ARRAY[@]}" | jq -R . | jq -s -c .)
    
    # Generate configuration based on transport
    if [[ "$TRANSPORT" == "xhttp" ]]; then
        generate_xhttp_config
    else
        generate_ws_config
    fi
    
    # Verify JSON
    if ! jq empty "$XRAY_CONFIG_FILE" 2>/dev/null; then
        if ! python3 -c "import json; json.load(open('$XRAY_CONFIG_FILE'))" 2>/dev/null; then
            print_warning "Could not validate JSON syntax"
        fi
    fi
    
    # Save client info
    mkdir -p "$(dirname "$CLIENTS_FILE")"
    echo "# Xray Clients - $(date)" > "$CLIENTS_FILE"
    echo "Xray-Edge-Tunnel|$UUID|Default Client|$(date +%Y-%m-%d)|$TRANSPORT" >> "$CLIENTS_FILE"
    
    print_msg "Configuration created"
}

# Generate xhttp configuration
generate_xhttp_config() {
    cat > "$XRAY_CONFIG_FILE" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "${DOMAIN}",
          "certificates": [
            {
              "certificateFile": "${CERT_FILE}",
              "keyFile": "${KEY_FILE}"
            }
          ],
          "alpn": ${ALPN_JSON},
          "fingerprint": "${FINGERPRINT}"
        },
        "xhttpSettings": {
          "path": "${XHTTP_PATH}",
          "host": "${DOMAIN}",
          "mode": "${XHTTP_MODE}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
}

# Generate WebSocket configuration
generate_ws_config() {
    cat > "$XRAY_CONFIG_FILE" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "serverName": "${DOMAIN}",
          "certificates": [
            {
              "certificateFile": "${CERT_FILE}",
              "keyFile": "${KEY_FILE}"
            }
          ],
          "alpn": ${ALPN_JSON},
          "fingerprint": "${FINGERPRINT}"
        },
        "wsSettings": {
          "path": "${WS_PATH}",
          "headers": {
            "Host": "${DOMAIN}"
          }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
}

# Start Xray service
start_xray() {
    print_info "Starting Xray..."
    
    # Test configuration before starting
    print_info "Testing configuration..."
    if ! xray -test -config "$XRAY_CONFIG_FILE" >> "${LOG_FILE}" 2>&1; then
        print_error "Configuration test failed"
        echo ""
        xray -test -config "$XRAY_CONFIG_FILE"
        error_exit "Invalid configuration" 6
        return 1
    fi
    print_msg "Configuration valid"
    
    systemctl enable xray >> "${LOG_FILE}" 2>&1
    systemctl restart xray 2>> "${LOG_FILE}"
    
    sleep 3
    
    if systemctl is-active --quiet xray; then
        print_msg "Xray started successfully"
    else
        print_error "Failed to start Xray"
        echo ""
        print_info "Detailed error logs:"
        journalctl -u xray -n 30 --no-pager
        echo ""
        print_info "Configuration file content:"
        cat "$XRAY_CONFIG_FILE"
        error_exit "Service failed" 6
        return 1
    fi
    
    # Verify port is listening
    sleep 2
    if netstat -tuln 2>/dev/null | grep -q ":${PORT} " || ss -tuln 2>/dev/null | grep -q ":${PORT} "; then
        print_msg "Xray is listening on port $PORT"
    else
        print_warning "Port $PORT might not be listening yet"
    fi
}

# Generate connection links
generate_links() {
    [[ ! -f "$SCRIPT_CONFIG" ]] && { print_error "Configuration not found"; return 1; }
    source "$SCRIPT_CONFIG"
    
    [[ ! -f "$CLIENTS_FILE" ]] && { print_error "No clients found"; return 1; }
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Connection Links & Details                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Use CDN_HOST as main address (like chatgpt.com)
    # Domain is only used for host and SNI headers
    CONNECT_ADDRESS="$CDN_HOST"
    
    while IFS='|' read -r name uuid desc date transport; do
        [[ "$name" == "#"* ]] && continue
        
        # Use saved transport or default to current
        [[ -z "$transport" ]] && transport="$TRANSPORT"
        
        if [[ "$transport" == "xhttp" ]]; then
            # URL encode the path for xhttp
            ENCODED_PATH=$(printf '%s' "$XHTTP_PATH" | jq -sRr @uri)
            # URL encode alpn (replace comma with %2C)
            ENCODED_ALPN=$(printf '%s' "$ALPN" | sed 's/,/%2C/g')
            # For xhttp: address=CDN, host=domain, sni=domain
            VLESS_LINK="vless://${uuid}@${CONNECT_ADDRESS}:${PORT}?type=xhttp&security=tls&path=${ENCODED_PATH}&host=${DOMAIN}&sni=${DOMAIN}&fp=${FINGERPRINT}&alpn=${ENCODED_ALPN}&mode=${XHTTP_MODE}#${name}"
        else
            # URL encode the path for websocket
            ENCODED_PATH=$(printf '%s' "$WS_PATH" | jq -sRr @uri)
            # URL encode alpn
            ENCODED_ALPN=$(printf '%s' "$ALPN" | sed 's/,/%2C/g')
            # For ws: address=CDN, host=domain, sni=domain
            VLESS_LINK="vless://${uuid}@${CONNECT_ADDRESS}:${PORT}?type=ws&security=tls&path=${ENCODED_PATH}&host=${DOMAIN}&sni=${DOMAIN}&fp=${FINGERPRINT}&alpn=${ENCODED_ALPN}#${name}"
        fi
        
        echo -e "${CYAN}Client:${NC} $name"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}UUID:${NC} $uuid"
        echo -e "${GREEN}Link:${NC}"
        echo -e "${BLUE}$VLESS_LINK${NC}"
        echo ""
    done < "$CLIENTS_FILE"
    
    echo -e "${YELLOW}Manual Settings:${NC}"
    echo -e "Address:     ${GREEN}$CONNECT_ADDRESS${NC} (CDN Host)"
    echo -e "Port:        ${GREEN}$PORT${NC}"
    echo -e "Transport:   ${GREEN}$TRANSPORT${NC}"
    if [[ "$TRANSPORT" == "xhttp" ]]; then
        echo -e "Path:        ${GREEN}$XHTTP_PATH${NC}"
        echo -e "Mode:        ${GREEN}$XHTTP_MODE${NC}"
    else
        echo -e "Path:        ${GREEN}$WS_PATH${NC}"
    fi
    echo -e "Host:        ${GREEN}$DOMAIN${NC} (Your Domain)"
    echo -e "TLS:         ${GREEN}Enable${NC}"
    echo -e "SNI:         ${GREEN}$DOMAIN${NC}"
    echo -e "ALPN:        ${GREEN}$ALPN${NC}"
    echo -e "Fingerprint: ${GREEN}$FINGERPRINT${NC}"
    echo ""
}

# Add new client
add_client() {
    [[ ! -f "$SCRIPT_CONFIG" ]] && { print_error "Install Xray first"; return 1; }
    source "$SCRIPT_CONFIG"
    
    echo ""
    read -p "$(echo -e ${YELLOW}Client name${NC}: )" CLIENT_NAME
    [[ -z "$CLIENT_NAME" ]] && { print_error "Name required"; return 1; }
    
    CLIENT_UUID=$(uuidgen)
    
    # Add to config file
    jq --arg uuid "$CLIENT_UUID" '.inbounds[0].settings.clients += [{"id": $uuid}]' \
        "$XRAY_CONFIG_FILE" > "${XRAY_CONFIG_FILE}.tmp" && \
        mv "${XRAY_CONFIG_FILE}.tmp" "$XRAY_CONFIG_FILE"
    
    # Add to clients list
    echo "$CLIENT_NAME|$CLIENT_UUID|Added via script|$(date +%Y-%m-%d)|$TRANSPORT" >> "$CLIENTS_FILE"
    
    systemctl restart xray
    
    print_msg "Client added: $CLIENT_NAME"
    
    # Use CDN_HOST as main address
    CONNECT_ADDRESS="$CDN_HOST"
    
    # Generate link
    if [[ "$TRANSPORT" == "xhttp" ]]; then
        ENCODED_PATH=$(printf '%s' "$XHTTP_PATH" | jq -sRr @uri)
        ENCODED_ALPN=$(printf '%s' "$ALPN" | sed 's/,/%2C/g')
        VLESS_LINK="vless://${CLIENT_UUID}@${CONNECT_ADDRESS}:${PORT}?type=xhttp&security=tls&path=${ENCODED_PATH}&host=${DOMAIN}&sni=${DOMAIN}&fp=${FINGERPRINT}&alpn=${ENCODED_ALPN}&mode=${XHTTP_MODE}#${CLIENT_NAME}"
    else
        ENCODED_PATH=$(printf '%s' "$WS_PATH" | jq -sRr @uri)
        ENCODED_ALPN=$(printf '%s' "$ALPN" | sed 's/,/%2C/g')
        VLESS_LINK="vless://${CLIENT_UUID}@${CONNECT_ADDRESS}:${PORT}?type=ws&security=tls&path=${ENCODED_PATH}&host=${DOMAIN}&sni=${DOMAIN}&fp=${FINGERPRINT}&alpn=${ENCODED_ALPN}#${CLIENT_NAME}"
    fi
    
    echo ""
    echo -e "${GREEN}Connection Link:${NC}"
    echo -e "${BLUE}$VLESS_LINK${NC}"
    echo ""
}

# Remove client
remove_client() {
    [[ ! -f "$CLIENTS_FILE" ]] && { print_error "No clients found"; return 1; }
    
    echo ""
    echo -e "${YELLOW}Existing Clients:${NC}"
    echo ""
    
    local i=1
    declare -A client_map
    
    while IFS='|' read -r name uuid desc date transport; do
        [[ "$name" == "#"* ]] && continue
        echo -e "${GREEN}$i)${NC} $name (Created: $date)"
        client_map[$i]="$name|$uuid"
        ((i++))
    done < "$CLIENTS_FILE"
    
    echo ""
    read -p "$(echo -e ${YELLOW}Select client number to remove${NC}: )" choice
    
    [[ -z "${client_map[$choice]}" ]] && { print_error "Invalid choice"; return 1; }
    
    IFS='|' read -r del_name del_uuid <<< "${client_map[$choice]}"
    
    if [[ "$del_name" == "Xray-Edge-Tunnel" ]]; then
        print_error "Cannot remove default client"
        return 1
    fi
    
    # Remove from config
    jq --arg uuid "$del_uuid" 'del(.inbounds[0].settings.clients[] | select(.id == $uuid))' \
        "$XRAY_CONFIG_FILE" > "${XRAY_CONFIG_FILE}.tmp" && \
        mv "${XRAY_CONFIG_FILE}.tmp" "$XRAY_CONFIG_FILE"
    
    # Remove from list
    sed -i "/^$del_name|$del_uuid|/d" "$CLIENTS_FILE"
    
    systemctl restart xray
    
    print_msg "Client removed: $del_name"
}

# List all clients
list_clients() {
    [[ ! -f "$CLIENTS_FILE" ]] && { print_error "No clients found"; return 1; }
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Client List                            ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    printf "%-20s %-40s %-15s %-10s\n" "Name" "UUID" "Created" "Transport"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    while IFS='|' read -r name uuid desc date transport; do
        [[ "$name" == "#"* ]] && continue
        [[ -z "$transport" ]] && transport="ws"
        printf "%-20s %-40s %-15s %-10s\n" "$name" "$uuid" "$date" "$transport"
    done < "$CLIENTS_FILE"
    
    echo ""
}

# Service management
service_management() {
    while true; do
        clear
        echo -e "${CYAN}Service Management${NC}"
        echo ""
        
        if systemctl is-active --quiet xray; then
            echo -e "Status: ${GREEN}Running ✓${NC}"
        else
            echo -e "Status: ${RED}Stopped ✗${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}1)${NC} Start Service"
        echo -e "${GREEN}2)${NC} Stop Service"
        echo -e "${GREEN}3)${NC} Restart Service"
        echo -e "${GREEN}4)${NC} View Status"
        echo -e "${GREEN}5)${NC} Enable Auto-start"
        echo -e "${GREEN}6)${NC} Disable Auto-start"
        echo -e "${RED}0)${NC} Back"
        echo ""
        
        read -p "Choice: " choice
        
        case $choice in
            1) systemctl start xray && print_msg "Service started" ;;
            2) systemctl stop xray && print_msg "Service stopped" ;;
            3) systemctl restart xray && print_msg "Service restarted" ;;
            4) systemctl status xray --no-pager ;;
            5) systemctl enable xray && print_msg "Auto-start enabled" ;;
            6) systemctl disable xray && print_msg "Auto-start disabled" ;;
            0) break ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# View logs
view_logs() {
    clear
    echo -e "${CYAN}Xray Logs${NC}"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    echo ""
    sleep 2
    journalctl -u xray -f
}

# Uninstall
uninstall_xray() {
    echo ""
    print_warning "This will remove Xray completely"
    read -p "$(echo -e ${RED}Are you sure? ${GREEN}\(yes/no\)${NC}: )" confirm
    
    [[ "$confirm" != "yes" ]] && { print_info "Cancelled"; return 0; }
    
    print_info "Uninstalling Xray..."
    
    systemctl stop xray 2>/dev/null || true
    systemctl disable xray 2>/dev/null || true
    
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove >> "${LOG_FILE}" 2>&1 || true
    
    rm -rf "$XRAY_CONFIG_DIR"
    rm -f "$SCRIPT_CONFIG" "$OUTPUT_CONFIG_FILE" "$CLIENTS_FILE"
    
    print_msg "Xray uninstalled"
    echo ""
    read -p "Press Enter to continue..."
}

# View configuration
view_config() {
    if [[ ! -f "$XRAY_CONFIG_FILE" ]]; then
        print_error "Configuration not found"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}Current Configuration:${NC}"
    echo ""
    cat "$XRAY_CONFIG_FILE" | jq '.'
    echo ""
}

# Installation process
install_xray_full() {
    log "=== Installation Started ==="
    
    check_system || return 1
    install_dependencies || return 1
    install_xray_binary || return 1
    get_config || return 1
    get_ssl || return 1
    generate_config || return 1
    start_xray || return 1
    
    generate_links
    
    print_msg "Installation completed!"
    log "=== Installation Completed ==="
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main function
main() {
    check_root
    
    while true; do
        show_menu
        read -p "$(echo -e ${YELLOW}Choose option ${GREEN}[0-9]${NC}: )" choice
        
        case $choice in
            1) install_xray_full ;;
            2) view_config; read -p "Press Enter..." ;;
            3) generate_links; read -p "Press Enter..." ;;
            4) add_client; read -p "Press Enter..." ;;
            5) remove_client; read -p "Press Enter..." ;;
            6) list_clients; read -p "Press Enter..." ;;
            7) service_management ;;
            8) view_logs ;;
            9) uninstall_xray ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) print_error "Invalid option" ;;
        esac
    done
}

# Run
main "$@"