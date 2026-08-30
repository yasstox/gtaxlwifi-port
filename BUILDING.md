# Building postmarketOS for the SM-T580

Current reproducible workflow for the `samsung-gtaxlwifi` Linux 6.19 port.

## Workspace

```text
gtaxlwifi-port/
├── src/linux
├── src/pmaports
├── src/pmbootstrap
├── src/vendor-kernel
├── artifacts/
└── work/                  # pmbootstrap workdir; never commit
```

Main branches:

```text
src/linux:    exynos7870/6.19
src/pmaports: port/gtaxlwifi-6.19
meta:         main
```

Current display integration worktree:

```text
/workspace/linux-gtaxlwifi-display
debug/display-regulator
```

Do not run concurrent pmbootstrap packaging/install jobs from multiple worktrees: they share the same pmbootstrap workdir/package repository.

## Host packages

On Ubuntu/Debian-like hosts:

```bash
sudo apt update
sudo apt install -y \
  git python3 build-essential bc bison flex \
  libssl-dev libelf-dev libncurses-dev \
  gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
  device-tree-compiler dwarves qemu-user-static binfmt-support \
  kpartx cpio rsync unzip zip xz-utils zstd adb openssl sshpass
```

Run normal builds as a regular user.

## Project environment

```bash
cd /workspace/gtaxlwifi-port
source scripts/lib/common.sh
pmb status
```

`.env` contains local SSH/device settings and must stay untracked.

## Build the kernel

Choose the exact kernel tree you intend to test. For the clean port use `src/linux`; for the current graphical integration baseline use `/workspace/linux-gtaxlwifi-display`.

For a clean `.output` configuration:

```bash
rm -rf .output
mkdir -p .output
cp /workspace/gtaxlwifi-port/src/pmaports/device/testing/linux-postmarketos-exynos7870/config-postmarketos-exynos7870.aarch64 .output/.config

make O=.output ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make O=.output ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)"
```

Required outputs:

```text
.output/arch/arm64/boot/Image
.output/arch/arm64/boot/dts/exynos/exynos7870-gtaxlwifi.dtb
```

For DT-only experiments, `make ... dtbs` is enough before packaging.

## Package the exact built kernel

Run `--envkernel` from the same kernel worktree whose `.output` you built:

```bash
source /workspace/gtaxlwifi-port/scripts/lib/common.sh
pmb build --force --envkernel linux-postmarketos-exynos7870
```

Do not package from `src/linux` after building another worktree.

## Device package and recovery ZIP

From the meta-repository:

```bash
cd /workspace/gtaxlwifi-port
source scripts/lib/common.sh

pmb build --force device-samsung-gtaxlwifi
pmb install \
  --android-recovery-zip \
  --recovery-install-partition=system \
  --password '<test-password>'
```

The device uses Exynos QCDT boot images. `dtbtool-exynos` and boot-deploy handle QCDT generation; do not add a second manual `dt.img` path.

If pmbootstrap selects an older/higher-`pkgrel` local device APK instead of your modified source package, remove/rebuild the stale local APK before generating the rootfs.

## Validate before flashing

### Kernel matches the intended worktree

```bash
sha256sum <kernel-worktree>/.output/arch/arm64/boot/Image
sudo sha256sum work/pmbootstrap-work/chroot_rootfs_samsung-gtaxlwifi/boot/vmlinuz
```

The hashes must match.

### DTB is the intended one

```bash
sudo dtc -I dtb -O dts \
  work/pmbootstrap-work/chroot_rootfs_samsung-gtaxlwifi/boot/dtbs/exynos/exynos7870-gtaxlwifi.dtb \
  > /tmp/gtaxlwifi-rootfs.dts
```

Inspect the properties relevant to the current experiment.

### Recovery ZIP and BOOT size

```bash
ZIP=work/pmbootstrap-work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gtaxlwifi.zip
unzip -t "$ZIP"

BOOT_IMG=work/pmbootstrap-work/chroot_rootfs_samsung-gtaxlwifi/boot/boot.img
test "$(sudo stat -Lc '%s' "$BOOT_IMG")" -le 33554432
```

The SM-T580 BOOT partition limit used by this project is 32 MiB.

## Flash

Prefer the helper with an explicit artifact path:

```bash
./scripts/flash-recovery.sh artifacts/<milestone>/<pmos-samsung-gtaxlwifi.zip>
```

or sideload the validated recovery ZIP through TWRP.

## Git discipline

- Keep one hardware hypothesis/fix per commit where practical.
- Push kernel/pmaports commits before advancing meta-repository submodule pointers.
- Keep temporary display hacks on their debug branch until replaced by proper hardware modelling.
- Use `git diff --cached --submodule=log` before a meta-repository milestone commit.
- The Git history is the experiment log; `STATUS.md` should describe only the current state.
