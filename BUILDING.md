# Building postmarketOS for Samsung Galaxy Tab A 10.1 2016 (SM-T580)

This document describes the reproducible build workflow for the `gtaxlwifi`
postmarketOS port based on the Exynos7870 mainline kernel.

It is intentionally written so it can remain in a public repository later.
Do not put passwords, access tokens, private repository credentials, device
serial numbers, or other secrets in this file.

## 1. Repository layout

The project uses a meta-repository with Git submodules:

```text
gtaxlwifi-port/
├── BUILDING.md
├── STATUS.md
├── config/
│   └── pmbootstrap-console.cfg
├── docs/
├── artifacts/                 # local build outputs; normally ignored by Git
├── src/
│   ├── linux/                 # Exynos7870 kernel fork
│   ├── pmaports/              # pmaports fork
│   ├── pmbootstrap/           # upstream pmbootstrap
│   └── vendor-kernel/         # vendor/legacy reference
└── work/                      # pmbootstrap workdir; never commit
```

Expected development branches:

```text
src/linux:    port/gtaxlwifi-6.19
src/pmaports: port/gtaxlwifi-6.19
meta repo:    main
```

The meta-repository records the exact commits of the kernel and pmaports
submodules. This makes a known-good milestone reproducible without flattening
the repositories or deleting their `.git` history.

## 2. Git discipline

### One hardware hypothesis per kernel commit

Do not combine unrelated experiments. Examples:

```text
arm64: dts: exynos7870-gtaxlwifi: add WLAN DCDC supply
arm64: dts: exynos7870-gtaxlwifi: enable MIPI DSI host
arm64: dts: exynos7870-gtaxlwifi: add Himax panel
```

Build and test a change before adding the next hardware hypothesis.

### Keep pmaports synchronized with kernel history

The kernel repository is the development source of truth. When a kernel
experiment becomes part of the reproducible port, export the corresponding
kernel commits as patches into the pmaports kernel package and commit that
packaging change separately.

Typical flow:

```text
kernel commit
    ↓
local compile
    ↓
pmbootstrap --envkernel package
    ↓
boot/test
    ↓
pmaports patch/checksum commit
    ↓
meta-repo submodule pointer commit
```

### Push only concrete milestones from the meta-repository

Push the kernel and pmaports branches regularly so work is backed up.

Update and push the **meta-repository** when there is a concrete checkpoint,
for example:

- kernel APK builds successfully;
- full `pmbootstrap install` finishes with `DONE!`;
- a recovery ZIP is validated;
- a device boot result has been recorded;
- Wi-Fi becomes functional;
- the DSI host binds;
- the panel appears on the MIPI-DSI bus;
- the native display pipeline reaches a new verified state.

Do not move the meta-repository pointer to a commit that is known to be broken
unless the commit is deliberately documenting a reproducible failure.

Before every milestone commit:

```bash
git -C src/linux status --short
git -C src/pmaports status --short
git status --short
git submodule status
```

Review staged submodule changes with:

```bash
git diff --cached --submodule=log
```

## 3. Host requirements

The known local build host is Ubuntu/Debian-like. Install at least:

```bash
sudo apt update
sudo apt install -y \
  git ca-certificates python3 python3-venv python3-pip \
  build-essential bc bison flex \
  libssl-dev libelf-dev libncurses-dev \
  gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
  device-tree-compiler dwarves \
  qemu-user-static binfmt-support kpartx \
  cpio rsync unzip zip xz-utils zstd \
  adb openssl procps
```

Run pmbootstrap as a normal user. Do not run normal builds as root.

Root may be useful only for inspecting root-owned chroot files. Return to the
normal build user before modifying Git files.

## 4. Project environment

From the project root:

```bash
export GTAXL_ROOT=/workspace/gtaxlwifi-port
export GTAXL_PMB="$GTAXL_ROOT/src/pmbootstrap/pmbootstrap.py"
export GTAXL_CFG="$GTAXL_ROOT/config/pmbootstrap-console.cfg"

pmb() {
    python3 "$GTAXL_PMB" --config "$GTAXL_CFG" "$@"
}
```

Check:

```bash
pmb status
```

Expected target:

```text
Device: samsung-gtaxlwifi (aarch64)
UI: console
systemd: yes
```

The pmbootstrap workdir is intentionally outside Git history:

```text
/workspace/gtaxlwifi-port/work/pmbootstrap-work
```

## 5. Clean kernel build

The kernel branch is currently based on Exynos7870 Linux 6.19 development
(`6.19.0-rc3-exynos7870+` at the first reproducible baseline).

Enter the kernel repository:

```bash
cd "$GTAXL_ROOT/src/linux"

git status --short
git branch --show-current
git log -5 --oneline --decorate
```

For a clean build, copy the pmaports kernel config:

```bash
rm -rf .output
mkdir -p .output

cp \
  "$GTAXL_ROOT/src/pmaports/device/testing/linux-postmarketos-exynos7870/config-postmarketos-exynos7870.aarch64" \
  .output/.config
```

Normalize the config:

```bash
make \
  O=.output \
  ARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  olddefconfig
```

Compile:

```bash
make \
  O=.output \
  ARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  -j"$(nproc)"
```

Required outputs:

```bash
test -f .output/arch/arm64/boot/Image
test -f .output/arch/arm64/boot/dts/exynos/exynos7870-gtaxlwifi.dtb
cat .output/include/config/kernel.release
```

Record checksums when the build is a milestone:

```bash
sha256sum \
  .output/arch/arm64/boot/Image \
  .output/arch/arm64/boot/dts/exynos/exynos7870-gtaxlwifi.dtb
```

## 6. Package the local kernel with pmbootstrap

`--envkernel` packages the already-built `.output` tree. Run it **from inside
the kernel source directory**:

```bash
cd "$GTAXL_ROOT/src/linux"

pmb build --force \
  --envkernel \
  linux-postmarketos-exynos7870
```

Locate the newest APK:

```bash
find "$GTAXL_ROOT/work/pmbootstrap-work/packages/edge/aarch64" \
  -type f \
  -name 'linux-postmarketos-exynos7870*.apk' \
  -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' \
  | sort
```

The kernel embedded in the package must match:

```bash
cat .output/include/config/kernel.release
```

## 7. Exynos QCDT boot-image rules

The SM-T580 package currently uses:

```text
deviceinfo_bootimg_qcdt="true"
deviceinfo_bootimg_qcdt_type="exynos"
deviceinfo_dtb="exynos/exynos7870-gtaxlwifi"
```

Important separation of responsibilities:

- the kernel package installs `vmlinuz` and DTBs;
- the device package has a runtime dependency on `dtbtool-exynos`;
- `boot-deploy` uses `dtbTool-exynos` during `mkinitfs` to create the Exynos
  QCDT data needed for `boot.img`.

Do **not** add a second manual `dt.img` generation path to the kernel package
while `deviceinfo_bootimg_qcdt_type="exynos"` is being used.

The final rootfs must contain:

```text
/boot/vmlinuz
/boot/dtbs/exynos/exynos7870-gtaxlwifi.dtb
```

and `boot-deploy` must finish without a QCDT error.

## 8. Build the device package

From the meta-repository:

```bash
cd "$GTAXL_ROOT"

pmb build --force device-samsung-gtaxlwifi
```

Verify that the device package depends on the mainline kernel:

```bash
grep -nA12 '^depends=' \
  src/pmaports/device/testing/device-samsung-gtaxlwifi/APKBUILD
```

It must use:

```text
linux-postmarketos-exynos7870
```

and must not depend on the old downstream kernel.

## 9. Build a recovery ZIP

Still from the meta-repository:

```bash
pmb install \
  --android-recovery-zip \
  --recovery-install-partition=system \
  --password '<test-password>'
```

A successful build must end with:

```text
DONE!
```

The recovery ZIP is currently generated at:

```text
work/pmbootstrap-work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gtaxlwifi.zip
```

Do not permanently assume this path in scripts without checking it first.

Locate important outputs:

```bash
sudo find work/pmbootstrap-work \
  -type f \
  \( -name 'pmos-samsung-gtaxlwifi.zip' \
     -o -name 'boot.img' \
     -o -name 'exynos7870-gtaxlwifi.dtb' \
     -o -name 'vmlinuz' \) \
  -printf '%s %p\n'
```

`sudo` is only for reading root-owned chroot files.

## 10. Mandatory validation before flashing

### ZIP integrity

```bash
unzip -t \
  work/pmbootstrap-work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gtaxlwifi.zip
```

Expected ending:

```text
No errors detected in compressed data
```

### BOOT partition limit

The SM-T580 BOOT partition limit used by this project is 32 MiB:

```text
33,554,432 bytes
```

Check:

```bash
BOOT_IMG="$GTAXL_ROOT/work/pmbootstrap-work/chroot_rootfs_samsung-gtaxlwifi/boot/boot.img"
BOOT_BYTES="$(sudo stat -Lc '%s' "$BOOT_IMG")"

echo "$BOOT_BYTES"
test "$BOOT_BYTES" -le 33554432
```

Do not flash a build if this test fails.

### Kernel and DTB

```bash
sudo sha256sum \
  work/pmbootstrap-work/chroot_rootfs_samsung-gtaxlwifi/boot/vmlinuz \
  work/pmbootstrap-work/chroot_rootfs_samsung-gtaxlwifi/boot/dtbs/exynos/exynos7870-gtaxlwifi.dtb \
  work/pmbootstrap-work/chroot_rootfs_samsung-gtaxlwifi/boot/boot.img
```

Record hashes in `docs/` for concrete milestones.

## 11. Artifact naming

Use revision names that describe the experiment:

```text
r0-simpledrm
r1-wifi
r2-dsi-host
r3-panel
r4-panel-power
r5-native-display
```

Example:

```text
artifacts/r0-simpledrm/
├── postmarketOS-edge-gtaxlwifi-6.19-r0-simpledrm.zip
├── boot-6.19-r0-simpledrm.img
└── exynos7870-gtaxlwifi-r0-simpledrm.dtb
```

`artifacts/` may stay ignored by Git. Commit the hashes instead:

```bash
sha256sum artifacts/r0-simpledrm/* \
  > docs/SHA256SUMS-r0-simpledrm

git add docs/SHA256SUMS-r0-simpledrm
```

## 12. Test-result logging

Every actual device experiment should append a new section to `STATUS.md`.

Recommended fields:

```text
revision:
kernel version:
kernel commit:
pmaports commit:
ZIP SHA256:
boot.img SHA256:
DTB SHA256:

physical display:
simpledrm:
fb0:
DECON:
14800000.dsi:
DSI driver:
MIPI child:
panel driver:
LCD_1P8:
backlight:

Wi-Fi:
USB SSH:

conclusion:
next experiment:
```

Do not rewrite previous experiment results. Failed experiments are useful data.

## 13. GitHub layout

Recommended private repositories during bring-up:

```text
gtaxlwifi-port                  # meta repo
linux-exynos7870-gtaxlwifi     # src/linux fork
pmaports-gtaxlwifi              # src/pmaports fork
```

`src/pmbootstrap` and `src/vendor-kernel` may continue to point to their public
upstreams if they are not modified.

Push the kernel and pmaports branches before pushing a meta-repository commit
that references them.

Example after creating the private GitHub repositories:

```bash
# kernel
cd "$GTAXL_ROOT/src/linux"
git remote add github https://github.com/<github-user>/linux-exynos7870-gtaxlwifi.git
git push -u github port/gtaxlwifi-6.19

# pmaports
cd "$GTAXL_ROOT/src/pmaports"
git remote add github https://github.com/<github-user>/pmaports-gtaxlwifi.git
git push -u github port/gtaxlwifi-6.19
```

Update only the mutable submodule URLs in the meta-repository:

```bash
cd "$GTAXL_ROOT"

git config -f .gitmodules \
  submodule.src/linux.url \
  https://github.com/<github-user>/linux-exynos7870-gtaxlwifi.git

git config -f .gitmodules \
  submodule.src/pmaports.url \
  https://github.com/<github-user>/pmaports-gtaxlwifi.git

git submodule sync
git add .gitmodules
git commit -m "chore: use GitHub mirrors for mutable submodules"
```

Then create/push the private meta-repository:

```bash
git remote add github https://github.com/<github-user>/gtaxlwifi-port.git
git push -u github main
```

Use your normal Git credential manager, SSH authentication, or GitHub CLI.
Never put access tokens directly into repository files.

## 14. GitHub Actions

The workflow in `.github/workflows/build.yml` is intended as a secondary,
reproducibility-oriented builder. Local builds remain the primary fast path.

The workflow runs:

- manually with `workflow_dispatch`;
- on tags matching `r*` or `v*`.

For private submodules, create a repository Actions secret:

```text
SUBMODULES_TOKEN
```

Use a fine-grained GitHub token with **read-only Contents access** to the
private meta, kernel, and pmaports repositories. GitHub's built-in
`GITHUB_TOKEN` is scoped to the current repository and normally cannot clone
another private repository.

Also create:

```text
PMOS_TEST_PASSWORD
```

for the generated test image.

On a tag, the workflow also creates a GitHub Release and attaches the build
outputs. On a manual run, outputs are available as normal Actions artifacts.

Treat CI output as an independent reproduction check. Do not flash a CI image
before verifying its hashes, ZIP integrity, BOOT size, and the commits it was
built from.

## 15. Full offline snapshot

A *literal* snapshot containing every file under the project includes:

- all Git object databases;
- submodule histories;
- build outputs;
- pmbootstrap caches;
- chroots;
- downloaded packages;
- root-owned files.

This will usually be **much larger than 700 MB**.

Before archiving, shut down pmbootstrap mounts:

```bash
cd "$GTAXL_ROOT"
pmb shutdown
```

Verify no mount remains below the project:

```bash
findmnt -R "$GTAXL_ROOT"
```

If the command shows mounted `proc`, `sys`, `dev`, chroot bind mounts, or
similar filesystems below the project, do not create the snapshot yet.

For a literal ZIP preserving symlinks as symlinks:

```bash
cd /workspace

sudo zip \
  -r -y -9 \
  "gtaxlwifi-port-full-$(date +%Y%m%d-%H%M).zip" \
  gtaxlwifi-port
```

Check it:

```bash
unzip -t gtaxlwifi-port-full-*.zip
sha256sum gtaxlwifi-port-full-*.zip
```

### 700 MB media

If the resulting archive exceeds the medium size, a single 700 MB disc cannot
hold a literal full snapshot. Split the ZIP into CD-sized volumes instead:

```bash
cd /workspace

sudo zip \
  -r -y -9 \
  -s 690m \
  "gtaxlwifi-port-full-$(date +%Y%m%d-%H%M).zip" \
  gtaxlwifi-port
```

This creates files such as:

```text
gtaxlwifi-port-full-....z01
gtaxlwifi-port-full-....z02
...
gtaxlwifi-port-full-....zip
```

All parts are required to restore the archive.

A smaller **source snapshot** can exclude `work/` because it is rebuildable,
but that is not a literal "every file" snapshot and must not be confused with
the full archive described above.

## 16. Before publishing publicly

Before changing the GitHub repositories from private to public:

1. inspect the complete Git history, not only the latest tree;
2. remove any secrets/tokens that were ever committed and rotate them;
3. remove personal machine-specific information if undesired;
4. verify licenses and attribution for imported patches;
5. document which functionality is verified and which remains experimental;
6. keep legacy/vendor code clearly identified as reference material;
7. make sure binary artifacts do not contain credentials or private data.

`BUILDING.md`, by design, should be suitable for public publication once the
port itself is ready.
