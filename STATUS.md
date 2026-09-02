# SM-T580 / gtaxlwifi — current status

Device: Samsung Galaxy Tab A 10.1 2016 Wi-Fi (`SM-T580`, `gtaxlwifi`)<br>
SoC: Samsung Exynos 7870<br>
Kernel baseline: Linux `7.1.0-rc2`<br>
postmarketOS: `edge`, systemd

## Working

- Full boot and normal systemd userspace from internal eMMC.
- USB gadget networking and SSH.
- Qualcomm QCA9377 Wi-Fi through `ath10k_sdio`.
- Native SM-T580 DECON -> DSIM/MIPI-DSI -> HX8279D display pipeline.
- HX8279D panel backlight control and corrected LCD 1.8 V supply.
- Legacy Samsung STMFTS touchscreen support.
- Mali-T830 through Panfrost with Mesa/glamor acceleration.
- GPIO keys and SM5703 fuel gauge.

## Incomplete

- CPU/GPU performance and DVFS tuning are still being refined.
- Bluetooth and normal USB OTG/host-mode support remain to be brought up.

## Integration branches

```text
kernel base:    exynos7870/7.1
kernel port:    port/gtaxlwifi-7.1
pmaports port:  port/gtaxlwifi-7.1
meta:           main
```

The recorded kernel checkpoint is `f6fc5b0eb294678c56ee33b0df142eeb8a046065`,
which is nine commits ahead of `exynos7870/7.1`.
