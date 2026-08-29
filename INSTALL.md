# Installing and using the gtaxlwifi workspace helpers

These files accompany the SM-T580 postmarketOS 6.19 development workspace.

The project has progressed beyond the original `r5-cache-debug` stage. The
current verified development baseline includes a persistent simpledrm display,
kernel-side debug command-line append support, postmarketOS debug shell, and
XFCE4 rendering. The display power workaround remains debug-only.

## Safe installation/update order

From the meta-repository:

```bash
cd /workspace/gtaxlwifi-port
```

First inspect local work:

```bash
git status --short
git -C src/linux status --short
git -C src/pmaports status --short
git submodule status
```

If GitHub contains newer meta-repository changes, fetch before overwriting
local files:

```bash
git fetch origin --prune
git log --oneline --decorate --left-right HEAD...origin/main
```

Do not blindly reset uncommitted work.

## Local `.env`

`.env` contains machine-local settings and credentials and must remain ignored.

Recommended SSH section:

```text
GTAXL_SSH_USER=user
GTAXL_SSH_HOST=172.16.42.1
GTAXL_SSH_PASSWORD=<local test password>
```

Do not copy real passwords into `.env.example`, documentation or Git history.

Protect it:

```bash
chmod 600 .env
git check-ignore -v .env
```

Install `sshpass` once if password automation is desired:

```bash
sudo apt install -y sshpass
```

## Daily helpers

From the project root:

```bash
./scripts/ssh-device.sh
./scripts/device-status.sh
./scripts/collect-boot-debug.sh <label>
./scripts/screen-refresh-test.sh
./scripts/build-kernel.sh
./scripts/build-recovery.sh <label>
./scripts/flash-recovery.sh artifacts/<milestone>/<file>.zip
./scripts/pull-cache-debug.sh <label>
./scripts/sync-repos.sh
./scripts/git-helper.sh
./scripts/snapshot-workspace.sh
```

Prefer an explicit recovery artifact path when flashing.

## `pmb` helper

The `pmb` command is a shell function provided by:

```bash
source /workspace/gtaxlwifi-port/scripts/lib/common.sh
```

It is not a globally installed command. A new SSH/login shell must source
`common.sh` again before `pmb` is available.

## Current display worktree

The active display debugging worktree is:

```text
/workspace/linux-gtaxlwifi-display
branch: debug/display-regulator
```

It is Git-isolated from `src/linux`, but both builds may still share the same
pmbootstrap workdir/package repository. Do not run concurrent pmbootstrap
packaging/install jobs from two agents/worktrees.

When building from the display worktree, run `--envkernel` from that exact
directory and compare its `Image` SHA-256 with the rootfs `/boot/vmlinuz`
SHA-256 before flashing.

## Current debug-only changes

The working display baseline currently relies on:

- `regulator-boot-on` + `regulator-always-on` for `vdd_ldo25`,
  `vdd_ldo33` and `vdd_ldo35`;
- a kernel-side command-line append implementation used to make
  `pmos.debug-shell` and other development arguments effective while retaining
  the Samsung bootloader command line.

These are intentional bring-up mechanisms, not final upstream-quality fixes.

## Workspace-additions installer

If using the generated workspace-additions bundle:

```bash
unzip gtaxlwifi-workspace-additions.zip
cd gtaxlwifi-workspace-additions
./apply.sh /workspace/gtaxlwifi-port
```

`apply.sh` should preserve an existing `.env` and install only public helper
files.

Always review:

```bash
git status --short
git diff
```

before committing generated/updated files.
