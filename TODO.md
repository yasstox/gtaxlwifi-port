# TODO — SM-T580 postmarketOS 6.19

Priorities are ordered so that the newly working display baseline is preserved
before another hardware subsystem is changed.

## P0 — Freeze the current working display checkpoint

- [x] Linux 6.19 full boot.
- [x] Internal eMMC restored through Samsung PMIC support.
- [x] USB gadget networking and SSH.
- [x] simpledrm inherited framebuffer.
- [x] Identify regulator cleanup as the cause of the post-login black screen.
- [x] Force `vdd_ldo25`, `vdd_ldo33` and `vdd_ldo35` on for debugging.
- [x] Verify all three rails remain enabled on real hardware.
- [x] Verify the display remains continuously visible.
- [x] Restore an effective kernel command-line append mechanism.
- [x] Verify `pmos.debug-shell` on real hardware.
- [x] Verify XFCE4 renders on the inherited framebuffer.
- [ ] Push the current `debug/display-regulator` kernel branch.
- [ ] Update/push the meta-repository documentation checkpoint.
- [ ] Record hashes for the last known-good display/XFCE recovery image.
- [ ] Keep a named copy of the successful recovery ZIP, boot.img and DTB.
- [ ] Do not replace this checkpoint until the next image has been verified on
      hardware.

## P0 — Keep debug workarounds clearly separated from final fixes

Current deliberate debug hacks:

```text
vdd_ldo25: regulator-boot-on + regulator-always-on
vdd_ldo33: regulator-boot-on + regulator-always-on
vdd_ldo35: regulator-boot-on + regulator-always-on
```

and the development kernel command-line append implementation used to preserve
the Samsung bootloader arguments while appending `CONFIG_CMDLINE`.

- [ ] Keep these changes on a debug branch while touchscreen bring-up starts.
- [ ] Do not call the regulator workaround the final display power model.
- [ ] Later determine which rails are genuinely required by the panel/display
      path.
- [ ] Replace broad always-on flags with real DT consumers/supplies where
      possible.
- [ ] Decide whether the custom command-line append behavior remains useful
      after bring-up or should be removed.
- [ ] Remove `pmos.debug-shell` from normal images once early-boot debugging is
      no longer required.

## P1 — Touchscreen bring-up

Current status: **FAIL**.

Observed:

```text
rmi4_i2c 1-0070: rmi_set_page: set page failed: -6
rmi4_i2c 1-0070: Failed to set page select to 0
mip4_touchkey 3-0049: Failed to read 4 byte(s)
```

The debug-shell on-screen keyboard appears, but touch input does not work.
XFCE4 also has no touchscreen input.

Reference material:

- current mainline 6.19 DTS/kernel;
- Samsung vendor kernel;
- previous/legacy working postmarketOS recovery image kept locally from the
  earlier port (`pmos-samsung-gtaxlwifi.zip`, 2026-08-27 workspace);
- old 6.15/mainline SM-T580 sources where applicable.

Work in this order:

1. [ ] Collect touchscreen-related nodes from the current 6.19 DTS.
2. [ ] Identify the exact controller used by the previous working image.
3. [ ] Compare I2C bus number/address.
4. [ ] Compare interrupt GPIO and trigger polarity.
5. [ ] Compare reset GPIO and reset timing.
6. [ ] Compare pinctrl states.
7. [ ] Compare regulator/supply names and voltages.
8. [ ] Compare required kernel config options/modules.
9. [ ] Check whether the current RMI4 node is actually appropriate for this
       tablet or inherited from a sibling Exynos7870 device.
10. [ ] Build one touchscreen hypothesis per kernel commit.
11. [ ] Verify `/dev/input/event*`.
12. [ ] Verify raw touch events with `evtest`/equivalent.
13. [ ] Verify coordinate orientation and 1200×1920 mapping in XFCE4.
14. [ ] Only after touch works, investigate the debug-shell on-screen keyboard
       layout issue (currently appears to omit the `m` key).

Do not mix Wi-Fi or native DSI work into touchscreen commits.

## P1 — Make graphical test images easier to use

- [x] XFCE4 displays.
- [ ] Keep a separate console/debug image and XFCE4 image if useful.
- [ ] Disable or avoid Plymouth while it remains unstable; `plymouthd` has
      segfaulted during current boots.
- [ ] Verify XFCE4 display manager/session startup logs.
- [ ] Check framebuffer orientation and DPI/scaling.
- [ ] Check software rendering vs Panfrost acceleration.
- [ ] Once touch works, configure sensible tablet scaling and input rotation.

## P1 — Finalize display power modelling

The black-screen cause is proven: regulator cleanup disabled rails required to
keep the bootloader-initialized panel alive.

Current dirty workaround keeps all three rails on.

Next clean-up experiments must be isolated:

1. [ ] Determine actual display role of LDO25.
2. [ ] Determine actual display role of LDO33.
3. [ ] Reconcile vendor `LCD_1P8` naming for LDO35 with the current 6.19 DT
       voltage constraint/runtime observation of 2.8 V.
4. [ ] Add proper `*-supply` consumers to the inherited
       `simple-framebuffer`/display path where supported.
5. [ ] Remove one `regulator-always-on` at a time and verify the panel remains
       alive.
6. [ ] Reduce the workaround to the minimum required rails.
7. [ ] Preserve a known-good recovery image before every cleanup experiment.

This work is separate from native DSI bring-up.

## P1 — Native display bring-up

Current graphical output still uses the bootloader-initialized framebuffer.

Target:

```text
DECON -> Exynos7870 DSIM/MIPI-DSI -> BOE/Himax8279D panel
```

Milestones:

1. [ ] Enable/test only the DSI host.
2. [ ] Verify `14800000.dsi` binds to the intended Exynos driver.
3. [ ] Verify `/sys/bus/mipi-dsi/devices/` gains the panel device.
4. [ ] Verify panel probe.
5. [ ] Model the real panel supplies.
6. [ ] Verify reset GPIO/pinctrl.
7. [ ] Verify backlight device/power.
8. [ ] Verify DECON gets a CRTC/mode.
9. [ ] Reach native scanout without relying on the Samsung bootloader display
       state.

Do not start these experiments until the current display baseline and
touchscreen work are safely checkpointed.

## P1 — Wi-Fi

Current status: **SDIO card detected, ath10k probe fails**.

Verified:

```text
QCA6174 on mmc1
mmc1: new high speed SDIO card at address 0001
ath10k_sdio module available/loaded in test image
firmware present
```

Current failure:

```text
unable to enable sdio function: -5
could not power on hif bus (-5)
could not probe fw (-5)
```

A `vmmc-supply` experiment did not fix it and was reverted.

Next Wi-Fi work:

1. [ ] Compare vendor CNSS power/reset sequence.
2. [ ] Verify WLAN enable/reset GPIOs (`WLAN_EN`, known vendor lines).
3. [ ] Verify host-wake wiring.
4. [ ] Compare DW-MMC SDIO setup against the previous working 6.15 port.
5. [ ] Enable detailed MMC/SDIO debug for one diagnostic build.
6. [ ] Capture the exact failing CMD52/SDIO operation if possible.
7. [ ] Keep Wi-Fi experiments on their own branch/commits.

Do not claim Wi-Fi PASS until `wlan0`, scan, association, DHCP and actual
network traffic work.

## P2 — Kernel command-line cleanup

The device `kernel-cmdline.conf` path did not affect the effective command line
with the Samsung bootloader.

The current development kernel append mechanism is verified working.

- [ ] Document the exact kernel commit that restores append semantics.
- [ ] Keep the Samsung bootloader command line intact.
- [ ] Do not use `CONFIG_CMDLINE_FORCE` unless deliberately testing a fully
      replaced command line.
- [ ] Decide whether to upstream/generalize the append behavior or keep it as a
      local bring-up patch.
- [ ] Remove obsolete `kernel-cmdline.conf` debug arguments from pmaports once
      they are no longer useful.
- [ ] Keep `console=tty0`, `consoleblank=0`, `pmos.debug-shell`,
      `plymouth.enable=0` and `systemd.show_status=1` only as long as they help
      bring-up.

## P2 — Initramfs cleanup

- [ ] Investigate repeated:

  ```text
  /lib/mdev/persistent-storage: not found
  ```

- [ ] Remove historical Stage 1 diagnostic instrumentation from clean branches.
- [ ] Keep `debug/gtaxlwifi-stage1-storage` only as historical diagnostic work.

## P2 — GPU / regulators

Current:

```text
panfrost ... no regulator (mali) found
supply mali not found, using dummy regulator
```

- [ ] Identify the real GPU rail.
- [ ] Add correct power description.
- [ ] Test Panfrost rendering separately from display/touch work.

## P2 — USB

USB gadget networking works.

- [ ] Identify missing `vbus`, `vbus-boost` and `vdd10` supplies.
- [ ] Investigate OTG host mode only after the current USB gadget debugging
      workflow is no longer critical.
- [ ] Keep USB power cleanup separate from touchscreen/display fixes.

## P2 — Other warnings

Track without mixing into critical hardware commits:

- [ ] `exynos-clkout ... failed with error -22`
- [ ] pinctrl device-link warning
- [ ] bootloader image-alignment warning
- [ ] Samsung x1-x3 ARM64 boot-protocol warning
- [ ] `systemd-firstboot` stdin failure
- [ ] touchkey/regulator warning during failed probe
- [ ] early RTC/time behaviour

## Git / reproducibility

Clean branches:

```text
src/linux:    port/gtaxlwifi-6.19
src/pmaports: port/gtaxlwifi-6.19
meta:         main
```

Current display debug:

```text
/workspace/linux-gtaxlwifi-display
branch: debug/display-regulator
```

- [ ] Push debug branches before moving the meta-repository pointer.
- [ ] Do not point meta `main` at unpushed commits.
- [ ] Keep `.env` untracked.
- [ ] Keep artifacts out of Git; commit SHA256SUMS for important milestones.
- [ ] Compare `.output/.../Image` with rootfs `/boot/vmlinuz` before every
      flash.
- [ ] Decompile and inspect the rootfs DTB for critical DT experiments before
      flashing.
- [ ] Explicitly pass the desired artifact path to `flash-recovery.sh`.
- [ ] Avoid concurrent pmbootstrap builds from Codex/another worktree when they
      share the same pmbootstrap workdir/package repository.

## Documentation checkpoint before touchscreen work

- [x] Update `STATUS.md`.
- [x] Update `TODO.md`.
- [x] Update `BUILDING.md`.
- [x] Update `README.md`.
- [x] Update `INSTALL.md` / manifest.
- [ ] Commit these updates to meta `main` after reviewing the diff.
