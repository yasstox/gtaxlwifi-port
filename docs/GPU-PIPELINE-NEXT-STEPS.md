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
