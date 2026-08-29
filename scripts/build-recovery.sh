#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"
require_not_root

LABEL="${1:-manual-$(date +%Y%m%d-%H%M)}"
PASSWORD="${GTAXL_SSH_PASSWORD:-postmarketos}"

log "Building device package"
cd "$GTAXL_ROOT/src/pmaports"
pmb build --arch aarch64 --force device-samsung-gtaxlwifi

log "Generating recovery ZIP"
cd "$GTAXL_ROOT"
pmb install \
  --android-recovery-zip \
  --recovery-install-partition="${GTAXL_RECOVERY_INSTALL_PARTITION:-system}" \
  --password "$PASSWORD"

ROOTFS="$GTAXL_ROOT/work/pmbootstrap-work/chroot_rootfs_samsung-gtaxlwifi"
IMAGE="$GTAXL_ROOT/src/linux/.output/arch/arm64/boot/Image"
VMLINUX="$ROOTFS/boot/vmlinuz"
RAWZIP="$GTAXL_ROOT/work/pmbootstrap-work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gtaxlwifi.zip"

[[ -f "$RAWZIP" ]] || die "Recovery ZIP not found"
unzip -t "$RAWZIP" >/dev/null

if [[ -f "$IMAGE" ]]; then
  IMAGE_SHA="$(sha256sum "$IMAGE" | awk '{print $1}')"
  ROOT_SHA="$(sudo sha256sum "$VMLINUX" | awk '{print $1}')"
  echo "Image:  $IMAGE_SHA"
  echo "rootfs: $ROOT_SHA"
  [[ "$IMAGE_SHA" == "$ROOT_SHA" ]] || die "Rootfs vmlinuz is stale; re-run envkernel packaging and install"
fi

log "Checking PMIC config in rootfs kernel"
for opt in CONFIG_MFD_SEC_I2C=y CONFIG_MFD_SEC_CORE=y CONFIG_REGMAP_I2C=y CONFIG_REGULATOR_S2MPS11=y; do
  sudo grep -qxF "$opt" "$ROOTFS/boot/config" || die "Rootfs kernel missing $opt"
done

DEST="$GTAXL_ROOT/artifacts/$LABEL"
mkdir -p "$DEST"
cp "$RAWZIP" "$DEST/postmarketOS-edge-gtaxlwifi-$LABEL.zip"
sha256sum "$DEST"/* >"$GTAXL_ROOT/docs/SHA256SUMS-$LABEL"

log "Recovery artifact ready"
ls -lh "$DEST"/*
cat "$GTAXL_ROOT/docs/SHA256SUMS-$LABEL"
