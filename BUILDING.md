# Building postmarketOS for the SM-T580

Current reproducible workflow for the `samsung-gtaxlwifi` Linux 7.1 port.

## Branches and workspace

```text
src/linux:    port/gtaxlwifi-7.1
src/pmaports: port/gtaxlwifi-7.1
meta:         main
```

The meta-repository records exact submodule revisions. Do not run concurrent
pmbootstrap packaging/install jobs: all worktrees share the same work directory.

## Build and package

```bash
cd /workspace/gtaxlwifi-port
source scripts/lib/common.sh
pmb build --force linux-postmarketos-exynos7870
pmb build --force device-samsung-gtaxlwifi
pmb install --android-recovery-zip --recovery-install-partition=system
```

For an already-built kernel worktree, run the following command from that exact
kernel tree:

```bash
source /workspace/gtaxlwifi-port/scripts/lib/common.sh
pmb build --force --envkernel linux-postmarketos-exynos7870
```

The device uses Exynos QCDT boot images; `dtbtool-exynos` and boot-deploy handle
QCDT generation. The BOOT partition limit used by this project is 32 MiB.

## Helpers

The build, recovery, flash and SSH helpers are documented by their `--help`
output and share settings from `scripts/lib/common.sh` and the ignored `.env`.
Use an explicit recovery ZIP path when flashing.

Before advancing the meta-repository, push the kernel and pmaports commits and
inspect `git diff --cached --submodule=log`.
