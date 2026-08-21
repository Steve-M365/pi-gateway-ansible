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
| Sun 06:00 | Weekly deep health | Weekly |
| 01 07:00 | fstrim | Monthly |

**Preferred behaviour:** keep cron focused on light, safe operations. Use these for non-emergency automation only. This schedule is intentionally conservative for a Pi4: backup and prune at night, network checks before typical use windows, and a factual weekly summary rather than disruptive changes.

## Maintenance Logs

Logs are collected under `/var/log/pi-gateway/` and `/opt/pi-gateway-ansible/logs/`.

Key logs:
- `backup.log`
- `self-heal.log`
- `optimize.log`
- `weekly-health.log`
- `network-check.log`
- `log-check.log`
- `docker-cleanup.log`

## Centralised Logging (Loki + syslog-ng)

If you want a Graylog-like experience without the JVM overhead, this gateway can ship logs to Loki.

What this adds:
- syslog-ng: receives UDP/TCP syslog on `{{ syslog_listen_port | default(514) }}`
- Loki: stores logs with retention controlled by `loki_retention_period`
- Grafana Explore: query logs without a separate UI
- Promtail: scrapes Docker container logs and ships them to Loki

Access:
- Grafana: `http://grafana.internal`
- Loki HTTP API: `http://loki.internal:3100`
- syslog-ng receiver: `udp://{{ lan_ip }}:514`

Prerequisites:
- Set `enable_syslog_server: true` in `group_vars/all.yml`
- Deploy with `make deploy`
- If `syslog-ng` needs port 514, ensure nothing else is bound

From another device:
- Point your syslog source at `{{ lan_ip }}:514` over UDP/TCP
- In Grafana, add Loki as a data source if it is not already present

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

### Syslog not receiving
1. Check `docker logs syslog-ng`
2. Verify port `514` is free and reachable
3. Verify `syslog-ng.conf` rendered correctly under `/opt/pi-gateway/syslog-ng/config`

---

For safe remote management, see `docs/ansible-control-node.md`.
