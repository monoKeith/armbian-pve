# 4. Rename the node

Renamed `nanopi-r6c` to `pvr6c`. Only safe on a standalone node with **no
VMs or containers**. Check with `qm list; pct list` (both empty) and
`pvecm status` (reports that it isn't part of a cluster).

```bash
OLD=nanopi-r6c NEW=pvr6c

hostnamectl set-hostname $NEW
sed -i "s/$OLD/$NEW/g" /etc/hosts /etc/mailname /etc/postfix/main.cf
newaliases
hostname -f; hostname -i    # pvr6c.lan / 192.168.x.y
reboot
```

After the reboot, pve-cluster creates `/etc/pve/nodes/$NEW`. Remove the old node and refresh the certificates:

```bash
OLD=nanopi-r6c
rm -rf /etc/pve/nodes/$OLD
rm -rf /var/lib/rrdcached/db/pve2-node/$OLD /var/lib/rrdcached/db/pve2-storage/$OLD
pvecm updatecerts --force
systemctl restart pveproxy pvedaemon
pvesh get /nodes    # only pvr6c, online
```

The browser shows a new certificate warning once.
