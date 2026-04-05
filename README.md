# 🛡️ NOOBS ZIVPN UDP PANEL
### *by autobot-sys*

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux%20x64-blue?style=for-the-badge&logo=linux"/>
  <img src="https://img.shields.io/badge/Protocol-ZIVPN%20UDP-green?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/Shell-Bash-yellow?style=for-the-badge&logo=gnubash"/>
  <img src="https://img.shields.io/badge/License-MIT-red?style=for-the-badge"/>
</p>

> A full-featured **UDP VPN installer + management panel** for [ZIVPN](https://github.com/zahidbd2/udp-zivpn) on Linux AMD x64.  
> One command install. One command to manage. Works directly with the **ZIVPN client app**.

---

## 📦 Repository Structure

```
autobot-sys/
├── scripts/
│   └── install.sh       ← Main installer (run this first)
├── panel/
│   └── zivudp.sh        ← Management panel (installed as `zivudp`)
├── README.md
└── LICENSE
```

---

## ⚡ Quick Install

```bash
# Clone the repo
git clone https://github.com/autobot-sys/autobot-sys.git
cd autobot-sys

# Make scripts executable
chmod +x scripts/install.sh panel/zivudp.sh

# Run as root
sudo bash scripts/install.sh
```

Or one-liner (once repo is public):

```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/autobot-sys/autobot-sys/main/scripts/install.sh)"
```

---

## 🖥️ Management Panel

After installation, open the panel at any time with:

```bash
zivudp
```

### Panel Features

| Option | Description |
|--------|-------------|
| `[1]` List Users | View all configured passwords/users |
| `[2]` Add Single | Add one new password |
| `[3]` Bulk Add | Add multiple passwords (comma-separated) |
| `[4]` Delete Single | Remove one password by number |
| `[5]` Delete Multiple | Remove several passwords at once |
| `[6]` Clear All | Wipe all passwords (with confirmation) |
| `[7]` Monitor | Live UDP connections + recent service logs |
| `[8]` Service Control | Start / Stop / Restart / Enable zivpn |
| `[9]` Change Port | Update the listen port in config |
| `[i]` About | Version info and file paths |

> Every add/delete operation **automatically restarts the service** — no manual steps needed.

---

## 🔌 Ports Used

| Port | Purpose |
|------|---------|
| `5667/udp` | Primary ZIVPN listen port |
| `6000–19999/udp` | NAT relay range (for client connections) |

---

## 📱 Client App

This panel manages passwords for the **ZIVPN** Android/iOS client app.  
Connect your client using:

- **Server IP** — your VPS public IP  
- **Port** — any port in range `6000–19999`  
- **Password** — one of the passwords you added via `zivudp`

---

## ⚙️ How It Works

```
Client App
    │
    ▼  (UDP 6000–19999)
iptables NAT PREROUTING
    │
    ▼  (redirected to :5667)
zivpn server
    │
    ▼
/etc/zivpn/config.json  ← passwords stored here
```

The installer:
1. Downloads the `zivpn` binary (AMD x64)
2. Generates a self-signed TLS certificate (RSA 4096, 365 days)
3. Writes a `systemd` service unit
4. Sets up `iptables` NAT for the relay port range
5. Opens firewall rules via `ufw`
6. Installs the `zivudp` panel command

---

## 🗂️ File Locations

| File | Path |
|------|------|
| Binary | `/usr/local/bin/zivpn` |
| Config | `/etc/zivpn/config.json` |
| TLS Cert | `/etc/zivpn/zivpn.crt` |
| TLS Key | `/etc/zivpn/zivpn.key` |
| systemd unit | `/etc/systemd/system/zivpn.service` |
| Panel command | `/usr/local/bin/zivudp` |

---

## 📋 Requirements

- Ubuntu / Debian (AMD x64)
- Root access
- `python3` (usually pre-installed)
- `openssl`, `wget`, `ufw`, `iptables`

---

## 🔄 Update Panel Only

To update the panel without reinstalling:

```bash
sudo wget -qO /usr/local/bin/zivudp \
  https://raw.githubusercontent.com/autobot-sys/autobot-sys/main/panel/zivudp.sh
sudo chmod +x /usr/local/bin/zivudp
```

---

## 📜 License

MIT License — see [LICENSE](LICENSE)

---

## 👤 Credits

- **Original ZIVPN UDP** — [Zahid Islam](https://github.com/zahidbd2)
- **Installer & Panel** — @ARDVAK / autobot-sys
