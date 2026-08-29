# postmarketOS SM-T580 / gtaxlwifi — Port Status

Device: Samsung Galaxy Tab A 10.1 2016 Wi-Fi (`SM-T580`, `gtaxlwifi`)  
SoC: Samsung Exynos 7870  
Current kernel baseline: `6.19.0-rc3-exynos7870+`  
postmarketOS channel: `edge` / systemd  
Current verified development state: **full Linux 6.19 boot, USB SSH, persistent simpledrm display, working debug shell, and XFCE4 rendering**

This file records verified observations from real-device tests. Unknown hardware is
marked as unknown rather than assumed working. Temporary debug workarounds are
explicitly identified as such.

## Summary

Verified working:

- Linux 6.19 boots on the SM-T580.
- Samsung PMIC support is sufficient for internal eMMC bring-up.
- postmarketOS finds `pmOS_boot` and `pmOS_root` inside Android `SYSTEM`.
- Normal userspace reaches `graphical.target`.
- USB gadget networking works at `172.16.42.1`.
- OpenSSH works over USB networking.
- The bootloader-provided framebuffer is inherited by `simpledrm`.
- Console output remains visible when the required display rails are prevented
  from being disabled.
- A kernel-side command-line append mechanism is verified working.
- `pmos.debug-shell` is verified working and presents an initramfs shell on the
  tablet framebuffer.
- XFCE4 renders successfully on the inherited framebuffer.

Not yet working / incomplete:

- The display fix is currently a **debug workaround**, not a final power model.
- Native `DECON -> DSIM/MIPI-DSI -> panel` scanout is not implemented yet.
- Touchscreen input does not work.
- Wi-Fi does not yet create `wlan0`; ath10k SDIO currently fails while enabling
  SDIO function 1 with `-EIO`.
- USB OTG keyboard input is not available while the USB controller is being used
  as the postmarketOS gadget/debug connection.
- GPU power supplies, USB supplies, touch/touchkey supplies and several smaller
  hardware descriptions are incomplete.

---

## r0 — Linux 6.19 baseline

Boot kernel: PASS  
Kernel: `6.19.0-rc3-exynos7870+`  
Bootloader framebuffer: PASS  
simpledrm console: PASS  
postmarketOS initramfs: PASS

Rootfs: FAIL  
Reason: `pmOS_boot` subpartition not found after 10 s.

At that point the internal eMMC was not being brought up, so the Android
`SYSTEM` partition and nested postmarketOS partitions were unavailable.

## r1/r2 — persistent early-boot diagnostics

Goal: stop relying on photographs/OCR and persist Stage 1 diagnostics.

Verified findings:

- the device initramfs hook was packaged correctly;
- the normal device hook was not executed before the failing subpartition lookup;
- temporary Stage 1 instrumentation was therefore added on a diagnostic pmaports
  branch;
- modified `postmarketos-initramfs` packages must be built for the target
  `aarch64` repository, not only the host `x86_64` repository.

These Stage 1 changes are diagnostic-only and must not be promoted to the clean
port.

## r3 — visual Stage 1 storage diagnostics

An eight-page framebuffer slideshow was used while persistent logging was not
available.

Verified:

- `/proc/partitions` did not contain the internal eMMC;
- `/sys/class/block` had loop devices but no `mmcblk0`;
- `/dev/mmc*` was absent;
- `mdev -s` did not create the missing block device;
- loop support itself worked.

Conclusion: failure occurred before postmarketOS partition mapping. The kernel
was not successfully bringing up internal eMMC.

## 6.15 vs 6.19 — PMIC configuration regression

The important difference between the old working baseline and the initial 6.19
port was kernel configuration, not the eMMC Device Tree node itself.

Validated 6.19 configuration:

```text
CONFIG_I2C=y
CONFIG_I2C_S3C2410=y
CONFIG_MFD_SEC_I2C=y
CONFIG_MFD_SEC_CORE=y
CONFIG_REGMAP_I2C=y
CONFIG_REGULATOR_S2MPS11=y
```

The pmaports fix commit uses the subject:

```text
linux-postmarketos-exynos7870: enable Samsung PMIC support
```

Important packaging lesson: after compiling a new
`.output/arch/arm64/boot/Image`, `pmbootstrap build --envkernel` must be run
again. Compare the source `Image` SHA-256 with rootfs `/boot/vmlinuz` before
flashing.

## r5-cache-debug — first complete Linux 6.19 boot

**Result: PASS.**

Verified:

### Internal eMMC — PASS

```text
mmc0: new MMC card at address 0001
mmcblk0: mmc0:0001 BJTD4R 29.1 GiB
```

All expected Android partitions become visible.

### Nested postmarketOS partitions — PASS

Android `SYSTEM` is mapped through a loop device and exposes:

```text
/dev/loop0p1: LABEL="pmOS_boot"
/dev/loop0p2: LABEL="pmOS_root"
```

Stage 1 reaches Stage 2 and normal userspace.

### Rootfs / userspace — PASS

`systemd` reaches normal userspace and OpenSSH starts.

### USB gadget networking — PASS

USB gadget networking provides:

```text
tablet: 172.16.42.1
host:   172.16.42.2
```

SSH over this link is reliable enough for development.

---

## Display investigation — simpledrm black-screen root cause

### Initial symptom

The bootloader framebuffer at `0x67000000` is inherited successfully:

```text
[drm] Initialized simpledrm 1.0.0 for 67000000.framebuffer
simple-framebuffer 67000000.framebuffer: [drm] fb0: simpledrmdrmfb frame buffer device
```

The console/login screen appears, but the panel turns black roughly 34 seconds
after boot.

While black:

```text
/proc/fb:                       0 simpledrmdrmfb
/sys/class/graphics/fb0/name:  simpledrmdrmfb
virtual_size:                  1200,1920
DRM connector:                 connected
fb0 blank:                     4
```

Manual fbdev tests did not restore the picture:

```text
echo 0 > /sys/class/graphics/fb0/blank
echo 0,0 > /sys/class/graphics/fb0/pan
chvt 2 ; chvt 1
```

### Regulator cleanup correlation

The kernel consistently logged:

```text
vdd_ldo25: disabling
vdd_ldo33: disabling
vdd_ldo35: disabling
```

at approximately 33.77 seconds, matching the physical display shutdown.

The relevant current board DTS constraints are:

```text
vdd_ldo25: variable range, runtime observed at 1.8 V
vdd_ldo33: 3.3 V
vdd_ldo35: 2.8 V
```

Vendor reference material identifies LDO35 as display-related (`LCD_1P8`), but
the voltage/model discrepancy still needs to be understood before a final
power description is written.

### Failed command-line experiment

A device `kernel-cmdline.conf` was built containing:

```text
console=tty0
consoleblank=0
pmos.debug-shell
regulator_ignore_unused
```

but the Samsung boot path did not propagate these additions to
`/proc/cmdline`.

This experiment was initially complicated by a stale local
`device-samsung-gtaxlwifi` APK with a higher `pkgrel`. After rebuilding with a
higher package revision, the expected file was verified inside the rootfs, but
the booted kernel command line still remained the Samsung-provided one.

Conclusion: for this device, `kernel-cmdline.conf` is not a reliable way to add
development kernel arguments to the effective command line.

### Working display debug workaround

On kernel branch/worktree:

```text
debug/display-regulator
```

the SM-T580 DTS was modified so these three regulators contain:

```dts
regulator-boot-on;
regulator-always-on;
```

for:

```text
vdd_ldo25
vdd_ldo33
vdd_ldo35
```

The final compiled DTB was decompiled and checked before packaging to verify
that all six properties were actually present.

**Hardware result: PASS.**

The panel no longer turns black. After boot:

```text
===== LDO25 =====
enabled
1800000
1

===== LDO33 =====
enabled
3300000
1

===== LDO35 =====
enabled
2800000
1
```

This proves that the black-screen transition was caused by display-related
power rails being released by the regulator framework.

This is intentionally a **dirty debug baseline**, not the final solution.
The final port should model the correct display consumers/supplies and keep only
the rails that are genuinely required.

---

## Kernel command line — working debug method

The current arm64 6.19 tree only exposed:

```text
CONFIG_CMDLINE_FROM_BOOTLOADER
CONFIG_CMDLINE_FORCE
```

and did not provide the historical `CONFIG_CMDLINE_EXTEND` behavior previously
used by this port.

A development-only kernel patch restores an append mode: the Samsung bootloader
command line is preserved and `CONFIG_CMDLINE` is appended by the kernel before
normal parameter parsing.

Verified development command line includes:

```text
console=tty0
consoleblank=0
pmos.debug-shell
plymouth.enable=0
systemd.show_status=1
```

**Hardware result: PASS.**

`pmos.debug-shell` is now honored and postmarketOS stops in its initramfs debug
shell. The tablet framebuffer shows the postmarketOS debug-shell interface,
including its on-screen keyboard.

Boot can be resumed with:

```sh
pmos_continue_boot
```

This method is currently preferred for development because it is deterministic
on the SM-T580 bootloader. It should remain a debug patch until the long-term
boot-command-line strategy is decided.

---

## XFCE4 display test — PASS

A postmarketOS XFCE4 rootfs was built using the same kernel/display debug
baseline.

Observed sequence:

1. early kernel/simpledrm console;
2. postmarketOS debug shell when enabled;
3. after continuing boot, a short console/login phase;
4. roughly ten seconds of black screen while graphical userspace starts;
5. XFCE4 desktop appears successfully.

**Result: XFCE4 renders on the 1200×1920 inherited framebuffer.**

This confirms that the inherited bootloader framebuffer + simpledrm path is
sufficient for a graphical X11 desktop during bring-up.

It does **not** mean native Exynos display support is complete. The screen is
still being kept alive by the temporary always-on regulator workaround and the
scanout is still inherited from the bootloader.

Plymouth has also been observed crashing (`plymouthd` SIGSEGV) on the console
baseline. During development it is preferable to keep Plymouth disabled or out
of the critical display path.

---

## Input status

### GPIO keys — PASS

GPIO keys register and produce an input event device.

### Touchscreen — FAIL

The touchscreen does not currently respond, including in the postmarketOS
debug-shell on-screen keyboard and in XFCE4.

Relevant kernel failures include:

```text
rmi4_i2c 1-0070: rmi_set_page: set page failed: -6
rmi4_i2c 1-0070: Failed to set page select to 0
```

The touchkey driver also fails communication:

```text
mip4_touchkey 3-0049: Failed to read 4 byte(s)
```

The debug-shell on-screen keyboard is rendered correctly enough to be visible,
but it cannot be operated because touch input is not working. Its current
layout also appears to omit the `m` key; this is a debug-shell UI/layout quirk,
not evidence about the physical touchscreen itself.

A legacy/original recovery image from the previous working port has been kept
locally and should be used later as a reference when comparing touchscreen
drivers, DT nodes, supplies, pinctrl and I2C configuration.

### USB OTG keyboard — not currently available in debug setup

During initramfs/debugging the USB controller is used as a USB gadget for
networking/log access. A normal USB OTG keyboard therefore cannot currently be
used as an input workaround in that configuration.

---

## Wi-Fi status — SDIO detected, ath10k probe blocked

Hardware identified:

```text
Qualcomm QCA6174
transport: SDIO on mmc1
```

SDIO detection is reliable:

```text
mmc1: new high speed SDIO card at address 0001
```

A test image enabled:

```text
CONFIG_ATH10K=m
CONFIG_ATH10K_SDIO=m
linux-firmware-ath10k
```

The ath10k modules load and the QCA6174 SDIO firmware is present, but no
`wlan0` is created.

Current failure:

```text
ath10k_sdio mmc1:0001:1: unable to enable sdio function: -5
ath10k_sdio mmc1:0001:1: could not power on hif bus (-5)
ath10k_sdio mmc1:0001:1: could not probe fw (-5)
```

An experimental WLAN regulator mapping as `vmmc-supply` did not change the
failure and was reverted.

Current conclusion: Wi-Fi is blocked during SDIO function enablement, not by
missing ath10k modules, missing firmware, or failure to enumerate the SDIO card.

Keep Wi-Fi work separate from the display/touchscreen branch.

---

## GPU

Panfrost probes, but the GPU power model is incomplete:

```text
panfrost ... no regulator (mali) found
supply mali not found, using dummy regulator
```

This is not currently a boot/display blocker.

## USB

USB gadget networking works despite incomplete supply modelling.

Warnings for missing USB PHY/DWC3 supplies remain cleanup work.

## Known non-blocking warnings / issues

Current logs include:

- Samsung bootloader x1-x3 ARM64 boot-protocol warning;
- kernel image alignment warning from the old bootloader;
- `exynos-clkout` probe failure `-22`;
- pinctrl device-link warning;
- repeated `/lib/mdev/persistent-storage: not found` during early initramfs;
- `systemd-firstboot` failure due missing stdin;
- Plymouth crash on the console baseline;
- touch/touchkey I2C failures;
- regulator warning during failed touchkey probe.

Do not mix these into unrelated fixes unless one becomes a demonstrated blocker.

---

## Current Git discipline

Clean development branches:

```text
src/linux:    port/gtaxlwifi-6.19
src/pmaports: port/gtaxlwifi-6.19
meta repo:    main
```

Active display debug work:

```text
kernel worktree: /workspace/linux-gtaxlwifi-display
kernel branch:   debug/display-regulator
```

Historical diagnostic pmaports work:

```text
debug/gtaxlwifi-stage1-storage
```

The regulator always-on patch and kernel command-line append implementation are
development/debug changes. Do not silently promote them to the clean port as
final hardware modelling.

---

## Next milestone

Before starting touchscreen bring-up:

1. update and commit the project documentation;
2. record/push the verified display debug checkpoint;
3. preserve the successful XFCE4 observation;
4. keep the current display workaround available as the known-good development
   baseline.

Then:

1. compare touchscreen support against the previous working recovery/vendor
   references;
2. identify the exact touchscreen controller, supplies, reset/IRQ GPIOs and
   pinctrl;
3. fix touchscreen I2C communication;
4. only afterwards return to cleanup of the display power model/native DSI path
   or Wi-Fi as separate workstreams.
