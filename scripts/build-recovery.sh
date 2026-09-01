#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/common.sh"
require_not_root
require_cmd git
require_cmd sha256sum
require_cmd unzip
require_cmd stat

PASSWORD="${GTAXL_SSH_PASSWORD:-}"
[[ -n "$PASSWORD" ]] ||
    die "GTAXL_SSH_PASSWORD is missing from $GTAXL_ROOT/.env"

KERNEL_REPO="$GTAXL_ROOT/src/linux"

[[ -d "$KERNEL_REPO" ]] ||
    die "Kernel repository not found: $KERNEL_REPO"


# ============================================================
# DISCOVER THE ACTIVE KERNEL WORKTREE
# ============================================================

discover_kernel_worktree() {
    local wt
    local image
    local dtb
    local modules
    local branch
    local stamp
    local image_stamp
    local dtb_stamp
    local modules_stamp

    local best=""
    local best_stamp=0

    while IFS= read -r wt; do
        [[ -n "$wt" ]] || continue

        image="$wt/.output/arch/arm64/boot/Image"
        dtb="$wt/.output/arch/arm64/boot/dts/exynos/exynos7870-gtaxlwifi.dtb"
        modules="$wt/.output/modules.order"

        # Ignore worktrees which have not been completely built.
        [[ -s "$image" ]] || continue
        [[ -s "$dtb" ]] || continue
        [[ -s "$modules" ]] || continue

        # We want a real checked-out development branch.
        branch="$(
            git -C "$wt" symbolic-ref \
                --quiet \
                --short HEAD \
                2>/dev/null || true
        )"

        [[ -n "$branch" ]] || continue

        image_stamp="$(stat -c '%Y' "$image")"
        dtb_stamp="$(stat -c '%Y' "$dtb")"
        modules_stamp="$(stat -c '%Y' "$modules")"

        stamp="$image_stamp"

        (( dtb_stamp > stamp )) &&
            stamp="$dtb_stamp"

        (( modules_stamp > stamp )) &&
            stamp="$modules_stamp"

        if (( stamp > best_stamp )); then
            best="$wt"
            best_stamp="$stamp"
        fi
    done < <(
        git -C "$KERNEL_REPO" \
            worktree list \
            --porcelain |
        sed -n 's/^worktree //p'
    )

    [[ -n "$best" ]] ||
        return 1

    printf '%s\n' "$best"
}


log "Discovering kernel Git worktree"

KERNEL_DIR="$(discover_kernel_worktree)" ||
    die "No fully-built kernel Git worktree found"

KERNEL_DIR="$(readlink -f "$KERNEL_DIR")"
KERNEL_OUT="$KERNEL_DIR/.output"

KERNEL_BRANCH="$(
    git -C "$KERNEL_DIR" \
        symbolic-ref \
        --quiet \
        --short HEAD
)"

KERNEL_COMMIT="$(
    git -C "$KERNEL_DIR" \
        rev-parse \
        --short=12 HEAD
)"

KERNEL_RELEASE="$(
    make -s \
        -C "$KERNEL_DIR" \
        O="$KERNEL_OUT" \
        ARCH=arm64 \
        kernelrelease
)"

IMAGE="$KERNEL_OUT/arch/arm64/boot/Image"
DTB="$KERNEL_OUT/arch/arm64/boot/dts/exynos/exynos7870-gtaxlwifi.dtb"

SAFE_BRANCH="$(
    printf '%s' "$KERNEL_BRANCH" |
    sed 's#[^A-Za-z0-9._-]#-#g'
)"

LABEL="${1:-${SAFE_BRANCH}-$(date +%Y%m%d-%H%M)}"


echo
echo '============================================================'
echo ' GTAXLWIFI RECOVERY BUILD'
echo '============================================================'
echo
echo "Kernel worktree : $KERNEL_DIR"
echo "Kernel branch   : $KERNEL_BRANCH"
echo "Kernel commit   : $KERNEL_COMMIT"
echo "Kernel release  : $KERNEL_RELEASE"
echo "Label           : $LABEL"
echo

git -C "$KERNEL_DIR" log -1 --oneline --decorate

if [[ -n "$(git -C "$KERNEL_DIR" status --porcelain)" ]]; then
    warn "Kernel worktree contains uncommitted changes"
    git -C "$KERNEL_DIR" status --short
fi


# ============================================================
# VERIFY KBUILD OUTPUT
# ============================================================

log "Validating selected kernel build"

[[ -s "$IMAGE" ]] ||
    die "Missing Image: $IMAGE"

[[ -s "$DTB" ]] ||
    die "Missing gtaxlwifi DTB: $DTB"

[[ -s "$KERNEL_OUT/modules.order" ]] ||
    die "Missing modules.order: kernel modules were not fully built"

echo
sha256sum "$IMAGE" "$DTB"


# ============================================================
# PACKAGE EXACT SELECTED KERNEL
# ============================================================

log "Packaging envkernel from $KERNEL_BRANCH"

cd "$KERNEL_DIR"

pmb build \
    --force \
    --envkernel \
    linux-postmarketos-exynos7870


# ============================================================
# LOCAL PRIVATE CONFIG
# ============================================================

LOCAL_CONFIG_DIR="$GTAXL_ROOT/src/pmaports/device/testing/gtaxlwifi-local-config"

if [[ -d "$LOCAL_CONFIG_DIR" ]]; then
    log "Building private gtaxlwifi local configuration"

    cd "$GTAXL_ROOT/src/pmaports"

    pmb build \
        --arch aarch64 \
        --force \
        gtaxlwifi-local-config
fi


# ============================================================
# DEVICE PACKAGE
# ============================================================

log "Building device package"

cd "$GTAXL_ROOT/src/pmaports"

pmb build \
    --arch aarch64 \
    --force \
    device-samsung-gtaxlwifi


# ============================================================
# RECOVERY ZIP
# ============================================================

log "Generating recovery ZIP"

cd "$GTAXL_ROOT"

pmb install \
    --android-recovery-zip \
    --recovery-install-partition="${GTAXL_RECOVERY_INSTALL_PARTITION:-system}" \
    --password "$PASSWORD"


# ============================================================
# VERIFY WHAT PMBOOTSTRAP ACTUALLY PACKAGED
# ============================================================

ROOTFS="$GTAXL_ROOT/work/pmbootstrap-work/chroot_rootfs_samsung-gtaxlwifi"

VMLINUX="$ROOTFS/boot/vmlinuz"
ROOT_DTB="$ROOTFS/boot/dtbs/exynos/exynos7870-gtaxlwifi.dtb"

RAWZIP="$GTAXL_ROOT/work/pmbootstrap-work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gtaxlwifi.zip"

[[ -s "$VMLINUX" ]] ||
    die "Rootfs vmlinuz not found"

[[ -s "$ROOT_DTB" ]] ||
    die "Rootfs gtaxlwifi DTB not found"

[[ -s "$RAWZIP" ]] ||
    die "Recovery ZIP not found"


log "Validating packaged kernel"

IMAGE_SHA="$(
    sha256sum "$IMAGE" |
    awk '{print $1}'
)"

ROOT_SHA="$(
    sudo sha256sum "$VMLINUX" |
    awk '{print $1}'
)"

echo "Selected Image : $IMAGE_SHA"
echo "Rootfs vmlinuz : $ROOT_SHA"

[[ "$IMAGE_SHA" == "$ROOT_SHA" ]] ||
    die "Rootfs kernel does not match selected worktree $KERNEL_BRANCH"


log "Validating packaged DTB"

DTB_SHA="$(
    sha256sum "$DTB" |
    awk '{print $1}'
)"

ROOT_DTB_SHA="$(
    sudo sha256sum "$ROOT_DTB" |
    awk '{print $1}'
)"

echo "Selected DTB : $DTB_SHA"
echo "Rootfs DTB   : $ROOT_DTB_SHA"

[[ "$DTB_SHA" == "$ROOT_DTB_SHA" ]] ||
    die "Rootfs DTB does not match selected worktree $KERNEL_BRANCH"


# ============================================================
# VALIDATE ZIP
# ============================================================

log "Validating recovery ZIP"

unzip -t "$RAWZIP" >/dev/null
sha256sum "$RAWZIP"


# ============================================================
# SAVE ARTIFACT
# ============================================================

DEST="$GTAXL_ROOT/artifacts/$LABEL"

mkdir -p "$DEST"

FINAL_ZIP="$DEST/postmarketOS-edge-gtaxlwifi-${SAFE_BRANCH}-${LABEL}.zip"

cp "$RAWZIP" "$FINAL_ZIP"

SHA_FILE="$DEST/SHA256SUMS"

sha256sum "$FINAL_ZIP" > "$SHA_FILE"

cat > "$DEST/kernel-build.txt" <<META
kernel_worktree=$KERNEL_DIR
kernel_branch=$KERNEL_BRANCH
kernel_commit=$KERNEL_COMMIT
kernel_release=$KERNEL_RELEASE
image_sha256=$IMAGE_SHA
dtb_sha256=$DTB_SHA
META


log "Recovery artifact ready"

echo
ls -lh "$FINAL_ZIP"

echo
cat "$SHA_FILE"

echo
cat "$DEST/kernel-build.txt"

echo
echo '============================================================'
echo ' BUILD VERIFIED'
echo '============================================================'
echo
echo "ZIP: $FINAL_ZIP"
