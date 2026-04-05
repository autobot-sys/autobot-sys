#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
#  NOOBS ZIVPN UDP PANEL  —  zivudp
#  Repo    : https://github.com/autobot-sys/autobot-sys
#  Creator : Zahid Islam  |  Panel by PowerMX / autobot-sys
# ╚══════════════════════════════════════════════════════════════╝

PANEL_VERSION="2.0.0"
CONFIG_FILE="/etc/zivpn/config.json"
BIN_PATH="/usr/local/bin/zivpn"
PANEL_PATH="/usr/local/bin/zivudp"
REPO_RAW="https://raw.githubusercontent.com/autobot-sys/autobot-sys/main"
IFACE=$(ip -4 route ls 2>/dev/null | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

# ── Colour palette ───────────────────────────────────────────────
BLK='\033[0;30m'
R='\033[1;31m';  DR='\033[0;31m'
G='\033[1;32m';  DG='\033[0;32m'
Y='\033[1;33m';  DY='\033[0;33m'
B='\033[1;34m'
M='\033[1;35m'
C='\033[1;36m';  DC='\033[0;36m'
W='\033[1;37m';  DW='\033[0;37m'
DIM='\033[2m';   BLINK='\033[5m'
BG_D='\033[40m'; UL='\033[4m'
NC='\033[0m'

# ── Root check ───────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "\n  ${R}✘  Run as root:${NC} sudo zivudp\n"; exit 1
fi
if ! command -v python3 &>/dev/null; then
  echo -e "\n  ${R}✘  python3 not found. Install it first.${NC}\n"; exit 1
fi

# ════════════════════════════════════════════════════════════════
#  CORE HELPERS
# ════════════════════════════════════════════════════════════════

svc_running()     { systemctl is-active --quiet zivpn.service; }
svc_start()       { systemctl start   zivpn.service 2>/dev/null; }
svc_stop()        { systemctl stop    zivpn.service 2>/dev/null; }
svc_restart()     { systemctl restart zivpn.service 2>/dev/null; }
svc_enable()      { systemctl enable  zivpn.service 2>/dev/null; }
svc_disable()     { systemctl disable zivpn.service 2>/dev/null; }

get_passwords() {
  python3 - <<PYEOF
import json
try:
    d = json.load(open("$CONFIG_FILE"))
    for p in d.get("config", []):
        print(p)
except:
    pass
PYEOF
}

write_passwords() {
  python3 - "$@" <<'PYEOF'
import json, sys
passwords = [p for p in sys.argv[1:] if p.strip()]
try:
    with open("/etc/zivpn/config.json") as f:
        d = json.load(f)
except:
    d = {"listen": ":5667"}
d["config"] = passwords
with open("/etc/zivpn/config.json", "w") as f:
    json.dump(d, f, indent=2)
PYEOF
}

get_port() {
  python3 -c "
import json
try:
    d=json.load(open('$CONFIG_FILE'))
    print(d.get('listen',':5667').lstrip(':'))
except:
    print('5667')
" 2>/dev/null
}

pwd_count() {
  local n; n=$(get_passwords | grep -c .)
  echo "$n"
}

server_ip() { hostname -I 2>/dev/null | awk '{print $1}'; }

uptime_str() {
  systemctl show zivpn.service --property=ActiveEnterTimestamp 2>/dev/null \
    | cut -d= -f2 | xargs -I{} date -d "{}" "+%s" 2>/dev/null \
    | xargs -I{} bash -c 'echo $(( $(date +%s) - {} ))' 2>/dev/null \
    | awk '{s=$1; h=int(s/3600); m=int((s%3600)/60); printf "%dh %dm\n",h,m}' 2>/dev/null \
    || echo "N/A"
}

press_any() {
  echo ""
  echo -e "  ${DIM}╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌${NC}"
  echo -ne "  ${DY}↩  Press Enter to return...${NC} "
  read -r
}

confirm_yn() {
  echo -ne "  ${Y}$1 ${DW}[yes/no]${NC}: "
  read -rp "" ans
  [ "$ans" = "yes" ]
}

spin_wait() {
  # spin_wait "msg" cmd args...
  local msg="$1"; shift
  local frames=('⠋' '⠙' '⠸' '⠴' '⠦' '⠇')
  "$@" &
  local pid=$!
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${C}%s${NC}  %s  " "${frames[$((i % 6))]}" "$msg"
    i=$((i+1)); sleep 0.1
  done
  wait "$pid"
  local rc=$?
  printf "\r  %*s\r" 60 ""
  return $rc
}

# ════════════════════════════════════════════════════════════════
#  HEADER & DASHBOARD
# ════════════════════════════════════════════════════════════════

draw_header() {
  clear
  echo -e "${C}  ╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${C}  ║${NC}  ${W}  ███╗   ██╗ ██████╗  ██████╗ ██████╗ ███████╗  ${C}        ║${NC}"
  echo -e "${C}  ║${NC}  ${W}  ████╗  ██║██╔═══██╗██╔═══██╗██╔══██╗██╔════╝  ${C}        ║${NC}"
  echo -e "${C}  ║${NC}  ${C}  ██╔██╗ ██║██║   ██║██║   ██║██████╔╝███████╗  ${C}        ║${NC}"
  echo -e "${C}  ║${NC}  ${DC} ██║╚██╗██║██║   ██║██║   ██║██╔══██╗╚════██║  ${C}        ║${NC}"
  echo -e "${C}  ║${NC}  ${DW} ██║ ╚████║╚██████╔╝╚██████╔╝██████╔╝███████║  ${C}        ║${NC}"
  echo -e "${C}  ║${NC}  ${DIM} ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝  ${C}        ║${NC}"
  echo -e "${C}  ║${NC}                                                          ${C}║${NC}"
  echo -e "${C}  ║${NC}  ${Y}  ━━━━━━━  Z I V P N   U D P   P A N E L  ━━━━━━━${NC}  ${C}  ║${NC}"
  echo -e "${C}  ║${NC}  ${DIM}          github.com/autobot-sys  ·  v${PANEL_VERSION}${NC}  ${C}            ║${NC}"
  echo -e "${C}  ╚══════════════════════════════════════════════════════════╝${NC}"
}

draw_dashboard() {
  local CNT; CNT=$(pwd_count)
  local IP;  IP=$(server_ip)
  local PORT; PORT=$(get_port)
  local UPTIME; UPTIME=$(uptime_str)

  local SVC_BADGE SVC_DOT
  if svc_running; then
    SVC_BADGE="${G}● RUNNING${NC}"; SVC_DOT="${G}"
  else
    SVC_BADGE="${R}● STOPPED${NC}"; SVC_DOT="${R}"
  fi

  echo ""
  echo -e "${DIM}  ┌─────────────────────────────────────────────────────────┐${NC}"
  printf  "  ${DIM}│${NC}  %-14s ${SVC_DOT}%-12s${NC}  ${DIM}│${NC}  ${DW}IP${NC}  ${W}%-20s${NC}  ${DIM}│${NC}\n" \
          "Service" "$(if svc_running; then echo "RUNNING"; else echo "STOPPED"; fi)" "$IP"
  printf  "  ${DIM}│${NC}  %-14s ${Y}%-12s${NC}  ${DIM}│${NC}  ${DW}Up${NC}  ${W}%-20s${NC}  ${DIM}│${NC}\n" \
          "Port" "$PORT/udp" "$UPTIME"
  printf  "  ${DIM}│${NC}  %-14s ${C}%-12s${NC}  ${DIM}│${NC}  ${DW}Relay${NC} ${W}%-20s${NC}  ${DIM}│${NC}\n" \
          "Active Users" "${CNT} user(s)" "6000-19999/udp"
  echo -e "${DIM}  └─────────────────────────────────────────────────────────┘${NC}"
  echo ""
}

# ════════════════════════════════════════════════════════════════
#  SECTION TITLE HELPER
# ════════════════════════════════════════════════════════════════

section() {
  # section COLOR "ICON  TITLE"
  local col="$1" title="$2"
  echo -e "  ${col}┌──────────────────────────────────────────────────────┐${NC}"
  printf  "  ${col}│${NC}   ${W}%-52s${col}│${NC}\n" "$title"
  echo -e "  ${col}└──────────────────────────────────────────────────────┘${NC}"
  echo ""
}

result_ok()   { echo -e "\n  ${G}  ✔  $*${NC}"; }
result_warn() { echo -e "\n  ${Y}  ⚠  $*${NC}"; }
result_err()  { echo -e "\n  ${R}  ✘  $*${NC}"; }

# ════════════════════════════════════════════════════════════════
#  [1]  LIST USERS
# ════════════════════════════════════════════════════════════════

screen_list() {
  draw_header; draw_dashboard
  section "$B" "👥   USER / PASSWORD LIST"

  mapfile -t PWDS < <(get_passwords)
  if [ ${#PWDS[@]} -eq 0 ]; then
    echo -e "  ${DIM}  ┄ No passwords configured. Use Add to create one. ┄${NC}"
  else
    echo -e "  ${DIM}  ┌──────┬────────────────────────────────────────┐${NC}"
    echo -e "  ${DIM}  │  #   │  Password                              │${NC}"
    echo -e "  ${DIM}  ├──────┼────────────────────────────────────────┤${NC}"
    local i=1
    for p in "${PWDS[@]}"; do
      printf "  ${DIM}  │${NC}  ${G}%-4s${NC}${DIM}│${NC}  ${W}%-40s${DIM}│${NC}\n" "$i" "$p"
      ((i++))
    done
    echo -e "  ${DIM}  └──────┴────────────────────────────────────────┘${NC}"
    echo -e "\n  ${DIM}  Total: ${NC}${Y}${#PWDS[@]} user(s)${NC}"
  fi
  press_any
}

# ════════════════════════════════════════════════════════════════
#  [2]  ADD SINGLE
# ════════════════════════════════════════════════════════════════

screen_add_single() {
  draw_header; draw_dashboard
  section "$G" "➕   ADD SINGLE PASSWORD"

  echo -ne "  ${DW}New password${NC}  ${DIM}▶${NC} "
  read -r new_pass
  new_pass=$(echo "$new_pass" | xargs 2>/dev/null)

  if [ -z "$new_pass" ]; then
    result_err "Password cannot be empty."; press_any; return
  fi

  mapfile -t PWDS < <(get_passwords)
  for p in "${PWDS[@]}"; do
    if [ "$p" = "$new_pass" ]; then
      result_warn "Password '${W}$new_pass${Y}' already exists — skipped."
      press_any; return
    fi
  done

  PWDS+=("$new_pass")
  write_passwords "${PWDS[@]}"
  svc_restart
  result_ok "Password '${W}$new_pass${G}' added. Service reloaded."
  press_any
}

# ════════════════════════════════════════════════════════════════
#  [3]  BULK ADD
# ════════════════════════════════════════════════════════════════

screen_bulk_add() {
  draw_header; draw_dashboard
  section "$G" "📋   BULK ADD PASSWORDS"

  echo -e "  ${DIM}  Enter multiple passwords separated by commas.${NC}"
  echo -e "  ${DIM}  Example:${NC}  ${DW}alice,bob123,vpnuser99${NC}\n"
  echo -ne "  ${DW}Passwords${NC}  ${DIM}▶${NC} "
  read -r input

  [ -z "$input" ] && { result_err "No input given."; press_any; return; }

  mapfile -t PWDS < <(get_passwords)
  IFS=',' read -r -a incoming <<< "$input"
  local added=0 skipped=0

  for np in "${incoming[@]}"; do
    np=$(echo "$np" | xargs 2>/dev/null)
    [ -z "$np" ] && continue
    local exists=0
    for ep in "${PWDS[@]}"; do [ "$ep" = "$np" ] && exists=1 && break; done
    if [ $exists -eq 0 ]; then PWDS+=("$np"); ((added++)); else ((skipped++)); fi
  done

  write_passwords "${PWDS[@]}"
  svc_restart
  result_ok "$added password(s) added. Service reloaded."
  [ $skipped -gt 0 ] && echo -e "  ${Y}  ⊘  $skipped duplicate(s) ignored.${NC}"
  press_any
}

# ════════════════════════════════════════════════════════════════
#  [4]  DELETE SINGLE
# ════════════════════════════════════════════════════════════════

screen_delete_single() {
  draw_header; draw_dashboard
  section "$R" "🗑   DELETE A PASSWORD"

  mapfile -t PWDS < <(get_passwords)
  [ ${#PWDS[@]} -eq 0 ] && { echo -e "  ${DIM}  No passwords to delete.${NC}"; press_any; return; }

  echo -e "  ${DIM}  ┌──────┬──────────────────────────────────────────┐${NC}"
  local i=1
  for p in "${PWDS[@]}"; do
    printf "  ${DIM}  │${NC}  ${G}%-4s${NC}${DIM}│${NC}  ${W}%-44s${DIM}│${NC}\n" "$i" "$p"
    ((i++))
  done
  echo -e "  ${DIM}  └──────┴──────────────────────────────────────────┘${NC}\n"
  echo -ne "  ${DW}Delete #${NC}  ${DIM}(0 to cancel)${NC}  ${DIM}▶${NC} "
  read -r sel

  { [ "$sel" = "0" ] || [ -z "$sel" ]; } && return
  if ! [[ "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -gt "${#PWDS[@]}" ]; then
    result_err "Invalid selection."; press_any; return
  fi

  local removed="${PWDS[$((sel-1))]}"
  unset 'PWDS[$((sel-1))]'
  PWDS=("${PWDS[@]}")
  write_passwords "${PWDS[@]}"
  svc_restart
  result_ok "Password '${W}$removed${G}' removed. Service reloaded."
  press_any
}

# ════════════════════════════════════════════════════════════════
#  [5]  DELETE MULTIPLE
# ════════════════════════════════════════════════════════════════

screen_delete_multi() {
  draw_header; draw_dashboard
  section "$R" "🗑   DELETE MULTIPLE PASSWORDS"

  mapfile -t PWDS < <(get_passwords)
  [ ${#PWDS[@]} -eq 0 ] && { echo -e "  ${DIM}  No passwords to delete.${NC}"; press_any; return; }

  echo -e "  ${DIM}  ┌──────┬──────────────────────────────────────────┐${NC}"
  local i=1
  for p in "${PWDS[@]}"; do
    printf "  ${DIM}  │${NC}  ${G}%-4s${NC}${DIM}│${NC}  ${W}%-44s${DIM}│${NC}\n" "$i" "$p"
    ((i++))
  done
  echo -e "  ${DIM}  └──────┴──────────────────────────────────────────┘${NC}\n"
  echo -e "  ${DIM}  Enter numbers to delete, e.g.${NC}  ${DW}1,3,5${NC}"
  echo -ne "  ${DW}Selection${NC}  ${DIM}(0 to cancel)${NC}  ${DIM}▶${NC} "
  read -r sel_input

  { [ "$sel_input" = "0" ] || [ -z "$sel_input" ]; } && return

  IFS=',' read -r -a sel_arr <<< "$sel_input"
  declare -A to_rm
  for s in "${sel_arr[@]}"; do
    s=$(echo "$s" | xargs 2>/dev/null)
    [[ "$s" =~ ^[0-9]+$ ]] && [ "$s" -ge 1 ] && [ "$s" -le "${#PWDS[@]}" ] && to_rm[$((s-1))]=1
  done

  local cnt=0; local new_pwds=()
  for idx in "${!PWDS[@]}"; do
    if [ -n "${to_rm[$idx]}" ]; then ((cnt++)); else new_pwds+=("${PWDS[$idx]}"); fi
  done

  write_passwords "${new_pwds[@]}"
  svc_restart
  result_ok "$cnt password(s) removed. Service reloaded."
  press_any
}

# ════════════════════════════════════════════════════════════════
#  [6]  CLEAR ALL
# ════════════════════════════════════════════════════════════════

screen_clear_all() {
  draw_header; draw_dashboard
  section "$R" "⚠   CLEAR ALL PASSWORDS"

  echo -e "  ${R}  This will remove EVERY password.${NC}"
  echo -e "  ${R}  All connected clients will be dropped.${NC}\n"

  if confirm_yn "Confirm wipe all?"; then
    write_passwords
    svc_restart
    result_ok "All passwords cleared. Service reloaded."
  else
    result_warn "Cancelled — nothing changed."
  fi
  press_any
}

# ════════════════════════════════════════════════════════════════
#  [7]  START ZIVPN
# ════════════════════════════════════════════════════════════════

screen_start() {
  draw_header; draw_dashboard
  section "$G" "▶   START ZIVPN"

  if svc_running; then
    result_warn "Service is already running."
  else
    echo -e "  ${DIM}  Starting zivpn service...${NC}"
    if svc_start; then
      sleep 1
      svc_running && result_ok "ZIVPN is now RUNNING." || result_err "Service started but may have crashed. Check logs."
    else
      result_err "Failed to start service. Run: systemctl status zivpn"
    fi
  fi
  press_any
}

# ════════════════════════════════════════════════════════════════
#  [8]  STOP ZIVPN
# ════════════════════════════════════════════════════════════════

screen_stop() {
  draw_header; draw_dashboard
  section "$R" "⏹   STOP ZIVPN"

  if ! svc_running; then
    result_warn "Service is already stopped."
  else
    echo -e "  ${DIM}  Stopping zivpn service...${NC}"
    if svc_stop; then
      sleep 1
      result_ok "ZIVPN is now STOPPED."
    else
      result_err "Failed to stop service."
    fi
  fi
  press_any
}

# ════════════════════════════════════════════════════════════════
#  [9]  RESTART ZIVPN
# ════════════════════════════════════════════════════════════════

screen_restart() {
  draw_header; draw_dashboard
  section "$Y" "↺   RESTART ZIVPN"

  echo -e "  ${DIM}  Restarting zivpn service...${NC}"
  if svc_restart; then
    sleep 1
    svc_running && result_ok "ZIVPN restarted successfully." || result_err "Service may have crashed. Check logs."
  else
    result_err "Restart command failed."
  fi
  press_any
}

# ════════════════════════════════════════════════════════════════
#  [U]  AUTO-UPDATE FROM GITHUB
# ════════════════════════════════════════════════════════════════

screen_autoupdate() {
  draw_header; draw_dashboard
  section "$M" "⟳   AUTO-UPDATE FROM GITHUB"

  echo -e "  ${DIM}  This will pull the latest scripts from:${NC}"
  echo -e "  ${W}  $REPO_RAW${NC}"
  echo -e "  ${DIM}  Files updated:  zivudp.sh (panel)  +  install.sh${NC}\n"

  if ! confirm_yn "Proceed with update?"; then
    result_warn "Update cancelled."; press_any; return
  fi

  echo ""
  local TMPDIR; TMPDIR=$(mktemp -d)
  local ERRORS=0

  # ── Update panel ────────────────────────────────────────────
  echo -ne "  ${C}⟳${NC}  Downloading panel  ${DIM}(zivudp.sh)${NC}..."
  if wget -q --timeout=20 "$REPO_RAW/panel/zivudp.sh" -O "$TMPDIR/zivudp.sh" \
     && [ -s "$TMPDIR/zivudp.sh" ]; then
    cp "$TMPDIR/zivudp.sh" "$PANEL_PATH"
    chmod +x "$PANEL_PATH"
    echo -e "  ${G}✔${NC}"
  else
    echo -e "  ${R}✘ Failed${NC}"; ((ERRORS++))
  fi

  # ── Update installer (saved to /etc/zivpn/) ─────────────────
  echo -ne "  ${C}⟳${NC}  Downloading installer ${DIM}(install.sh)${NC}..."
  if wget -q --timeout=20 "$REPO_RAW/scripts/install.sh" -O "$TMPDIR/install.sh" \
     && [ -s "$TMPDIR/install.sh" ]; then
    cp "$TMPDIR/install.sh" "/etc/zivpn/install.sh"
    chmod +x "/etc/zivpn/install.sh"
    echo -e "  ${G}✔${NC}"
  else
    echo -e "  ${R}✘ Failed${NC}"; ((ERRORS++))
  fi

  # ── Optionally update zivpn binary ──────────────────────────
  echo -ne "  ${C}⟳${NC}  Checking ZIVPN binary update..."
  LATEST_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
  if wget -q --timeout=30 "$LATEST_URL" -O "$TMPDIR/zivpn_new" \
     && [ -s "$TMPDIR/zivpn_new" ]; then
    if ! cmp -s "$TMPDIR/zivpn_new" "$BIN_PATH" 2>/dev/null; then
      svc_stop
      cp "$TMPDIR/zivpn_new" "$BIN_PATH"
      chmod +x "$BIN_PATH"
      svc_start
      echo -e "  ${G}✔ Binary updated${NC}"
    else
      echo -e "  ${DIM}already latest${NC}"
    fi
  else
    echo -e "  ${Y}⚠ Skipped${NC}"; ((ERRORS++))
  fi

  rm -rf "$TMPDIR"
  echo ""
  echo -e "  ${DIM}  ────────────────────────────────────────────────────${NC}"

  if [ "$ERRORS" -eq 0 ]; then
    result_ok "All components updated from GitHub successfully."
    echo -e "  ${DIM}  The panel has been updated — ${W}zivudp${DIM} will use new code next run.${NC}"
  else
    result_warn "Update completed with $ERRORS error(s). Check internet connection."
  fi
  press_any
}

# ════════════════════════════════════════════════════════════════
#  [M]  MONITOR
# ════════════════════════════════════════════════════════════════

screen_monitor() {
  draw_header; draw_dashboard
  section "$Y" "📡   LIVE CONNECTION MONITOR"

  echo -e "  ${W}  UDP connections on port $(get_port):${NC}\n"
  local PORT; PORT=$(get_port)
  local CONNS; CONNS=$(ss -anu 2>/dev/null | grep ":$PORT")

  if [ -z "$CONNS" ]; then
    echo -e "  ${DIM}  ┄ No active UDP connections detected ┄${NC}"
  else
    echo -e "  ${DIM}  ┌──────────────────────────────┬──────────────────────────────┐${NC}"
    echo -e "  ${DIM}  │  Local Address               │  Peer Address                │${NC}"
    echo -e "  ${DIM}  ├──────────────────────────────┼──────────────────────────────┤${NC}"
    echo "$CONNS" | awk '{
      printf "  \033[2m  │\033[0m  \033[1;32m%-28s\033[0m\033[2m│\033[0m  \033[1;37m%-28s\033[0m\033[2m│\033[0m\n", $5, $6
    }'
    echo -e "  ${DIM}  └──────────────────────────────┴──────────────────────────────┘${NC}"
  fi

  echo -e "\n  ${W}  Recent service logs:${NC}\n"
  journalctl -u zivpn.service -n 20 --no-pager 2>/dev/null \
    | tail -20 \
    | sed 's/^/    /' \
    | sed "s/error\|Error\|ERROR/${R}&${NC}/Ig" \
    | sed "s/connect\|auth\|Connected/${G}&${NC}/Ig" \
    || echo -e "  ${DIM}  No logs available.${NC}"

  press_any
}

# ════════════════════════════════════════════════════════════════
#  [P]  CHANGE PORT
# ════════════════════════════════════════════════════════════════

screen_change_port() {
  draw_header; draw_dashboard
  section "$C" "🔌   CHANGE LISTEN PORT"

  local curr; curr=$(get_port)
  echo -e "  ${DIM}  Current port:${NC}  ${W}$curr/udp${NC}\n"
  echo -ne "  ${DW}New port${NC}  ${DIM}(1024–65535, 0 to cancel)${NC}  ${DIM}▶${NC} "
  read -r np

  { [ "$np" = "0" ] || [ -z "$np" ]; } && return
  if ! [[ "$np" =~ ^[0-9]+$ ]] || [ "$np" -lt 1024 ] || [ "$np" -gt 65535 ]; then
    result_err "Invalid port."; press_any; return
  fi

  python3 - "$np" <<'PYEOF'
import json, sys
port = sys.argv[1]
with open("/etc/zivpn/config.json") as f:
    d = json.load(f)
d["listen"] = f":{port}"
with open("/etc/zivpn/config.json", "w") as f:
    json.dump(d, f, indent=2)
PYEOF

  ufw allow "${np}/udp" 1>/dev/null 2>/dev/null
  svc_restart
  result_ok "Port changed to ${W}$np${G}. Service reloaded."
  press_any
}

# ════════════════════════════════════════════════════════════════
#  [I]  ABOUT
# ════════════════════════════════════════════════════════════════

screen_about() {
  draw_header
  echo ""
  section "$C" "ℹ   ABOUT  NOOBS ZIVPN UDP PANEL"

  echo -e "  ${DIM}  ┌─────────────────────────┬─────────────────────────────┐${NC}"
  printf  "  ${DIM}  │${NC}  %-23s  ${DIM}│${NC}  ${W}%-27s${DIM}│${NC}\n"  "Panel Version"    "$PANEL_VERSION"
  printf  "  ${DIM}  │${NC}  %-23s  ${DIM}│${NC}  ${W}%-27s${DIM}│${NC}\n"  "Repository"       "github.com/autobot-sys"
  printf  "  ${DIM}  │${NC}  %-23s  ${DIM}│${NC}  ${W}%-27s${DIM}│${NC}\n"  "Protocol"         "ZIVPN UDP"
  printf  "  ${DIM}  │${NC}  %-23s  ${DIM}│${NC}  ${W}%-27s${DIM}│${NC}\n"  "Binary"           "/usr/local/bin/zivpn"
  printf  "  ${DIM}  │${NC}  %-23s  ${DIM}│${NC}  ${W}%-27s${DIM}│${NC}\n"  "Config"           "/etc/zivpn/config.json"
  printf  "  ${DIM}  │${NC}  %-23s  ${DIM}│${NC}  ${W}%-27s${DIM}│${NC}\n"  "TLS Certificate"  "/etc/zivpn/zivpn.crt"
  printf  "  ${DIM}  │${NC}  %-23s  ${DIM}│${NC}  ${W}%-27s${DIM}│${NC}\n"  "Systemd Unit"     "zivpn.service"
  printf  "  ${DIM}  │${NC}  %-23s  ${DIM}│${NC}  ${W}%-27s${DIM}│${NC}\n"  "Panel Command"    "zivudp"
  printf  "  ${DIM}  │${NC}  %-23s  ${DIM}│${NC}  ${W}%-27s${DIM}│${NC}\n"  "Original Creator" "Zahid Islam"
  printf  "  ${DIM}  │${NC}  %-23s  ${DIM}│${NC}  ${W}%-27s${DIM}│${NC}\n"  "Panel by"         "PowerMX / autobot-sys"
  echo -e "  ${DIM}  └─────────────────────────┴─────────────────────────────┘${NC}"
  press_any
}

# ════════════════════════════════════════════════════════════════
#  MAIN MENU
# ════════════════════════════════════════════════════════════════

main_menu() {
  while true; do
    draw_header
    draw_dashboard

    echo -e "  ${DIM}  ┌── 👥  USER MANAGEMENT ──────────────────────────────┐${NC}"
    echo -e "  ${DIM}  │${NC}  ${G}[1]${NC}  List All Users / Passwords                    ${DIM}│${NC}"
    echo -e "  ${DIM}  │${NC}  ${G}[2]${NC}  Add Single Password                            ${DIM}│${NC}"
    echo -e "  ${DIM}  │${NC}  ${G}[3]${NC}  Bulk Add  ${DIM}(comma-separated)${NC}                    ${DIM}│${NC}"
    echo -e "  ${DIM}  │${NC}  ${R}[4]${NC}  Delete Single Password                         ${DIM}│${NC}"
    echo -e "  ${DIM}  │${NC}  ${R}[5]${NC}  Delete Multiple Passwords                      ${DIM}│${NC}"
    echo -e "  ${DIM}  │${NC}  ${R}[6]${NC}  Clear ALL Passwords                            ${DIM}│${NC}"
    echo -e "  ${DIM}  ├── ⚙  SERVICE CONTROL ───────────────────────────────┤${NC}"
    echo -e "  ${DIM}  │${NC}  ${G}[7]${NC}  Start ZIVPN                                    ${DIM}│${NC}"
    echo -e "  ${DIM}  │${NC}  ${R}[8]${NC}  Stop  ZIVPN                                    ${DIM}│${NC}"
    echo -e "  ${DIM}  │${NC}  ${Y}[9]${NC}  Restart ZIVPN                                  ${DIM}│${NC}"
    echo -e "  ${DIM}  │${NC}  ${M}[u]${NC}  Auto-Update from GitHub  ${DIM}⟳${NC}                    ${DIM}│${NC}"
    echo -e "  ${DIM}  ├── 🛠  TOOLS ────────────────────────────────────────┤${NC}"
    echo -e "  ${DIM}  │${NC}  ${C}[m]${NC}  Live Connection Monitor                        ${DIM}│${NC}"
    echo -e "  ${DIM}  │${NC}  ${C}[p]${NC}  Change Listen Port                             ${DIM}│${NC}"
    echo -e "  ${DIM}  │${NC}  ${W}[i]${NC}  About / Info                                   ${DIM}│${NC}"
    echo -e "  ${DIM}  │${NC}  ${DR}[q]${NC}  Exit                                           ${DIM}│${NC}"
    echo -e "  ${DIM}  └────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -ne "  ${C}▶${NC}  Select option: "
    read -r choice

    case "$choice" in
      1)   screen_list          ;;
      2)   screen_add_single    ;;
      3)   screen_bulk_add      ;;
      4)   screen_delete_single ;;
      5)   screen_delete_multi  ;;
      6)   screen_clear_all     ;;
      7)   screen_start         ;;
      8)   screen_stop          ;;
      9)   screen_restart       ;;
      u|U) screen_autoupdate    ;;
      m|M) screen_monitor       ;;
      p|P) screen_change_port   ;;
      i|I) screen_about         ;;
      q|Q|0)
        clear
        echo -e "\n  ${C}  ★  NOOBS ZIVPN UDP PANEL  —  Goodbye!  ★${NC}\n"
        exit 0 ;;
      *)
        echo -e "\n  ${R}  ✘  Invalid option — try again.${NC}"; sleep 1 ;;
    esac
  done
}

main_menu
