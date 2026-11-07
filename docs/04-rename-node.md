# 4. Rename the node

Renamed `nanopi-r6c` to `pvrk3588`. Only safe on a standalone node with **no
VMs or containers**. Check with `qm list; pct list` (both empty) and
`pvecm status` (reports that it isn't part of a cluster).

```bash
OLD=nanopi-r6c NEW=pvrk3588

hostnamectl set-hostname $NEW
sed -i "s/$OLD/$NEW/g" /etc/hosts /etc/mailname /etc/postfix/main.cf
newaliases
hostname -f; hostname -i    # pvrk3588.lan / 192.168.x.y
reboot
```

After the reboot, pve-cluster creates `/etc/pve/nodes/$NEW`. Remove the old node and refresh the certificates:

```bash
OLD=nanopi-r6c
rm -rf /etc/pve/nodes/$OLD
rm -rf /var/lib/rrdcached/db/pve2-node/$OLD /var/lib/rrdcached/db/pve2-storage/$OLD
pvecm updatecerts --force
systemctl restart pveproxy pvedaemon
pvesh get /nodes    # only pvrk3588, online
```

The browser shows a new certificate warning once.
