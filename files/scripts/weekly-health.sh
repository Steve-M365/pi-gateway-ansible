#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/pi-gateway/weekly-health.log"

log() {
  echo "[$(date +%Y-%m-%dT%H:%M:%S)] $*" | tee -a "$LOG_FILE"
}

check_failed_services() {
  log "Checking for failed systemd services..."
  local failed
  failed=$(systemctl --failed --no-legend | wc -l || echo 0)
  if [[ "$failed" -gt 0 ]]; then
    log "[ALERT] $failed failed systemd services:"
    systemctl --failed --no-legend | tee -a "$LOG_FILE" || true
  else
    log "[OK] No failed systemd services"
  fi
}

check_docker_disk() {
  log "Checking Docker disk usage..."
  docker system df | tee -a "$LOG_FILE" || true
}

check_filesystem() {
  log "Checking filesystem usage..."
  df -h | tee -a "$LOG_FILE" || true
}

generate_summary() {
  log "=== Weekly Health Summary ==="
  log "Host: $(hostname)"
  log "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  log "Uptime: $(uptime -p)"
  log "Load: $(uptime | awk -F'load average:' '{print $2}')"
  log "Memory: $(free -h | awk 'NR==2{print $3\"/\"$2}')"
  log "Disk: $(df -h / | awk 'NR==2{print $5\" used of \"$2}')"
  log "Temperature: $(vcgencmd measure_temp 2>/dev/null || echo 'N/A')"
  log "Docker containers: $(docker ps --format '{{.Names}}' 2>/dev/null | wc -l) running"
  log "========================"
}

log "=== Starting weekly health check ==="
check_failed_services
check_docker_disk
check_filesystem
generate_summary
log "=== Weekly health check complete ==="
