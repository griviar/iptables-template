#!/bin/bash
# Saves current IPSet and IPTables rules for persistence across reboots.
# Requires: iptables-persistent (netfilter-persistent) and ipset-persistent packages.
#
# Docker handling (when Docker daemon is running):
#   EXCLUDED  — DOCKER, DOCKER-ISOLATION-STAGE-1, DOCKER-ISOLATION-STAGE-2 chains
#   PRESERVED — DOCKER-USER chain definition and all its rules
#   NOTE      — All "-j DOCKER*" jumps are removed; Docker re-adds them on startup
#               to avoid duplicates. Your DOCKER-USER rules stay intact.

set -euo pipefail

RULES_V4="/etc/iptables/rules.v4"
IPSET_FILE="/etc/iptables/ipsets"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || error "Must run as root: sudo bash save.sh"

for cmd in iptables-save ipset; do
    command -v "$cmd" &>/dev/null \
        || error "Command not found: '$cmd'. Install packages: iptables-persistent ipset-persistent"
done

mkdir -p /etc/iptables

# ── IPSet ─────────────────────────────────────────────────────────────────────

info "Saving IPSet rules → $IPSET_FILE"
ipset save > "$IPSET_FILE"

# ── IPTables ──────────────────────────────────────────────────────────────────

info "Saving IPTables rules → $RULES_V4"

docker_active=false
if systemctl is-active --quiet docker 2>/dev/null; then
    docker_active=true
fi

if $docker_active; then
    info "Docker is running — filtering Docker-managed chains, preserving DOCKER-USER"

    # What gets removed:
    #   ^:(DOCKER|DOCKER-ISOLATION-STAGE-1|DOCKER-ISOLATION-STAGE-2) ...
    #       chain declarations for Docker-managed chains
    #   ^-A (DOCKER|DOCKER-ISOLATION-STAGE-1|DOCKER-ISOLATION-STAGE-2) ...
    #       rules that live inside those chains
    #   -j DOCKER...
    #       all jumps to any Docker chain, including DOCKER-USER
    #       (Docker re-adds FORWARD→DOCKER-USER on startup; removing it here prevents duplicates)
    #
    # What gets kept:
    #   :DOCKER-USER ...      chain declaration
    #   -A DOCKER-USER ...    all user rules inside the chain

    iptables-save \
        | grep -vE "^:(DOCKER|DOCKER-ISOLATION-STAGE-[12]) " \
        | grep -vE "^-A (DOCKER|DOCKER-ISOLATION-STAGE-[12]) " \
        | grep -vE " -j DOCKER[^ ]*( |\$)" \
        > "$RULES_V4"
else
    iptables-save > "$RULES_V4"
fi

info "Done."
info "  IPTables : $RULES_V4"
info "  IPSet    : $IPSET_FILE"

# ── Check autostart ───────────────────────────────────────────────────────────

if systemctl is-enabled --quiet netfilter-persistent 2>/dev/null; then
    info "netfilter-persistent is enabled — rules will be restored on next boot."
else
    warn "netfilter-persistent is NOT enabled in autostart."
    warn "Rules were saved but won't be restored on reboot until you run:"
    warn "  sudo systemctl enable netfilter-persistent"
fi
