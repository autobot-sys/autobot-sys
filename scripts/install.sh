#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  NOOBS ZIVPN UDP — Installer Script
#  Repo    : https://github.com/autobot-sys/autobot-sys
#  Creator : Zahid Islam  |  Modified by PowerMX
#  Arch    : AMD x64 (Linux/Debian)
# ═══════════════════════════════════════════════════════════════
# NOTE: No set -e — we handle errors manually for reliability

CONFIG_FILE="/etc/zivpn/config.json"
PANEL_SCRIPT="/usr/local/bin/zivudp"
BIN_PATH="/usr/local/bin/zivpn"

# ── Colours ──────────────────────────────────────────────────────
R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'
C='\033[1;36m'; W='\033[1;37m'; NC='\033[0m'

ok()   { echo -e "      ${G}✔ Done.${NC}"; }
fail() { echo -e "      ${R}✘ Warning: $1 (continuing...)${NC}"; }

banner() {
  clear
  echo -e "${C}"
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║       NOOBS ZIVPN UDP PANEL — INSTALLER             ║"
  echo "  ║       github.com/autobot-sys                        ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

banner

# Fix hostname warning (sudo: unable to resolve host)
HOSTNAME=$(hostname)
if ! grep -q "$HOSTNAME" /etc/hosts 2>/dev/null; then
  echo "127.0.1.1 $HOSTNAME" >> /etc/hosts
fi

# ── Step 1: System update ────────────────────────────────────────
echo -e "${Y}[1/7]${NC} Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y 1>/dev/null 2>/dev/null || fail "apt-get update"
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" 1>/dev/null 2>/dev/null || fail "apt-get upgrade"
ok

# ── Step 2: Install dependencies ─────────────────────────────────
echo -e "${Y}[2/7]${NC} Installing dependencies..."
apt-get install -y wget openssl python3 ufw iptables \
  1>/dev/null 2>/dev/null || fail "some dependencies"
ok

# ── Step 3: Stop existing service ────────────────────────────────
echo -e "${Y}[3/7]${NC} Stopping existing zivpn service (if any)..."
systemctl stop zivpn.service 1>/dev/null 2>/dev/null || true
ok

# ── Step 4: Download binary ───────────────────────────────────────
echo -e "${Y}[4/7]${NC} Downloading ZIVPN UDP binary..."
wget -q --timeout=30 \
  https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 \
  -O "$BIN_PATH"
if [ $? -eq 0 ] && [ -s "$BIN_PATH" ]; then
  chmod +x "$BIN_PATH"
  echo -e "      ${G}✔ Downloaded → $BIN_PATH${NC}"
else
  echo -e "      ${R}✘ Download failed! Check your internet connection.${NC}"
  exit 1
fi

# ── Step 5: Config directory & default config ─────────────────────
echo -e "${Y}[5/7]${NC} Setting up config..."
mkdir -p /etc/zivpn
cat > "$CONFIG_FILE" <<'CONF'
{
  "listen": ":5667",
  "config": []
}
CONF
ok

# ── Step 6: Generate TLS certificates ────────────────────────────
echo -e "${Y}[6/7]${NC} Generating TLS certificates (this may take ~30s)..."
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
  -subj "/C=US/ST=California/L=Los Angeles/O=Autobot-Sys/OU=NOOBS/CN=zivpn" \
  -keyout "/etc/zivpn/zivpn.key" \
  -out    "/etc/zivpn/zivpn.crt" 2>/dev/null
if [ $? -eq 0 ]; then
  echo -e "      ${G}✔ Certificates generated.${NC}"
else
  fail "TLS cert generation"
fi

# ── Step 7: systemd service + firewall ───────────────────────────
echo -e "${Y}[7/7]${NC} Installing service and firewall rules..."

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

sysctl -w net.core.rmem_max=16777216 1>/dev/null 2>/dev/null || true
sysctl -w net.core.wmem_max=16777216 1>/dev/null 2>/dev/null || true
systemctl daemon-reload
systemctl enable zivpn.service 1>/dev/null 2>/dev/null || true
systemctl start  zivpn.service || fail "service start (check: systemctl status zivpn)"

IFACE=$(ip -4 route ls 2>/dev/null | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
if [ -n "$IFACE" ]; then
  iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 6000:19999 \
    -j DNAT --to-destination :5667 2>/dev/null || true
fi
ufw allow 6000:19999/udp 1>/dev/null 2>/dev/null || true
ufw allow 5667/udp        1>/dev/null 2>/dev/null || true
ok

# ── Install management panel ──────────────────────────────────────
echo -e "\n${C}Installing zivudp management panel...${NC}"
wget -q --timeout=30 \
  https://raw.githubusercontent.com/autobot-sys/autobot-sys/main/panel/zivudp.sh \
  -O "$PANEL_SCRIPT"
if [ $? -eq 0 ] && [ -s "$PANEL_SCRIPT" ]; then
  chmod +x "$PANEL_SCRIPT"
  echo -e "      ${G}✔ Panel installed → $PANEL_SCRIPT${NC}"
else
  fail "panel download"
fi

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo -e "${G}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${G}║          INSTALLATION COMPLETE! ✔                   ║${NC}"
echo -e "${G}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${G}║${NC}  Management Panel : ${W}zivudp${NC}                          ${G}║${NC}"
echo -e "${G}║${NC}  Config File      : ${W}$CONFIG_FILE${NC}            ${G}║${NC}"
echo -e "${G}║${NC}  Listen Port      : ${W}5667/udp${NC}                        ${G}║${NC}"
echo -e "${G}║${NC}  Relay Range      : ${W}6000–19999/udp${NC}                  ${G}║${NC}"
echo -e "${G}║${NC}  Repo             : ${W}github.com/autobot-sys${NC}           ${G}║${NC}"
echo -e "${G}╚══════════════════════════════════════════════════════╝${NC}"
echo -e "\n  ${Y}➤  Type ${W}zivudp${Y} to open the management panel.${NC}\n"
