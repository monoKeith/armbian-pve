#!/bin/sh
# Make Proxmox qemu-server use the right vTPM device on arm64 VMs.
#
# qemu-server (9.2.x) always adds "-device tpm-tis", the x86 ISA device. The
# arm64 QEMU build has no tpm-tis, only "tpm-tis-device" (sysbus, for the
# 'virt' machine), so any ARM VM with a tpmstate0 disk fails to start with:
#   'tpm-tis' is not a valid device model name
#
# This rewrites that one line to choose the device by VM arch. It's idempotent
# and safe to run any time. Install it as /usr/local/sbin/pve-arm-tpm-fix and
# let the apt hook (99pve-arm-tpm-fix) re-run it after qemu-server upgrades.
set -eu

F="${F:-/usr/share/perl5/PVE/QemuServer.pm}"
OLD='    push @$devices, "-device", "tpm-tis,tpmdev=tpmdev";'
MARK='# pve-arm-tpm-fix'

[ -f "$F" ] || exit 0
grep -qF "$MARK" "$F" && exit 0                 # already patched
grep -qxF "$OLD" "$F" || { echo "pve-arm-tpm-fix: expected line not found in $F, upstream changed? not patching" >&2; exit 0; }

cp -a "$F" "$F.orig-tpm"
perl -0pi -e '
  my $old = q{    push @$devices, "-device", "tpm-tis,tpmdev=tpmdev";};
  my $new = q{    my $tpm_dev = PVE::QemuServer::Helpers::get_vm_arch($conf) eq "aarch64" ? "tpm-tis-device" : "tpm-tis"; # pve-arm-tpm-fix
    push @$devices, "-device", "$tpm_dev,tpmdev=tpmdev";};
  s/\Q$old\E/$new/;
' "$F"

if ! perl -I/usr/share/perl5 -c "$F" >/dev/null 2>&1; then
  echo "pve-arm-tpm-fix: patched file failed perl -c, restoring original" >&2
  mv "$F.orig-tpm" "$F"
  exit 1
fi
rm -f "$F.orig-tpm"
echo "pve-arm-tpm-fix: patched $F"

# Running daemons have the old code loaded.
systemctl reload-or-restart pvedaemon pveproxy pvescheduler 2>/dev/null || true
