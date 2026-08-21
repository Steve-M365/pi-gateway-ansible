# Getting Started Guide

## Prerequisites

- Raspberry Pi 4 (2GB+ RAM)
- Raspberry Pi OS Lite (64-bit) - download from [raspberrypi.com](https://www.raspberrypi.com/software/)
- Two Ethernet cables
- MicroSD card (32GB+ recommended, high-endurance)
- USB-C power supply (official or 3A+ certified)
- Modem + LAN switch
- Control machine (laptop/desktop) with:
  - Git
  - Ansible 2.9+
  - SSH client

## Step 1: Flash Raspberry Pi OS

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Select:
   - OS: **Raspberry Pi OS Lite (64-bit)**
   - Storage: Your microSD card
3. Click the gear icon (advanced settings) and:
   - Enable SSH
   - Set username: `pi`
   - Set password: `<your-strong-password>`
   - Configure wireless LAN (optional, but this guide is wired-only)
4. Flash and eject

## Step 2: First Boot and Network Setup

1. Insert microSD card into Pi
2. Connect cables:
   - USB-C power
   - `eth0` → modem/upstream router
   - `eth1` → LAN switch
3. Boot Pi and find its IP:
   ```bash
   # Check your router's DHCP client list
   # Or use nmap:
   nmap -sn 192.168.1.0/24
   ```
4. Test SSH:
   ```bash
   ssh pi@<pi-ip-address>
   ```

## Step 3: Clone the Repository

On your control machine:
```bash
git clone https://github.com/Steve-M365/pi-gateway-ansible.git
cd pi-gateway-ansible
```

## Step 4: Configure Variables

Edit `group_vars/all.yml`:
```yaml
# Network
lan_interface: "eth1"
wan_interface: "eth0"
lan_subnet: "192.168.10.0/24"
lan_ip: "192.168.10.1"
lan_cidr: "24"

# Services
pihole_password: "your-strong-password"
pihole_upstream_dns: "1.1.1.1"
domain_suffix: ".internal"

# Tailscale
tailscale_auth_key: "tskey-auth-XXXX"
tailscale_hostname: "pi-gateway"
tailscale_advertise_routes: "192.168.10.0/24"

# Deployment mode: minimal | full
deployment_mode: "minimal"

# Pi4 optimizations
enable_swap: true
```

**Important:** Move secrets to Ansible Vault:
```bash
ansible-vault create group_vars/vault.yml
# Add:
vault_pihole_password: "your-strong-password"
vault_tailscale_auth_key: "tskey-auth-XXXX"
```

Update `group_vars/all.yml` to reference vault:
```yaml
pihole_password: "{{ vault_pihole_password }}"
tailscale_auth_key: "{{ vault_tailscale_auth_key }}"
```

## Step 5: Run Bootstrap Playbook

```bash
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --vault-id vault@prompt
```

This will:
1. Install base OS packages (no recommends)
2. Configure 2GB swap
3. Set timezone and hostname
4. Harden SSH (key-only, no root login)
5. Enable fail2ban
6. Configure UFW firewall
7. Install Docker Engine + Compose plugin
8. Install Ansible on the Pi itself

## Step 6: Deploy Gateway

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy_gateway.yml --vault-id vault@prompt
```

This will:
1. Configure networking (IP forwarding, NAT, sysctl)
2. Deploy Tailscale (native or container)
3. Deploy all Docker services via Compose
4. Set up status dashboard

## Step 7: Complete Tailscale Setup

After the playbook completes:

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/machines)
2. Find `pi-gateway` in the device list
3. Click "Edit route settings"
4. Approve subnet route: `192.168.10.0/24`
5. Enable "Use as exit node"

## Step 8: Configure Clients

On your devices:
1. Set DNS to `192.168.10.1` (Pi-hole)
2. Set gateway to `192.168.10.1`
3. For Tailscale exit node:
   ```bash
   tailscale up --exit-node=pi-gateway
   ```

## Step 9: Access Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Pi-hole | http://pihole.internal/admin | `admin` + your `pihole_password` |
| Traefik | http://traefik.internal:8080 | None (dashboard) |
| Grafana | http://grafana.internal | `admin` + your `pihole_password` (full mode) |
| Uptime Kuma | http://uptime.internal | Create account on first visit (full mode) |
| Portainer | http://portainer.internal | Create admin account on first visit (full mode) |
| Status API | http://pi-gateway.internal:5000 | None |

**Note:** `*.internal` domains resolve via Pi-hole DNS. Ensure your clients use Pi-hole as their DNS server.
