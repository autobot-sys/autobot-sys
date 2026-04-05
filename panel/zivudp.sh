#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  NOOBS ZIVPN UDP PANEL — User Management
#  Command : zivudp
#  Repo    : https://github.com/autobot-sys
# ═══════════════════════════════════════════════════════════════

CONFIG_FILE="/etc/zivpn/config.json"

# ── Colours ──────────────────────────────────────────────────────
R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'
B='\033[1;34m'; C='\033[1;36m'; W='\033[1;37m'
M='\033[1;35m'; DIM='\033[2m';  NC='\033[0m'

# ── Sanity check ─────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "${R}  ✘ Please run as root (sudo zivudp)${NC}"; exit 1
fi
if ! command -v python3 &>/dev/null; then
  echo -e "${R}  ✘ python3 is required but not found.${NC}"; exit 1
fi

# ═════════════════════════════════════════════════════════════════
#  HELPER FUNCTIONS
# ═════════════════════════════════════════════════════════════════

reload_service() {
  systemctl restart zivpn.service 1>/dev/null 2>/dev/null
}

get_passwords() {
  python3 - <<PYEOF
import json
try:
    d = json.load(open("$CONFIG_FILE"))
    for p in d.get("config", []):
        print(p)
except Exception:
    pass
PYEOF
}

write_passwords() {
  # Accepts passwords as arguments
  python3 - "$@" <<'PYEOF'
import json, sys
passwords = [p for p in sys.argv[1:] if p]
try:
    with open("/etc/zivpn/config.json") as f:
        d = json.load(f)
except Exception:
    d = {"listen": ":5667"}
d["config"] = passwords
with open("/etc/zivpn/config.json", "w") as f:
    json.dump(d, f, indent=2)
print("ok")
PYEOF
}

password_count() {
  get_passwords | wc -l | tr -d ' '
}

service_is_running() {
  systemctl is-active --quiet zivpn.service
}

press_enter() {
  echo -e "\n${DIM}  ─────────────────────────────────────────${NC}"
  echo -e "  ${Y}Press [Enter] to return to main menu...${NC}"
  read -r
}

confirm() {
  # Usage: confirm "message" → returns 0 for yes, 1 for no
  echo -e "  ${Y}$1 ${W}[yes/no]${NC}"
  read -rp "  ➜ " ans
  [ "$ans" = "yes" ] && return 0 || return 1
}

# ═════════════════════════════════════════════════════════════════
#  HEADER & STATUS BAR
# ═════════════════════════════════════════════════════════════════

draw_header() {
  clear
  echo -e "${C}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║                                                          ║"
  echo "  ║   ███╗   ██╗ ██████╗  ██████╗ ██████╗ ███████╗          ║"
  echo "  ║   ████╗  ██║██╔═══██╗██╔═══██╗██╔══██╗██╔════╝          ║"
  echo "  ║   ██╔██╗ ██║██║   ██║██║   ██║██████╔╝███████╗          ║"
  echo "  ║   ██║╚██╗██║██║   ██║██║   ██║██╔══██╗╚════██║          ║"
  echo "  ║   ██║ ╚████║╚██████╔╝╚██████╔╝██████╔╝███████║          ║"
  echo "  ║   ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝          ║"
  echo "  ║                                                          ║"
  echo -e "  ║${Y}  ★★★   Z I V P N   U D P   P A N E L   ★★★${C}           ║"
  echo -e "  ║${G}       github.com/autobot-sys  |  by PowerMX${C}            ║"
  echo "  ║                                                          ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

draw_status() {
  local COUNT; COUNT=$(password_count)
  local SVCLINE PORTLINE IPLINE
  PORTLINE="${W}5667/udp${NC}   Relay: ${W}6000–19999/udp${NC}"
  IPLINE=$(hostname -I | awk '{print $1}')

  if service_is_running; then
    SVCLINE="${G}● RUNNING${NC}"
  else
    SVCLINE="${R}● STOPPED${NC}"
  fi

  echo -e "  ${DIM}──────────────────────────────────────────────────────────${NC}"
  echo -e "  Service : $SVCLINE    ${DIM}|${NC}  IP : ${W}$IPLINE${NC}"
  echo -e "  Port    : $PORTLINE"
  echo -e "  Users   : ${Y}$COUNT password(s) active${NC}"
  echo -e "  ${DIM}──────────────────────────────────────────────────────────${NC}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
#  MENU SCREENS
# ═════════════════════════════════════════════════════════════════

# ── [1] List all users ────────────────────────────────────────────
screen_list() {
  draw_header
  echo -e "  ${B}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${B}║   👥  PASSWORD / USER LIST               ║${NC}"
  echo -e "  ${B}╚══════════════════════════════════════════╝${NC}\n"

  mapfile -t PWDS < <(get_passwords)
  if [ ${#PWDS[@]} -eq 0 ]; then
    echo -e "  ${R}  ✘ No passwords configured yet.${NC}"
    echo -e "  ${DIM}  Use option [2] or [3] to add users.${NC}"
  else
    echo -e "  ${DIM}  #   Password${NC}"
    echo -e "  ${DIM}  ─   ────────${NC}"
    local i=1
    for p in "${PWDS[@]}"; do
      printf "  ${G}  %-3s${NC} ${W}%s${NC}\n" "[$i]" "$p"
      ((i++))
    done
    echo ""
    echo -e "  ${DIM}  Total: ${#PWDS[@]} user(s)${NC}"
  fi
  press_enter
}

# ── [2] Add single password ───────────────────────────────────────
screen_add_single() {
  draw_header
  echo -e "  ${G}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${G}║   ➕  ADD SINGLE PASSWORD               ║${NC}"
  echo -e "  ${G}╚══════════════════════════════════════════╝${NC}\n"

  read -rp "  Enter new password: " new_pass
  new_pass=$(echo "$new_pass" | xargs)

  if [ -z "$new_pass" ]; then
    echo -e "\n  ${R}✘ Password cannot be empty.${NC}"
    press_enter; return
  fi

  mapfile -t PWDS < <(get_passwords)
  for p in "${PWDS[@]}"; do
    if [ "$p" = "$new_pass" ]; then
      echo -e "\n  ${Y}⚠ Password '${W}$new_pass${Y}' already exists.${NC}"
      press_enter; return
    fi
  done

  PWDS+=("$new_pass")
  write_passwords "${PWDS[@]}" 1>/dev/null
  reload_service
  echo -e "\n  ${G}✔ Password '${W}$new_pass${G}' added successfully.${NC}"
  echo -e "  ${DIM}  Service reloaded — client can connect now.${NC}"
  press_enter
}

# ── [3] Bulk add passwords ────────────────────────────────────────
screen_bulk_add() {
  draw_header
  echo -e "  ${G}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${G}║   📋  BULK ADD PASSWORDS                ║${NC}"
  echo -e "  ${G}╚══════════════════════════════════════════╝${NC}\n"
  echo -e "  ${DIM}  Enter passwords separated by commas.${NC}"
  echo -e "  ${DIM}  Example: user1,user2,strongpass99${NC}\n"
  read -rp "  ➜ " input

  if [ -z "$input" ]; then
    echo -e "\n  ${R}✘ No input provided.${NC}"
    press_enter; return
  fi

  mapfile -t PWDS < <(get_passwords)
  IFS=',' read -r -a incoming <<< "$input"
  added=0; skipped=0

  for np in "${incoming[@]}"; do
    np=$(echo "$np" | xargs)
    [ -z "$np" ] && continue
    exists=0
    for ep in "${PWDS[@]}"; do [ "$ep" = "$np" ] && exists=1 && break; done
    if [ $exists -eq 0 ]; then
      PWDS+=("$np"); ((added++))
    else
      ((skipped++))
    fi
  done

  write_passwords "${PWDS[@]}" 1>/dev/null
  reload_service
  echo -e "\n  ${G}✔ $added new password(s) added.${NC}"
  [ $skipped -gt 0 ] && echo -e "  ${Y}  $skipped duplicate(s) skipped.${NC}"
  echo -e "  ${DIM}  Service reloaded.${NC}"
  press_enter
}

# ── [4] Delete single password ────────────────────────────────────
screen_delete_single() {
  draw_header
  echo -e "  ${R}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${R}║   🗑  DELETE A PASSWORD                 ║${NC}"
  echo -e "  ${R}╚══════════════════════════════════════════╝${NC}\n"

  mapfile -t PWDS < <(get_passwords)
  if [ ${#PWDS[@]} -eq 0 ]; then
    echo -e "  ${R}✘ No passwords to delete.${NC}"
    press_enter; return
  fi

  local i=1
  for p in "${PWDS[@]}"; do
    printf "  ${G}  %-4s${NC} ${W}%s${NC}\n" "[$i]" "$p"
    ((i++))
  done
  echo -e "  ${DIM}  [0] Cancel${NC}\n"
  read -rp "  Enter number to delete: " sel

  if [ "$sel" = "0" ] || [ -z "$sel" ]; then return; fi
  if ! [[ "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -gt "${#PWDS[@]}" ]; then
    echo -e "\n  ${R}✘ Invalid selection.${NC}"; press_enter; return
  fi

  removed="${PWDS[$((sel-1))]}"
  unset 'PWDS[$((sel-1))]'
  PWDS=("${PWDS[@]}")
  write_passwords "${PWDS[@]}" 1>/dev/null
  reload_service
  echo -e "\n  ${G}✔ Password '${W}$removed${G}' removed.${NC}"
  echo -e "  ${DIM}  Service reloaded.${NC}"
  press_enter
}

# ── [5] Delete multiple passwords ────────────────────────────────
screen_delete_multi() {
  draw_header
  echo -e "  ${R}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${R}║   🗑  DELETE MULTIPLE PASSWORDS         ║${NC}"
  echo -e "  ${R}╚══════════════════════════════════════════╝${NC}\n"

  mapfile -t PWDS < <(get_passwords)
  if [ ${#PWDS[@]} -eq 0 ]; then
    echo -e "  ${R}✘ No passwords to delete.${NC}"
    press_enter; return
  fi

  local i=1
  for p in "${PWDS[@]}"; do
    printf "  ${G}  %-4s${NC} ${W}%s${NC}\n" "[$i]" "$p"
    ((i++))
  done
  echo ""
  echo -e "  ${DIM}  Enter numbers separated by commas (e.g. 1,3,5) or 0 to cancel:${NC}"
  read -rp "  ➜ " sel_input

  [ "$sel_input" = "0" ] || [ -z "$sel_input" ] && return

  IFS=',' read -r -a sel_arr <<< "$sel_input"
  declare -A to_remove
  for s in "${sel_arr[@]}"; do
    s=$(echo "$s" | xargs)
    if [[ "$s" =~ ^[0-9]+$ ]] && [ "$s" -ge 1 ] && [ "$s" -le "${#PWDS[@]}" ]; then
      to_remove[$((s-1))]=1
    fi
  done

  removed_count=0
  new_pwds=()
  for idx in "${!PWDS[@]}"; do
    if [ -z "${to_remove[$idx]}" ]; then
      new_pwds+=("${PWDS[$idx]}")
    else
      ((removed_count++))
    fi
  done

  write_passwords "${new_pwds[@]}" 1>/dev/null
  reload_service
  echo -e "\n  ${G}✔ $removed_count password(s) removed.${NC}"
  echo -e "  ${DIM}  Service reloaded.${NC}"
  press_enter
}

# ── [6] Clear all passwords ───────────────────────────────────────
screen_clear_all() {
  draw_header
  echo -e "  ${R}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${R}║   ⚠  CLEAR ALL PASSWORDS               ║${NC}"
  echo -e "  ${R}╚══════════════════════════════════════════╝${NC}\n"
  echo -e "  ${R}This will remove every configured password.${NC}"
  echo -e "  ${R}All connected clients will be disconnected.${NC}\n"

  if confirm "Are you absolutely sure?"; then
    write_passwords 1>/dev/null
    reload_service
    echo -e "\n  ${G}✔ All passwords cleared. Service reloaded.${NC}"
  else
    echo -e "\n  ${Y}Cancelled.${NC}"
  fi
  press_enter
}

# ── [7] Live connection monitor ───────────────────────────────────
screen_monitor() {
  draw_header
  echo -e "  ${Y}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${Y}║   📡  LIVE CONNECTION MONITOR           ║${NC}"
  echo -e "  ${Y}╚══════════════════════════════════════════╝${NC}\n"

  echo -e "  ${W}Active UDP connections on port 5667:${NC}\n"
  local CONNS
  CONNS=$(ss -anu 2>/dev/null | grep ':5667')
  if [ -z "$CONNS" ]; then
    echo -e "  ${DIM}  No active connections.${NC}"
  else
    echo -e "  ${DIM}  Local Address               Peer Address${NC}"
    echo -e "  ${DIM}  ─────────────────────────   ────────────────────────${NC}"
    echo "$CONNS" | awk '{printf "  \033[1;32m  %-28s\033[0m \033[1;37m%s\033[0m\n", $5, $6}'
  fi

  echo -e "\n  ${W}Network traffic on $IFACE (live 3s sample):${NC}\n"
  if command -v ifstat &>/dev/null; then
    ifstat -i "$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)" 1 1 2>/dev/null | tail -1 | \
      awk '{printf "  RX: \033[1;32m%s KB/s\033[0m   TX: \033[1;33m%s KB/s\033[0m\n", $1, $2}'
  else
    echo -e "  ${DIM}  (install ifstat for live bandwidth stats)${NC}"
  fi

  echo -e "\n  ${W}Recent zivpn logs (last 25 lines):${NC}\n"
  journalctl -u zivpn.service -n 25 --no-pager 2>/dev/null | \
    sed 's/^/  /' | \
    GREP_COLOR='1;32' grep --color=always -E 'connect|auth|ERROR|$' || \
    echo -e "  ${DIM}  No logs found.${NC}"

  press_enter
}

# ── [8] Service control ───────────────────────────────────────────
screen_service() {
  while true; do
    draw_header
    echo -e "  ${M}╔══════════════════════════════════════════╗${NC}"
    echo -e "  ${M}║   ⚙  SERVICE CONTROL                   ║${NC}"
    echo -e "  ${M}╚══════════════════════════════════════════╝${NC}\n"

    if service_is_running; then
      echo -e "  Status : ${G}● RUNNING${NC}"
    else
      echo -e "  Status : ${R}● STOPPED${NC}"
    fi
    echo ""
    echo -e "  ${G}[1]${NC} Start Service"
    echo -e "  ${Y}[2]${NC} Stop Service"
    echo -e "  ${C}[3]${NC} Restart Service"
    echo -e "  ${W}[4]${NC} View Full Status"
    echo -e "  ${W}[5]${NC} Enable on Boot"
    echo -e "  ${W}[6]${NC} Disable on Boot"
    echo -e "  ${R}[0]${NC} Back to Main Menu"
    echo ""
    read -rp "  ➜ " sc

    case "$sc" in
      1) systemctl start   zivpn.service && echo -e "\n  ${G}✔ Service started.${NC}" || echo -e "\n  ${R}✘ Failed to start.${NC}" ;;
      2) systemctl stop    zivpn.service && echo -e "\n  ${Y}✔ Service stopped.${NC}" ;;
      3) systemctl restart zivpn.service && echo -e "\n  ${G}✔ Service restarted.${NC}" ;;
      4) echo ""; systemctl status zivpn.service --no-pager | sed 's/^/  /' ;;
      5) systemctl enable  zivpn.service && echo -e "\n  ${G}✔ Enabled on boot.${NC}" ;;
      6) systemctl disable zivpn.service && echo -e "\n  ${Y}✔ Disabled on boot.${NC}" ;;
      0) return ;;
      *) echo -e "\n  ${R}✘ Invalid option.${NC}" ;;
    esac
    press_enter
  done
}

# ── [9] Change listen port ────────────────────────────────────────
screen_change_port() {
  draw_header
  echo -e "  ${C}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${C}║   🔌  CHANGE LISTEN PORT               ║${NC}"
  echo -e "  ${C}╚══════════════════════════════════════════╝${NC}\n"

  CURR_PORT=$(python3 -c "import json; d=json.load(open('$CONFIG_FILE')); print(d.get('listen',':5667').lstrip(':'))" 2>/dev/null)
  echo -e "  Current port : ${W}$CURR_PORT${NC}"
  echo -e "  ${DIM}  Enter new port (1024–65535) or 0 to cancel:${NC}"
  read -rp "  ➜ " new_port

  if [ "$new_port" = "0" ] || [ -z "$new_port" ]; then return; fi
  if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
    echo -e "\n  ${R}✘ Invalid port number.${NC}"; press_enter; return
  fi

  python3 - "$new_port" <<'PYEOF'
import json, sys
port = sys.argv[1]
with open("/etc/zivpn/config.json") as f:
    d = json.load(f)
d["listen"] = f":{port}"
with open("/etc/zivpn/config.json", "w") as f:
    json.dump(d, f, indent=2)
PYEOF

  ufw allow "${new_port}/udp" 1>/dev/null 2>/dev/null
  reload_service
  echo -e "\n  ${G}✔ Listen port changed to ${W}$new_port${G}. Service reloaded.${NC}"
  press_enter
}

# ── [0] About ─────────────────────────────────────────────────────
screen_about() {
  draw_header
  echo -e "  ${C}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${C}║   ℹ  ABOUT                             ║${NC}"
  echo -e "  ${C}╚══════════════════════════════════════════╝${NC}\n"
  echo -e "  ${W}NOOBS ZIVPN UDP PANEL${NC}"
  echo -e "  ${DIM}  Version   :${NC} ${G}1.0.0${NC}"
  echo -e "  ${DIM}  Repo      :${NC} ${W}github.com/autobot-sys${NC}"
  echo -e "  ${DIM}  Protocol  :${NC} ${W}ZIVPN UDP (Hysteria-based)${NC}"
  echo -e "  ${DIM}  Binary    :${NC} ${W}/usr/local/bin/zivpn${NC}"
  echo -e "  ${DIM}  Config    :${NC} ${W}/etc/zivpn/config.json${NC}"
  echo -e "  ${DIM}  TLS Cert  :${NC} ${W}/etc/zivpn/zivpn.crt${NC}"
  echo -e "  ${DIM}  Service   :${NC} ${W}zivpn.service (systemd)${NC}"
  echo -e "  ${DIM}  Panel Cmd :${NC} ${W}zivudp${NC}"
  echo ""
  echo -e "  ${DIM}  Original Creator : Zahid Islam${NC}"
  echo -e "  ${DIM}  Modified by      : PowerMX / autobot-sys${NC}"
  press_enter
}

# ═════════════════════════════════════════════════════════════════
#  MAIN LOOP
# ═════════════════════════════════════════════════════════════════
while true; do
  draw_header
  draw_status

  echo -e "  ${DIM}  ── USER MANAGEMENT ────────────────────────────────────${NC}"
  echo -e "  ${G}  [1]${NC}  List All Users / Passwords"
  echo -e "  ${G}  [2]${NC}  Add Single Password"
  echo -e "  ${G}  [3]${NC}  Bulk Add Passwords  ${DIM}(comma-separated)${NC}"
  echo -e "  ${R}  [4]${NC}  Delete Single Password"
  echo -e "  ${R}  [5]${NC}  Delete Multiple Passwords"
  echo -e "  ${R}  [6]${NC}  Clear ALL Passwords"
  echo ""
  echo -e "  ${DIM}  ── SYSTEM ─────────────────────────────────────────────${NC}"
  echo -e "  ${Y}  [7]${NC}  Live Connection Monitor"
  echo -e "  ${M}  [8]${NC}  Service Control  ${DIM}(Start / Stop / Restart)${NC}"
  echo -e "  ${C}  [9]${NC}  Change Listen Port"
  echo -e "  ${W}  [i]${NC}  About / Info"
  echo -e "  ${R}  [q]${NC}  Exit"
  echo ""
  echo -e "  ${DIM}───────────────────────────────────────────────────────────${NC}"
  read -rp "  Select option ➜ " choice

  case "$choice" in
    1) screen_list          ;;
    2) screen_add_single    ;;
    3) screen_bulk_add      ;;
    4) screen_delete_single ;;
    5) screen_delete_multi  ;;
    6) screen_clear_all     ;;
    7) screen_monitor       ;;
    8) screen_service       ;;
    9) screen_change_port   ;;
    i|I) screen_about       ;;
    q|Q|0) clear; echo -e "  ${G}Goodbye!${NC}\n"; exit 0 ;;
    *) echo -e "\n  ${R}✘ Invalid option.${NC}"; sleep 1 ;;
  esac
done
