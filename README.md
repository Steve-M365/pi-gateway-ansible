# 🥧 Raspberry Pi Gateway

**A reproducible, Ansible-driven, Docker-based home network gateway for Raspberry Pi 4.**

![Status](https://img.shields.io/badge/status-production-green)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## 🎯 What This Does

Your Raspberry Pi 4 becomes your home network's **central nervous system**:

| Service | Purpose | Access |
|---------|---------|--------|
| **Pi-hole** | DNS + ad blocking | `http://pihole.internal/admin` |
| **Traefik** | Reverse proxy + TLS | `http://traefik.internal:8080` |
| **Grafana** | Metrics dashboards | `http://grafana.internal` (full mode) |
| **Prometheus** | Time-series metrics | `http://prometheus.internal` (full mode) |
| **Smokeping** | Latency monitoring | `http://smokeping.internal` (full mode) |
| **Uptime Kuma** | Uptime monitoring | `http://uptime.internal` (full mode) |
| **Tailscale** | VPN exit node | Tailnet |
| **Portainer** | Container management | `http://portainer.internal` (full mode) |
| **Watchtower** | Auto-updates | Background |
| **Status Dashboard** | Gateway health | `http://pi-gateway.internal:5000` |

---

## ⚡ Quick Commands (Makefile)

```bash
make bootstrap   # Run bootstrap playbook
make deploy      # Deploy full gateway
make update      # Update all containers
make review      # Generate status report
make status      # Quick container status
make logs        # Tail all container logs
make shell       # Shell into a container
make backup      # Backup volumes
make help        # Show all commands
```

---

## 🚀 Quick Start (3 Commands)

```bash
# 1. Flash Raspberry Pi OS Lite (64-bit) to SD card
#    Before first boot: touch /boot/ssh

# 2. Boot Pi, connect eth0 to modem, eth1 to LAN switch

# 3. Run setup wizard (on the Pi itself)
curl -fsSL https://raw.githubusercontent.com/yourusername/pi-gateway-ansible/main/setup.sh | sudo bash

# 4. On your control machine:
cd pi-gateway-ansible
ansible-playbook playbooks/bootstrap.yml --vault-id vault@prompt
ansible-playbook playbooks/deploy_gateway.yml --vault-id vault@prompt
```

**That's it.** The wizard handles everything.

---

## 📋 What the Wizard Does

The interactive `setup.sh` script:

1. ✅ Detects your network interfaces (eth0, eth1)
2. ✅ Configures LAN subnet and gateway IP
3. ✅ Sets up Tailscale (exit node + subnet router)
4. ✅ Configures Pi-hole (DNS + upstream)
5. ✅ Generates Ansible variables and inventory
6. ✅ Creates encrypted Ansible Vault
7. ✅ Provides step-by-step next steps

**No manual config needed.** Just answer the prompts.

---

## 🛠️ Repair / Rebuild Workflow

If your Pi breaks or you want to rebuild from scratch:

```bash
# 1. Flash fresh Raspberry Pi OS
# 2. Boot and enable SSH
# 3. Run setup wizard
curl -fsSL https://raw.githubusercontent.com/yourusername/pi-gateway-ansible/main/setup.sh | sudo bash

# 4. On control machine, re-run playbooks
cd pi-gateway-ansible
ansible-playbook playbooks/bootstrap.yml --vault-id vault@prompt
ansible-playbook playbooks/deploy_gateway.yml --vault-id vault@prompt
```

**Everything is reproducible.** One script rebuilds the entire gateway.

---

## 📊 Monitoring & Management

### Web Dashboards

| URL | Service | Purpose |
|-----|---------|---------|
| `http://pihole.internal/admin` | Pi-hole | DNS queries, blocklists, stats |
| `http://grafana.internal` | Grafana | Network traffic, CPU, memory, containers |
| `http://traefik.internal:8080` | Traefik | Router status, health checks |
| `http://smokeping.internal` | Smokeping | Latency graphs (Google, Cloudflare, etc.) |
| `http://uptime.internal` | Uptime Kuma | Service uptime, alerts |
| `http://portainer.internal` | Portainer | Container logs, exec, management |

### Status Page

Generate a human-readable status report:

```bash
ansible-playbook playbooks/review_gateway.yml --vault-id vault@prompt
```

Or view live status via the bundled status dashboard:

```bash
# Open in browser (served by the Pi)
http://pi-gateway.internal:5000
```

---

## 🔄 Update Workflow

Update all containers safely:

```bash
ansible-playbook playbooks/update_gateway.yml --vault-id vault@prompt
```

This will:
1. Pull latest images
2. Recreate containers with zero downtime (where possible)
3. Prune old images
4. Report status

**Set it and forget it:** Watchtower auto-updates containers daily at 4 AM.

---

## 🔐 Security

### Defaults
- ✅ SSH key-only authentication (no passwords)
- ✅ Fail2ban enabled
- ✅ UFW firewall (deny all, allow LAN only)
- ✅ Tailscale exit node (VPN-protected remote access)
- ✅ Ansible Vault for secrets

### Manual Steps Required
After first deploy, complete these in the **Tailscale admin console**:

1. **Approve subnet route**: `192.168.10.0/24` (or your LAN subnet)
2. **Enable exit node**: Toggle "Use as exit node" for `pi-gateway`
3. **On clients**: `tailscale up --exit-node=pi-gateway`

---

## 📁 Directory Structure

```
pi-gateway-ansible/
├── setup.sh                          # Interactive setup wizard
├── README.md                         # This file
├── Makefile                          # Quick commands
├── ansible.cfg                       # Ansible config
├── .gitignore
├── requirements.yml                  # Galaxy collections
├── inventory/
│   └── hosts.yml                     # Pi inventory
├── group_vars/
│   └── all.yml                       # All variables
├── host_vars/
│   └── pi-gateway.yml                # Pi-specific vars
├── roles/
│   ├── base_os/                      # OS packages, swap, timezone
│   ├── networking/                   # IP forwarding, NAT
│   ├── docker_engine/                # Docker installation
│   ├── docker_compose_services/      # All Docker services
│   ├── tailscale/                    # Tailscale exit node
│   ├── security_hardening/           # SSH, fail2ban, ufw
│   ├── ansible_self_install/         # Ansible on the Pi
│   └── status_dashboard/             # Flask status API + UI
├── playbooks/
│   ├── bootstrap.yml                 # Initial setup (run once)
│   ├── deploy_gateway.yml            # Full deployment (idempotent)
│   ├── update_gateway.yml            # Update containers
│   └── review_gateway.yml            # Status report
└── files/
    ├── prometheus.yml                 # Prometheus config (full mode)
    ├── status-api.py                 # Flask API
    └── status-dashboard.html         # Web dashboard
```

---

## 🎨 Design Principles

### Usability First
- **One script to rule them all**: `setup.sh` handles everything
- **Color-coded output**: Clear status messages
- **Interactive prompts**: No manual config file editing
- **Guided workflows**: Clear next steps after each phase

### Safety
- **Idempotent**: Re-running playbooks is safe
- **Reversible**: Flash OS, re-run, done
- **Logged**: All actions logged to `/var/log/pi-gateway-setup.log`
- **Vault-encrypted**: Secrets never in plaintext

### Observability
- **Status dashboard**: Quick overview of all services
- **Grafana dashboards**: Deep metrics (full mode)
- **Uptime Kuma**: Alerting (full mode)
- **Review playbook**: Generate detailed reports

---

## 🆘 Troubleshooting

### "I locked myself out of SSH"
1. Connect monitor + keyboard to Pi
2. Run: `sudo ufw disable`
3. Fix SSH config, then: `sudo ufw enable`

### "Pi has no network"
1. Check cables: eth0 -> modem, eth1 -> LAN switch
2. Verify interfaces: `ip a`
3. Re-run networking role: `make deploy -t networking`

### "Containers won't start"
1. Check logs: `docker logs <container-name>`
2. Or use Portainer: `http://portainer.internal`
3. Re-deploy: `make deploy`

### "Tailscale not working"
1. Check container: `docker logs tailscale`
2. Verify admin console: Approve routes + enable exit node
3. Re-run tailscale role: `make deploy -t tailscale`

### "Pi-hole not resolving"
1. Check container: `docker logs pihole`
2. Verify DNS on client: `cat /etc/resolv.conf`
3. Restart Pi-hole: `docker restart pihole`

---

## 📖 Detailed Documentation

### Prerequisites
- Raspberry Pi 4 (2GB+ RAM recommended)
- Raspberry Pi OS Lite (64-bit)
- Two Ethernet cables
- Modem + LAN switch
- Control machine (laptop/desktop) with Ansible installed

### Network Diagram

```
                    ┌─────────────────────────┐
                    │   INTERNET (WAN)        │
                    └───────────┬─────────────┘
                                │ eth0
                    ┌───────────▼─────────────┐
                    │   RASPBERRY PI GATEWAY  │
                    │  ┌───────────────────┐  │
                    │  │  IP Forwarding    │  │
                    │  │  NAT / Masquerade │  │
                    │  └───────────────────┘  │
                    │  ┌───────────────────┐  │
                    │  │  Docker Engine    │  │
                    │  │  ┌─────────────┐  │  │
                    │  │  │  Pi-hole    │  │  │
                    │  │  │  (DNS)      │  │  │
                    │  │  └─────────────┘  │  │
                    │  │  ┌─────────────┐  │  │
                    │  │  │  Traefik    │  │  │
                    │  │  │  (Proxy)    │  │  │
                    │  │  └─────────────┘  │  │
                    │  │  ┌─────────────┐  │  │
                    │  │  │  Tailscale  │  │  │
                    │  │  │  (VPN)      │  │  │
                    │  │  └─────────────┘  │  │
                    │  └───────────────────┘  │
                    └───────────┬─────────────┘
                                │ eth1
                    ┌───────────▼─────────────┐
                    │   INTERNAL LAN          │
                    │  192.168.10.0/24        │
                    │  ┌─────────────────┐    │
                    │  │  Your Devices   │    │
                    │  │  (phones, PCs)  │    │
                    │  └─────────────────┘    │
                    └─────────────────────────┘
```

### Tailscale Flow

```
Your laptop (tailnet)
       │
       │ Tailscale encrypted tunnel
       │
       ▼
┌───────────────────┐
│  Tailscale        │
│  Container        │
│  (exit node)      │
└────────┬──────────┘
         │
         │ Host network (eth0)
         │
         ▼
    Internet (WAN)
```

---

## 🎓 Advanced Usage

### Running Playbooks Locally on Pi

After bootstrap, you can SSH into the Pi and run playbooks locally:

```bash
ssh pi@192.168.10.1
cd /opt/pi-gateway-ansible
ansible-playbook playbooks/deploy_gateway.yml -i inventory/hosts.yml --connection=local
```

### Customizing Services

Edit `group_vars/all.yml`:

```yaml
# Add more Smokeping targets
smokeping_targets:
  - name: NAS
    host: 192.168.10.50

# Change upstream DNS
pihole_upstream_dns: "1.1.1.1,8.8.8.8"

# Add more domain names
domain_suffix: ".internal"
traefik_additional_routes:
  - "homeassistant.internal"
  - "plex.internal"
```

Then re-run: `make deploy`

### Backing Up

```bash
# Backup Docker volumes
tar -czf pi-gateway-backup-$(date +%Y%m%d).tar.gz   /opt/pi-gateway/pihole/etc   /opt/pi-gateway/grafana/data   /opt/pi-gateway/prometheus/data   /opt/pi-gateway/uptime/data

# Backup Ansible config
git archive --format=tar.gz -o pi-gateway-ansible-backup-$(date +%Y%m%d).tar.gz HEAD
```

---

## 📝 License

MIT - feel free to fork, modify, and use.

## 🤝 Contributing

Issues and PRs welcome. This is a personal project, but improvements benefit everyone.

---

**Built with ❤️ for the homelab community.**

**Last updated:** 2026-08-21
