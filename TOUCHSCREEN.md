# Touchscreen bring-up checkpoint — SM-T580 / gtaxlwifi

Status: **not working yet**, but the hardware identification is now much clearer.

This file is a resume point for the current experiment, not a full history.

## Known hardware

The old postmarketOS/downstream kernel where touch worked used the Samsung FTS7 driver (`CONFIG_TOUCHSCREEN_FTS7=y`). Samsung's SM-T580 device tree describes an STMicro FTS touchscreen, not Synaptics RMI4.

Known SM-T580 wiring from the Samsung sources:

```text
controller: STMicro FTS / FTS1A096 (STM_VER5)
I2C controller: 0x13840000 -> i2c1 in the 6.19 tree
I2C address: 0x49
IRQ: gpa0-4, level-low
DVDD: 1.8 V, enabled by gpd1-4
AVDD: 3.3 V, enabled by gpd1-6
resolution: 1200x1920
touchkeys: 2, integrated in the FTS controller in the Samsung description
```

The old 6.19 board description was therefore wrong for this tablet: it described a Synaptics RMI4 device at `i2c3/0x70` plus a separate Melfas touchkey device.

## Current experimental branch/worktree

Remote branch:

```text
debug/vendor-dts-lottery
```

Remote checkpoint currently used to boot the experiment:

```text
0435a34b8eb4 arm64: dts: exynos7870-gtaxlwifi: try vendor touchscreen lottery
```

Worktree:

```text
/workspace/linux-gtaxlwifi-lottery
```

It was created from `origin/debug/vendor-dts-lottery`, so it started in detached-HEAD state.

**Important:** later `drivers/input/touchscreen/stmfts.c` experiments were made locally after that commit and were not yet promoted to the remote branch. Run `git status --short` and `git diff` before switching/resetting anything.

## Current 6.19 DT experiment

The experimental DTS replaces the bogus RMI4 description with the mainline STMFTS binding:

```text
st,stmfts
I2C1 / 0x49
IRQ gpa0-4 / level-low
vdd-supply -> 1.8 V TSP DVDD
aVDD/avdd-supply -> 3.3 V TSP AVDD
1200x1920
```

The two Samsung enable GPIOs are modelled as fixed regulators:

```text
gpd1-4 -> tsp_dvdd 1.8 V
gpd1-6 -> tsp_avdd 3.3 V
```

The DTB compiles successfully.

Kernel config used for this experiment:

```text
CONFIG_TOUCHSCREEN_STMFTS=m
CONFIG_LEDS_CLASS=y
# CONFIG_RMI4_I2C is not set
```

## Verified boot result

The recovery ZIP containing the STMFTS DTS/module boots.

The kernel creates the expected I2C device:

```text
/sys/bus/i2c/devices/1-0049
modalias: of:NtouchscreenT(null)Cst,stmfts
```

The mainline driver probes the correct address but fails:

```text
stmfts 1-0049: probe with driver stmfts failed with error -110
```

`-110` is `ETIMEDOUT`.

No touchscreen input device is registered; only the GPIO keys and regulator-haptic input devices are present.

The I2C device is currently **NOT BOUND** to a driver after the failed probe.

## Driver compatibility hypothesis

Samsung's working downstream driver identifies `gtaxl` as an older STM_VER5 / FTS1A096 device.

The downstream initialization differs from the generic mainline STMFTS path. Important Samsung behavior found in the old driver includes:

```text
power: AVDD first, then DVDD
system reset: B6 00 23 01
wait ready: poll READ_ONE_EVENT (0x85) until CONTROLLER_READY (0x10)
sense on: 0x93
force calibration: 0xA2
internal IRQ enable: B6 00 1C 41
```

Experimental local changes were made to `stmfts.c` to reproduce parts of this sequence and add `GTAXL:` / `GTAXL-PROBE:` tracing.

However, **the last instrumented-module test is not conclusive**: the file named `/tmp/stmfts-probe.ko` on the tablet did not contain any `GTAXL` strings, and no new instrumented probe appeared in dmesg. Do not use that attempt as evidence for or against the AVDD/DVDD or legacy-init hypotheses.

## ccache

ccache is enabled and working for manual kernel/module builds. A recent module-only build reported about 48% cache hits.

Use the shared cache for later tests.

## Resume procedure

First preserve/inspect the local WIP:

```bash
cd /workspace/linux-gtaxlwifi-lottery

git status --short
git diff -- drivers/input/touchscreen/stmfts.c

grep -nE 'GTAXL(:|-PROBE:)' drivers/input/touchscreen/stmfts.c
```

Before any new hypothesis, make the instrumentation test trustworthy.

Compile only the touchscreen modules:

```bash
make \
  O=.output \
  ARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CC="ccache aarch64-linux-gnu-gcc" \
  HOSTCC="ccache gcc" \
  -j"$(nproc)" \
  M=drivers/input/touchscreen \
  modules
```

Verify the freshly built module locally:

```bash
strings .output/drivers/input/touchscreen/stmfts.ko | grep -E 'GTAXL(:|-PROBE:)'
sha256sum .output/drivers/input/touchscreen/stmfts.ko
```

Copy it under a new unique filename, then verify the same strings and SHA256 on the tablet before loading it.

After loading, inspect:

```bash
sudo dmesg | grep -E 'GTAXL|stmfts|1-0049' | tail -100
```

The first goal is to identify the exact stage returning `-110`:

```text
probe entry
I2C capability check
regulator acquisition
IRQ request
power-on
first I2C READ_INFO
legacy reset
CONTROLLER_READY polling
```

Until that is known, avoid changing the DTS again: the current DT already reaches the correct `st,stmfts` device at `i2c1/0x49`, so the next uncertainty is primarily driver initialization / exact power sequencing.

## Useful reference sources

Working old postmarketOS kernel package pointed at:

```text
TALUAtGitHub/android_kernel_samsung_exynos7870
kernel 3.18.140
commit d8deb7266a4aa634bc0b96bb9a10fb9c335cc6e2
```

Samsung/vendor reference tree already present in the project:

```text
src/vendor-kernel
```

Relevant downstream areas:

```text
arch/arm64/boot/dts/exynos7870-gtaxl*.dts*
drivers/input/touchscreen/stm/fts7/
```

Mainline driver under test:

```text
drivers/input/touchscreen/stmfts.c
```
