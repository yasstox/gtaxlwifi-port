#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"

log "USB/ADB"
adb_cmd devices -l || true

if [[ -n "${GTAXL_SSH_USER:-}" && -n "${GTAXL_SSH_HOST:-}" ]]; then
  log "SSH $GTAXL_SSH_USER@$GTAXL_SSH_HOST"
  if ssh_reachable; then
    echo "TCP/22 reachable"
    remote_cmd 'uname -a; echo; cat /etc/os-release | head -8' || true
  else
    echo "SSH port not reachable"
  fi
else
  log "SSH"
  echo "GTAXL_SSH_USER / GTAXL_SSH_HOST are not configured in .env"
fi
