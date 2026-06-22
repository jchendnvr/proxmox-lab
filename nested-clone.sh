#!/bin/bash
# nested-clone.sh
# For use on nested Proxmox VMs you clone. ( The Clone Source) 
# Then set the IP and Hostname below and run it on the newly cloned machine. 

IP_ADDR=10.10.10.105
HOST_NAME=nprox05.nested.lab

#echo -n > /etc/machine-id
#rm /var/lib/dbus/machine-id
#ln -s /etc/machine-id /var/lib/dbus/machine-id

# machine id
cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# hostname
hostnamectl hostname $HOST_NAME

# hosts file
echo "127.0.0.1 localhost.localdomain localhost
$IP_ADDR $(hostname) $(hostname -s)

# The following lines are desirable for IPv6 capable hosts

::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
" > /etc/hosts


# updating NICs
rm -rf /usr/local/lib/systemd/network/50-pmx-nic*.link
yes | pve-network-interface-pinning generate

# update the vmbr0 IP address 
pvesh set /nodes/$(hostname -s)/network/vmbr0 --type bridge --address $(IP_ADDR) --netmask 255.255.255.0
pvesh set /nodes/$(hostname -s)/network


# ssh host keys
rm -v /etc/ssh/ssh_host_*_key*
dpkg-reconfigure openssh-server
systemctl restart sshd

# iscsi initiator
echo "InitiatorName=iqn.1993-08.org.debian:01:$(hostname -s)" > /etc/iscsi/initiatorname.iscsi

# apparmor
rm -rf /var/cache/apparmor/*

# apt cache
apt clean
rm -rf /var/lib/apt/lists/*

# removing the pvecerts
rm /etc/pve/pve-root-ca.pem
rm /etc/pve/priv/pve-root-ca.key
rm /etc/pve/local/pveproxy-ssl.pem
rm /etc/pve/local/pveproxy-ssl.key

pvecm updatecerts -f
systemctl restart pveproxy pvedaemon


echo "
Should do following next
# 1) update the repos
#    update-repos.sh
# 2) Patch the no subscription issue
#    pve-sub-nag-patch-creator.sh
# 3) If single host, disable HA, 
#      systemctl disable -q --now pve-ha-lrm
#      systemctl disable -q --now pve-ha-crm
#      systemctl disable -q --now corosync
"

# clearning logs
systemctl stop systemd-journald.service
rm -rf /var/log/journal/*
systemctl start systemd-journald.service


# Delete rotated and zipped log files
find /var/log -type f \( -name "*.gz" -o -name "*.1" -o -name "*.old" \) -delete

# Truncate all remaining active text logs
find /var/log -type f -exec truncate -s 0 {} +


truncate -s 0 /var/log/wtmp
truncate -s 0 /var/log/btmp
truncate -s 0 /var/log/lastlog

# Truncate the history file on disk
truncate -s 0 /root/.bash_history

# Clear the history buffer of the current active session
history -c

truncate -s 0 /root/.zsh_history
truncate -s 0 /root/.zhistory

# Unset the history file variable so the current logout writes nothing
unset HISTFILE && exit
