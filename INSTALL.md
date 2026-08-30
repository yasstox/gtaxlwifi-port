# gtaxlwifi workspace helpers

## Start a shell

```bash
cd /workspace/gtaxlwifi-port
source scripts/lib/common.sh
```

`pmb` is a shell helper from `scripts/lib/common.sh`; source it again in each new login shell.

## Local settings

Keep machine-local settings and credentials in the ignored `.env` file:

```text
GTAXL_SSH_USER
GTAXL_SSH_HOST
GTAXL_SSH_PASSWORD
```

```bash
chmod 600 .env
git check-ignore -v .env
```

Never commit `.env` or real credentials.

## Useful helpers

```bash
./scripts/ssh-device.sh
./scripts/device-status.sh
./scripts/collect-boot-debug.sh <label>
./scripts/screen-refresh-test.sh
./scripts/build-kernel.sh
./scripts/build-recovery.sh <label>
./scripts/flash-recovery.sh artifacts/<milestone>/<file>.zip
./scripts/sync-repos.sh
./scripts/git-helper.sh
./scripts/snapshot-workspace.sh
```

Prefer explicit artifact paths when flashing.

## Worktrees

Current display integration worktree:

```text
/workspace/linux-gtaxlwifi-display
debug/display-regulator
```

The clean kernel remains in `src/linux` on `port/gtaxlwifi-6.19`.

The worktrees share pmbootstrap's package/rootfs workdir. Do not run concurrent packaging or `pmb install` jobs from multiple worktrees.

When using an alternate worktree, run `pmb build --envkernel` from that exact tree and verify its `Image` hash against rootfs `/boot/vmlinuz` before flashing.
