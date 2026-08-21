#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/var/log/pi-gateway"
ALERT_THRESHOLD=100

check_log() {
  local logfile="$1"
  local service="$2"

  if [[ ! -f "$logfile" ]]; then
    return
  fi

  local errors
  errors=$(grep -cE "(ERROR|WARN|CRITICAL|FATAL)" "$logfile" 2>/dev/null || echo "0")

  if [[ "$errors" -gt "$ALERT_THRESHOLD" ]]; then
    echo "[ALERT] $service: $errors errors/warnings in last 24h (threshold: $ALERT_THRESHOLD)"
  elif [[ "$errors" -gt 0 ]]; then
    echo "[INFO] $service: $errors errors/warnings (within threshold)"
  fi
}

echo "[$(date +%Y-%m-%dT%H:%M:%S)] Starting log check"

check_log "$LOG_DIR/backup.log" "backup"
check_log "$LOG_DIR/docker-cleanup.log" "docker-cleanup"
check_log "$LOG_DIR/updates.log" "system-updates"
check_log "$LOG_DIR/self-heal.log" "self-heal"
check_log "$LOG_DIR/optimize.log" "optimize"
check_log "$LOG_DIR/dns-flush.log" "dns-flush"
check_log "$LOG_DIR/network-check.log" "network-check"

if command -v docker >/dev/null 2>&1; then
  docker ps --format "{{.Names}}" | while read -r container; do
    logfile="$LOG_DIR/containers/${container}.log"
    mkdir -p "$(dirname "$logfile")"
    docker logs --tail 100 "$container" 2>&1 | tee "$logfile" >/dev/null || true
    errors=$(grep -cE "(ERROR|WARN|CRITICAL|FATAL)" "$logfile" 2>/dev/null || echo "0")
    if [[ "$errors" -gt "$ALERT_THRESHOLD" ]]; then
      echo "[ALERT] container/$container: $errors errors/warnings"
    fi
  done
fi

failed_services=$(systemctl --failed --no-legend | wc -l || echo 0)
if [[ "$failed_services" -gt 0 ]]; then
  echo "[ALERT] systemd: $failed_services failed services"
  systemctl --failed --no-legend || true
fi

echo "[$(date +%Y-%m-%dT%H:%M:%S)] Log check complete"
