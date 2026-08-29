#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"
require_not_root
ssh_reachable || die "SSH is not reachable at $GTAXL_SSH_HOST"

LABEL="${1:-$(date +%Y%m%d-%H%M%S)}"
DEST="$GTAXL_ROOT/docs/debug/$LABEL"
mkdir -p "$DEST"

capture() {
  local name="$1"; shift
  echo "Collecting $name"
  remote_cmd "$*" >"$DEST/$name" 2>&1 || true
}

capture uname.txt 'uname -a'
capture cmdline.txt 'cat /proc/cmdline'
capture os-release.txt 'cat /etc/os-release'
capture ip.txt 'ip addr; echo; ip route; echo; ip link'
capture drm.txt 'ls -la /sys/class/drm; echo; for x in /sys/class/drm/*/status; do echo "=== $x ==="; cat "$x"; done 2>/dev/null'
capture framebuffer.txt 'cat /proc/fb; echo; ls -la /sys/class/graphics/fb0; echo; cat /sys/class/graphics/fb0/name 2>/dev/null; cat /sys/class/graphics/fb0/virtual_size 2>/dev/null; cat /sys/class/graphics/fb0/blank 2>/dev/null'
capture mipi-dsi.txt 'ls -la /sys/bus/mipi-dsi/devices 2>/dev/null; echo; readlink -f /sys/bus/platform/devices/14800000.dsi/driver 2>/dev/null || true'
capture input.txt 'ls -la /dev/input 2>/dev/null; echo; cat /proc/bus/input/devices 2>/dev/null'
capture wifi.txt 'ip link; echo; lsmod | grep -E "ath10k|cfg80211|mac80211" || true; echo; dmesg | grep -iE "ath10k|wlan|firmware|mmc1|sdio" | tail -300'
capture services.txt 'systemctl --failed --no-pager; echo; systemctl status getty@tty1 --no-pager 2>&1 || true; echo; systemctl status sshd --no-pager 2>&1 || true'
capture journal.txt 'journalctl -b --no-pager'
capture dmesg.txt 'dmesg'

log "Saved to $DEST"
