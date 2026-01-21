#!/bin/bash

# Xray-Edge-Tunnel - Complete Management Script
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
    echo "║          Xray-Edge-Tunnel Manager v2.0           ║"
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
    
    # WebSocket Path
    echo ""
    read -p "$(echo -e ${YELLOW}WebSocket Path ${GREEN}\(default: /graphql\)${NC}: )" WS_PATH
    WS_PATH=${WS_PATH:-/graphql}
    [[ "$WS_PATH" != /* ]] && WS_PATH="/$WS_PATH"
    print_msg "Path: $WS_PATH"
    
    # CDN Host
    echo ""
    read -p "$(echo -e ${YELLOW}CDN Host ${GREEN}\(default: chatgpt.com\)${NC}: )" CDN_HOST
    CDN_HOST=${CDN_HOST:-chatgpt.com}
    print_msg "CDN Host: $CDN_HOST"
    
    # Port
    echo ""
    echo -e "${YELLOW}Cloudflare HTTPS Ports:${NC} 443, 2053, 2083, 2087, 2096, 8443"
    read -p "$(echo -e ${YELLOW}Port ${GREEN}\(default: 443\)${NC}: )" PORT
    PORT=${PORT:-443}
    print_msg "Port: $PORT"
    
    # Summary
    echo ""
    echo -e "${BLUE}Configuration Summary:${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Domain:      ${GREEN}$DOMAIN${NC}"
    echo -e "Path:        ${GREEN}$WS_PATH${NC}"
    echo -e "CDN Host:    ${GREEN}$CDN_HOST${NC}"
    echo -e "Port:        ${GREEN}$PORT${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Proceed? ${GREEN}\(y/n\)${NC}: )" PROCEED
    [[ ! "$PROCEED" =~ ^[yY]$ ]] && return 1
    
    # Save configuration
    cat > "$SCRIPT_CONFIG" <<EOF
DOMAIN="$DOMAIN"
WS_PATH="$WS_PATH"
CDN_HOST="$CDN_HOST"
PORT="$PORT"
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

# Get SSL certificate
get_ssl() {
    print_info "Obtaining SSL certificate for $DOMAIN..."
    
    stop_services
    
    if certbot certonly --standalone --non-interactive --agree-tos \
        --register-unsafely-without-email -d "$DOMAIN" \
        --preferred-challenges http >> "${LOG_FILE}" 2>&1; then
        
        if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
            print_msg "SSL certificate obtained"
            
            # Fix permissions for Xray to read certificates
            print_info "Setting certificate permissions..."
            chmod 755 /etc/letsencrypt/live
            chmod 755 /etc/letsencrypt/archive
            chmod 755 "/etc/letsencrypt/live/$DOMAIN"
            chmod 755 "/etc/letsencrypt/archive/$DOMAIN"
            chmod 644 "/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
            chmod 644 "/etc/letsencrypt/live/$DOMAIN/chain.pem"
            chmod 600 "/etc/letsencrypt/live/$DOMAIN/privkey.pem"
            
            # Allow Xray user to read certificates
            if id nobody &>/dev/null; then
                chgrp -R nobody "/etc/letsencrypt/live/$DOMAIN"
                chgrp -R nobody "/etc/letsencrypt/archive/$DOMAIN"
            fi
            
            print_msg "Certificate permissions configured"
        else
            error_exit "Certificate files not found" 4
            return 1
        fi
    else
        error_exit "Failed to obtain SSL certificate. Check DNS and port 80" 4
        return 1
    fi
}

# Generate Xray configuration
generate_config() {
    print_info "Generating configuration..."
    
    UUID=$(uuidgen)
    [[ -z "$UUID" ]] && { error_exit "Failed to generate UUID" 5; return 1; }
    
    print_msg "UUID: $UUID"
    
    mkdir -p "$XRAY_CONFIG_DIR"
    [[ -f "$XRAY_CONFIG_FILE" ]] && cp "$XRAY_CONFIG_FILE" "${XRAY_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
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
              "certificateFile": "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem",
              "keyFile": "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
            }
          ]
        },
        "wsSettings": {
          "path": "${WS_PATH}"
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
    
    # Verify JSON
    if ! jq empty "$XRAY_CONFIG_FILE" 2>/dev/null; then
        if ! python3 -c "import json; json.load(open('$XRAY_CONFIG_FILE'))" 2>/dev/null; then
            print_warning "Could not validate JSON syntax"
        fi
    fi
    
    # Save client info
    mkdir -p "$(dirname "$CLIENTS_FILE")"
    echo "# Xray Clients - $(date)" > "$CLIENTS_FILE"
    echo "Xray-Edge-Tunnel github|$UUID|Default Client|$(date +%Y-%m-%d)" >> "$CLIENTS_FILE"
    
    print_msg "Configuration created"
}

# Start Xray service
start_xray() {
    print_info "Starting Xray..."
    
    # Verify certificate permissions before starting
    # Fix permission denied error for SSL certs
    if [[ -d "/etc/letsencrypt/live/$DOMAIN" ]]; then
        print_info "Adjusting certificate permissions..."
        chmod -R 755 /etc/letsencrypt/live/
        chmod -R 755 /etc/letsencrypt/archive/
        chmod 644 "/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
        chmod 644 "/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    fi
    
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
    
    ENCODED_PATH=$(printf '%s' "$WS_PATH" | jq -sRr @uri)
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Connection Links & Details                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    while IFS='|' read -r name uuid desc date; do
        [[ "$name" == "#"* ]] && continue
        
        VLESS_LINK="vless://${uuid}@${CDN_HOST}:${PORT}?type=ws&security=tls&path=${ENCODED_PATH}&host=${DOMAIN}&sni=${DOMAIN}#${name}"
        
        echo -e "${CYAN}Client:${NC} $name"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}UUID:${NC} $uuid"
        echo -e "${GREEN}Link:${NC}"
        echo -e "${BLUE}$VLESS_LINK${NC}"
        echo ""
    done < "$CLIENTS_FILE"
    
    echo -e "${YELLOW}Manual Settings:${NC}"
    echo -e "Address:     ${GREEN}$CDN_HOST${NC}"
    echo -e "Port:        ${GREEN}$PORT${NC}"
    echo -e "Network:     ${GREEN}ws${NC}"
    echo -e "Path:        ${GREEN}$WS_PATH${NC}"
    echo -e "Host:        ${GREEN}$DOMAIN${NC}"
    echo -e "TLS:         ${GREEN}Enable${NC}"
    echo -e "SNI:         ${GREEN}$DOMAIN${NC}"
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
    echo "$CLIENT_NAME|$CLIENT_UUID|Added via script|$(date +%Y-%m-%d)" >> "$CLIENTS_FILE"
    
    systemctl restart xray
    
    print_msg "Client added: $CLIENT_NAME"
    
    ENCODED_PATH=$(printf '%s' "$WS_PATH" | jq -sRr @uri)
    VLESS_LINK="vless://${CLIENT_UUID}@${CDN_HOST}:${PORT}?type=ws&security=tls&path=${ENCODED_PATH}&host=${DOMAIN}&sni=${DOMAIN}#${CLIENT_NAME}"
    
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
    
    while IFS='|' read -r name uuid desc date; do
        [[ "$name" == "#"* ]] && continue
        echo -e "${GREEN}$i)${NC} $name (Created: $date)"
        client_map[$i]="$name|$uuid"
        ((i++))
    done < "$CLIENTS_FILE"
    
    echo ""
    read -p "$(echo -e ${YELLOW}Select client number to remove${NC}: )" choice
    
    [[ -z "${client_map[$choice]}" ]] && { print_error "Invalid choice"; return 1; }
    
    IFS='|' read -r del_name del_uuid <<< "${client_map[$choice]}"
    
    if [[ "$del_name" == "Xray-Edge-Tunnel github" ]]; then
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
    
    printf "%-20s %-40s %-15s\n" "Name" "UUID" "Created"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    while IFS='|' read -r name uuid desc date; do
        [[ "$name" == "#"* ]] && continue
        printf "%-20s %-40s %-15s\n" "$name" "$uuid" "$date"
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