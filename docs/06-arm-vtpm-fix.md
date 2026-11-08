# 6. Fix vTPM (TPM state) on ARM VMs

## Symptom

An ARM VM with a TPM state disk (`tpmstate0`) fails to start. `swtpm_setup`
succeeds, then:

```
kvm: -device tpm-tis,tpmdev=tpmdev: 'tpm-tis' is not a valid device model name
TASK ERROR: start failed: QEMU exited with code 1
```

## Cause

`qemu-server` (seen in 9.2.9) always adds `-device tpm-tis`, the x86 ISA TPM.
The arm64 QEMU build doesn't include it, only the version for the `virt` machine:

```bash
kvm -device help | grep -i tpm
# name "tpm-tis-device", bus System
# name "tpm-tis-i2c", bus i2c-bus
```

## Fix

[`scripts/pve-arm-tpm-fix.sh`](../scripts/pve-arm-tpm-fix.sh) changes the one
line in `/usr/share/perl5/PVE/QemuServer.pm` (`add_tpm_device`) to choose
the device by VM architecture: `tpm-tis-device` on aarch64, `tpm-tis`
otherwise. It's idempotent, checks the result with `perl -c` (and restores the
original if that fails), and **restarts** `pvedaemon`, `pveproxy` and
`pvescheduler`. A reload isn't enough: `qm start` on the CLI picks up the fix,
but starting from the web UI goes through `pvedaemon` and keeps failing with the
old error until it's restarted.

```bash
# from the Mac
scp scripts/pve-arm-tpm-fix.sh root@192.168.x.y:/usr/local/sbin/pve-arm-tpm-fix
ssh root@192.168.x.y 'chmod 755 /usr/local/sbin/pve-arm-tpm-fix && pve-arm-tpm-fix'
```

Check:

```bash
qm showcmd <vmid> --pretty | grep tpm     # -device 'tpm-tis-device,tpmdev=tpmdev'
qm start <vmid>
echo "info tpm" | qm monitor <vmid>       # tpm0 ... tpmdev: type=emulator
```

## Keep it after updates

A `qemu-server` upgrade overwrites the file. The apt hook
[`scripts/99pve-arm-tpm-fix`](../scripts/99pve-arm-tpm-fix) runs the script
after every dpkg run. It does nothing when the file is already patched.

```bash
scp scripts/99pve-arm-tpm-fix root@192.168.x.y:/etc/apt/apt.conf.d/99pve-arm-tpm-fix
```

If the script prints `expected line not found`, upstream changed the code.
Check whether Proxmox fixed it, and don't patch blindly.

## Undo

```bash
rm /etc/apt/apt.conf.d/99pve-arm-tpm-fix /usr/local/sbin/pve-arm-tpm-fix
apt install --reinstall qemu-server
```
