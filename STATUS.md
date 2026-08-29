# postmarketOS SM-T580 / gtaxlwifi — Port Status

Device: Samsung Galaxy Tab A 10.1 2016 Wi-Fi (`SM-T580`, `gtaxlwifi`)  
SoC: Samsung Exynos 7870  
Current kernel baseline: `6.19.0-rc3-exynos7870+`  
postmarketOS channel: `edge` / systemd  
Current known-good milestone: **r5-cache-debug — first complete Linux 6.19 boot with SSH**

This file records verified observations. Unknown hardware is marked as unknown rather than assumed working.

## r0 — Linux 6.19 baseline

Boot kernel: PASS  
Kernel: `6.19.0-rc3-exynos7870+`  
Bootloader framebuffer: PASS  
simpledrm console: PASS  
postmarketOS initramfs: PASS

Rootfs: FAIL  
Reason: `pmOS_boot` subpartition not found after 10 s

USB gadget: FAIL at the failure path  
Reason observed at the time: no usable UDC / could not bind gadget

Input devices: FAIL/absent at that early failure point  
`/dev/input` absent

Important observation:  
The inherited framebuffer remains usable on 6.19. Native display pipeline has not yet been enabled.

## r1/r2 — persistent early-boot diagnostics

Goal: stop relying on OCR/photos and persist Stage 1 diagnostics to Android `CACHE` (`mmcblk0p20`) for later retrieval through TWRP.

What was learned:

- `initfs-hook.sh` was correctly packaged into the device package and copied into `/hooks/00-device-samsung-gtaxlwifi.sh`.
- The Stage 1 `/init` did **not** execute normal device hooks before trying to mount `pmOS_boot`.
- Therefore the hook existed but was never executed on the failing path.
- A temporary debug-only pmaports branch was created: `debug/gtaxlwifi-stage1-storage`.
- `postmarketos-initramfs` was temporarily patched so only the SM-T580 diagnostic hook runs immediately after `mount_subpartitions()` in Stage 1.
- A packaging trap was found: the modified `postmarketos-initramfs` was first built into the local `x86_64` repo. The SM-T580 rootfs is `aarch64`, so it continued using upstream `3.12.3-r1`. Rebuilding explicitly with `--arch aarch64` fixed this.

These Stage 1 hook changes are diagnostic-only and must not be promoted to the clean port branch.

## r3 — visual Stage 1 storage diagnostics

Because `CACHE` was unavailable on the failing kernel, the diagnostic hook temporarily became an eight-page framebuffer slideshow with timed pauses.

Verified from the photographs:

- `/proc/partitions` did not contain the eMMC.
- `/sys/class/block` contained loop devices but no `mmcblk0`.
- `/dev/mmc*` did not exist.
- Running `mdev -s` did not create the missing eMMC nodes.
- Loop support itself worked.
- The failure therefore occurred before `fdisk`, `losetup`, or postmarketOS subpartition mapping.

Conclusion: the blocking problem was the kernel not successfully bringing up the internal eMMC (`13540000.mmc`).

## 6.15 vs 6.19 comparison — PMIC support regression found

The 6.15 and 6.19 board Device Tree definitions for the eMMC were effectively equivalent; `&mmc0` was already enabled in the 6.19 board DTS.

The important difference was kernel configuration.

Known-working 6.15 configuration included:

```text
CONFIG_I2C=y
CONFIG_I2C_S3C2410=y
CONFIG_REGMAP_I2C=y
CONFIG_MFD_SEC_CORE=y
CONFIG_REGULATOR_S2MPS11=y
```

The initial 6.19 configuration had I2C, but lacked the Samsung PMIC/regulator support and had `CONFIG_REGMAP_I2C=m`.

Linux 6.19 uses the newer Kconfig split where the visible transport driver is `CONFIG_MFD_SEC_I2C`; it selects the hidden/common `CONFIG_MFD_SEC_CORE` and `REGMAP_I2C`.

Validated 6.19 configuration:

```text
CONFIG_I2C=y
CONFIG_I2C_S3C2410=y
CONFIG_MFD_SEC_I2C=y
CONFIG_MFD_SEC_CORE=y
CONFIG_REGMAP_I2C=y
CONFIG_REGULATOR_S2MPS11=y
```

The pmaports fix commit was created with subject:

```text
linux-postmarketos-exynos7870: enable Samsung PMIC support
```

Important build lesson: after compiling a new `.output/arch/arm64/boot/Image`, `pmb build --envkernel` must be run again. A first r4 ZIP accidentally reused an older envkernel APK; comparing the SHA-256 of `.output/.../Image` with rootfs `/boot/vmlinuz` caught this before flashing.

## r5-cache-debug — FIRST COMPLETE 6.19 BOOT

**Result: PASS.**

The kernel boots, postmarketOS finds its subpartitions, reaches normal userspace, displays a console/login screen, and SSH works on `172.16.42.1`.

Verified from `r5-cache-debug`:

### Internal eMMC — PASS

Kernel log:

```text
dwmmc_exynos 13540000.mmc: DW MMC controller at irq 43,64 bit host data width,64 deep fifo
mmc_host mmc0: card is non-removable.
mmc0: new MMC card at address 0001
mmcblk0: mmc0:0001 BJTD4R 29.1 GiB
mmcblk0: p1 p2 p3 p4 p5 p6 p7 p8 p9 p10 p11 p12 p13 p14 p15 p16 p17 p18 p19 p20 p21 p22
```

The PMIC configuration fix restored the internal eMMC and all Android partitions.

### postmarketOS nested partitions — PASS

Stage 1 now finds Android `SYSTEM` (`/dev/mmcblk0p19`) and creates a loop mapping:

```text
SUBPARTITION_DEV=/dev/mmcblk0p19
SUBPARTITION_LOOP=/dev/loop0
PMOS_BOOT=/dev/loop0p1
PMOS_ROOT=/dev/loop0p2
```

`blkid` confirms:

```text
/dev/loop0p1: LABEL="pmOS_boot" TYPE="ext2"
/dev/loop0p2: LABEL="pmOS_root" TYPE="ext4"
```

`part_count=2` and `fdisk` sees the expected 243 MiB boot + ~3.1 GiB root partitions.

Stage 1 successfully performs:

```text
Mount subpartitions of /dev/mmcblk0p19
Mount boot partition (/dev/loop0p1) to /boot (read-only)
Extract /boot/initramfs-extra
PMOS STAGE 2
```

### Root filesystem / userspace — PASS

Normal postmarketOS userspace is reached. A login screen is visible briefly and SSH succeeds:

```text
ssh user@172.16.42.1
Welcome to postmarketOS! o/
```

The earlier `Connection refused` results are not fully proven, but the simplest explanation is that those builds had not reached normal userspace/`sshd` yet (or SSH was attempted before it started). r5 definitively reaches it.

### USB gadget networking — PASS on r5

The initramfs successfully sets up the configfs USB gadget and DHCP/networking:

```text
Setting up USB gadget through configfs
Trying to start server with parameters: Server IP addr: 172.16.42.1:67, client IP addr: 172.16.42.2, interface: usb0
```

SSH over USB networking works after userspace starts.

### Display baseline — PARTIAL PASS

Verified:

- Bootloader framebuffer reserved at `0x67000000`.
- `simpledrm` initializes successfully.
- `fb0` is `simpledrmdrmfb`.
- Console text and the login screen are visible.
- Kernel command line contains `consoleblank=0`.

Current problem:

- The display becomes black a few seconds after the login screen.
- Native `DECON -> DSIM/MIPI-DSI -> panel` bring-up has **not** been started in this 6.19 baseline.
- Because `consoleblank=0` is already present, the normal kernel console blank timer is not the only/obvious explanation. A framebuffer refresh/blanking/userspace transition issue must be tested next.

This distinction remains essential: inherited bootloader framebuffer/simpledrm works; native Exynos display is still a separate future milestone.

### SDIO / Wi-Fi — CARD DETECTED, FUNCTIONAL STATUS UNKNOWN

Kernel log shows:

```text
mmc1: new high speed SDIO card at address 0001
```

This proves the SDIO device is detected. It does **not** prove that `ath10k`, firmware, `wlan0`, association, DHCP, or Internet work on 6.19. Wi-Fi must be tested from the now-working SSH session.

### Input — PARTIAL

Kernel log shows:

```text
input: GPIO Keys as /devices/platform/gpio-keys/input/input0
```

`evdev` is loaded. Touchscreen functionality is still unknown.

### GPU — DRIVER PROBES, POWER MODEL INCOMPLETE

`panfrost` initializes, but the log reports no `mali` regulator and falls back to a dummy regulator. This is not currently a boot blocker and is lower priority than display/Wi-Fi.

### USB power supplies — INCOMPLETE MODEL, FUNCTIONAL GADGET

The USB PHY/DWC3 log still reports missing supply descriptions and uses dummy regulators, but gadget networking works. Clean up later; do not mix it into display bring-up.

## Current Git discipline

Clean development branches should remain:

```text
src/linux:    port/gtaxlwifi-6.19
src/pmaports: port/gtaxlwifi-6.19
meta repo:    main
```

Temporary diagnostic work lives on:

```text
src/pmaports: debug/gtaxlwifi-stage1-storage
```

Only the successful Samsung PMIC kernel-config fix should be promoted from the debug branch to `port/gtaxlwifi-6.19`. The temporary Stage 1 initramfs patch and diagnostic hooks must stay out of the clean branch.

## Next milestone

1. Promote the PMIC configuration fix cleanly.
2. Record/update the meta-repository submodule pointer.
3. Investigate the simpledrm/login-screen-to-black transition over SSH.
4. Verify Wi-Fi on 6.19.
5. Only after the baseline is understood, begin isolated native DSI bring-up.
