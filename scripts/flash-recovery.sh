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
  log "Automatically rebooting $GTAXL_SSH_HOST into recovery"
  remote_sudo reboot recovery || warn "SSH reboot failed; enter TWRP manually."
fi

log "Waiting for TWRP/ADB"
adb_cmd wait-for-recovery

adb_cmd devices -l

log "Starting TWRP sideload"
# TWRP stops adbd while switching to sideload, so the shell transport normally
# closes before this command can return a successful status.
adb_cmd shell twrp sideload || true

log "Waiting for ADB sideload state"
adb_cmd wait-for-sideload

log "Sideloading $(basename "$ZIP")"
adb_cmd sideload "$ZIP"

log "Waiting for recovery to return"
adb_cmd wait-for-recovery

if [[ "$(adb_state)" == "recovery" ]]; then
  log "TWRP result"
  adb_cmd shell "tail -200 /tmp/recovery.log | grep -E 'Installation done|Updater process ended|RC=|[Ee]rror'" || true
fi

if [[ "$(adb_state)" == "recovery" ]]; then
  log "Automatically rebooting into postmarketOS"
  adb_cmd reboot
else
  warn "Recovery did not return after sideload; not forcing reboot."
fi
