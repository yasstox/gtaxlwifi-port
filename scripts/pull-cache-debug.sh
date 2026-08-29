#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"
require_not_root

LABEL="${1:-$(date +%Y%m%d-%H%M%S)}"
DEST="$GTAXL_ROOT/docs/debug/$LABEL"
mkdir -p "$DEST"

if ssh_reachable; then
  log "Linux detected; rebooting to recovery"
  if confirm "Reboot into TWRP to retrieve CACHE logs?"; then
    remote_sudo reboot recovery || warn "Automatic reboot failed. Enter TWRP manually."
  fi
fi

log "Waiting for recovery"
for _ in $(seq 1 90); do
  if adb_cmd devices 2>/dev/null | awk 'NR>1 && $2=="recovery" {found=1} END{exit !found}'; then break; fi
  sleep 2
done
adb_cmd devices -l

log "Mounting CACHE"
adb_cmd shell 'mkdir -p /cache'
adb_cmd shell "mount '$GTAXL_CACHE_DEVICE' /cache 2>/dev/null || true"

LATEST="$(adb_cmd shell "ls -1dt /cache/pmos-debug-* 2>/dev/null | head -1" | tr -d '\r')"
[[ -n "$LATEST" ]] || die "No /cache/pmos-debug-* directory found."

echo "Pulling: $LATEST"
adb_cmd pull "$LATEST" "$DEST/"
sudo chown -R "$(id -u):$(id -g)" "$DEST" 2>/dev/null || true

log "Saved"
find "$DEST" -maxdepth 2 -type f -printf '%p\n' | sort
