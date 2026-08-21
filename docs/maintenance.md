# System Maintenance

## Automated Maintenance Schedule

The Pi gateway runs a set of cron jobs for hands-off upkeep.

| Time | Task | Frequency |
|------|------|-----------|
| 03:00 | Backup to GitHub | Daily |
| 03:30 | Docker cleanup | Daily |
| 04:30 | Log check | Daily |
| 05:00 | Self-healing checks | Daily |
| 05:30 | System optimization | Daily |
| 06:00 | DNS flush | Daily |
| 06:30 | Network connectivity check | Daily |
| Sun 06:00 | Weekly deep health check | Weekly |
| 01 07:00 | fstrim | Monthly |

**Preferred behaviour:** keep cron focused on light, safe operations. Use these for non-emergency automation only. This schedule is intentionally conservative for a Pi4: backup and prune at night, network checks before typical use windows, and a factual weekly summary rather than disruptive changes.

## Maintenance Logs

Logs are collected under `/var/log/pi-gateway/`:
- `/var/log/pi-gateway/backup.log`
- `/var/log/pi-gateway/self-heal.log`
- `/var/log/pi-gateway/optimize.log`
- `/var/log/pi-gateway/weekly-health.log`
- `/var/log/pi-gateway/network-check.log`
- `/var/log/pi-gateway/log-check.log`
- `/var/log/pi-gateway/docker-cleanup.log`

## Update Strategy

To keep the gateway stable:
- Docker containers are updated through the existing `update_gateway.yml` playbook.
- OS package updates are not enforced by cron automatically, because reboots and partial upgrades are more disruptive on a gateway. Apply them intentionally from the control machine or during a maintenance window.
- Security updates can be reviewed manually before installing.

## Alerting

Current automation is alert-through-log only. If you want delivery, route outputs from:
- `/var/log/pi-gateway/weekly-health.log`
- `/var/log/pi-gateway/self-heal.log`

to one of the existing internal services such as Uptime Kuma, rather than adding new inbound alerting paths.

## Runbooks

### Backup failed
1. Check `/var/log/pi-gateway/backup.log`
2. Verify GitHub token and network
3. Retry with `/opt/pi-gateway-ansible/files/pi-backup.sh`

### Self-heal triggered
1. Check `/var/log/pi-gateway/self-heal.log`
2. Use the status dashboard or `make status`
3. Treat repeated heal actions as a signal to investigate root cause manually

### Disk high
1. Review `/var/log/pi-gateway/self-heal.log`
2. Use Portainer or `docker system df`
3. Prune via `make clean` or `make update`

### DNS issues
1. Check `/var/log/pi-gateway/network-check.log`
2. Inspect `docker logs pihole`
3. Review `/var/log/pi-gateway/dns-flush.log`

---

For safe remote management, see `docs/ansible-control-node.md`.
