# SM-T580 GPU/display pipeline: reproducible follow-up

The tablet uses `Mesa Panfrost (Mali-T830) -> Exynos DRM/KMS (DECON) ->
DSIM -> HX8279D`. Rendering and scanout are separate: a Panfrost renderer
does not establish that a compositor can allocate/display buffers promptly.

The prior hardware log in `CPU-GPU-DISPLAY-DIAGNOSTIC.md` demonstrates seven
working GPU frequencies (343.2–1001 MHz), Mesa/Xorg Glamor, and failures in
DECON's contiguous buffer allocation with **32 MiB** CMA. The current pmaports
configuration already has `CONFIG_CMA_SIZE_MBYTES=128`, while
`CONFIG_EXYNOS_IOMMU` remains disabled: enabling the latter previously broke
display startup. `STATUS.md` remains the authoritative hardware status.

## Same-SoC comparisons

The kernel's `exynos7870-j7xelte.dts` (Galaxy J7 2016) and
`exynos7870-a2corelte.dts` (Galaxy A2 Core) both enable the shared
`exynos7870.dtsi` Mali-T830 node. Neither board file provides a GPU OPP
table or `mali-supply`, unlike `exynos7870-gtaxlwifi.dts` with its
`vdd_buck3` supply and seven OPPs. DECON bring-up was reported tested on
Galaxy J7 Prime and A2 Core in the upstream Exynos DRM patch discussion.
These facts establish useful *topology* comparisons, not that any peer is
verified 100% functional for rendering, scanout, devfreq, memory and thermal
behavior. No such fully validated peer was found; do not transfer a DT setup
just because another device has the same GPU ID.

No current post-128-MiB idle/load capture is in this repository. Run these
read-only captures against the *currently booted* build, using existing `.env`
SSH settings. Start the load capture while dragging windows, and keep dragging
throughout its 24-second default duration:

```sh
bash scripts/collect-gpu-pipeline.sh idle
bash scripts/collect-gpu-pipeline.sh load
```

The output under ignored `docs/debug/` includes actual boot arguments,
DRM device mapping, render nodes, Panfrost devfreq values, `CmaFree`, memory
and reclaim counters, process CPU/RSS, and kernel graphics messages. Compare
the two sample sets and especially *changes* in `pgscan_kswapd`/`allocstall`.
Read `kernel-graphics.txt` for allocation failures and Panfrost faults.

For an experimental kernel worktree, set `GTAXL_KERNEL_DIR` in the local `.env`
to its absolute path. `build-kernel.sh` now builds that worktree, and
`build-recovery.sh` uses the same explicitly selected complete build. With the
default `src/linux` value, recovery retains its old worktree discovery. The
existing Image/DTB checksum checks remain in place. These scripts only build
packages/ZIPs; flashing remains a separate operation.

Interpretation:

1. If the booted kernel still exposes 32 MiB CMA, verify the **installed**
   kernel/config/boot arguments before changing source; packaging may be stale.
2. If CMA drops and DECON allocation errors recur at 128 MiB, investigate
   Exynos scanout buffer lifetime, pitch/format, Mesa BO reuse and safe
   Exynos IOMMU bring-up. Do not increase CMA blindly on this 2 GiB tablet.
3. If CMA stays healthy yet `kswapd`/Xorg CPU and `Unevictable` rise, trace
   BO imports/exports and compositor allocations; changing GPU OPPs cannot
   remove that memory churn.
4. If the memory/display path is quiet but frame rate stays low, compare
   actual GPU clocks, thermal state, Panfrost faults and CPU time under the
   same workload. `glxinfo` alone only establishes renderer selection.

The older `debug/g3d-clock-dvfs` kernel branch adds rate propagation through
G3D mux/divider and reports the achieved rate to devfreq. It is an isolated
experiment; the port's own diagnostic recorded normal transitions without it.
Do not merge that patch until a fresh capture shows a clock transition defect.

This branch changes collection/documentation only; it has no flashed or
benchmarked kernel. A hardware fix must be validated by fresh boot and paired
captures before promoting it to the port branch.
