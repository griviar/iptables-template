# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project does

Template-based framework for assembling per-server `iptables.sh` scripts from shared snippets. Templates live in Git; server-specific configuration is created locally on each server (gitignored).

## Key commands

```bash
bash detect-wan.sh     # detect WAN interface/IP and write to user/.env
bash build.sh          # reads .tag, assembles iptables.sh
sudo bash iptables.sh  # apply generated rules (run on the target Linux server)
sudo bash save.sh      # persist current rules across reboots (iptables-persistent + ipset-persistent)
```

`build.sh` exits silently (code 0) if `.tag` is absent — this is intentional.

## Assembly order

`build.sh` hard-codes this pipeline:

1. `templates/general/10-vars.sh` — IPT/IPS aliases and IPset names (`SSH_SET`, `APP_SET`)
2. `user/.env` — server variables (WAN, WAN_IP, PORT_SSH, PORT_APP, …)
3. `user/ipsets/` — each file becomes one IPSet: created, flushed, and populated (generated dynamically by `build.sh`)
4. `templates/general/[3-9][0-9]-*.sh` (sorted) — base firewall rules
5. `templates/<tag>/[0-9]*.sh` (sorted) for each tag in `.tag`
6. `user/custom.sh` — server-specific additions

IPSet setup (step 3) must happen before iptables rules reference set names.

## IPSet files (`user/ipsets/`)

Each file in this directory becomes one IPSet. The filename is the set name. Type: `hash:net` (supports single IPs and CIDR).

```
# comment line — preserved in generated script
1.2.3.4              # single IP
10.0.0.0/24          # subnet
5.6.7.8 # label      # inline comment stripped, IP used
```

## SSH access

Default (`templates/general/90-ssh.sh`): port 22 open for all, hardcoded — no variable needed.

To harden (whitelist + custom port): comment out the open rule in `90-ssh.sh`, then uncomment the SSH block in `user/custom.sh` — see `user/custom.sh.example` for the full steps. `PORT_SSH` in `user/.env` is only needed when using a non-standard port.

## APP port whitelist (optional)

Not in any template by default. See `user/custom.sh.example` — requires `PORT_APP` in `user/.env` and `user/ipsets/app-list`.

## Adding a new tag

1. Create `templates/<tagname>/` and add one or more `NN-description.sh` snippet files
2. The numeric prefix (`10-`, `20-`, …) controls ordering *within* the tag directory
3. Snippets are bare bash — no shebang; they reference exported vars like `$IPT`, `$IPS`, `$WAN`

## Server-side setup (gitignored files)

| File/Dir | Purpose |
|----------|---------|
| `user/.env` | `export WAN=`, `WAN_IP=`, `PORT_SSH=`, `PORT_APP=`; add `LAN1`/`LAN1_IP_RANGE` for `gateway` tag |
| `user/ipsets/<name>` | One file per IPSet — IPs/CIDRs, one per line |
| `user/custom.sh` | Extra rules appended after all templates |

## Tag reference

| Tag | Opens |
|-----|-------|
| `web` | TCP 80, 443 |
| `mail` | TCP 25, 110, 143, 465, 993, 995 |
| `sip` | UDP/TCP 5060, UDP 10000–15000 (RTP) |
| `h323` | TCP 1720 |
| `dns` | UDP/TCP 53 |
| `gateway` | LAN→WAN FORWARD + MASQUERADE (needs `LAN1`, `LAN1_IP_RANGE` in `user/.env`) |
| `logging` | Logs all dropped packets — **must be listed last** in `.tag` |
