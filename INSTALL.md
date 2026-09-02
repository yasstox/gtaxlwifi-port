# gtaxlwifi workspace helpers

```bash
cd /workspace/gtaxlwifi-port
source scripts/lib/common.sh
```

Keep machine-local SSH/device settings in the ignored `.env` file. The main
helpers are:

```bash
./scripts/build-kernel.sh
./scripts/build-recovery.sh <label>
./scripts/flash-recovery.sh artifacts/<milestone>/<file>.zip
./scripts/ssh-device.sh
./scripts/device-status.sh
./scripts/collect-boot-debug.sh <label>
```

The clean kernel and pmaports branches are both `port/gtaxlwifi-7.1`. Alternate
kernel worktrees share pmbootstrap's package/rootfs work directory; do not run
concurrent packaging jobs. When using one, package with `--envkernel` from that
exact tree and verify its Image hash against rootfs `/boot/vmlinuz` before flash.
