#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"
require_not_root
require_cmd make
require_cmd sha256sum

KERNEL="$GTAXL_ROOT/src/linux"
CONFIG_SRC="$GTAXL_ROOT/src/pmaports/device/testing/linux-postmarketos-exynos7870/config-postmarketos-exynos7870.aarch64"
OUT="$KERNEL/.output"

[[ "${1:-}" != "--incremental" ]] && { log "Cleaning kernel output"; rm -rf "$OUT"; }
mkdir -p "$OUT"
cp "$CONFIG_SRC" "$OUT/.config"

log "olddefconfig"
make -C "$KERNEL" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

log "Required SM-T580 PMIC options"
required=(
  CONFIG_I2C=y
  CONFIG_I2C_S3C2410=y
  CONFIG_MFD_SEC_I2C=y
  CONFIG_MFD_SEC_CORE=y
  CONFIG_REGMAP_I2C=y
  CONFIG_REGULATOR_S2MPS11=y
)
for opt in "${required[@]}"; do
  grep -qxF "$opt" "$OUT/.config" || die "Missing required config: $opt"
  echo "$opt"
done

log "Building kernel"
make -C "$KERNEL" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)"

IMAGE="$OUT/arch/arm64/boot/Image"
DTB="$OUT/arch/arm64/boot/dts/exynos/exynos7870-gtaxlwifi.dtb"
[[ -f "$IMAGE" && -f "$DTB" ]] || die "Image or DTB missing after build"
sha256sum "$IMAGE" "$DTB"

log "Packaging current .output with pmbootstrap --envkernel"
cd "$KERNEL"
pmb build --force --envkernel linux-postmarketos-exynos7870

APK="$(find "$GTAXL_ROOT/work/pmbootstrap-work/packages/edge/aarch64" -maxdepth 1 -type f -name 'linux-postmarketos-exynos7870*.apk' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)"
[[ -f "$APK" ]] || die "Kernel APK not found"

echo "Newest APK: $APK"
IMAGE_SHA="$(sha256sum "$IMAGE" | awk '{print $1}')"
APK_SHA="$(tar -xOf "$APK" boot/vmlinuz 2>/dev/null | sha256sum | awk '{print $1}')"
echo "Image: $IMAGE_SHA"
echo "APK:   $APK_SHA"
[[ "$IMAGE_SHA" == "$APK_SHA" ]] || die "APK vmlinuz does not match the freshly built Image"

log "Kernel build/package verified"
