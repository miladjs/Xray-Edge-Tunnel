# Xray-Edge-Tunnel | Xray + CDN + SSL Auto Installer

[![Persian](https://img.shields.io/badge/Language-Persian-green?style=flat-square)](README.md)

This script automates the installation and configuration of Xray (VLESS-WebSocket-TLS) with Cloudflare CDN support. It sets up a secure and fast proxy server designed to bypass censorship using CDN capabilities.

## ✨ Features

- **Automated Installation**: Installs Xray, Certbot, and other dependencies automatically.
- **SSL Certificate**: Automatically obtains a free Let's Encrypt SSL certificate.
- **Auto-Renewal**: Configures automatic renewal for SSL certificates via cron hooks.
- **CDN Support**: Configured to work with Cloudflare CDN (WebSocket + TLS).
- **Interactive Setup**:
    - **DNS Verification**: Automatically checks if your domain points to the server IP (IPv4 & IPv6).
    - **Port Conflict Detection**: Ensures the selected port is available before installation.
    - **System Checks**: Verifies OS compatibility and internet connectivity.
- **Custom Configuration**:
    - **Custom WebSocket Path**: Choose your own path (default: `/graphql`).
    - **Custom CDN Host**: Set your preferred CDN host (default: `chatgpt.com`).
    - **Custom Ports**: Choose from Cloudflare-supported HTTPS ports (443, 2053, 2083, 2087, 2096, 8443).
- **Client Link Generation**: Generates VLESS connection links (share links) for easy import into V2rayN, v2rayNG, etc.

## 📋 Prerequisites

- A **VPS** with a fresh installation of **Ubuntu 20.04+** or **Debian 10+**.
- A **Domain Name** connected to your server via Cloudflare.
    - **DNS Record**: Create an `A` record (for IPv4) or `AAAA` record (for IPv6) pointing to your server's IP.
    - **Proxy Status**: Initially set to **DNS Only (Grey Cloud)** for SSL generation. After installation, switch to **Proxied (Orange Cloud)**.
- **Port 80**: Must be open for Let's Encrypt verification.

## 🚀 Installation

Run the following command on your server as root:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/miladjs/Xray-Edge-Tunnel/main/xray-cdn-installer.sh)
```

## 🛠️ Usage

1.  **Run the script**: Execute the installation command.
2.  **Enter Domain**: When prompted, enter your domain name (e.g., `example.com`).
3.  **DNS Check**: The script will detect your server IPs and guide you through DNS configuration.
    - You can choose to verify DNS records automatically before proceeding.
4.  **Configure Settings**:
    - **WebSocket Path**: Enter a custom path or press Enter for default (`/graphql`).
    - **CDN Host**: Enter a CDN host or press Enter for default (`chatgpt.com`).
    - **Port**: Enter a port or press Enter for default (`443`). The script will check if the port is free.
5.  **Wait for Completion**: The script will install Xray, obtain SSL, and generate the configuration.
6.  **Get Link**: Copy the generated `vless://` link and import it into your client.
7.  **Enable CDN**: Go to Cloudflare and enable the proxy (Orange Cloud) for your domain.

## 📱 Recommended Clients

-   **Windows**: [v2rayN](https://github.com/2dust/v2rayN)
-   **Android**: [v2rayNG](https://github.com/2dust/v2rayNG)
-   **iOS**: [V2Box](https://apps.apple.com/us/app/v2box-v2ray-client/id6446814690) or [Shadowrocket](https://apps.apple.com/us/app/shadowrocket/id932747118)
-   **macOS**: [V2rayU](https://github.com/yanue/V2rayU) or [Foxray](https://apps.apple.com/us/app/foxray/id6448898396)

## ⚠️ Important Notes

-   **Files Location**:
    -   Config file: `/usr/local/etc/xray/config.json`
    -   Installation Log: `/var/log/xray-installer.log`
    -   User Config Info: `/root/xray-config.txt`
-   **Cloudflare Settings**: Ensure your SSL/TLS mode in Cloudflare is set to **Full** or **Full (Strict)**.
-   **Auto-Renewal**: The SSL certificate will automatically renew. No manual action is required.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/miladjs/Xray-Edge-Tunnel/issues).

## 📄 License

This project is licensed under the MIT License.
