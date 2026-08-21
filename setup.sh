#!/usr/bin/env bash
set -euo pipefail

LOGFILE="/var/log/pi-gateway-setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    fail "Run as root: sudo $0"
  fi
}

confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local choice
  if [[ "$default" =~ ^[Yy]$ ]]; then
    prompt="$prompt [Y/n]"
  else
    prompt="$prompt [y/N]"
  fi
  read -rp "$prompt " choice
  choice="${choice:-$default}"
  [[ "$choice" =~ ^[Yy]$ ]]
}

intro() {
  clear
  cat <<'BANNER'
+----------------------------------------------------------+
|                                                          |
|   🥧  Raspberry Pi Gateway Setup Wizard                   |
|        Optimized for Pi4 (2GB RAM)                       |
|                                                          |
|   This will configure your Pi as a wired home           |
|   network gateway with DNS, monitoring, VPN, and         |
|   reverse proxy.                                         |
|                                                          |
+----------------------------------------------------------+
BANNER
  echo
  warn "This modifies networking, installs Docker, and deploys services."
  echo
  confirm "Continue?" "y" || fail "Setup cancelled."
  echo
}

check_os() {
  info "Checking OS..."
  if [[ ! -f /etc/os-release ]]; then
    fail "Cannot detect OS. Are you on Raspberry Pi OS?"
  fi
  . /etc/os-release
  if [[ "${ID:-}" != "debian" && "${ID_LIKE:-}" != *debian* ]]; then
    warn "This script expects Debian-based OS. Proceeding anyway..."
  fi
  ok "OS check passed: ${PRETTY_NAME:-unknown}"
}

deployment_mode_ui() {
  info "Deployment mode (Pi4 2GB optimization)"
  echo
  echo "Choose deployment mode:"
  echo "  1) minimal  - Core services only (lowest RAM usage)"
  echo "  2) full     - All services including monitoring"
  echo
  read -rp "Enter choice [1]: " mode_choice
  mode_choice="${mode_choice:-1}"
  if [[ "$mode_choice" == "2" ]]; then
    DEPLOYMENT_MODE="full"
  else
    DEPLOYMENT_MODE="minimal"
  fi
  echo "Selected: $DEPLOYMENT_MODE"
  echo
}

network_config() {
  info "Network configuration"
  echo
  echo "The Pi needs TWO network interfaces:"
  echo "  - eth0 -> WAN (modem / upstream router)"
  echo "  - eth1 -> LAN (internal switch / APs)"
  echo

  mapfile -t ifaces < <(ls /sys/class/net/ | grep -E '^eth' || true)
  echo "Detected Ethernet interfaces: ${ifaces[*]:-none}"
  echo

  if [[ ${#ifaces[@]} -ge 2 ]]; then
    echo "Detected multiple interfaces. Please confirm mapping:"
    echo "  0) ${ifaces[0]} -> WAN (eth0)"
    echo "  1) ${ifaces[1]} -> LAN (eth1)"
    read -rp "Enter WAN interface index [0]: " wan_idx
    wan_idx="${wan_idx:-0}"
    read -rp "Enter LAN interface index [1]: " lan_idx
    lan_idx="${lan_idx:-1}"
    WAN_IF="${ifaces[$wan_idx]}"
    LAN_IF="${ifaces[$lan_idx]}"
  else
    warn "Could not auto-detect multiple interfaces."
    read -rp "Enter WAN interface name [eth0]: " WAN_IF
    WAN_IF="${WAN_IF:-eth0}"
    read -rp "Enter LAN interface name [eth1]: " LAN_IF
    LAN_IF="${LAN_IF:-eth1}"
  fi

  read -rp "LAN subnet [192.168.10.0/24]: " LAN_SUBNET
  LAN_SUBNET="${LAN_SUBNET:-192.168.10.0/24}"

  read -rp "Pi LAN IP [192.168.10.1]: " LAN_IP
  LAN_IP="${LAN_IP:-192.168.10.1}"

  read -rp "SSH port [22]: " SSH_PORT
  SSH_PORT="${SSH_PORT:-22}"

  echo
  echo "Summary:"
  echo "  WAN interface : $WAN_IF"
  echo "  LAN interface : $LAN_IF"
  echo "  LAN subnet    : $LAN_SUBNET"
  echo "  Pi LAN IP     : $LAN_IP"
  echo "  SSH port      : $SSH_PORT"
  echo
  confirm "Correct?" "y" || fail "Please re-run and enter correct values."
}

tailscale_config() {
  info "Tailscale configuration"
  echo
  if ! confirm "Enable Tailscale exit node + subnet router?" "y"; then
    TAILSCALE_ENABLED="false"
    return
  fi
  TAILSCALE_ENABLED="true"

  echo "Tailscale role:"
  echo "  1) native  - Run on host (recommended for Pi4, lowest overhead)"
  echo "  2) container - Run in Docker"
  read -rp "Enter choice [1]: " ts_role_choice
  ts_role_choice="${ts_role_choice:-1}"
  if [[ "$ts_role_choice" == "2" ]]; then
    TS_ROLE="container"
  else
    TS_ROLE="native"
  fi

  read -rp "Tailscale hostname [pi-gateway]: " TS_HOSTNAME
  TS_HOSTNAME="${TS_HOSTNAME:-pi-gateway}"

  read -rp "Tailscale auth key (tskey-auth-...): " TS_AUTHKEY
  if [[ -z "$TS_AUTHKEY" ]]; then
    warn "No auth key provided. You will need to set it manually later."
  fi

  echo
  read -rp "Subnet to advertise [${LAN_SUBNET}]: " TS_ROUTES
  TS_ROUTES="${TS_ROUTES:-$LAN_SUBNET}"
}

dns_config() {
  info "DNS / Pi-hole configuration"
  echo
  if ! confirm "Deploy Pi-hole for DNS + ad blocking?" "y"; then
    PIHOLE_ENABLED="false"
    return
  fi
  PIHOLE_ENABLED="true"

  read -rp "Upstream DNS (comma-separated) [1.1.1.1]: " UPSTREAM_DNS
  UPSTREAM_DNS="${UPSTREAM_DNS:-1.1.1.1}"

  read -rp "Pi-hole admin password: " PIHOLE_PASSWORD
  while [[ -z "$PIHOLE_PASSWORD" ]]; do
    warn "Password cannot be empty."
    read -rp "Pi-hole admin password: " PIHOLE_PASSWORD
  done
}

write_ansible_vars() {
  info "Writing Ansible variables..."
  local vars_dir="/tmp/pi-gateway-setup-vars"
  mkdir -p "$vars_dir"

  cat > "$vars_dir/setup-vars.yml" <<EOF
---
# Auto-generated by pi-gateway-setup.sh
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

# Deployment mode
deployment_mode: "${DEPLOYMENT_MODE:-minimal}"
monitoring_mode: "lightweight"
tailscale_role: "${TS_ROLE:-native}"

# Network
wan_interface: "${WAN_IF}"
lan_interface: "${LAN_IF}"
lan_subnet: "${LAN_SUBNET}"
lan_ip: "${LAN_IP}"
lan_cidr: "${LAN_SUBNET#*/}"
gateway_ip: "${LAN_IP}"

# Services
traefik_dashboard_port: 8080
domain_suffix: ".internal"
default_timezone: "Australia/Sydney"
pihole_password: "${PIHOLE_PASSWORD:-}"
pihole_upstream_dns: "${UPSTREAM_DNS:-1.1.1.1}"

# Tailscale
tailscale_enabled: "${TAILSCALE_ENABLED:-false}"
tailscale_auth_key: "${TS_AUTHKEY:-}"
tailscale_hostname: "${TS_HOSTNAME:-pi-gateway}"
tailscale_advertise_routes: "${TS_ROUTES:-${LAN_SUBNET}}"
tailscale_accept_routes: "true"
tailscale_exit_node: "true"

# Docker
docker_compose_dir: "/opt/pi-gateway"
docker_compose_file: "{{ docker_compose_dir }}/docker-compose.yml"
docker_network_name: "internal"

# Security
ssh_port: "${SSH_PORT}"

# Pi4 optimizations
enable_swap: true
EOF

  ok "Variables written to $vars_dir/setup-vars.yml"
  echo "$vars_dir" > /tmp/pi-gateway-setup-vars-dir
}

write_ansible_vault() {
  info "Creating Ansible Vault password file..."
  echo
  read -rp "Enter a strong vault password (stored locally only): " -s VAULT_PASS
  echo
  read -rp "Confirm vault password: " -s VAULT_PASS2
  echo
  [[ "$VAULT_PASS" == "$VAULT_PASS2" ]] || fail "Passwords do not match."

  local vault_dir="/tmp/pi-gateway-setup-vault"
  mkdir -p "$vault_dir"
  echo "$VAULT_PASS" > "$vault_dir/.vault_pass.txt"
  chmod 600 "$vault_dir/.vault_pass.txt"

  if command -v ansible-vault &>/dev/null; then
    echo '{}' > /tmp/empty_vault.yml
    ansible-vault encrypt /tmp/empty_vault.yml --vault-password-file="$vault_dir/.vault_pass.txt"       --output="$vault_dir/vault.yml" 2>/dev/null || true
    ok "Vault password file: $vault_dir/.vault_pass.txt"
    echo "$vault_dir" > /tmp/pi-gateway-setup-vault-dir
  else
    warn "ansible-vault not found yet. Vault will be created after bootstrap."
    echo "$vault_dir" > /tmp/pi-gateway-setup-vault-dir
  fi
}

install_ansible() {
  info "Installing Ansible..."
  apt-get update -qq
  apt-get install -y -qq python3-pip >/dev/null 2>&1 || true
  pip3 install --quiet ansible ansible-vault 2>/dev/null || true
  ok "Ansible installed"
}

generate_inventory() {
  info "Generating inventory..."
  local inv_dir="/tmp/pi-gateway-setup-inventory"
  mkdir -p "$inv_dir"

  cat > "$inv_dir/hosts.yml" <<EOF
all:
  hosts:
    pi-gateway:
      ansible_host: ${LAN_IP}
      ansible_user: pi
      ansible_python_interpreter: /usr/bin/python3
      ansible_port: ${SSH_PORT}
  children:
    gateway:
      hosts:
        pi-gateway:
EOF

  ok "Inventory generated at $inv_dir/hosts.yml"
  echo "$inv_dir" > /tmp/pi-gateway-setup-inventory-dir
}

bootstrap_instructions() {
  echo
  cat <<'BANNER'
+----------------------------------------------------------+
|                    SETUP COMPLETE                        |
+----------------------------------------------------------+
BANNER
  echo
  info "Next steps:"
  echo
  echo "1. Transfer generated files to your control machine:"
  echo "   scp -r /tmp/pi-gateway-setup-* pi@<control-machine>:~/"
  echo
  echo "2. On the control machine, clone the pi-gateway-ansible repo:"
  echo "   git clone <your-repo-url> pi-gateway-ansible"
  echo "   cd pi-gateway-ansible"
  echo
  echo "3. Copy generated files into place:"
  echo "   cp ~/setup-vars.yml group_vars/all.yml"
  echo "   cp ~/vault.yml group_vars/vault.yml"
  echo "   cp ~/hosts.yml inventory/hosts.yml"
  echo
  echo "4. Run bootstrap playbook:"
  echo "   make bootstrap"
  echo "   # or: ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --vault-id vault@prompt"
  echo
  echo "5. Deploy gateway:"
  echo "   make deploy"
  echo "   # or: ansible-playbook -i inventory/hosts.yml playbooks/deploy_gateway.yml --vault-id vault@prompt"
  echo
  echo "6. Access dashboards:"
  echo "   Pi-hole     : http://pihole.internal/admin"
  echo "   Traefik     : http://traefik.internal:8080"
  echo "   Grafana     : http://grafana.internal  (full mode only)"
  echo "   Portainer   : http://portainer.internal (full mode only)"
  echo "   Uptime Kuma : http://uptime.internal    (full mode only)"
  echo "   Status API  : http://pi-gateway.internal:5000"
  echo
  warn "Tailscale admin console steps (after deploy):"
  echo "  a) Approve subnet route: ${LAN_SUBNET}"
  echo "  b) Enable 'Use as exit node' for ${TS_HOSTNAME:-pi-gateway}"
  echo
  echo "  Note: If using native Tailscale mode, the admin console approval"
  echo "  is still required for subnet routes and exit node."
  echo
  ok "Setup wizard complete. Log saved to $LOGFILE"
}

main() {
  require_root
  intro
  check_os
  deployment_mode_ui
  network_config
  tailscale_config
  dns_config
  install_ansible
  write_ansible_vars
  write_ansible_vault
  generate_inventory
  bootstrap_instructions
}

main "$@"
