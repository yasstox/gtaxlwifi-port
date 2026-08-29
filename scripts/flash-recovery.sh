#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"
require_not_root
require_cmd unzip

ZIP="${1:-$(newest_recovery_zip)}"
[[ -n "$ZIP" && -f "$ZIP" ]] || die "Recovery ZIP not found. Pass it as argument 1."
ZIP="$(readlink -f "$ZIP")"

log "Validating recovery ZIP"
ls -lh "$ZIP"
unzip -t "$ZIP" >/dev/null
sha256sum "$ZIP"

if ssh_reachable; then
  log "Device appears to be booted in Linux"
  if confirm "Reboot $GTAXL_SSH_HOST into recovery now?"; then
    remote_sudo reboot recovery || warn "SSH reboot failed; enter TWRP manually."
  fi
fi

log "Waiting for TWRP/ADB"
for _ in $(seq 1 90); do
  if adb_cmd devices 2>/dev/null | awk 'NR>1 && $2=="recovery" {found=1} END{exit !found}'; then
    break
  fi
  sleep 2
done

adb_cmd devices -l

if adb_cmd devices 2>/dev/null | awk 'NR>1 && $2=="recovery" {found=1} END{exit !found}'; then
  log "Starting TWRP sideload"
  if ! adb_cmd shell twrp sideload; then
    warn "Could not start sideload automatically. Start ADB Sideload physically in TWRP."
  fi
fi

log "Waiting for ADB sideload state"
if ! wait_for_adb_state sideload 120; then
  warn "ADB did not report sideload automatically. Current state: $(adb_state)"
  echo "Start TWRP -> Advanced -> ADB Sideload, then press Enter."
  read -r
  wait_for_adb_state sideload 60 || die "Still not in sideload mode."
fi

log "Sideloading $(basename "$ZIP")"
adb_cmd sideload "$ZIP"

log "Waiting for recovery to return"
wait_for_adb_state recovery 30 || true

if [[ "$(adb_state)" == "recovery" ]]; then
  log "TWRP result"
  adb_cmd shell "tail -200 /tmp/recovery.log | grep -E 'Installation done|Updater process ended|RC=|[Ee]rror'" || true
fi

if confirm "Reboot into postmarketOS now?"; then
  adb_cmd reboot
else
  echo "Leaving device in TWRP."
fi
