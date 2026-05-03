#!/bin/bash
# Detects network interfaces, lets you pick the WAN one, and writes it to user/.env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_ENV="$SCRIPT_DIR/user/.env"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Gather interfaces ─────────────────────────────────────────────────────────
# Skip: loopback, Docker bridges, veth (containers), VPN tunnels, libvirt

SKIP_RE='^(lo$|docker[0-9]*$|br-|veth|virbr|tun[0-9]*$|tap[0-9]*$|dummy)'

declare -a IFACES=()
declare -a IPS=()

while IFS=' ' read -r _ iface _ addr _rest; do
    ip="${addr%%/*}"                        # strip prefix length (/24 etc.)
    [[ "$ip"    =~ ^127\. ]] && continue   # loopback addresses
    [[ "$iface" =~ $SKIP_RE ]] && continue # virtual / container interfaces
    IFACES+=("$iface")
    IPS+=("$ip")
done < <(ip -4 -o addr show 2>/dev/null | grep 'scope global')

[[ ${#IFACES[@]} -gt 0 ]] || error "No suitable network interfaces found."

# ── Detect default-route interface ───────────────────────────────────────────

DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk '/^default/ {print $5; exit}')

# ── Select ────────────────────────────────────────────────────────────────────

SEL_IFACE="" SEL_IP=""

if [[ ${#IFACES[@]} -eq 1 ]]; then
    SEL_IFACE="${IFACES[0]}"
    SEL_IP="${IPS[0]}"

    echo ""
    echo -e "  Detected interface: ${BOLD}${SEL_IFACE}${NC}  —  IP: ${BOLD}${SEL_IP}${NC}"
    echo ""
    read -rp "  Use as WAN? [Y/n] " yn
    [[ "${yn,,}" == n ]] && { echo ""; warn "Aborted."; exit 0; }

else
    echo ""
    echo -e "  Found ${BOLD}${#IFACES[@]}${NC} network interfaces:"
    echo ""

    DEFAULT_IDX=""
    for i in "${!IFACES[@]}"; do
        note=""
        if [[ "${IFACES[$i]}" == "$DEFAULT_IFACE" ]]; then
            note="  ${CYAN}← default route${NC}"
            DEFAULT_IDX=$((i + 1))
        fi
        printf "  %2d)  %-16s  %s%b\n" $((i + 1)) "${IFACES[$i]}" "${IPS[$i]}" "$note"
    done
    echo ""

    prompt="  Enter number [1-${#IFACES[@]}]"
    [[ -n "$DEFAULT_IDX" ]] && prompt+=" (Enter = ${DEFAULT_IDX})"
    prompt+=": "

    while true; do
        read -rp "$prompt" choice
        [[ -z "$choice" && -n "$DEFAULT_IDX" ]] && choice="$DEFAULT_IDX"
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#IFACES[@]} )); then
            SEL_IFACE="${IFACES[$((choice - 1))]}"
            SEL_IP="${IPS[$((choice - 1))]}"
            break
        fi
        warn "Please enter a number between 1 and ${#IFACES[@]}."
    done
fi

echo ""
info "WAN=${SEL_IFACE}  WAN_IP=${SEL_IP}"
echo ""

# ── Write to user/.env ────────────────────────────────────────────────────────

read -rp "  Write to user/.env? [Y/n] " yn
if [[ "${yn,,}" == n ]]; then
    echo ""
    echo "  Add to user/.env manually:"
    echo "    export WAN=${SEL_IFACE}"
    echo "    export WAN_IP=${SEL_IP}"
    echo ""
    exit 0
fi

mkdir -p "$SCRIPT_DIR/user"

# If .env doesn't exist yet, seed it from the example file
if [[ ! -f "$USER_ENV" ]] && [[ -f "$SCRIPT_DIR/user/.env.example" ]]; then
    cp "$SCRIPT_DIR/user/.env.example" "$USER_ENV"
    info "Created user/.env from example"
fi

# Update a KEY=value line in a file, or append if not found
update_env() {
    local file="$1" key="$2" value="$3"
    local new_line="export ${key}=${value}"
    if [[ -f "$file" ]] && grep -qE "^(export[[:space:]]+)?${key}=" "$file"; then
        local tmp
        tmp=$(mktemp)
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^(export[[:space:]]+)?${key}= ]]; then
                echo "$new_line"
            else
                echo "$line"
            fi
        done < "$file" > "$tmp"
        mv "$tmp" "$file"
    else
        echo "$new_line" >> "$file"
    fi
}

if [[ -f "$USER_ENV" ]]; then
    update_env "$USER_ENV" "WAN"    "$SEL_IFACE"
    update_env "$USER_ENV" "WAN_IP" "$SEL_IP"
    info "Updated: $USER_ENV"
else
    { echo "export WAN=${SEL_IFACE}"; echo "export WAN_IP=${SEL_IP}"; } > "$USER_ENV"
    info "Created: $USER_ENV"
fi

echo ""
info "Done. Run 'bash build.sh' to regenerate iptables.sh."
