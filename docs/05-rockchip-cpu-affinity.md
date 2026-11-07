# 5. Rockchip: pin VMs to one type of CPU core

> **Not tried yet.** This follows PXVIRT's Rockchip notes and hasn't been run on this board.

Reference: <https://docs.pxvirt.lierfang.com/zh/case/issue/rockchip.html>
(details in [jiangcuo/Proxmox-Arm64#59](https://github.com/jiangcuo/Proxmox-Arm64/issues/59))

The RK3588/RK3588S has two kinds of cores, and KVM can't move a multi-vCPU VM
between them. Without pinning, the VM may see only one CPU, or use 100% CPU
while doing nothing. Pin every VM with more than one vCPU to either the fast
cores or the slow cores, never both.

On the R6C:

| CPUs | Core | `CPU part` in `/proc/cpuinfo` |
|---|---|---|
| 0–3 | Cortex-A55 (slow) | `0xd05` |
| 4–7 | Cortex-A76 (fast) | `0xd0b` |

Check with `grep "CPU part" /proc/cpuinfo`.

## Set it

Use the web UI (VM → Hardware → Processors → **CPU Affinity**), or the CLI:

```bash
qm set <vmid> --cpu host --cores 4 --affinity 4-7   # 4 vCPUs on the A76 cores
qm set <vmid> --cores 2 --affinity 0-3              # small VM on the A55 cores
```

`cores` should not exceed the number of CPUs in `affinity`.

## Note

According to the GitHub issue, newer kernels (Armbian 6.5+) carry a KVM fix
that makes pinning unnecessary. This board runs 6.18, so it might work without
pinning, but pinning is what PXVIRT recommends and does no harm.
