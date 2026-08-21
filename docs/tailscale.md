# Tailscale Configuration

## Architecture

This gateway supports two Tailscale modes:

### Native Mode (Recommended for Pi4)
- Tailscale runs directly on the Pi host
- Lower overhead, no container layer
- Better performance
- Simpler debugging

### Container Mode
- Tailscale runs in a Docker container
- Isolated from host
- Easier to manage via Docker Compose
- Slightly higher overhead

## Setup

### 1. Create Auth Key

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
2. Click "Generate auth key"
3. Set:
   - Expiry: 90 days (or as desired)
   - Reusable: Yes
   - Tags: `tag:server` (optional)
4. Copy the key (`tskey-auth-XXXX`)

### 2. Configure in Ansible

Edit `group_vars/all.yml`:
```yaml
tailscale_enabled: true
tailscale_auth_key: "{{ vault_tailscale_auth_key }}"
tailscale_hostname: "pi-gateway"
tailscale_advertise_routes: "192.168.10.0/24"
tailscale_accept_routes: "true"
tailscale_exit_node: "true"
tailscale_role: "native"  # or "container"
```

Or use the setup wizard:
```bash
curl -fsSL https://raw.githubusercontent.com/Steve-M365/pi-gateway-ansible/main/setup.sh | sudo bash
```

### 3. Deploy

```bash
make deploy
```

### 4. Approve in Admin Console

After deployment:
1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/machines)
2. Find `pi-gateway`
3. Click "Edit route settings"
4. Approve subnet route: `192.168.10.0/24`
5. Enable "Use as exit node"

## Using the Exit Node

On your laptop/phone:
```bash
tailscale up --exit-node=pi-gateway
```

To disable:
```bash
tailscale up --exit-node=disable
```

## Subnet Router

The Pi advertises your LAN (`192.168.10.0/24`) to your tailnet.

To access LAN devices from your tailnet:
```bash
# On your laptop
tailscale up --accept-dns=true --accept-routes=true
```

Then access Pi-hole: `http://pihole.internal/admin`

## Troubleshooting

### Can't connect to exit node
- Check Tailscale status: `tailscale status`
- Check admin console: exit node enabled?
- Check firewall: ports 41641/ UDP open?

### Subnet route not working
- Check admin console: subnet route approved?
- Check `tailscale status` for advertised routes
- Check `ip route` on Pi for Tailscale routes

### Container mode not working
- Check container logs: `docker logs tailscale`
- Check `/dev/net/tun` exists: `ls -l /dev/net/tun`
- Check capabilities: `docker inspect tailscale | grep -i cap`
