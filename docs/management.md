# Management Guide

## Using Make Commands

The Makefile provides shortcuts for common operations:

```bash
make bootstrap   # Run bootstrap playbook
make deploy      # Deploy full gateway
make update      # Update all containers
make review      # Generate status report
make status      # Quick container status
make logs        # Tail all container logs
make restart     # Restart all services
make shell       # Shell into a container (CONTAINER=name)
make backup      # Backup Docker volumes
make help        # Show all commands
```

## Using Ansible Directly

If you prefer Ansible CLI over Make:

```bash
# Bootstrap
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --vault-id vault@prompt

# Deploy/repair
ansible-playbook -i inventory/hosts.yml playbooks/deploy_gateway.yml --vault-id vault@prompt

# Update containers
ansible-playbook -i inventory/hosts.yml playbooks/update_gateway.yml --vault-id vault@prompt

# Review state
ansible-playbook -i inventory/hosts.yml playbooks/review_gateway.yml --vault-id vault@prompt
```

## Running Playbooks Locally on the Pi

After bootstrap, you can SSH into the Pi and run playbooks locally:

```bash
ssh pi@192.168.10.1
cd /opt/pi-gateway-ansible
ansible-playbook playbooks/deploy_gateway.yml -i inventory/hosts.yml --connection=local --vault-id vault@prompt
```

**Benefit:** No network dependency - run changes directly on the Pi even if networking is broken.

## Adding New Services

1. Edit `roles/docker_compose_services/templates/docker-compose.yml.j2`
2. Add service definition with resource limits
3. Add Traefik labels if you want reverse proxy access
4. Run `make deploy`

## Changing Network Settings

Edit `group_vars/all.yml`:
```yaml
lan_subnet: "192.168.20.0/24"
lan_ip: "192.168.20.1"
lan_interface: "eth1"
wan_interface: "eth0"
```

Then run:
```bash
make deploy
```

**Warning:** Changing network settings may disrupt connectivity. Have console access ready.

## Updating the Pi Itself

The Pi OS is not automatically updated. To update:

```bash
# Via Ansible (if you added the update role)
ansible-playbook -i inventory/hosts.yml playbooks/update_os.yml --vault-id vault@prompt

# Or manually on the Pi
ssh pi@192.168.10.1
sudo apt update && sudo apt upgrade -y
sudo reboot
```

## Backing Up

### Manual Backup
```bash
make backup
# Creates: /tmp/pi-gateway-backup-YYYYMMDD.tar.gz
```

### Automated Backup (cron)
```bash
# On the Pi
crontab -e
# Add:
0 3 * * * /usr/bin/make -C /opt/pi-gateway-ansible backup >/dev/null 2>&1
```

### Restore
```bash
# On the Pi
cd /opt/pi-gateway
tar -xzf /tmp/pi-gateway-backup-YYYYMMDD.tar.gz
docker compose down
docker compose up -d
```

## Monitoring Health

### Status Dashboard
Visit: http://pi-gateway.internal:5000

### Ansible Review Playbook
```bash
make review
```

### Container Logs
```bash
make logs
# Or specific container:
docker logs pihole
docker logs tailscale
```

### System Metrics
```bash
# CPU temp
vcgencmd measure_temp

# Throttling status
vcgencmd get_throttled

# Disk usage
df -h

# Memory
free -h

# Container resource usage
docker stats
```

## Troubleshooting

### Pi Won't Boot
- Check power supply (needs 3A+)
- Check SD card (re-flash if corrupted)
- Connect monitor/keyboard for console access

### Can't SSH
- Check `ufw` status: `sudo ufw status`
- Check SSH service: `sudo systemctl status ssh`
- Check network: `ip a`

### Containers Won't Start
```bash
docker logs <container-name>
docker compose ps
docker compose down && docker compose up -d
```

### DNS Not Working
```bash
# Check Pi-hole
docker logs pihole

# Test DNS locally
dig @192.168.10.1 google.com

# Check iptables
sudo iptables -t nat -L POSTROUTING
```

### Tailscale Not Connecting
```bash
docker logs tailscale
tailscale status  # if native mode
```

Check Tailscale admin console for:
- Approved subnet routes
- Exit node enabled
- ACLs allowing traffic

### Low Memory / OOM
```bash
# Check what's using memory
free -h
docker stats

# Consider switching to minimal mode:
# Edit group_vars/all.yml: deployment_mode: "minimal"
make deploy
```

## Repair / Rebuild

If the Pi is broken or you want a clean rebuild:

1. Flash fresh Raspberry Pi OS
2. Enable SSH
3. Run setup wizard or bootstrap playbook
4. Run deploy playbook

```bash
# On control machine
cd pi-gateway-ansible
make bootstrap
make deploy
```

**Everything is reproducible from the Git repo.**
