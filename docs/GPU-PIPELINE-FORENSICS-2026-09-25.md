# GPU / CPU / RAM forensic review — SM-T580, 2026-09-25

This is a static review of the versioned port, existing hardware notes, Linux
drivers, device trees and comparable devices. No tablet was available for a
new measurement. "Works" below means the existing project recorded a test;
"configured" means source only. Neither establishes smooth operation today.

## Executive finding

The old performance failure has a demonstrated *display/memory* component:
DECON could not allocate contiguous scanout buffers from the original 32 MiB
CMA while Xorg and `kswapd` were busy. The prior temporary 128 MiB CMA build
booted, with about 110 MiB free after graphics startup and no DECON allocation
errors; no conclusive sustained frame pacing result was recorded. The current
pmaports config already requests 128 MiB, so another CMA increase is not
justified. Actual installed configuration and measured memory behavior remain
unknown. Refer to `CPU-GPU-DISPLAY-DIAGNOSTIC.md`, especially the distinction
between the 32 MiB and 128 MiB captures.

The Mali GPU already ran Mesa Panfrost/Glamor and all seven measured OPPs;
clock ceiling, AFBC and shmem THP toggles did not explain the recorded lag.
There may be *additional* issues in GPU/runtime PM or Exynos buffer imports,
but they have not been demonstrated as the cause of the user-visible symptom.

## Pipeline, ownership and current evidence

| Stage | Versioned code/config | What the existing log establishes | Open question |
| --- | --- | --- | --- |
| GPU resources | `exynos7870.dtsi`, board `&gpu`, `vdd_buck3`, G3D clocks | Panfrost probes, seven GPU OPPs transition, 343.2–1001 MHz | Runtime power after inactivity, throttling during prolonged load |
| Shader and BOs | Mesa Panfrost, kernel `panfrost_*` | Hardware renderer/Glamor; many cached 4–6 MiB BOs | Per workload buffer lifetime; faults/timeout count |
| Handoff | Mesa `kmsro` plus PRIME/dma-buf between Mali render and Exynos KMS | GPU render node and display work together | Whether import/export copies or waits dominate |
| Scanout | Exynos DRM GEM + DECON + DSIM + HX8279D | Original `exynos_drm_gem_create` allocation failures | Whether failures recur on *installed* 128 MiB build |
| Memory | 2 GiB RAM, CMA config in pmaports | At 32 MiB, high shmem/unevictable and active reclaim | Current CMA size/free, sustained reclaim, app memory |

In `drivers/gpu/drm/exynos/exynos_drm_gem.c`, noncontiguous Exynos BOs are
reduced to contiguous when DRM IOMMU is unavailable. Its dumb buffer path uses
contiguous scanout allocation. `drivers/gpu/drm/exynos/exynos_drm_dma.c`
returns early when `CONFIG_EXYNOS_IOMMU` is disabled. Together these make
CMA exhaustion a coherent explanation for the documented DECON errors and CPU
reclaim; it is not proof of every source of high Xorg CPU. One 1200x1920x4
scanout is 9,216,000 bytes (about 8.79 MiB), so multiple buffers and
fragmentation can pressure a 32 MiB pool.

The board `&gpu` provides seven 900 mV OPPs matching the relevant Samsung
vendor G3D table. Its G3D clock defaults to 343.2 MHz. The recorded runtime
MIF/INT clocks also reached approximately the expected 902/400 MHz. No
source-backed benefit supports overclocking or changing regulator voltage.

`arm,mali-t830` selects Panfrost's `default_data`, not
`default_pm_rt_data`: normal runtime suspend calls `panfrost_gpu_power_off`
but does not explicitly disable GPU clocks/reset through the `GPU_PM_RT`
path. G3D gates are also marked `CLK_IS_CRITICAL` in the clock driver. This
is a power-efficiency investigation, **not a proven fix for Xorg lag**;
changing clock flags/reset handling without board power-domain evidence could
break display or graphics. Idle runtime status is now included in the capture.

## Precisely matched peer devices

| Device | Match | Publicly established functionality | Transfer limit |
| --- | --- | --- | --- |
| Galaxy A2 Core `a2corelte` | Exynos 7870, Mali-T830 MP1, upstream shared GPU node | [postmarketOS device page](https://wiki.postmarketos.org/wiki/Samsung_Galaxy_A2_Core_%28samsung-a2corelte%29) lists 3D acceleration as **Works** | Page also says display uses simple-framebuffer and DECON/DSIM is in progress; it does not validate full accelerated native scanout or 100% stability |
| Galaxy J7 2016 `jxelte` / kernel `j7xelte` | Exynos 7870, Mali-T830 MP1, 2 GiB | [postmarketOS page](https://wiki.postmarketos.org/wiki/Samsung_Galaxy_J7_%282016%29_%28samsung-jxelte%29) describes an old downstream kernel | This page cannot certify a modern Panfrost/DECON end-to-end pipeline |
| Galaxy J7 Prime `on7xelte` | Exynos 7870 and same upstream GPU node | DECON development was reported tested on this board; DT uses explicit framebuffer IOVA reservation | DECON bring-up is not a complete GPU/CPU/RAM performance validation |
| SM-T580 `gtaxlwifi` | Reference device | `STATUS.md` lists Mali/Panfrost/Glamor and native DECON display as working | Existing performance notes document remaining contention |

**No peer with public evidence of 100% GPU + native scanout + power management
+ sustained low CPU/RAM usage was found.** The A2 Core *does* independently
validate this SoC/GPU's 3D path, but its simple-framebuffer display path is
materially different. Its upstream board DT and J7's lack the SM-T580
`mali-supply`/seven OPPs; a smaller DT is not a better default for this board.

## IOMMU and framebuffer hypothesis, deliberately unmerged

The SM-T580 board reserves physical `0x67000000..0x678c9fff` for the boot
simple-framebuffer and sets native DECON `status="okay"`. The A2 Core and
J7 Prime upstream DTs additionally label their continuous splash reservation,
set `iommu-addresses = <&decon ...>` and pass it with `&decon
{ memory-region = <&cont_splash_mem>; }`. SM-T580 lacks those two properties.
This is a verifiable difference for a future isolated IOMMU handoff experiment,
not sufficient evidence that it caused the previously observed black screen
with `CONFIG_EXYNOS_IOMMU=y`. Investigate IOVA reservation semantics, driver
probe logs and boot framebuffer handoff before an IOMMU build. Keep the
versioned IOMMU setting disabled until a controlled recovery route exists.

## Changes staged on the experimental branches

* Meta branch `debug/gpu-pipeline-2026-09-25`: explicit kernel worktree
  selection for both kernel and recovery builds, read-only paired collection,
  this review and a standalone `analyze-gpu-pipeline.py` interpreter. This
  addresses accidental packaging of a different worktree/build.
* Kernel branch with the same name: fix `QUERY_BO_INFO` to check `bo->wb_mmap`
  when selecting `DRM_PANFROST_BO_NOEXEC`, instead of the unrelated GEM
  `map_wc` flag. This is a narrow correctness fix independently reviewed in
  the upstream Panfrost patch discussion; no evidence links it to the observed
  pressure. No clock/OPP/CMA/IOMMU behavior changes in this kernel patch.
* Existing `debug/g3d-clock-dvfs` is **not** merged: the measured seven OPPs
  already transition on the port, so its clock propagation modification needs
  a new failure case before consideration.

## Autonomous validation and decision points when the tablet is available

From the meta repository with an existing `.env` SSH setup, capture a resting
desktop and the same sustained window drag used in the prior diagnostic:

```sh
bash scripts/collect-gpu-pipeline.sh idle 30 2
bash scripts/collect-gpu-pipeline.sh load 30 2
python3 scripts/analyze-gpu-pipeline.py docs/debug/gpu-YYYYMMDD-HHMMSS-idle docs/debug/gpu-YYYYMMDD-HHMMSS-load
```

Use the two *actual* printed paths from the capture, never those placeholders.
Run the stock current build first, and retain its logs as baseline. Only then
build and compare the kernel experimental branch separately using
`GTAXL_KERNEL_DIR` as documented in `GPU-PIPELINE-NEXT-STEPS.md`. These
captures are read-only; packaging or installing remains a deliberate separate
step. Preserve a previously bootable kernel/recovery image when testing.

| Observation | Decision |
| --- | --- |
| `CmaTotal < 100 MiB` | Check `/proc/cmdline` and installed kernel/config: the versioned 128 MiB configuration is not the running configuration. Fix packaging/selection first. |
| DECON allocation failures, low `CmaFree` at 128 MiB | Review scanout buffer count and lifetime, then separately investigate safe IOMMU handoff. Do not blindly increase CMA on 2 GiB RAM. |
| No DECON failures, rising `pgscan_kswapd` and shmem | Investigate Mesa cached BO pressure, Xorg/compositor BO imports and RAM usage; OPP changes will not solve reclaim. |
| Healthy memory and DECON, low GPU clocks under load | Inspect actual `cur_freq`, governor, OPP/regulator warnings and thermal state; compare branch `debug/g3d-clock-dvfs` in isolation if rate propagation fails. |
| Healthy memory and clocks, Panfrost job timeout/MMU faults | Inspect fault logs and GPU-specific kernel fixes, one at a time. |

Compare counter *deltas within each capture*, not absolute `pgscan_kswapd`;
compare equivalent duration and workload across builds. The collection script
reports process `ps %CPU` as a lifetime average; use it for rough process
identification, not a frame-time benchmark. Smoothness needs direct observation
and a repeated comparable workload on the actual tablet. A successful compile
cannot prove GPU correctness, latency, power draw or a 100% fix.

Sources: project `STATUS.md`, `docs/CPU-GPU-DISPLAY-DIAGNOSTIC.md`, source
paths named above; [Mesa Panfrost and KMSRO integration](https://docs.mesa3d.org/drivers/panfrost.html),
[Linux Exynos GEM](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/exynos/exynos_drm_gem.c),
[Linux reserved-memory binding](https://github.com/torvalds/linux/blob/master/Documentation/devicetree/bindings/reserved-memory/reserved-memory.yaml),
and the linked postmarketOS device pages. Source trees and external pages can
change; record exact revisions when reproducing these comparisons.
