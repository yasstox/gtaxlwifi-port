#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"
require_not_root

DEST_DIR="${1:-$(dirname "$GTAXL_ROOT")/snapshots}"
mkdir -p "$DEST_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$DEST_DIR/gtaxlwifi-port-$STAMP.snapshot.tar.zst"

log "Stopping pmbootstrap chroots"
pmb shutdown || true

if findmnt -R "$GTAXL_ROOT" 2>/dev/null | grep -q "$GTAXL_ROOT/work/pmbootstrap-work"; then
  die "pmbootstrap/chroot mounts still exist below the workspace; refusing snapshot."
fi

log "Creating full snapshot"
tar --zstd -cpf "$OUT" -C "$(dirname "$GTAXL_ROOT")" "$(basename "$GTAXL_ROOT")"
sha256sum "$OUT" >"$OUT.sha256"
ls -lh "$OUT" "$OUT.sha256"
