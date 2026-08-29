#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"
require_not_root
ssh_reachable || die "SSH is not reachable at ${GTAXL_SSH_HOST:-<unset>}"

log "Framebuffer state"
remote_cmd 'cat /proc/fb; cat /sys/class/graphics/fb0/name 2>/dev/null; cat /sys/class/graphics/fb0/virtual_size 2>/dev/null; cat /sys/class/graphics/fb0/blank 2>/dev/null || true'

if confirm "Write 0 to fb0/blank?"; then
  remote_sudo sh -c "'echo 0 > /sys/class/graphics/fb0/blank'" || true
  echo "Observe the screen."
fi

if confirm "Force a framebuffer pan/refresh (echo 0,0 > fb0/pan)?"; then
  remote_sudo sh -c "'echo 0,0 > /sys/class/graphics/fb0/pan'" || true
  echo "Observe the screen."
fi

log "Framebuffer refresher"
remote_cmd 'command -v msm-fb-refresher || true; pgrep -af msm-fb-refresher || true'

if confirm "Start msm-fb-refresher --loop temporarily if available?"; then
  remote_sudo sh -c "'command -v msm-fb-refresher >/dev/null && nohup msm-fb-refresher --loop >/tmp/msm-fb-refresher.log 2>&1 &'" || true
  echo "Observe the screen, then stop it later with: sudo pkill msm-fb-refresher"
fi
