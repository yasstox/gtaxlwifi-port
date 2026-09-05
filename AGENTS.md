# AGENTS.md

## Scope

These instructions apply to the whole `gtaxlwifi-port` meta-repository and its
work on the Samsung Galaxy Tab A 10.1 2016 Wi-Fi (`SM-T580`, `gtaxlwifi`).

This is hardware bring-up work, not a normal application repository. A change
that compiles successfully can still prevent the tablet from booting or silently
break unrelated hardware.

The goal is a maintainable modern Linux/postmarketOS port with as much hardware
support as reasonably possible, while preserving already-working functionality.


## Read the project before acting

Before making a non-trivial change:

1. Read this file.
2. Read `STATUS.md` for the currently verified hardware state.
3. Read `BUILDING.md` for the current build/package workflow.
4. Read the relevant subsystem documentation in this repository.
5. Inspect `git status` in every repository that may be modified.
6. Inspect recent history for the subsystem being changed.
7. Inspect current runtime logs when the task concerns hardware behavior.

Do not rely on remembered commands, old chat context, an old debugging attempt,
or assumptions about how the workspace used to be configured.

`STATUS.md` is the source of truth for the current verified hardware state. If
runtime evidence contradicts it, trust the runtime evidence and update the
status documentation when appropriate.


## Learn the repository commands from its scripts

The scripts are part of the project's interface. Read them before using or
reconstructing their commands.

At the beginning of a task involving build, package, flash, SSH, ADB, debug,
Git synchronization, or device inspection:

- inspect `scripts/`;
- read the relevant helper script(s);
- read `scripts/lib/common.sh` when the helper sources it;
- inspect the helper's `--help` output when it provides one;
- check `.env.example` and the documented environment variables when relevant.

Prefer the existing project helpers over manually recreating long command lines.
They encode workspace paths, pmbootstrap configuration, package names, device
assumptions, validation, and safety checks.

Do not guess a command from memory when the repository already contains a helper
for it.

Do not assume two similarly named helpers behave the same way or operate on the
same worktree. Read the implementation first.

In particular, a helper whose workflow includes flashing must not be used for a
build-only task merely because its name also contains `build`.

If a helper is unsuitable and a lower-level command must be run manually, first
understand what the helper normally does and explain why the manual invocation
is different.


## Long-running commands

Builds, packaging jobs, kernel compilation, pmbootstrap jobs, schema checks, and
other expected long-running commands should normally be launched exactly once
and allowed to finish naturally.

Do not impose an agent-side timeout on a normal long-running command merely to
check progress.

Do not repeatedly poll, re-run, interrupt, or restart a command just because it
has produced no new output for a while.

Do not return to the shell every short interval only to inspect whether the same
command is still running. Wait for the command to exit and inspect its final
result.

Only intervene before natural completion when there is concrete evidence that
human input is required, the process is genuinely stuck, the environment has
failed, or continuing would be unsafe.

Do not confuse this rule with short, intentional protocol/device-detection
timeouts implemented inside project scripts. Those may be legitimate parts of
ADB/SSH probing and should not be removed merely because long builds should be
allowed to finish.

Never launch a second packaging/build job against the same pmbootstrap work
directory while the first one is still running.


## Primary rule: do not regress working hardware

Preserving already-working functionality is more important than producing a
speculative fix quickly.

Before modifying shared resources such as:

- clocks;
- regulators;
- power domains;
- pinctrl;
- GPIOs;
- interrupts;
- reserved memory;
- CMA;
- IOMMU configuration;
- bus configuration;
- OPP tables;
- thermal configuration;
- device-tree parent nodes;

identify which existing devices depend on them.

Do not disable working hardware merely to make another driver probe.

Do not remove an apparently unused node without understanding why it exists.


## Debug before patching

Do not immediately edit code when a device fails.

Prefer this order:

1. reproduce or precisely identify the current symptom;
2. inspect the relevant kernel/userspace logs;
3. identify the failing driver or subsystem;
4. inspect the relevant device-tree node and parent resources;
5. inspect what the current driver expects;
6. read the relevant DT binding/API documentation;
7. compare with similar upstream devices;
8. compare with Samsung/downstream sources when useful;
9. form a concrete hypothesis;
10. make the smallest change that can test that hypothesis.

Avoid shotgun debugging where several unrelated properties or subsystems are
changed at once.

Change one logical thing at a time whenever practical so the outcome remains
interpretable.

A useful negative result that eliminates a hypothesis is better than a large
speculative patch.


## Device-tree rules

Every device-tree value must have a traceable reason for existing.

Do not invent:

- register addresses;
- IRQ numbers;
- GPIO numbers;
- clock IDs;
- clock rates;
- regulator voltages;
- supply relationships;
- OPP frequencies;
- thermal limits;
- memory regions;

just because a guessed value makes a driver probe further.

Prefer evidence in roughly this order:

1. current upstream Linux bindings and drivers;
2. current upstream DTS/DTSI for the same or closely related hardware;
3. Samsung downstream source for this device/SoC;
4. established LineageOS or other known-good device trees;
5. runtime evidence from Android/downstream Linux;
6. implementations using the same component on related devices.

Samsung's downstream kernel is a hardware reference. Its age is not a reason to
ignore it.

Do not copy old downstream properties mechanically. Understand the hardware
behavior they describe, then express it through the APIs and bindings expected
by the current kernel whenever possible.

Prefer standard upstream bindings over vendor-specific properties when the
current driver supports them.


## Mainline and downstream

The objective is not "mainline at all costs".

Prefer modern upstream drivers and APIs when they correctly support the
hardware. At the same time, use Samsung downstream code as valuable hardware
documentation for things such as:

- topology;
- initialization sequences;
- power sequencing;
- clocks;
- regulators;
- GPIOs;
- interrupts;
- memory layout;
- firmware expectations.

When modern Linux behavior differs significantly from the known Android/vendor
behavior, investigate the downstream implementation instead of assuming the
current port is correct.

Avoid importing large vendor code dumps unless there is a strong technical
reason. Prefer understanding the missing behavior and implementing the smallest
clean support needed by the modern kernel.


## GPU / Panfrost work

Do not automatically classify a graphics problem as a Panfrost driver bug.

When investigating GPU performance, latency, instability, low utilization, or
poor desktop smoothness, check the relevant parts of the complete stack:

- actual GPU clock;
- devfreq state;
- OPP table;
- voltage and regulator state;
- clock parents;
- runtime PM;
- power-domain state;
- interrupts;
- scheduler activity;
- Panfrost errors;
- Mesa/Panfrost userspace;
- DRM/display path;
- compositor behavior;
- memory pressure;
- CMA/reserved memory;
- CPU bottlenecks;
- thermal throttling.

Keep these distinct:

- driver probe/initialization;
- rendering acceleration being available;
- correct GPU power management;
- correct DVFS/frequency behavior;
- actual desktop/compositor performance;
- display scanout performance.

Do not claim that "Panfrost works" merely because a renderer is detected, and
do not claim that Panfrost itself is broken merely because Linux is less smooth
than Android.


## Performance work

Do not optimize by blindly increasing clocks, voltages, CMA size, memory
reservations, or scheduler aggressiveness.

Gather evidence first.

When comparing Linux with Android, investigate the relevant differences rather
than assuming a single cause. These may include kernel configuration, scheduler,
GPU frequency, memory configuration, display/compositor path, thermal policy,
vendor behavior, and userspace.

Prefer fixing the underlying configuration or missing support over adding a
permanent workaround.


## Kernel changes

Follow normal Linux kernel coding style and subsystem conventions.

Keep patches small and subsystem-focused.

Do not perform broad refactors during hardware debugging unless they are needed
for the fix.

Do not modify generated files when the source can be modified instead.

Preserve existing copyright and SPDX headers.

Temporary diagnostics must be easy to identify and should be removed after they
have served their purpose unless they provide lasting diagnostic value.


## Kernel configuration

Do not enable arbitrary drivers merely because they compile.

For a new config option, determine which hardware or feature requires it and
whether it should be built-in or modular.

Consider the tablet's RAM/storage constraints.

Do not disable required options merely to reduce kernel size without checking
what currently depends on them.


## Build workflow

Use the project's documented/scripted workflow before inventing a new one.

Avoid unnecessary clean rebuilds when an incremental validation is sufficient,
but do not preserve stale build state when it would invalidate the test.

For a focused change, use the smallest useful validation first when the project
workflow supports it, then expand validation as necessary.

A successful compilation proves only that the code builds. It does not prove
that the hardware works.

Do not run concurrent pmbootstrap packaging/install jobs against the shared work
directory.


## Validation

After a change, perform the practical validation relevant to it. Depending on
the task this may include:

- kernel compilation;
- module compilation;
- DTB compilation;
- DT schema/binding validation;
- checking newly introduced warnings;
- inspecting `git diff`;
- checking packaged output against the freshly built kernel;
- runtime testing on the tablet when access is available.

Clearly distinguish these states:

- edited only;
- compiled;
- statically validated;
- packaged;
- boot-tested;
- hardware-tested.

Never report runtime success when the change was not actually tested on the
physical device.


## Warnings

Do not silently ignore new warnings caused by the change.

Existing unrelated warnings do not need to be fixed unless they affect the task.

Do not turn a focused hardware fix into a repository-wide cleanup.


## Git and workspace safety

Before editing, inspect `git status` in the affected repository/submodule.

Assume existing uncommitted changes are intentional.

Never discard unrelated user modifications.

Do not use destructive commands such as:

```text
git reset --hard
git clean -fd
git clean -fdx
git checkout -- .
git restore .
```

unless explicitly requested and the consequences are understood.

Do not rewrite published history or force-push unless explicitly requested.

Keep unrelated changes out of a commit.

Do not move a debug submodule revision into the meta-repository accidentally.
Inspect submodule changes before advancing the meta-repository checkpoint.

When publishing a meta-repository checkpoint, ensure dependent kernel/pmaports
commits are already available remotely first.


## Device safety

Building images/packages is not permission to flash them.

Do not flash, erase, repartition, format, factory-reset, or otherwise write to
the physical tablet unless the task explicitly calls for that operation.

Read any build/flash helper completely before executing it; some helpers combine
multiple stages and may end by flashing automatically.

Treat commands involving block devices, boot/recovery/system partitions,
bootloaders, `dd`, TWRP sideload, or equivalent low-level writes as potentially
destructive.

Never assume a `/dev/...` path identifies the intended device without evidence.


## postmarketOS / pmbootstrap

Do not recreate or wipe the pmbootstrap environment merely to solve a build
problem unless there is evidence that the environment itself is the cause.

Do not clear caches/chroots reflexively.

Prefer finding the actual dependency, packaging, or workspace problem.

Keep kernel, pmaports, and meta-repository responsibilities distinct.


## Documentation and status tracking

For meaningful hardware changes, keep `STATUS.md` accurate.

Document verified outcomes such as:

- what changed;
- what was actually tested;
- what started working;
- what remains incomplete;
- regressions;
- important persistent error messages;
- useful conclusions from failed hypotheses.

Do not mark hardware as working based only on a successful probe if its actual
function was not tested.

Do not turn `STATUS.md` into a transcript of every failed experiment. Git
history and focused debug notes can preserve development detail; `STATUS.md`
should describe the useful current state.


## Experiments

Experiments are allowed, but distinguish them from fixes.

For a speculative experiment:

1. state the hypothesis;
2. minimize the patch;
3. define what observation would support or reject it;
4. test it;
5. keep or revert only the experiment's own changes based on the result.

Never revert unrelated work while cleaning up a failed experiment.


## External references

Prefer primary sources when researching implementation details:

- Linux kernel source and documentation;
- Device Tree bindings;
- Mesa;
- postmarketOS/pmaports;
- pmbootstrap;
- Samsung/vendor kernel sources;
- established LineageOS trees;
- official component documentation when available.

Forum posts, random patches, and discussions can provide leads, but verify their
claims against code, documentation, or runtime evidence before treating them as
authoritative.


## Do not hide uncertainty

Do not claim an issue is solved merely because:

- an error message disappeared;
- a driver probes;
- the kernel compiles;
- a DT node is enabled;
- a renderer appears in userspace.

Verify the actual functionality whenever possible.

If the evidence is incomplete, say exactly what has and has not been verified.


## When stuck

Do not respond to uncertainty by making increasingly speculative changes.

Instead:

1. summarize what is known;
2. list the concrete evidence;
3. identify the exact unknown;
4. compare current upstream and downstream behavior where relevant;
5. choose the next test that best distinguishes between competing hypotheses.

Prefer gaining information over generating patch volume.


## Final report after changes

At the end of a task, report concisely:

- files changed;
- the identified cause, if known;
- what was changed and why;
- commands/validation performed;
- what was actually tested on hardware;
- remaining warnings or uncertainty;
- whether additional physical-device testing is required.

Do not present untested assumptions as facts.
