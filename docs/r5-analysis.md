# r5-cache-debug analysis

Source: `r5-cache-debug.zip`, captured from the SM-T580 after enabling Samsung PMIC support in the 6.19 kernel configuration.

## Executive result

r5 is the first verified complete postmarketOS boot on the new 6.19 baseline.

The PMIC configuration fix restored the internal eMMC, allowing postmarketOS Stage 1 to find Android `SYSTEM`, expose the nested `pmOS_boot` and `pmOS_root` partitions through `/dev/loop0`, extract `initramfs-extra`, enter Stage 2, and eventually reach normal userspace/SSH.

## Storage evidence

`dmesg`:

```text
dwmmc_exynos 13540000.mmc: DW MMC controller at irq 43,64 bit host data width,64 deep fifo
mmc_host mmc0: card is non-removable.
mmc0: new MMC card at address 0001
mmcblk0: mmc0:0001 BJTD4R 29.1 GiB
mmcblk0: p1 p2 p3 p4 p5 p6 p7 p8 p9 p10 p11 p12 p13 p14 p15 p16 p17 p18 p19 p20 p21 p22
```

The full Android partition table is present. `SYSTEM` is `mmcblk0p19`; `CACHE` is `mmcblk0p20`.

The nested postmarketOS image is detected correctly:

```text
/dev/loop0: [0006]:672 (/dev/mmcblk0p19)
/dev/loop0p1: LABEL="pmOS_boot" TYPE="ext2"
/dev/loop0p2: LABEL="pmOS_root" TYPE="ext4"
```

The diagnostic summary reports:

```text
PMOS_ROOT=/dev/loop0p2
PMOS_BOOT=/dev/loop0p1
SUBPARTITION_DEV=/dev/mmcblk0p19
SUBPARTITION_LOOP=/dev/loop0
```

## Initramfs evidence

`pmOS_init.log`:

```text
Trying to mount subpartitions for 10 seconds...
Mount subpartitions of /dev/mmcblk0p19
gtaxlwifi-debug: diagnostics saved to CACHE
Mount boot partition (/dev/loop0p1) to /boot (read-only)
Extract /boot/initramfs-extra
❬❬ PMOS STAGE 2 ❭❭
```

The original r0 blocker is therefore resolved.

## USB gadget

The r5 dmesg/initramfs shows successful configfs gadget setup and DHCP server startup on `usb0`. The user subsequently established SSH to `user@172.16.42.1`, confirming the USB networking path is functional on r5.

## Display

Early display path:

```text
[drm] Initialized simpledrm ... for 67000000.framebuffer
Console: switching to colour frame buffer device 150x120
simple-framebuffer 67000000.framebuffer: [drm] fb0: simpledrmdrmfb frame buffer device
```

The inherited bootloader framebuffer remains functional on 6.19. A login screen is visible, then the panel becomes black a few seconds later.

The captured command line already contains:

```text
consoleblank=0
```

Linux documents `consoleblank=0` as disabling the normal console blank timer. Therefore the next test should distinguish framebuffer refresh/userspace blanking from the standard kernel console blank timer.

Recommended first tests over SSH after the display turns black:

```bash
echo 0 | sudo tee /sys/class/graphics/fb0/blank
echo 0,0 | sudo tee /sys/class/graphics/fb0/pan
command -v msm-fb-refresher || true
pgrep -af msm-fb-refresher || true
```

A successful `pan`/refresher wake-up would strongly point to an inherited-framebuffer refresh quirk.

## Wi-Fi

The kernel sees an SDIO device:

```text
mmc1: new high speed SDIO card at address 0001
```

This does not establish Wi-Fi functionality. No r5 evidence yet proves `ath10k_sdio` binding, firmware loading, `wlan0`, association, or IP connectivity.

## Input

The kernel registers GPIO keys:

```text
input: GPIO Keys as /devices/platform/gpio-keys/input/input0
```

The `evdev` module is loaded. Touchscreen remains unverified.

## Remaining warnings worth tracking

Not current boot blockers:

```text
panfrost ... no regulator (mali) found
exynos5_usb3drd_phy ... supply vbus not found, using dummy regulator
exynos5_usb3drd_phy ... supply vbus-boost not found, using dummy regulator
exynos-dwc3 ... supply vdd10 not found, using dummy regulator
exynos-clkout ... failed with error -22
Warning: unable to open an initial console.
```

Stage 1 also repeatedly reports a missing `/lib/mdev/persistent-storage` helper. Because r5 boots successfully, handle this as cleanup rather than mixing it into display work.
