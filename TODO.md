# TODO — SM-T580 postmarketOS 6.19

Priorities are ordered to preserve a reproducible baseline and avoid mixing unrelated hardware hypotheses.

## P0 — Promote the known-good boot fix

- [ ] Keep `debug/gtaxlwifi-stage1-storage` as a diagnostic branch.
- [ ] Promote **only** the commit with subject:

  ```text
  linux-postmarketos-exynos7870: enable Samsung PMIC support
  ```

  to `src/pmaports` branch `port/gtaxlwifi-6.19`.
- [ ] Do **not** promote:
  - temporary `postmarketos-initramfs` Stage 1 hook invocation;
  - framebuffer slideshow diagnostics;
  - CACHE logging hook revisions.
- [ ] Push the clean pmaports branch.
- [ ] Pull/rebase the meta repo `main` first, because the GitHub Actions workflow was edited on GitHub.
- [ ] Update the meta-repo pmaports submodule pointer to the new clean commit.
- [ ] Commit/push `STATUS.md`, `TODO.md`, scripts and `.env.example` from the meta repo.
- [ ] Keep `.env` untracked.
- [ ] Consider a milestone tag only after the clean branch rebuild has been reproduced without the debug-only initramfs patch.

## P0 — Establish a clean r6 / known-good reproduction

The current r5 boot proves the hardware fix, but it still contains diagnostic pmaports changes.

- [ ] Build the clean pmaports branch with PMIC fix only.
- [ ] Clean kernel build from the tracked pmaports config.
- [ ] Verify these options after `olddefconfig`:

  ```text
  CONFIG_I2C=y
  CONFIG_I2C_S3C2410=y
  CONFIG_MFD_SEC_I2C=y
  CONFIG_MFD_SEC_CORE=y
  CONFIG_REGMAP_I2C=y
  CONFIG_REGULATOR_S2MPS11=y
  ```

- [ ] Run `pmb build --envkernel` **after** compiling the new Image.
- [ ] Verify `.output/arch/arm64/boot/Image` SHA-256 equals the kernel APK `boot/vmlinuz`.
- [ ] After `pmb install`, verify the same SHA-256 equals rootfs `/boot/vmlinuz`.
- [ ] Generate, validate and archive a clean recovery ZIP.
- [ ] Boot it and confirm SSH again.

## P1 — Display turns black after login

Known facts:

- simpledrm works;
- framebuffer console works;
- login screen is visible;
- command line already contains `consoleblank=0`;
- native Exynos DSI is not yet the active display path.

First SSH tests after the screen becomes black:

```bash
cat /proc/cmdline
cat /proc/consoles
ls -la /sys/class/graphics/fb0
cat /sys/class/graphics/fb0/name
cat /sys/class/graphics/fb0/virtual_size
cat /sys/class/graphics/fb0/blank 2>/dev/null || true
ls -la /sys/class/vtconsole
systemctl status getty@tty1 --no-pager
journalctl -b --no-pager | tail -300
```

Refresh tests (one at a time, observe screen after each):

```bash
echo 0 | sudo tee /sys/class/graphics/fb0/blank

echo 0,0 | sudo tee /sys/class/graphics/fb0/pan
```

Check whether the historical workaround is installed/running:

```bash
command -v msm-fb-refresher || true
pgrep -af msm-fb-refresher || true
```

If present but not running, test it temporarily. If a forced pan/refresh immediately restores the picture, classify the issue as an inherited-framebuffer refresh problem rather than kernel console blanking.

Also investigate:

- [ ] `Warning: unable to open an initial console.`
- [ ] inherited Samsung `console=ram` command line;
- [ ] whether `console=tty0` should be appended in the kernel config for this bootloader;
- [ ] `tee: /dev/: Is a directory` in Stage 1 logging, likely related to console selection/parsing.

Do not begin native DSI changes until this baseline behavior is captured.

## P1 — Verify Wi-Fi on 6.19

SDIO card detection is confirmed, but Wi-Fi functionality is not.

Over SSH:

```bash
ip link
ip addr
dmesg | grep -iE 'ath10k|wlan|firmware|mmc1|sdio'
lsmod | grep -E 'ath10k|cfg80211|mac80211'
rfkill list 2>/dev/null || true
```

Then verify, in order:

- [ ] `ath10k_sdio` binds;
- [ ] firmware loads;
- [ ] `wlan0` exists;
- [ ] scan works;
- [ ] association works;
- [ ] DHCP works;
- [ ] DNS/ping works.

Do not claim Wi-Fi PASS until these are tested on 6.19.

## P1 — Native display bring-up (after baseline checks)

Target chain:

```text
DECON -> Exynos7870 DSIM/MIPI-DSI -> boe,himax8279d10p panel
```

Isolated milestones:

1. [ ] Enable/test only the DSI host.
2. [ ] Verify `14800000.dsi` binds to the expected Exynos DSI driver.
3. [ ] Verify `/sys/bus/mipi-dsi/devices/` gains the panel device.
4. [ ] Verify panel probe.
5. [ ] Verify `LCD_1P8` consumer/power path.
6. [ ] Verify reset GPIO/pinctrl.
7. [ ] Verify backlight device/power.
8. [ ] Confirm DECON gets a CRTC/mode and native scanout.

At every step, record whether the inherited simpledrm console remains visible or disappears.

## P2 — Initramfs cleanup

r5 Stage 1 logs repeatedly contain:

```text
/lib/mdev/persistent-storage: not found
```

Boot still succeeds, so this is not the current blocker.

- [ ] Determine whether the Stage 1 mdev config references a helper that only exists in `initramfs-extra`.
- [ ] Decide whether this is an upstream packaging issue or a local debug artifact.
- [ ] Remove the temporary Stage 1 diagnostic patch once clean boot reproduction is confirmed.

## P2 — Input

- [x] GPIO keys register as `input0`.
- [x] `evdev` loads.
- [ ] List `/dev/input/event*` after normal userspace boot.
- [ ] Identify touchscreen controller and driver.
- [ ] Verify touch coordinates/orientation.

## P2 — GPU / regulators

Current log:

```text
panfrost ... no regulator (mali) found
supply mali not found, using dummy regulator
```

- [ ] Identify the correct GPU rail in vendor DTS/reference kernel.
- [ ] Model it only after display and Wi-Fi baseline work.
- [ ] Test Panfrost rendering after power description is correct.

## P2 — USB power description

Current warnings include missing USB PHY/DWC3 supplies, but USB gadget networking works.

- [ ] Identify `vbus`, `vbus-boost`, and `vdd10` supplies.
- [ ] Compare vendor/mainline Exynos7870 DTS.
- [ ] Keep this separate from display work unless it becomes a functional blocker.

## P2 — Other kernel warnings

Track but do not mix into critical fixes:

- [ ] `exynos-clkout ... failed with error -22`.
- [ ] pinctrl device-link warning.
- [ ] bootloader image alignment warning.
- [ ] Samsung bootloader x1-x3 protocol warning.
- [ ] RTC/time starts at Unix epoch in early initramfs; verify normal userspace time sync/RTC.

## CI / GitHub

- [ ] Pull the workflow edits made through GitHub before the next meta-repo push.
- [ ] Confirm the workflow adds an official postmarketOS `upstream` remote to `src/pmaports` after checkout.
- [ ] Confirm the runner builds modified `noarch` pmaports packages into the **aarch64** local repo when they are needed by the aarch64 rootfs.
- [ ] Confirm CI verifies the built kernel Image hash against the packaged/rootfs `vmlinuz`.
- [ ] Confirm Actions artifacts contain recovery ZIP, boot.img, DTB, vmlinuz, SHA256SUMS and build metadata.
