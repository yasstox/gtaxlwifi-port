#!/usr/bin/env bash
# Read-only, paired measurements for Exynos DECON + Panfrost bring-up.
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"

if [[ ${1:-} == --help ]]; then
  echo "Usage: $0 idle|load [sample-count=12] [interval-seconds=2]"
  echo "For 'load', start dragging windows before launching and keep doing it until completion."
  exit 0
fi
require_not_root
phase=${1:-}
samples=${2:-12}
interval=${3:-2}
[[ $phase == idle || $phase == load ]] || die "Expected idle or load. See --help."
[[ $samples =~ ^[0-9]+$ && $samples -ge 1 && $samples -le 120 ]] || die "sample-count must be 1..120"
[[ $interval =~ ^[0-9]+$ && $interval -ge 1 && $interval -le 30 ]] || die "interval-seconds must be 1..30"
ssh_reachable || die "SSH is not reachable at ${GTAXL_SSH_HOST:-<unset>}"

dest="$GTAXL_ROOT/docs/debug/gpu-$(date +%Y%m%d-%H%M%S)-$phase"
mkdir -p "$dest"
remote_cmd "sh -s -- $samples $interval" >"$dest/samples.txt" <<'REMOTE'
samples=$1
interval=$2
printf 'kernel: '; uname -r
printf 'boot args: '; cat /proc/cmdline
printf 'DRM cards and drivers:\n'
for d in /sys/class/drm/card[0-9]; do
  [ -e "$d" ] || continue
  printf '%s -> ' "$d"
  readlink -f "$d/device/driver" || true
done
printf 'render devices:\n'; ls -l /dev/dri/renderD* 2>/dev/null || true
printf 'Panfrost devfreq devices:\n'
for d in /sys/class/devfreq/*; do
  [ -e "$d" ] || continue
  case "$(readlink -f "$d")" in
    *11400000*|*mali*|*gpu*) printf '%s\n' "$d"; for p in governor available_frequencies min_freq max_freq; do printf '%s: ' "$p"; cat "$d/$p" 2>/dev/null || true; done ;;
  esac
done
i=1
while [ "$i" -le "$samples" ]; do
  printf '\n=== sample %s %s ===\n' "$i" "$(date -Is)"
  sed -n '/^MemTotal:/p;/^MemAvailable:/p;/^Shmem:/p;/^Unevictable:/p;/^CmaTotal:/p;/^CmaFree:/p' /proc/meminfo
  sed -n '/^pgscan_kswapd/p;/^pgsteal_kswapd/p;/^allocstall/p;/^compact_stall /p' /proc/vmstat
  for d in /sys/class/devfreq/*; do
    [ -e "$d" ] || continue
    case "$(readlink -f "$d")" in
      *11400000*|*mali*|*gpu*) printf '%s current_frequency=' "$d"; cat "$d/cur_freq" 2>/dev/null || true ;;
    esac
  done
  ps -eo pid,comm,%cpu,rss --sort=-%cpu 2>/dev/null | head -12 || true
  if [ "$i" -lt "$samples" ]; then sleep "$interval"; fi
  i=$((i + 1))
done
REMOTE
remote_cmd 'journalctl -k -b --no-pager 2>/dev/null | grep -iE "panfrost|decon|exynos_drm_gem|cma|allocat|iommu|mmu|gpu@11400000" | tail -200' >"$dest/kernel-graphics.txt" 2>&1 || true
log "Read-only GPU/display/memory sample saved in $dest"
