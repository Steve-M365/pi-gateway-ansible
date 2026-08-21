#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/pi-gateway/optimize.log"

log() {
  echo "[$(date +%Y-%m-%dT%H:%M:%S)] $*" | tee -a "$LOG_FILE"
}

optimize_swap() {
  log "Optimizing swap..."
  sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
  sysctl -w vm.dirty_ratio=10 >/dev/null 2>&1 || true
  sysctl -w vm.dirty_background_ratio=5 >/dev/null 2>&1 || true
  log "Swap optimization applied (swappiness=10)"
}

optimize_cpu() {
  if [[ ! -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    return
  fi
  if command -v vcgencmd >/dev/null 2>&1; then
    local throttled
    throttled=$(vcgencmd get_throttled | cut -d'=' -f2)
    if [[ "$throttled" != "0x0" ]]; then
      log "CPU throttling detected, using ondemand governor"
      for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "ondemand" > "$cpu" 2>/dev/null || true
      done
    else
      log "No throttling detected, keeping current governor"
    fi
  fi
}

clear_dns_cache() {
  if docker ps --format "{{.Names}}" | grep -q "^pihole$"; then
    log "Flushing Pi-hole DNS cache..."
    docker exec pihole pihole-FTL -- flush >/dev/null 2>&1 || true
  fi
}

compact_docker() {
  log "Compacting Docker storage..."
  docker system prune -f --filter "until=168h" >/dev/null 2>&1 || true
  docker volume prune -f >/dev/null 2>&1 || true
}

log "=== Starting system optimization ==="
optimize_swap
optimize_cpu
clear_dns_cache
compact_docker
log "=== Optimization complete ==="
