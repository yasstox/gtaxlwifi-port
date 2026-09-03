# SM-T580 Linux 7.1 — CPU, GPU and display performance diagnostic

Date: 2026-09-02  
Development kernel: `/workspace/linux-gtaxlwifi-7.1`, branch `debug/cpufreq-clock`

## Scope

This document records the investigation performed while bringing the Samsung
Galaxy Tab A 10.1 Wi-Fi (SM-T580 / `gtaxlwifi`, Exynos 7870) to Linux 7.1.
It distinguishes changes already validated from experiments that must not be
promoted.

## CPU

The initial port did not expose the tablet's complete CPU operating range.
The Exynos 7870 clock and OPP data were compared with the Samsung sources and
the tablet DTB. The resulting clock configuration allows the Cortex-A53
cluster to reach the GTAXLWIFI ceiling of 1.586 GHz.

Validated points:

- the complete tablet CPU frequency range is exposed;
- PLL transitions use safe intermediate clocking;
- the shared BUCK1 regulator is handled without unsafe voltage transitions;
- frequency changes were exercised at runtime without clock or regulator
  faults.

Further work, not required for nominal operation, includes Samsung ASV binning
and per-device voltage selection.

## GPU

The Mali-T830 initially lacked correct power and clock data. The port now uses
BUCK3 for the GPU and has a seven-level G3D PLL/devfreq table:

- 343.2 MHz
- 449.8 MHz
- 546 MHz
- 676 MHz
- 728 MHz
- 845 MHz
- 1.001 GHz

All manual transitions were tested. The `simple_ondemand` governor moves the
GPU between 343.2 MHz at idle and 1.001 GHz under graphical load. Panfrost and
Xorg Glamor are active. The GPU reaches 1.001 GHz while dragging windows, so
the remaining desktop latency is not caused by a low GPU frequency ceiling.

`CONFIG_DEVFREQ_THERMAL=y` was added so the GPU cooling device can be
registered. Thermal behaviour still needs a longer load test.

## MIF and INT clocks

Samsung's Android configuration requests up to approximately 902 MHz for MIF
and 400 MHz for the internal interconnect. Runtime clock inspection showed
that Linux already reaches approximately 902.2 MHz for MIF and 399.75 MHz for
the relevant INT buses. These clocks were therefore ruled out as the immediate
cause of the window-drag latency.

## Xorg, Mesa and buffer pressure

Xorg uses the Exynos DRM KMS device for scanout and the Panfrost render node
through Mesa's `kmsro` path. Glamor reports a Mali-T830 OpenGL 3.1 context.

During repeated window dragging with the original 32 MiB CMA reservation:

- Xorg could consume most of one CPU;
- shared/unevictable memory grew to roughly 1.1–1.46 GiB;
- `kswapd` became very active;
- Panfrost debugfs showed hundreds of 4–6 MiB objects labelled
  `Unused (BO cache)`;
- DECON emitted repeated `exynos_drm_gem_create: failed to allocate buffer`.

Mesa 26.1.6 keeps unused Panfrost BOs for roughly one to two seconds and marks
them `DONTNEED`. Two diagnostic environment settings were tested:

- `PAN_MESA_DEBUG=noafbc`: no perceptible improvement; AFBC was ruled out;
- `PAN_MESA_DEBUG=nocache`: memory stayed low, but kernel CPU time and buffer
  allocation churn increased substantially and the user-visible latency became
  worse.

Both settings were removed. They must not be shipped.

Transparent huge pages for shmem were also disabled temporarily. Huge shmem
disappeared, but ordinary shmem/unevictable growth and the latency remained.
THP was therefore ruled out.

## CMA root cause and current test

The Exynos DRM driver uses physically contiguous dumb buffers when its IOMMU is
not available. At 1600×1200, one scanout-sized allocation observed in the CMA
trace requested 2269 pages, or about 8.9 MiB.

The kernel reserved only 32 MiB of CMA. Three full-screen buffers consumed
nearly the whole area, leaving too little contiguous space for another buffer.
DECON then retried and failed repeatedly during graphical activity.

Enabling `CONFIG_EXYNOS_IOMMU=y` was tested because the DT describes
`decon -> sysmmu_decon`. That build reached the initial framebuffer cursor and
then remained on a black backlit screen. It was immediately rejected and the
known-good build was restored. The Exynos SYSMMU must not be enabled again
until its early-boot/display failure has been diagnosed.

The safe fallback under test is:

```text
CONFIG_CMA_SIZE_MBYTES=128
# CONFIG_EXYNOS_IOMMU is not set
```

Runtime validation on kernel build `#18` showed:

- `CmaTotal`: 128 MiB;
- approximately 110 MiB CMA free after graphical startup;
- zero DECON allocation failures;
- Panfrost devfreq working normally.

This is promising but remains uncommitted until the user confirms that the
window-drag behaviour is improved during sustained use.

## Known relevant upstream kernel issue

The Linux 7.1-rc Panfrost `QUERY_BO_INFO` implementation reports
`PANFROST_BO_WB_MMAP` from `!bo->base.map_wc`. A later upstream correction uses
the explicit `bo->wb_mmap` state instead. This fix has not been applied because
the observed Mesa BO cache and CMA failure have a more direct explanation, and
the query is primarily relevant to imported BO metadata. It remains a candidate
for a later compatibility cleanup with Mesa 26.1.

## Current status

- CPU nominal performance: validated.
- GPU nominal frequency and dynamic scaling: validated.
- GPU cooling support: built, longer validation pending.
- MIF/INT maximum clocks: validated.
- CMA 128 MiB mitigation: booted with no DECON allocation errors; subjective
  latency validation pending.
- Exynos SYSMMU: rejected for now because it breaks display startup.
- Mesa `noafbc`, `nocache`, and shmem THP experiments: rejected.
- No current experimental performance change has been committed.

## Micro-USB charging investigation

The working fuel-gauge driver only reports battery state; it does not configure
the separate SM5703 charger. Samsung's SM-T580 sources place the charger on
I2C4 at address `0x49`, the SM5703 MUIC on I2C2 at `0x25`, and use GPD1.3 as
the active-low charger-enable signal. The Android configuration uses a 4.30 V
float voltage, with 460 mA for a USB source and higher currents only after
cable classification.

Linux 7.1 has SM5703 MUIC support through the SM5502 extcon driver, but no
mainline SM5703 charger driver. A first deliberately conservative prototype
was therefore added locally. It programs a 500 mA input/charge limit, 4.30 V
float voltage and automatic charge termination, polls the charger's own
`VBUSOK` status, and exports an `sm5703-charger` power-supply device. The DT
prototype instantiates it on I2C4 and describes GPD1.3 as active-low.

Kernel build `#19` compiled, packaged and flashed successfully. It exposes
both `sm5703-charger` and `sm5703-fuel-gauge`, which validates I2C4 probing and
power-supply registration. An initial loss of SSH led to a precautionary
restore of the known-good build `#16`. The recovery kernel's
`/proc/last_kmsg` contained an older Samsung Android log rather than a Linux
7.1 panic. A controlled second flash of `#19` then booted normally and remained
reachable, so the apparent failure has not reproduced as a kernel crash.

With the display at full brightness, the charger reports `online=1` and
`Charging` at a conservative 500 mA limit, but the fuel gauge measures roughly
-430 to -500 mA: the active tablet consumes more than this USB budget. After
setting the panel backlight to zero, battery current became positive at
+304 mA, voltage rose from 3.859 V to 3.933 V, and temperature fell from 40.7
to 39.5 degrees C. This is the first direct evidence that the SM5703 actually
charges under Linux rather than merely detecting VBUS.

Build `#19` remains uncommitted. Capacity and voltage progression must now be
sampled over a longer interval with the display off. Higher input current must
not be enabled until the MUIC identifies a charger capable of supplying it.

The longer validation completed successfully. With the display off and the
same USB source, build `#19` remained stable and produced these readings:

| Elapsed uptime | Capacity | Voltage | Battery current | Temperature |
| --- | ---: | ---: | ---: | ---: |
| about 1 minute | 62% | 3.933 V | +304 mA | 39.5 C |
| 12 minutes | 63% | 3.960 V | +304 mA | 36.8 C |
| 17 minutes | 64% | 3.972 V | +308 mA | 36.4 C |

This validates sustained positive charging: both voltage and reported capacity
rise while current remains positive, and temperature trends downward. The
500 mA USB limit is intentionally retained because this test connection is a
computer USB port. At full display brightness the tablet can consume more than
500 mA and therefore still show a negative net battery current; that does not
justify exceeding the USB source limit. Faster wall-charger operation requires
SM5703 MUIC cable classification in a later revision.

The same logic was then reformatted as build `#20`, with complete register-write
error handling and a clean `checkpatch` result. It boots stably and the charger
registers confirm charging mode (`CNTL=0x55`), VBUS present (`STATUS5=0x20`),
charger active (`STATUS3=0x03`), 500 mA limits, and the active-low enable GPIO
physically low. During this run the battery current nevertheless remained
negative, between approximately -300 and -450 mA, and capacity fell from 66%
to 65%. Because the programmed and reported hardware state matches build `#19`,
this may be a variable USB source/cable limitation; the cable has previously
been intermittent. Build `#20` must not be committed as validated until a
repeat positive-current interval is observed or the source is reconnected.

Host-side USB descriptor inspection found an additional integration bug: the
postmarketOS configfs gadget advertised `MaxPower 2mA`, because
`configs/c.1/MaxPower` was left at its configfs default. A live reconfiguration
successfully changed the descriptor to `MaxPower 500mA` and the host confirmed
the new value after re-enumeration. This is correct for an ordinary USB 2.0
host connection and must be made persistent in the initramfs gadget setup.
It did not immediately turn build `#20`'s battery current positive, so source
advertisement alone does not explain the difference from the positive `#19`
interval. The charger registers read back as expected (`CNTL=0x55`,
`VBUSCNTL=0x08`, `CHGCNTL2=0x08`, `CHGCNTL3=0x12`, `CHGCNTL4=0xa0`,
`CHGCNTL5=0xfa`, `STATUS5=0x20`) and GPD1.3 is physically low, confirming that
the charger is enabled. The remaining possibilities are an intermittent power
path/source or unusually high Linux consumption while the display pipeline is
still active.

Disabling and re-enabling the charger driver in build `#20` produced virtually
no change in battery current, despite the charger's `CHGON` status. This points
to a missing upstream component in the physical USB power path rather than to
the current-limit register itself. The positive `#19` interval followed a long
TWRP session, whose downstream Samsung kernel had initialized the SM5703 MUIC;
the later cold/repeated Linux boots did not. Linux 7.1 already supports the
SM5703 MUIC in `extcon-sm5502`, but the port had neither its DT node nor
`CONFIG_EXTCON_SM5502` enabled. Build `#21` therefore adds the MUIC at I2C2
address `0x25`, with its Samsung-source GPA2.6 falling-edge interrupt, and
enables the upstream extcon driver. This is the current test hypothesis.

Build `#21` validates that hypothesis only in part: the upstream MUIC probes and
correctly reports `USB=1`, `SDP=1`, `DCP=0`, but battery current remains
negative. A full register comparison then exposed a more direct difference.
Samsung's known charging state uses `VBUSCNTL=0x07`, `CHGCNTL2=0x07` and
`CHGCNTL5=0x7a`; the cleaned prototype forced `0x08`, `0x08` and `0xfa`.
Bit 7 of `CHGCNTL5` enables AICL. The original `#19` ignored write errors, so
its positive result could have retained Samsung/TWRP's AICL-disabled state.
Revision `#22` therefore matches Samsung's USB profile: 450 mA input/charge
limits and AICL disabled. The MUIC remains enabled for correct SDP detection.

Build `#22` confirms the hypothesis and separates charging from consumption.
The MUIC reports `SDP=1`; charger registers match Samsung's USB state
(`VBUSCNTL=0x07`, `CHGCNTL2=0x07`, `CHGCNTL5=0x7a`) and `STATUS3=0x03`
reports charging active. Merely blanking the backlight still left a negative
net current because Xorg/XFCE and the display pipeline continued running. Once
the display manager was stopped, battery current changed from approximately
-328 mA to +289 mA and voltage jumped from 3.789 V to 3.871 V while temperature
fell from 45.1 to 43.1 degrees C. After ten minutes the current remained
+277 mA; after thirty minutes of uptime it was still +210 mA. Capacity rose
from 53% to 54%, voltage reached 3.882 V, and temperature fell to 37.8 degrees
C. This validates sustained charging from a clean Linux boot. The remaining
inability to gain charge while the desktop is active is a system
power-consumption problem, not a charger-enable failure.

Revision `#23` connects the charger driver to the SM5703 MUIC extcon and
selects the Samsung-style current profile dynamically: 450 mA for an SDP/USB
host and 1.65 A only when the MUIC reports a dedicated charging port (DCP).
The kernel and DTB compile cleanly, the recovery ZIP checksum matched the
kernel installed in the rootfs, TWRP completed with return code zero, and the
tablet booted kernel `#23` normally. On the development PC the MUIC correctly
reported `USB=1`, `SDP=1`, `DCP=0`, and the charger exposed a 450 mA input
limit. This validates the conservative SDP branch on real hardware; the DCP
branch still requires a wall-charger test.

At full brightness with XFCE active, the battery measured about -406 mA even
though the charger reported charging. Reducing brightness alone did not make
the net current positive during this run. With the display manager stopped,
the backlight state changed to `brightness=0`, `bl_power=0`, and battery current
became +277 mA at 3.871 V. This reconfirms real charging and shows that a 450 mA
computer USB source cannot cover the tablet's full active-display load. It does
not yet prove positive charging during normal XFCE use; that acceptance test
must be repeated on a correctly detected DCP source.
