#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  NOOBS ZIVPN UDP — Installer Script
#  Repo    : https://github.com/autobot-sys
#  Creator : Zahid Islam  |  Modified by PowerMX
#  Arch    : AMD x64 (Linux)
# ═══════════════════════════════════════════════════════════════

set -e

CONFIG_FILE="/etc/zivpn/config.json"
PANEL_SCRIPT="/usr/local/bin/zivudp"
BIN_PATH="/usr/local/bin/zivpn"
IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

# ── Colours ──────────────────────────────────────────────────────
R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'
B='\033[1;34m'; C='\033[1;36m'; W='\033[1;37m'; NC='\033[0m'

banner() {
  echo -e "${C}"
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║       NOOBS ZIVPN UDP PANEL — INSTALLER             ║"
  echo "  ║       github.com/autobot-sys                        ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

banner

# ── Step 1: System update ────────────────────────────────────────
echo -e "${Y}[1/7]${NC} Updating system packages..."
apt-get update -y 1>/dev/null 2>/dev/null
apt-get upgrade -y 1>/dev/null 2>/dev/null
echo -e "      ${G}Done.${NC}"

# ── Step 2: Stop existing service ────────────────────────────────
echo -e "${Y}[2/7]${NC} Stopping existing zivpn service (if any)..."
systemctl stop zivpn.service 1>/dev/null 2>/dev/null || true
echo -e "      ${G}Done.${NC}"

# ── Step 3: Download binary ───────────────────────────────────────
echo -e "${Y}[3/7]${NC} Downloading ZIVPN UDP binary..."
wget -q https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 \
  -O "$BIN_PATH"
chmod +x "$BIN_PATH"
echo -e "      ${G}Downloaded → $BIN_PATH${NC}"

# ── Step 4: Config directory & default config ─────────────────────
echo -e "${Y}[4/7]${NC} Setting up config directory..."
mkdir -p /etc/zivpn

cat > "$CONFIG_FILE" <<'CONF'
{
  "listen": ":5667",
  "config": []
}
CONF
echo -e "      ${G}Config written → $CONFIG_FILE${NC}"

# ── Step 5: Generate TLS certificates ────────────────────────────
echo -e "${Y}[5/7]${NC} Generating self-signed TLS certificates..."
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
  -subj "/C=US/ST=California/L=Los Angeles/O=Autobot-Sys/OU=NOOBS/CN=zivpn" \
  -keyout "/etc/zivpn/zivpn.key" \
  -out    "/etc/zivpn/zivpn.crt" 2>/dev/null
echo -e "      ${G}Certificates generated.${NC}"

# ── Step 6: systemd service unit ─────────────────────────────────
echo -e "${Y}[6/7]${NC} Installing systemd service..."
cat > /etc/systemd/system/zivpn.service <<'UNIT'
[Unit]
Description=NOOBS ZIVPN UDP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
UNIT

sysctl -w net.core.rmem_max=16777216 1>/dev/null 2>/dev/null
sysctl -w net.core.wmem_max=16777216 1>/dev/null 2>/dev/null
systemctl daemon-reload
systemctl enable zivpn.service 1>/dev/null 2>/dev/null
systemctl start  zivpn.service
echo -e "      ${G}Service enabled and started.${NC}"

# ── Step 7: Firewall / NAT rules ─────────────────────────────────
echo -e "${Y}[7/7]${NC} Applying firewall rules (interface: ${W}$IFACE${NC})..."
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 6000:19999 \
  -j DNAT --to-destination :5667
ufw allow 6000:19999/udp 1>/dev/null 2>/dev/null
ufw allow 5667/udp        1>/dev/null 2>/dev/null
echo -e "      ${G}Firewall rules applied.${NC}"

# ── Install management panel ──────────────────────────────────────
echo -e "\n${C}Installing NOOBS ZIVPN UDP PANEL...${NC}"
cp "$(dirname "$0")/../panel/zivudp.sh" "$PANEL_SCRIPT" 2>/dev/null || \
  bash -c "$(wget -qO- https://raw.githubusercontent.com/autobot-sys/main/panel/zivudp.sh)" 2>/dev/null || true
chmod +x "$PANEL_SCRIPT"

echo -e "\n${G}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${G}║          INSTALLATION COMPLETE! ✔                   ║${NC}"
echo -e "${G}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${G}║${NC}  Management Panel : ${W}zivudp${NC}                          ${G}║${NC}"
echo -e "${G}║${NC}  Config File      : ${W}$CONFIG_FILE${NC}            ${G}║${NC}"
echo -e "${G}║${NC}  Listen Port      : ${W}5667/udp${NC}                        ${G}║${NC}"
echo -e "${G}║${NC}  Relay Range      : ${W}6000–19999/udp${NC}                  ${G}║${NC}"
echo -e "${G}║${NC}  Repo             : ${W}github.com/autobot-sys${NC}           ${G}║${NC}"
echo -e "${G}╚══════════════════════════════════════════════════════╝${NC}"
echo -e "\n  ${Y}➤  Type ${W}zivudp${Y} to open the management panel.${NC}\n"
