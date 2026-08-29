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

require_ssh_config() {
  [[ -n "${GTAXL_SSH_USER:-}" ]] || die "GTAXL_SSH_USER is missing from $GTAXL_ROOT/.env"
  [[ -n "${GTAXL_SSH_HOST:-}" ]] || die "GTAXL_SSH_HOST is missing from $GTAXL_ROOT/.env"

  require_cmd ssh

  # Password authentication is intentionally automated from the local-only
  # .env. sshpass receives it through SSHPASS rather than a command-line arg.
  if [[ -n "${GTAXL_SSH_PASSWORD:-}" ]]; then
    require_cmd sshpass
  fi
}

ssh_options=(
  -o UserKnownHostsFile=/dev/null
  -o StrictHostKeyChecking=no
  -o ConnectTimeout=5
  -o LogLevel=ERROR
)

ssh_run() {
  require_ssh_config

  if [[ -n "${GTAXL_SSH_PASSWORD:-}" ]]; then
    SSHPASS="$GTAXL_SSH_PASSWORD" sshpass -e \
      ssh "${ssh_options[@]}" "$GTAXL_SSH_USER@$GTAXL_SSH_HOST" "$@"
  else
    ssh "${ssh_options[@]}" "$GTAXL_SSH_USER@$GTAXL_SSH_HOST" "$@"
  fi
}

ssh_device() {
  require_ssh_config

  if [[ -n "${GTAXL_SSH_PASSWORD:-}" ]]; then
    SSHPASS="$GTAXL_SSH_PASSWORD" sshpass -e \
      ssh -tt "${ssh_options[@]}" "$GTAXL_SSH_USER@$GTAXL_SSH_HOST" "$@"
  else
    ssh -tt "${ssh_options[@]}" "$GTAXL_SSH_USER@$GTAXL_SSH_HOST" "$@"
  fi
}

ssh_reachable() {
  [[ -n "${GTAXL_SSH_HOST:-}" ]] || return 1
  timeout 2 bash -c "</dev/tcp/$GTAXL_SSH_HOST/22" >/dev/null 2>&1
}

remote_cmd() {
  ssh_run "$@"
}

remote_sudo() {
  require_ssh_config

  if [[ -n "${GTAXL_SSH_PASSWORD:-}" ]]; then
    printf '%s\n' "$GTAXL_SSH_PASSWORD" | ssh_run "sudo -S -p '' $*"
  else
    ssh_device "sudo $*"
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
