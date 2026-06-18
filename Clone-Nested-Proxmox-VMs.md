These are the steps you should follow when cloning nested Proxmox Hosts. 
- First Explanation, at bottom of file a script to do quickly. 

## Cloning Proxmox Nested VMs

#### Machine IDs
- Verify the VM \> options \> SMBIOS settings uuid is unique from clone source. 
- This becomes the machine ID

- Clear the machine id
```
echo -n > /etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id
reboot
```

alternative, update the machine-id not involving reboot
```
cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id 
ln -sf /etc/machine-id /var/lib/dbus/machine-id
```

Note: The VMs smbios uuid in the configuration file for it, eg /etc/pve/qemu-server/904.conf, is the same as the product uuid in os, /sys/class/dmi/id/product_uuid



#### Update Hostname
- hostnamectl hostname new-hostname
```
hostnamectl hostname host02.example.lab
```

#### Update hosts file
- update /etc/hosts with new IP and new hostname
```
127.0.0.1 localhost.localdomain localhost
10.10.10.102 nprox02.nested.lab nprox02

# The following lines are desirable for IPv6 capable hosts

::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
```


#### Update the NIC config
- Delete the old NIC pin files

```
# delete the old nic pins if needed
rm -rf /usr/local/lib/systemd/network/50-pmx-nic*.link
```

- Generate the new NIC pin files
```
yes | pve-network-interface-pinning generate

This will generate name pinning configuration for all interfaces - continue (y/N)? 
Name for link 'nic0' (enp0s18, enxbc24119bc6d8) will change to 'nic0'
Generating link files
Successfully generated .link files in '/usr/local/lib/systemd/network/'
Updating /etc/pve/nodes/nprox02/host.fw.new
Updating /etc/network/interfaces.new
Updating /etc/pve/sdn/controllers.cfg
Updating /etc/pve/sdn/fabrics.cfg
Successfully updated Proxmox VE configuration files.

Please reboot to apply the changes to your configuration
```

- Verify against ```ip link``` output 
- This should update the mac in the /usr/local/lib/systemd/network/50-pmx-nic0.link ( and any others ) as it will pin the nic of the source. 
```
MAC_ADDR=$(cat /sys/class/net/ens18/address)
sed -i "s/MACAddress=.*/MACAddress=$MAC_ADDR/g" /usr/local/lib/systemd/network/50-pmx-nic0.link
```


Alternative to the above. 
- note: The mac addresses for nics comes from /sys/class/net/$INTERFACE/address 
- eg: /sys/class/net/ens19/address 

The .link files such as 50-pmx-nic1.link can be placed in:
- /usr/local/lib/systemd/network/ 
- /etc/systemd/network/
- /run/systemd/network/
- /usr/lib/systemd/network
- Their contents is similar to. 
```
[Match]
MACAddress=bc:24:11:8d:36:b1
Type=ether

[Link]
Name=nic2
```


#### Update the Network Interfaces file with new IPs. 
   
   
- update /etc/network/interfaces with new IPs
- It may require first rebooting if you generated new nic pinning. 


#### clear and regenerate ssh keys
```
rm -v /etc/ssh/ssh_host_*_key*
dpkg-reconfigure openssh-server
systemctl restart sshd
```

#### Clear old logs
- clear old logs that will be under other machine-id 
```
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
```



#### clean old apt  cache
```
apt clean
rm -rf /var/lib/apt/lists/*
```

#### clean the app armor cache
```
rm -rf /var/cache/apparmor/*
```


#### Remove the existing SSL certificates and regenerate
```
rm /etc/pve/pve-root-ca.pem
rm /etc/pve/priv/pve-root-ca.key
rm /etc/pve/local/pveproxy-ssl.pem
rm /etc/pve/local/pveproxy-ssl.key

pvecm updatecerts -f
systemctl restart pveproxy pvedaemon
```

#### Update the iSCSI initiator name
```
echo "InitiatorName=iqn.1993-08.org.debian:01:$(hostname -s)" > /etc/iscsi/initiatorname.iscsi
```



#### Verify initramfs 
You likely will not need to do this, but documenting it. 
- verify there isn't a /etc/initramfs-tools/conf.d/resume file. 
- verify the current initramfs image doesn't have the UUIDs of storage embedded in them. 
```
uname -r
mkdir temp
unmkinitramfs /boot/initrd.img-7.0.2-6-pve temp/
cd temp/
```
  
- if there is regenerate the initramfs for grub after redoing the UUIDs of the storage
```
update-initramfs -u -k all
update-grub
```


#### Update filesystem UUIDs if needed 
- You may need to update the filesystem UUIDs.
- If you installed your nested Proxmox on ext4 and like normal it shouldn't need its uuids updated.

But, if you do you may need to boot from live disk and perform something like this. For non root UUIDs it can be done while unmounted. 

- Ext4
```
# Generate a new random UUID on the specified partition
tune2fs /dev/sdX1 -U random

# Clear the local blkid cache so it scans the physical changes immediately
blkid -g
```

- xfs
```
xfs_admin -U $(uuidgen) /dev/sdX1
```

- zfs
```
# Force import the pool under a brand new name to regenerate its unique mappings
zpool import -f -R /mnt/newpool old_pool_name new_pool_name
```

- lvm thin
```
# Regenerate the Physical Volume UUID
pvchange --uuid /dev/sdX1

# Regenerate the Volume Group UUID
vgchange --uuid pve
```


- Updating Partition UUIDs (`PARTUUID=`)

If your `/etc/fstab` or systemd-boot configuration references hardware layouts by partition blocks (`PARTUUID`), changing the internal filesystem structure above will not alter the partition table structure. You must use `fdisk` or `gdisk` to rewrite the GUID Partition Table metadata.

1. **Open the disk partition table editor:**
Target the base drive containing the target partitions (do not target the specific partition index number, run against the raw block device):

```bash
fdisk /dev/sdX
```

2. **Enter Expert Mode:**
Switch `fdisk` over to the expert function sub-menu:

* Type **`x`** and hit `Enter`.


3. **Randomize the Partition IDs:**
Change the unique disk identifiers:

* To change the main Disk GUID: Type **`g`** and hit `Enter`.
* To change specific Partition UUIDs: Type **`i`** and hit `Enter`, then input the partition index number you wish to alter. Type **`R`** to assign a completely random UUID.


4. **Write changes and exit:**
Save the modified structural data layout directly to the partition table blocks:

* Type **`w`** and hit `Enter` to write changes and close the utility.




### Networking with nested proxmox. 
- On the top most Proxmox host, do not tag a vlan on the nested Proxmox VM's NICs. 
- Instead tag the vlan inside the nested Proxmox OS, creating Linux VlANS within its network stack.



# Script to use. Place this script on your clone in root directory, something like nested-clone.sh
- Chmod the script +x and then call it after changing the hostname and IP in the script. 

```sh

#!/bin/bash                                                                                                       
                                                                                                                  
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
```
