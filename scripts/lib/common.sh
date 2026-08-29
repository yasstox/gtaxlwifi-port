#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
GTAXL_ROOT="${GTAXL_ROOT:-$DEFAULT_ROOT}"

if [[ -f "$GTAXL_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$GTAXL_ROOT/.env"
  set +a
fi

GTAXL_ROOT="${GTAXL_ROOT:-$DEFAULT_ROOT}"
GTAXL_PMB="${GTAXL_PMB:-$GTAXL_ROOT/src/pmbootstrap/pmbootstrap.py}"
GTAXL_PMB_CFG="${GTAXL_PMB_CFG:-$GTAXL_ROOT/config/pmbootstrap-console.cfg}"
GTAXL_SSH_HOST="${GTAXL_SSH_HOST:-172.16.42.1}"
GTAXL_SSH_USER="${GTAXL_SSH_USER:-user}"
GTAXL_ADB_SUDO="${GTAXL_ADB_SUDO:-1}"
GTAXL_CACHE_DEVICE="${GTAXL_CACHE_DEVICE:-/dev/mmcblk0p20}"

log() { printf '\n==> %s\n' "$*"; }
warn() { printf '\nWARNING: %s\n' "$*" >&2; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

confirm() {
  local prompt="${1:-Continue?}"
  local answer
  read -r -p "$prompt [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_not_root() {
  [[ ${EUID:-$(id -u)} -ne 0 ]] || die "Run this script as the normal build user, not root."
}

pmb() {
  python3 "$GTAXL_PMB" --config "$GTAXL_PMB_CFG" "$@"
}

adb_cmd() {
  if [[ "$GTAXL_ADB_SUDO" == "1" ]]; then
    sudo adb "$@"
  else
    adb "$@"
  fi
}

adb_state() {
  adb_cmd get-state 2>/dev/null || true
}

wait_for_adb_state() {
  local wanted="$1"
  local timeout="${2:-120}"
  local start now state
  start=$(date +%s)
  while :; do
    state="$(adb_state)"
    [[ "$state" == "$wanted" ]] && return 0
    now=$(date +%s)
    (( now - start >= timeout )) && return 1
    sleep 2
  done
}

ssh_base=(
  ssh
  -o UserKnownHostsFile=/dev/null
  -o StrictHostKeyChecking=no
  -o ConnectTimeout=5
  "$GTAXL_SSH_USER@$GTAXL_SSH_HOST"
)

ssh_reachable() {
  timeout 2 bash -c "</dev/tcp/$GTAXL_SSH_HOST/22" >/dev/null 2>&1
}

remote_cmd() {
  "${ssh_base[@]}" "$@"
}

remote_sudo() {
  if [[ -n "${GTAXL_SSH_PASSWORD:-}" ]]; then
    printf '%s\n' "$GTAXL_SSH_PASSWORD" | "${ssh_base[@]}" "sudo -S -p '' $*"
  else
    "${ssh_base[@]}" -tt "sudo $*"
  fi
}

newest_recovery_zip() {
  local raw="$GTAXL_ROOT/work/pmbootstrap-work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gtaxlwifi.zip"
  if [[ -f "$raw" ]]; then
    printf '%s\n' "$raw"
    return 0
  fi
  find "$GTAXL_ROOT/artifacts" -type f -name '*.zip' -printf '%T@ %p\n' 2>/dev/null \
    | sort -n | tail -1 | cut -d' ' -f2-
}
