# postmarketOS for Samsung Galaxy Tab A 10.1 2016 (SM-T580)

Main development repository for the `samsung-gtaxlwifi` postmarketOS port on the Samsung Exynos 7870 platform.

The goal is a maintainable Linux 6.19-based port with as much hardware support as possible.

## Current status

| Component | Status | Notes |
| --- | --- | --- |
| Linux 6.19 boot | PASS | Full boot into postmarketOS/systemd |
| Internal eMMC / rootfs | PASS | `pmOS_boot` and `pmOS_root` work from Android `SYSTEM` |
| USB gadget + SSH | PASS | Main development connection |
| Wi-Fi | PASS | QCA9377, SDIO High-Speed 50 MHz, 2.4/5 GHz, IPv4/IPv6 |
| Display | PARTIAL | Bootloader framebuffer via `simpledrm`; XFCE4 works |
| GPU | PARTIAL | Mali-T830 + Panfrost + Mesa/glamor acceleration; power rail not modelled |
| GPIO keys | PASS | Input events available |
| Touchscreen | FAIL | Current RMI4 I2C communication fails |
| Native display | TODO | DECON -> DSIM/MIPI-DSI -> panel not yet brought up |
| Bluetooth | TODO | Not brought up yet |

The current graphical development baseline still depends on the Samsung bootloader having initialized the display and on a temporary display-regulator workaround. It is not native display support.

See:

- `STATUS.md` for the current verified state;
- `TODO.md` for remaining work;
- `BUILDING.md` for the current build/flash workflow;
- `WIFI.md` for the final Wi-Fi implementation summary.

## Repository layout

This is a meta-repository using Git submodules:

```text
src/linux          Exynos7870 / SM-T580 kernel fork
src/pmaports       postmarketOS device and kernel packaging
src/pmbootstrap    upstream pmbootstrap
src/vendor-kernel  Samsung/vendor reference source
```

The meta-repository records exact submodule revisions for reproducible checkpoints.

Main development branches:

```text
src/linux:    port/gtaxlwifi-6.19
src/pmaports: port/gtaxlwifi-6.19
meta:         main
```

Current display integration worktree:

```text
/workspace/linux-gtaxlwifi-display
debug/display-regulator
```

## Development model

Hardware work is kept incremental: one subsystem or hardware hypothesis per commit where practical. Working fixes are promoted to the clean branches; temporary bring-up hacks remain on debug branches.

The Git history is the development log. Documentation intentionally describes the current state instead of preserving every failed experiment.

## Upstream / reference projects

- Exynos7870 mainline Linux: `https://gitlab.com/exynos7870-mainline/linux`
- postmarketOS pmaports: `https://gitlab.postmarketos.org/postmarketOS/pmaports`
- pmbootstrap: `https://gitlab.postmarketos.org/postmarketOS/pmbootstrap`
- Earlier SM-T580 mainline work: `https://gitlab.com/randwardatake/mainline-samsung-gtaxlwifi`
- Samsung vendor-kernel reference: `https://github.com/Yusuf6411/Kernel_SM-T580_gtaxlwifi`

## Licensing

Files written for this meta-repository are licensed under GPL-3.0-only. Submodules and imported/derived upstream code retain their original licenses and attribution requirements.
