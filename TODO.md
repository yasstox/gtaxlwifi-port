# TODO — SM-T580 postmarketOS 6.19

Only unfinished work is listed here. Completed bring-up work belongs in Git history, not the TODO.

## P0 — Touchscreen

- Identify the exact touchscreen controller used by the SM-T580.
- Compare current DT against vendor/older working sources: I2C address, IRQ, reset GPIO, pinctrl and supplies.
- Fix the current RMI4 I2C failure.
- Verify raw input events and coordinate/orientation mapping in XFCE4.
- Fix touchkey communication separately if needed.

## P1 — Native display

Target:

```text
DECON -> Exynos7870 DSIM/MIPI-DSI -> BOE/Himax8279D panel
```

- Bind and validate the DSI host.
- Register/probe the panel on the MIPI-DSI bus.
- Model panel supplies, reset and backlight correctly.
- Reach native scanout without depending on the bootloader framebuffer.

## P1 — Display power cleanup

- Determine the real consumers for `vdd_ldo25`, `vdd_ldo33` and `vdd_ldo35`.
- Replace the current broad `regulator-always-on` workaround with proper DT supply relationships.
- Reconcile the current LDO35 voltage/model with vendor `LCD_1P8` naming.

## P1 — GPU power

- Identify the real Mali-T830 regulator.
- Add the correct `mali` supply / OPP power model.
- Revalidate Panfrost after removing the dummy-regulator fallback.

## P2 — Bluetooth / USB

- Bring up Bluetooth and identify its power/reset/transport requirements.
- Model missing USB supplies.
- Test OTG host mode once USB gadget networking is no longer required for every debug session.

## P2 — Development cleanup

- Remove or simplify the custom kernel command-line append patch when no longer needed.
- Investigate duplicated development arguments in the effective kernel command line.
- Keep Plymouth out of the critical path while it remains unreliable.
- Track remaining non-blocking clock/pinctrl/bootloader warnings only when they become relevant.

## Git / reproducibility

- Keep clean kernel fixes on `port/gtaxlwifi-6.19`.
- Keep clean pmaports fixes on `port/gtaxlwifi-6.19`.
- Keep temporary display hacks on `debug/display-regulator` until replaced.
- Do not run concurrent pmbootstrap packaging/install jobs against the shared workdir.
- Before flashing, verify that the packaged `vmlinuz` and DTB come from the intended worktree.
