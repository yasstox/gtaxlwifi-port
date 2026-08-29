# SM-T580 / gtaxlwifi — current status

Device: Samsung Galaxy Tab A 10.1 2016 Wi-Fi (`SM-T580`, `gtaxlwifi`)  
SoC: Samsung Exynos 7870  
Kernel baseline: Linux `6.19.0-rc3-exynos7870+`  
postmarketOS: `edge`, systemd

This file only tracks the current verified state. Historical bring-up details remain in Git history.

## Working

- Full Linux 6.19 boot and normal systemd userspace.
- Internal eMMC and postmarketOS partitions inside Android `SYSTEM`.
- USB gadget networking and SSH.
- GPIO keys.
- Bootloader framebuffer inherited by `simpledrm` at 1200x1920.
- XFCE4 rendering on the inherited framebuffer.
- Mali-T830 detected by Panfrost; `/dev/dri/renderD128` exists.
- Mesa/glamor uses `Mali-T830 MC1 (Panfrost)` for X acceleration.
- Qualcomm QCA9377 Wi-Fi over SDIO with `ath10k_sdio`.
- Wi-Fi SD High-Speed at 50 MHz, 2.4 GHz and 5 GHz scanning, association, IPv4/IPv6 and Internet traffic.

## Incomplete / not working

### Touchscreen

Current RMI4 communication fails on I2C:

```text
rmi4_i2c 1-0070: rmi_set_page: set page failed: -6
rmi4_i2c 1-0070: Failed to set page select to 0
```

Touchkeys also fail communication.

### Display

The current visible display is still the framebuffer initialized by the Samsung bootloader. Native:

```text
DECON -> DSIM/MIPI-DSI -> panel
```

is not working yet.

The current display integration branch temporarily keeps `vdd_ldo25`, `vdd_ldo33` and `vdd_ldo35` enabled. This is a bring-up workaround, not the final power model.

### GPU power

Panfrost works, but the DT does not provide its real `mali` regulator yet:

```text
panfrost ... no regulator (mali) found
supply mali not found, using dummy regulator
```

### Other

- Bluetooth has not been brought up yet.
- USB OTG/host-mode support is not yet part of the normal development setup.
- The custom arm64 command-line append patch is still a development aid and needs cleanup.

## Current integration branches

```text
clean kernel:   port/gtaxlwifi-6.19
clean pmaports: port/gtaxlwifi-6.19
display debug:  debug/display-regulator
meta:           main
```

The meta-repository should point at a verified integration checkpoint, while clean fixes remain independently available on their clean branches.
