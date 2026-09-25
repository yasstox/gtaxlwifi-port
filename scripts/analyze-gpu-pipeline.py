#!/usr/bin/env python3
"""Compare paired read-only SM-T580 GPU/display captures without dependencies."""

import argparse
import re
from pathlib import Path


FIELDS = ("MemAvailable", "Shmem", "Unevictable", "CmaTotal", "CmaFree")
COUNTERS = ("pgscan_kswapd", "pgsteal_kswapd", "allocstall", "compact_stall")


def read_capture(directory):
    text = (directory / "samples.txt").read_text(errors="replace")
    sections = re.split(r"(?m)^=== sample \d+ .* ===\s*$", text)
    samples = []
    for section in sections[1:]:
        sample = {}
        for line in section.splitlines():
            mem = re.match(r"^(\w+):\s+(\d+) kB$", line)
            counter = re.match(r"^(\w+)\s+(\d+)$", line)
            freq = re.search(r"current_frequency=(\d+)$", line)
            if mem and mem.group(1) in FIELDS:
                sample[mem.group(1)] = int(mem.group(2))
            if counter and counter.group(1) in COUNTERS:
                sample[counter.group(1)] = int(counter.group(2))
            if freq:
                sample["gpu_frequency"] = int(freq.group(1))
        samples.append(sample)
    if not samples:
        raise ValueError(f"No complete samples in {directory / 'samples.txt'}")
    logs = (directory / "kernel-graphics.txt")
    return text, samples, logs.read_text(errors="replace") if logs.exists() else ""


def number(value):
    return "n/a" if value is None else str(value)


def change(samples, key):
    if key not in samples[0] or key not in samples[-1]:
        return None
    return samples[-1][key] - samples[0][key]


def present(samples, key):
    values = [sample[key] for sample in samples if key in sample]
    return f"{min(values)}..{max(values)}" if values else "n/a"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("idle", type=Path, help="gpu-...-idle directory")
    parser.add_argument("load", type=Path, help="gpu-...-load directory")
    args = parser.parse_args()
    idle_text, idle, idle_logs = read_capture(args.idle)
    load_text, load, load_logs = read_capture(args.load)
    idle_kernel = re.search(r"(?m)^kernel: (.*)$", idle_text)
    load_kernel = re.search(r"(?m)^kernel: (.*)$", load_text)
    print("# Paired GPU/display capture")
    print(f"Kernel: idle={idle_kernel.group(1) if idle_kernel else 'unknown'}; "
          f"load={load_kernel.group(1) if load_kernel else 'unknown'}")
    print(f"Samples: idle={len(idle)}; load={len(load)}")
    if idle_kernel and load_kernel and idle_kernel.group(1) != load_kernel.group(1):
        print("WARNING: kernels differ; comparisons are not controlled.")
    print("| Metric | Idle range | Load range | Change during load |")
    print("| --- | ---: | ---: | ---: |")
    for key in FIELDS + COUNTERS + ("gpu_frequency",):
        print(f"| {key} | {present(idle, key)} | {present(load, key)} | "
              f"{number(change(load, key))} |")
    for label, logs in (("idle", idle_logs), ("load", load_logs)):
        decon = len(re.findall(r"exynos_drm_gem_create: failed to allocate buffer", logs, re.I))
        faults = len(re.findall(r"(?:panfrost.*(?:fault|timeout)|(?:mmu|gpu).*fault)", logs, re.I))
        print(f"{label} graphics-log lines: DECON allocation failures={decon}; "
              f"possible GPU faults/timeouts={faults} (inspect full logs).")
    cma = load[0].get("CmaTotal")
    if cma is not None and cma < 100 * 1024:
        print("CHECK: active CMA is under 100 MiB; verify installed kernel and boot args.")
    if change(load, "pgscan_kswapd") is not None and change(load, "pgscan_kswapd") > 0:
        print("CHECK: kswapd scanned memory during load; correlate with CMA and Xorg.")
    if any("failed to allocate buffer" in logs.lower() for logs in (idle_logs, load_logs)):
        print("CHECK: DECON allocation failed; inspect CMA and actual boot configuration.")
    print("Interpretation requires matching workload, duration and installed kernel. "
          "PS %CPU is a process lifetime average, not instantaneous utilization.")


if __name__ == "__main__":
    main()
