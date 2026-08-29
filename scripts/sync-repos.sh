#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"
require_not_root

show_repo() {
  local path="$1" name="$2"
  [[ -d "$path/.git" || -f "$path/.git" ]] || return 0
  log "$name"
  echo "branch: $(git -C "$path" branch --show-current)"
  git -C "$path" status --short
  echo "remotes:"
  git -C "$path" remote -v
  echo "fetching..."
  while read -r remote; do
    [[ -n "$remote" ]] && git -C "$path" fetch "$remote" --prune --tags || true
  done < <(git -C "$path" remote)
  echo "HEAD: $(git -C "$path" log -1 --oneline --decorate)"
}

show_repo "$GTAXL_ROOT" meta
show_repo "$GTAXL_ROOT/src/linux" linux
show_repo "$GTAXL_ROOT/src/pmaports" pmaports
show_repo "$GTAXL_ROOT/src/pmbootstrap" pmbootstrap
show_repo "$GTAXL_ROOT/src/vendor-kernel" vendor-kernel

echo
log "No merges/rebases were performed automatically."
