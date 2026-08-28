## About this repository

This repository is the main development and coordination repository for the postmarketOS port of the Samsung Galaxy Tab A 10.1 2016 Wi-Fi (SM-T580 / `gtaxlwifi`).

The goal of this project is to bring the tablet to a modern Linux kernel and obtain a clean, reproducible and maintainable postmarketOS port.

Development currently focuses on the Samsung Exynos 7870 platform and includes work on:

* mainline Linux kernel support for the SM-T580;
* Device Tree integration;
* Wi-Fi bring-up;
* Exynos DECON / DSIM / MIPI-DSI display support;
* BOE Himax8279D panel support;
* postmarketOS device and kernel packaging;
* reproducible build and recovery-image generation;
* documentation of hardware findings, experiments and known-good revisions.

This repository acts as a **meta-repository**.

It records the exact revisions of the kernel, pmaports and reference repositories used for each development milestone, while keeping their original Git histories in separate repositories.

### Repository structure

The main external repositories are included as Git submodules.

Typical layout:

```text
src/linux
    SM-T580 development kernel based on Exynos7870 mainline Linux

src/pmaports
    postmarketOS packaging and device definitions used by this port

src/pmbootstrap
    official postmarketOS pmbootstrap tooling

src/vendor-kernel
    Samsung/vendor kernel source kept as a hardware reference
```

The parent repository additionally contains project documentation, build instructions, CI configuration, checksums and development status information.

### Upstream projects

This project builds on several existing open-source projects.

Important upstream sources include:

* Linux / Exynos7870 development:
  `https://gitlab.com/exynos7870-mainline/linux`

* postmarketOS pmaports:
  `https://gitlab.postmarketos.org/postmarketOS/pmaports`

* postmarketOS pmbootstrap:
  `https://gitlab.postmarketos.org/postmarketOS/pmbootstrap`

* Earlier SM-T580 mainline work:
  `https://gitlab.com/randwardatake/mainline-samsung-gtaxlwifi`

* Samsung SM-T580 vendor-kernel reference:
  `https://github.com/Yusuf6411/Kernel_SM-T580_gtaxlwifi`

No ownership of these upstream projects or their code is claimed by this repository.

Their original authorship, copyright notices and license terms remain applicable.

### Development model

Hardware bring-up is performed incrementally.

Whenever possible, one hardware hypothesis or functional change is kept per commit.

Examples include:

```text
SM-T580 Device Tree support
Wi-Fi power supply
MIPI-DSI host enablement
panel registration
panel power/reset
native display pipeline
```

Known-good states are recorded as concrete milestones in this repository.

The kernel and pmaports development repositories continue to track their respective upstream projects. Upstream changes are not automatically considered part of a known-good SM-T580 release: they are merged, rebuilt and tested first.

This allows the project to remain up to date without losing reproducibility.

### Reproducibility

The meta-repository records exact Git commits for its submodules.

A particular commit of this repository therefore identifies a specific combination of:

```text
kernel revision
pmaports revision
pmbootstrap revision
reference sources
project configuration
```

Build results and important device experiments are documented so that regressions can be traced to specific revisions.

See `BUILDING.md` for the build procedure and `STATUS.md` for development progress and hardware-test results.

### Licensing

Files written specifically for this repository are distributed under the license stated by this repository.

Git submodules and external projects are **not relicensed** by this repository. They remain subject to their own licenses and copyright notices.

Likewise, patches or files derived from Linux, postmarketOS or other upstream projects remain subject to the applicable upstream licensing terms.

When redistributing or publishing this project, the licenses and attribution requirements of each included or referenced project must be preserved.

### Project status

This project is experimental and under active development.

Not every hardware component is expected to work yet, and development images may contain regressions or incomplete hardware support.

Build artifacts should be considered development/testing images unless a specific revision is explicitly documented as validated.

## AI-assisted development

This project was developed with extensive assistance from AI tools, primarily for research, debugging, code review, documentation, and guidance through the Linux kernel and postmarketOS development process.

When I started working on this port, I had no prior experience with Linux kernel porting, Device Tree bring-up, DRM/KMS display pipelines, or postmarketOS device development. AI assistance made it possible for me to understand these systems while actively working on a real device, instead of spending months learning every component before being able to experiment.

This does **not** mean the project was generated autonomously by AI.

All builds, hardware tests, flashes, observations and validation were performed on real hardware. Changes were reviewed, tested incrementally and documented based on their actual results. AI suggestions were treated as hypotheses to verify rather than assumed to be correct.

The use of AI dramatically accelerated the learning and development process, but the project remains the result of experimentation, debugging, decision-making and hands-on work.

Without these tools, I probably would not have been able to reach this point nearly as quickly — and this project is also a practical example of how AI can help someone learn a complex technical field by building something real.
