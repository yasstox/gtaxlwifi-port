# Wi-Fi — SM-T580 / gtaxlwifi

Status: **PASS**.

## Implementation

- Chip: Qualcomm QCA9377 hw1.1 (`SDIO_ID=0271:0701`).
- Transport: SDIO on `mmc1`, 4-bit SD High-Speed at 50 MHz / 3.3 V signalling.
- Driver: `ath10k_sdio`.
- Firmware package: `linux-firmware-ath10k`.
- WLAN 3.3 V rail: `cnss_dcdc_en`, controlled by `gpa0-6`, exposed as `mmc1` `vmmc-supply` with a 4 ms startup delay.
- `gpd3-6` remains the WLAN enable/reset line through `mmc-pwrseq-simple`.

2.4 GHz and 5 GHz scanning, association, IPv4/IPv6 and real Internet traffic are verified on hardware.

ath10k currently falls back successfully to board API 1 when no exact `board-2.bin` tuple matches the device. This is non-blocking.

No active Wi-Fi bring-up work is planned.
