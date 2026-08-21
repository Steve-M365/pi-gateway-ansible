#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/pi-gateway/self-heal.log"
HEALED=0

log() {
  echo "[$(date +%Y-%m-%dT%H:%M:%S)] $*" | tee -a "$LOG_FILE"
}

restart_failed_containers() {
  if ! command -v docker >/dev/null 2>&1; then
    return
  fi
  local failed
  failed=$(docker ps -a --filter "status=exited" --format "{{.Names}}" | grep -v "^$" || true)

  if [[ -n "$failed" ]]; then
    for container in $failed; do
      if [[ "$container" == "watchtower" ]]; then
        continue
      fi
      log "Healing: restarting container $container"
      docker restart "$container" || log "ERROR: Failed to restart $container"
      HEALED=$((HEALED + 1))
    done
  fi
}

check_disk_space() {
  local usage
  usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')

  if [[ "$usage" -gt 90 ]]; then
    log "[ALERT] Disk usage critical: ${usage}%"
    log "Healing: pruning Docker resources..."
    docker system prune -f --filter "until=24h" >/dev/null 2>&1 || true
    docker volume prune -f >/dev/null 2>&1 || true
    find /var/log/pi-gateway -name "*.log" -mtime +7 -delete >/dev/null 2>&1 || true
    HEALED=$((HEALED + 1))
  elif [[ "$usage" -gt 80 ]]; then
    log "[WARN] Disk usage high: ${usage}%"
  fi
}

check_memory() {
  local free_mem
  free_mem=$(free -m | awk 'NR==2{print $4}')

  if [[ "$free_mem" -lt 100 ]]; then
    log "[ALERT] Low memory: ${free_mem}MB free"
    for container in prometheus grafana; do
      if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        log "Healing: restarting $container to free memory"
        docker restart "$container" || true
        HEALED=$((HEALED + 1))
        sleep 5
      fi
    done
  fi
}

check_temperature() {
  if ! command -v vcgencmd >/dev/null 2>&1; then
    return
  fi
  local temp
  temp=$(vcgencmd measure_temp | cut -d'=' -f2 | cut -d"'" -f1 | cut -d'.' -f1)

  if [[ "$temp" -gt 80 ]]; then
    log "[ALERT] CPU temperature critical: ${temp}°C"
    HEALED=$((HEALED + 1))
  elif [[ "$temp" -gt 70 ]]; then
    log "[WARN] CPU temperature high: ${temp}°C"
  fi
}

check_dns() {
  if ! docker ps --format "{{.Names}}" | grep -q "^pihole$"; then
    return
  fi
  if ! docker exec pihole dig @127.0.0.1 google.com +short +timeout=2 >/dev/null 2>&1; then
    log "[ALERT] Pi-hole DNS not responding"
    log "Healing: restarting Pi-hole container..."
    docker restart pihole || true
    HEALED=$((HEALED + 1))
  fi
}

check_network() {
  if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    log "[ALERT] WAN connectivity lost"
    if command -v dhclient >/dev/null 2>&1; then
      log "Healing: renewing DHCP on eth0..."
      dhclient -r eth0 || true
      dhclient eth0 || true
      HEALED=$((HEALED + 1))
    fi
  fi
}

check_tailscale() {
  if ! docker ps --format "{{.Names}}" | grep -q "^tailscale$"; then
    return
  fi
  if ! docker exec tailscale tailscale status >/dev/null 2>&1; then
    log "[ALERT] Tailscale container not responding"
    log "Healing: restarting Tailscale..."
    docker restart tailscale || true
    HEALED=$((HEALED + 1))
  fi
}

log "=== Starting self-healing checks ==="
restart_failed_containers
check_disk_space
check_memory
check_temperature
check_dns
check_network
check_tailscale

if [[ "$HEALED" -gt 0 ]]; then
  log "=== Self-healing complete. Actions taken: $HEALED ==="
else
  log "=== Self-healing complete. No issues found. ==="
fi
