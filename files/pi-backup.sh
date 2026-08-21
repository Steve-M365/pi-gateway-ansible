#!/usr/bin/env bash
set -euo pipefail

# pi-backup.sh - Backup Pi gateway config and push to GitHub
# Designed for cron: 0 3 * * * /opt/pi-gateway-ansible/files/pi-backup.sh

BACKUP_DIR="/opt/pi-gateway"
BACKUP_NAME="pi-gateway-backup"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TEMP_DIR="/tmp/${BACKUP_NAME}-${TIMESTAMP}"
REPO_DIR="/opt/pi-gateway-ansible"

# GitHub settings (override via env or config file)
GITHUB_BACKUP_REPO="${GITHUB_BACKUP_REPO:-Steve-M365/pi-gateway-backups}"
GITHUB_TOKEN_FILE="${GITHUB_TOKEN_FILE:-/etc/pi-gateway/github-token}"

log() {
  echo "[$(date +%Y-%m-%dT%H:%M:%S)] $*"
}

check_dependencies() {
  if ! command -v gh &>/dev/null; then
    log "ERROR: gh CLI not found. Install with: sudo apt install gh"
    exit 1
  fi
}

read_github_token() {
  if [[ -f "$GITHUB_TOKEN_FILE" ]]; then
    GITHUB_TOKEN=$(cat "$GITHUB_TOKEN_FILE")
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    : # use env var
  else
    log "ERROR: GitHub token not found. Set GITHUB_TOKEN_FILE or GITHUB_TOKEN env var."
    exit 1
  fi
}

create_backup() {
  log "Creating backup..."
  mkdir -p "$TEMP_DIR"

  # Docker volumes
  log "  Backing up Docker volumes..."
  tar -czf "${TEMP_DIR}/docker-volumes.tar.gz" \
    -C "$BACKUP_DIR" \
    pihole/etc \
    pihole/etc-dnsmasq.d \
    traefik/data \
    traefik/certs \
    tailscale/state \
    grafana/data \
    prometheus/data \
    uptime/data \
    smokeping/data 2>/dev/null || true

  # Ansible config
  log "  Backing up Ansible config..."
  tar -czf "${TEMP_DIR}/ansible-config.tar.gz" \
    -C "$REPO_DIR" \
    inventory \
    group_vars \
    host_vars \
    roles \
    playbooks \
    files \
    ansible.cfg \
    setup.sh \
    Makefile \
    README.md 2>/dev/null || true

  # System config
  log "  Backing up system config..."
  tar -czf "${TEMP_DIR}/system-config.tar.gz" \
    /etc/network/interfaces \
    /etc/network/interfaces.d \
    /etc/sysctl.d/99-gateway.conf \
    /etc/iptables/rules.v4 \
    /etc/ssh/sshd_config \
    /etc/ufw \
    /etc/fail2ban \
    /etc/hostname \
    /etc/hosts 2>/dev/null || true

  # Status report
  log "  Generating status report..."
  if [[ -f "$REPO_DIR/playbooks/review_gateway.yml" ]]; then
    cd "$REPO_DIR"
    ansible-playbook -i inventory/hosts.yml playbooks/review_gateway.yml \
      --connection=local \
      --vault-id vault@prompt \
      > "${TEMP_DIR}/ansible-review.log" 2>&1 || true
  fi

  # Create manifest
  cat > "${TEMP_DIR}/backup-manifest.txt" <<EOF
Pi Gateway Backup
=================
Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Host: $(hostname)
Pi4 backup created by pi-backup.sh

Contents:
  - docker-volumes.tar.gz  (Docker persistent data)
  - ansible-config.tar.gz  (Ansible playbooks and configs)
  - system-config.tar.gz   (Network, SSH, firewall configs)
  - ansible-review.log     (Ansible review output)
  - backup-manifest.txt    (This file)

Restore:
  1. Extract tarballs
  2. Run bootstrap playbook
  3. Run deploy playbook
  4. Restore Docker volumes if needed
EOF

  # Final combined tarball
  cd /tmp
  tar -czf "${BACKUP_NAME}-${TIMESTAMP}.tar.gz" \
    -C "$TEMP_DIR" .

  log "Backup created: ${BACKUP_NAME}-${TIMESTAMP}.tar.gz"
  echo "$TEMP_DIR/${BACKUP_NAME}-${TIMESTAMP}.tar.gz"
}

push_to_github() {
  local backup_file="$1"
  local size=$(du -h "$backup_file" | cut -f1)

  log "Pushing to GitHub..."
  log "  Repo: $GITHUB_BACKUP_REPO"
  log "  File: $backup_file ($size)"

  # Use gh CLI to create a release and upload asset
  # Tag name based on date
  local tag_name="backup-${TIMESTAMP}"

  cd "$REPO_DIR"

  # Configure git user for commits
  git config user.email "pi-gateway@local"
  git config user.name "Pi Gateway Backup"

  # Create backup branch if it doesn't exist
  if ! git ls-remote --heads origin backup-main &>/dev/null; then
    log "  Creating backup branch..."
    git checkout --orphan backup-main
    git rm -rf . 2>/dev/null || true
    echo "# Pi Gateway Backups" > README.md
    echo "Automated backups from Pi gateway." >> README.md
    git add README.md
    git commit -m "Initial backup branch"
    git push origin backup-main
    git checkout main
  fi

  # Create backup commit
  # We copy the backup to the repo directory as an artifact
  local backup_dir="${REPO_DIR}/backups"
  mkdir -p "$backup_dir"

  # Copy tarball
  cp "$backup_file" "${backup_dir}/backup-${TIMESTAMP}.tar.gz"

  # Copy manifest
  cp "${TEMP_DIR}/backup-manifest.txt" "${backup_dir}/backup-${TIMESTAMP}-manifest.txt"

  # Git operations
  git add "backups/backup-${TIMESTAMP}.tar.gz" "backups/backup-${TIMESTAMP}-manifest.txt"
  git commit -m "Backup ${TIMESTAMP}: Pi gateway state backup

- Docker volumes
- Ansible config
- System config
- Status report

Size: ${size}"

  # Push backup branch
  git push origin backup-main || {
    log "ERROR: Failed to push to GitHub. Check token and network."
    return 1
  }

  # Create a lightweight tag for this backup
  git tag -f "backup-${TIMESTAMP}" || true
  git push origin "backup-${TIMESTAMP}" --force || true

  log "Successfully pushed backup to GitHub"
}

cleanup() {
  log "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
  rm -f "/tmp/${BACKUP_NAME}-"*.tar.gz
}

main() {
  log "=== Pi Gateway Backup to GitHub ==="

  check_dependencies
  read_github_token

  local backup_file
  backup_file=$(create_backup)

  if push_to_ithub "$backup_file"; then
    log "Backup complete!"
  else
    log "WARNING: Backup created but GitHub push failed"
  fi

  cleanup
  log "=== Backup finished ==="
}

main "$@"
