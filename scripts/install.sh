#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  NOOBS ZIVPN UDP — Installer
#  Repo    : https://github.com/autobot-sys/autobot-sys
#  Panel   : zivudp
# ═══════════════════════════════════════════════════════════════

CONFIG_FILE="/etc/zivpn/config.json"
DB_FILE="/etc/zivpn/users.db"
PANEL_PATH="/usr/local/bin/zivudp"
BIN_PATH="/usr/local/bin/zivpn"
REPO_RAW="https://raw.githubusercontent.com/autobot-sys/autobot-sys/main"

# ── Colours ──────────────────────────────────────────────────────
R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'
C='\033[1;36m'; W='\033[1;37m'; DIM='\033[2m'; NC='\033[0m'

step()  { echo -e "\n${Y}[$1/$TOTAL]${NC} $2"; }
ok()    { echo -e "  ${G}✔ $*${NC}"; }
fail()  { echo -e "  ${R}✘ $* — exiting.${NC}"; exit 1; }
warn()  { echo -e "  ${Y}⚠ $* (continuing)${NC}"; }

TOTAL=7

# ── Root check ───────────────────────────────────────────────────
[ "$EUID" -ne 0 ] && { echo -e "${R}Run as root.${NC}"; exit 1; }

# ── Fix hostname DNS warning ─────────────────────────────────────
HN=$(hostname)
grep -q "$HN" /etc/hosts 2>/dev/null || echo "127.0.1.1 $HN" >> /etc/hosts

# ── Server info ───────────────────────────────────────────────────
GEO=$(curl -4 -s --max-time 10 "https://ipapi.co/json/" 2>/dev/null || echo '{}')
IP=$(echo "$GEO"   | grep -oP '"ip":\s*"\K[^"]+' 2>/dev/null || hostname -I | awk '{print $1}')
CITY=$(echo "$GEO" | grep -oP '"city":\s*"\K[^"]+' 2>/dev/null || echo "Unknown")
ISP=$(echo "$GEO"  | grep -oP '"org":\s*"\K[^"]+' 2>/dev/null  || echo "Unknown")
OS_INFO=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2)
ARCH=$(uname -m)

clear
echo -e "${C}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║       NOOBS ZIVPN UDP PANEL — INSTALLER             ║"
echo "  ║       github.com/autobot-sys                        ║"
echo "  ╠══════════════════════════════════════════════════════╣"
printf "  ║  OS   : %-44s║\n" "$OS_INFO"
printf "  ║  IP   : %-44s║\n" "$IP"
printf "  ║  City : %-44s║\n" "$CITY"
printf "  ║  ISP  : %-44s║\n" "$ISP"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Step 1: Dependencies ─────────────────────────────────────────
step 1 "Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl wget jq openssl iptables iptables-persistent \
  netfilter-persistent bc vnstat || warn "Some packages may not have installed"
ok "Dependencies ready"

# ── Step 2: Architecture ──────────────────────────────────────────
step 2 "Detecting architecture..."
case $ARCH in
  x86_64|amd64) BIN_ARCH="amd64" ;;
  aarch64|arm64) BIN_ARCH="arm64" ;;
  *) fail "Unsupported architecture: $ARCH" ;;
esac
ok "Architecture: $ARCH → $BIN_ARCH"

# ── Step 3: Download ZIVPN binary ────────────────────────────────
step 3 "Downloading ZIVPN binary..."
systemctl stop zivpn 2>/dev/null || true

wget -q --timeout=30 --show-progress \
  "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-$BIN_ARCH" \
  -O "$BIN_PATH" || fail "Binary download failed. Check internet connection."

[ -s "$BIN_PATH" ] || fail "Downloaded binary is empty."
chmod +x "$BIN_PATH"
ok "Binary installed → $BIN_PATH"

# ── Step 4: Config & database ────────────────────────────────────
step 4 "Writing config and database..."
mkdir -p /etc/zivpn

# ─── CORRECT config format matching ZIVPN client expectations ───
cat > "$CONFIG_FILE" << 'CONF'
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": []
  }
}
CONF

touch "$DB_FILE"
ok "Config → $CONFIG_FILE"

# ── Step 5: SSL Certificate ───────────────────────────────────────
step 5 "Generating SSL certificate (RSA 4096 — ~30s)..."
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
  -subj "/C=GH/ST=Accra/L=Accra/O=NoobsVPN/CN=zivpn" \
  -keyout "/etc/zivpn/zivpn.key" \
  -out    "/etc/zivpn/zivpn.crt" 2>/dev/null || fail "SSL generation failed."
chmod 600 /etc/zivpn/zivpn.key
ok "Certificate generated"

# ── Step 6: Firewall ─────────────────────────────────────────────
step 6 "Configuring firewall..."

# Disable UFW — it conflicts with iptables NAT rules
if command -v ufw &>/dev/null; then
  ufw disable &>/dev/null || true
  ok "UFW disabled (using iptables directly)"
fi

# Allow SSH to prevent lockout
iptables -I INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
# Allow ZIVPN ports
iptables -I INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 6000:19999 -j ACCEPT 2>/dev/null || true
# NAT relay — client hits any port 6000-19999, gets forwarded to 5667
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || true

# Persist iptables rules across reboots
mkdir -p /etc/iptables
if command -v netfilter-persistent &>/dev/null; then
  netfilter-persistent save 2>/dev/null || true
else
  iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi
ok "Firewall rules applied and saved"

# ── Step 7: Systemd service ───────────────────────────────────────
step 7 "Installing systemd service..."

cat > /etc/systemd/system/zivpn.service << 'UNIT'
[Unit]
Description=NOOBS ZIVPN UDP Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable zivpn 2>/dev/null
systemctl start  zivpn

sleep 2
if systemctl is-active --quiet zivpn; then
  ok "Service running"
else
  echo -e "  ${R}✘ Service failed to start. Checking logs:${NC}"
  journalctl -u zivpn -n 10 --no-pager 2>/dev/null | sed 's/^/    /'
fi

# ── Install management panel ──────────────────────────────────────
echo -e "\n${C}Installing zivudp management panel...${NC}"
wget -q --timeout=30 "$REPO_RAW/panel/zivudp.sh" -O "$PANEL_PATH" || \
  warn "Panel download failed — upload panel/zivudp.sh manually"
[ -s "$PANEL_PATH" ] && chmod +x "$PANEL_PATH" && ok "Panel installed → zivudp"

# ── Summary ───────────────────────────────────────────────────────
echo ""
echo -e "${G}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${G}║          ✔  INSTALLATION COMPLETE                   ║${NC}"
echo -e "${G}╠══════════════════════════════════════════════════════╣${NC}"
printf "${G}║${NC}  %-20s ${W}%-31s${G}║${NC}\n" "Server IP"   "$IP"
printf "${G}║${NC}  %-20s ${W}%-31s${G}║${NC}\n" "Location"    "$CITY"
printf "${G}║${NC}  %-20s ${W}%-31s${G}║${NC}\n" "Listen Port" "5667/udp"
printf "${G}║${NC}  %-20s ${W}%-31s${G}║${NC}\n" "NAT Relay"   "6000–19999/udp"
printf "${G}║${NC}  %-20s ${W}%-31s${G}║${NC}\n" "Obfs Key"    "zivpn"
printf "${G}║${NC}  %-20s ${W}%-31s${G}║${NC}\n" "Panel Cmd"   "zivudp"
echo -e "${G}╚══════════════════════════════════════════════════════╝${NC}"
echo -e "\n  ${Y}▶  Type ${W}zivudp${Y} to open the management panel.${NC}\n"
