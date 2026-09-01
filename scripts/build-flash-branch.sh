#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GTAXL_ROOT:-/workspace/gtaxlwifi-port}"

source "$ROOT/scripts/lib/common.sh"
require_not_root

# IMPORTANT:
# This is intentionally the active Linux 7.1 development worktree.
# We do NOT trust the old GTAXL_KERNEL_DIR from .env for this workflow.
KERNEL="${GTAXL_BUILD_KERNEL_DIR:-/workspace/linux-gtaxlwifi-7.1}"
PMAPORTS="$ROOT/src/pmaports"

require_cmd git
require_cmd make
require_cmd sha256sum
require_cmd ccache
require_cmd unzip
require_cmd aarch64-linux-gnu-gcc

[[ -d "$KERNEL" ]] || die "Kernel tree missing: $KERNEL"
[[ -e "$KERNEL/.git" ]] || die "Not a Git worktree: $KERNEL"

OUT="$KERNEL/.output"

IMAGE="$OUT/arch/arm64/boot/Image"
DTB="$OUT/arch/arm64/boot/dts/exynos/exynos7870-gtaxlwifi.dtb"

CONFIG_SRC="$PMAPORTS/device/testing/linux-postmarketos-exynos7870/config-postmarketos-exynos7870.aarch64"

ROOTFS="$ROOT/work/pmbootstrap-work/chroot_rootfs_samsung-gtaxlwifi"
ROOTFS_IMAGE="$ROOTFS/boot/vmlinuz"

RAWZIP="$ROOT/work/pmbootstrap-work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gtaxlwifi.zip"

PASSWORD="${GTAXL_SSH_PASSWORD:-}"
[[ -n "$PASSWORD" ]] || die "GTAXL_SSH_PASSWORD missing from $ROOT/.env"

# ------------------------------------------------------------
# Git state — READ ONLY
# ------------------------------------------------------------

CURRENT_BRANCH="$(git -C "$KERNEL" branch --show-current)"

if [[ -z "$CURRENT_BRANCH" ]]; then
    CURRENT_BRANCH="DETACHED"
fi

CURRENT_COMMIT="$(git -C "$KERNEL" rev-parse HEAD)"
SHORT_COMMIT="$(git -C "$KERNEL" rev-parse --short=12 HEAD)"

EXPECTED_BRANCH="${1:-}"

if [[ -n "$EXPECTED_BRANCH" && "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]]; then
    die "Current branch is '$CURRENT_BRANCH', but '$EXPECTED_BRANCH' was requested. Switch manually; this script never changes branches."
fi

BRANCH_FOR_LABEL="$CURRENT_BRANCH"

if [[ "$BRANCH_FOR_LABEL" == "DETACHED" ]]; then
    BRANCH_FOR_LABEL="detached-$SHORT_COMMIT"
fi

SAFE_BRANCH="$(printf '%s' "$BRANCH_FOR_LABEL" | tr '/ ' '--')"

LABEL="${2:-$SAFE_BRANCH-$(date +%Y%m%d-%H%M%S)}"

echo
echo '============================================================'
echo ' GTAXLWIFI LOCAL BUILD + PACKAGE + FLASH'
echo '============================================================'
echo
echo "Kernel tree : $KERNEL"
echo "Branch      : $CURRENT_BRANCH"
echo "Commit      : $CURRENT_COMMIT"
echo "pmaports    : $PMAPORTS"
echo "Label       : $LABEL"
echo
echo 'Git operations: READ ONLY'
echo 'No fetch / pull / merge / switch / push will be performed.'

echo
echo '=== 1. LOCAL GIT STATE ==='

git -C "$KERNEL" log -1 --oneline --decorate
git -C "$KERNEL" status --short

if [[ -n "$(git -C "$KERNEL" status --porcelain)" ]]; then
    echo
    echo 'Local modifications detected.'
    echo 'They WILL be included in the build.'
fi


# ------------------------------------------------------------
# Kernel configuration
# ------------------------------------------------------------

echo
echo '=== 2. KERNEL CONFIG ==='

mkdir -p "$OUT"

if [[ ! -s "$OUT/.config" ]]; then
    [[ -s "$CONFIG_SRC" ]] || die "Missing kernel config: $CONFIG_SRC"

    echo 'No .output/.config exists.'
    echo 'Importing pmaports config once.'

    cp "$CONFIG_SRC" "$OUT/.config"
else
    echo 'Existing .output/.config found.'
    echo 'Preserving it.'
fi

# Non-interactive.
make \
    -C "$KERNEL" \
    O="$OUT" \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    olddefconfig


# ------------------------------------------------------------
# Compile
# ------------------------------------------------------------

echo
echo '=== 3. BUILD IMAGE + MODULES + DTBS ==='

make \
    -C "$KERNEL" \
    O="$OUT" \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CC="ccache aarch64-linux-gnu-gcc" \
    HOSTCC="ccache gcc" \
    -j"$(nproc)" \
    Image \
    modules \
    dtbs


# ------------------------------------------------------------
# Verify outputs
# ------------------------------------------------------------

echo
echo '=== 4. VERIFY BUILD ==='

test -s "$IMAGE" || die "Image missing"
test -s "$DTB" || die "gtaxlwifi DTB missing"
test -s "$OUT/modules.order" || die "modules.order missing"

RELEASE="$(
    make -s \
        -C "$KERNEL" \
        O="$OUT" \
        ARCH=arm64 \
        kernelrelease
)"

echo "Kernel release: $RELEASE"

echo
sha256sum "$IMAGE" "$DTB"

echo
echo '=== CCACHE ==='
ccache -s


# ------------------------------------------------------------
# Envkernel
# ------------------------------------------------------------

echo
echo '=== 5. PACKAGE CURRENT .output WITH ENVKERNEL ==='

cd "$KERNEL"

pmb build \
    --force \
    --envkernel \
    linux-postmarketos-exynos7870


# ------------------------------------------------------------
# Local package
# ------------------------------------------------------------

echo
echo '=== 6. LOCAL CONFIG PACKAGE ==='

LOCAL_PACKAGE="$PMAPORTS/device/testing/gtaxlwifi-local-config"

if [[ -d "$LOCAL_PACKAGE" ]]; then
    cd "$ROOT"

    pmb build \
        --arch aarch64 \
        --force \
        gtaxlwifi-local-config
else
    warn "gtaxlwifi-local-config not found"
fi


# ------------------------------------------------------------
# Device package
# ------------------------------------------------------------

echo
echo '=== 7. DEVICE PACKAGE ==='

cd "$ROOT"

pmb build \
    --arch aarch64 \
    --force \
    device-samsung-gtaxlwifi


# ------------------------------------------------------------
# Generate recovery ZIP
# ------------------------------------------------------------

echo
echo '=== 8. GENERATE ROOTFS + RECOVERY ZIP ==='

pmb install \
    --android-recovery-zip \
    --recovery-install-partition="${GTAXL_RECOVERY_INSTALL_PARTITION:-system}" \
    --password "$PASSWORD"


# ------------------------------------------------------------
# Verify packaged kernel
# ------------------------------------------------------------

echo
echo '=== 9. VERIFY ROOTFS KERNEL ==='

test -s "$ROOTFS_IMAGE" || die "Rootfs /boot/vmlinuz missing"

SOURCE_SHA="$(sha256sum "$IMAGE" | awk '{print $1}')"
ROOTFS_SHA="$(sudo sha256sum "$ROOTFS_IMAGE" | awk '{print $1}')"

echo "Built Image : $SOURCE_SHA"
echo "Rootfs      : $ROOTFS_SHA"

[[ "$SOURCE_SHA" == "$ROOTFS_SHA" ]] ||
    die "Rootfs contains a stale kernel"

echo 'Kernel match: OK'


# ------------------------------------------------------------
# Verify ZIP
# ------------------------------------------------------------

echo
echo '=== 10. VERIFY RECOVERY ZIP ==='

test -s "$RAWZIP" || die "Recovery ZIP missing"

unzip -t "$RAWZIP" >/dev/null
sha256sum "$RAWZIP"


# ------------------------------------------------------------
# Save artifact
# ------------------------------------------------------------

echo
echo '=== 11. SAVE ARTIFACT ==='

DEST="$ROOT/artifacts/$LABEL"
mkdir -p "$DEST"

FINAL_ZIP="$DEST/postmarketOS-edge-gtaxlwifi-$LABEL.zip"

cp "$RAWZIP" "$FINAL_ZIP"

sha256sum "$FINAL_ZIP" |
    tee "$DEST/SHA256SUMS"

ls -lh "$FINAL_ZIP"


# ------------------------------------------------------------
# Flash
# ------------------------------------------------------------

echo
echo '=== 12. FLASH ==='

cd "$ROOT"

"$ROOT/scripts/flash-recovery.sh" "$FINAL_ZIP"


echo
echo '============================================================'
echo ' COMPLETE'
echo '============================================================'
echo
echo "Tree   : $KERNEL"
echo "Branch : $CURRENT_BRANCH"
echo "Commit : $CURRENT_COMMIT"
echo "Kernel : $RELEASE"
echo "ZIP    : $FINAL_ZIP"

if [[ -n "$(git -C "$KERNEL" status --porcelain)" ]]; then
    echo
    echo 'NOTE: kernel was built with uncommitted local modifications.'
fi
