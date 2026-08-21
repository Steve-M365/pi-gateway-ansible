#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/pi-gateway/network-check.log"

log() {
  echo "[$(date +%Y-%m-%dT%H:%M:%S)] $*" | tee -a "$LOG_FILE"
}

check_wan() {
  if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    log "[OK] WAN connectivity: UP"
    return 0
  else
    log "[FAIL] WAN connectivity: DOWN"
    return 1
  fi
}

check_lan() {
  if ping -c 1 -W 2 192.168.10.1 >/dev/null 2>&1; then
    log "[OK] LAN gateway: reachable"
    return 0
  else
    log "[FAIL] LAN gateway: unreachable"
    return 1
  fi
}

check_dns() {
  if dig @192.168.10.1 google.com +short +timeout=2 >/dev/null 2>&1; then
    log "[OK] DNS resolution: working"
    return 0
  else
    log "[FAIL] DNS resolution: failing"
    return 1
  fi
}

check_tailscale() {
  if ! command -v tailscale >/dev/null 2>&1; then
    return
  fi
  if tailscale status >/dev/null 2>&1; then
    log "[OK] Tailscale: connected"
    if tailscale status | grep -q "exit node"; then
      log "[OK] Tailscale exit node: active"
    fi
  else
    log "[FAIL] Tailscale: not connected"
  fi
}

check_nat() {
  if iptables -t nat -L POSTROUTING -n | grep -q "MASQUERADE"; then
    log "[OK] NAT (MASQUERADE): configured"
  else
    log "[FAIL] NAT (MASQUERADE): not configured"
  fi
}

log "=== Starting network checks ==="
WAN_OK=0
LAN_OK=0
DNS_OK=0

check_wan || WAN_OK=1
check_lan || LAN_OK=1
check_dns || DNS_OK=1
check_tailscale
check_nat

if [[ $WAN_OK -eq 0 && $LAN_OK -eq 0 && $DNS_OK -eq 0 ]]; then
  log "=== All network checks passed ==="
else
  log "=== Some network checks failed ==="
fi
