# Install Proxmox on Debian 13 desktop running Wayland

## Goal
- I wanted to have a mobile lab I could use for testing and demo of Proxmox. I wanted to use a Laptop and do nested virtualization. I had a thinkpad with 64GB of RAM and 12 threads of CPU processing power. It has a 1 TB boot drive and a 2 TB secondary which is plenty for this purpose. 

## Issues: 
- Following the standard guide will complicate your networking as it removes the default desktop tools. 

## Requirements
This was created on 20260519 and the laptop is updated to the current version of Debian 13.5 


## Steps: 
1: Check /etc/NetworkManager/NetworkManager.conf. It should read as follows so that NetworkManager ignores the /etc/network/interfaces file. Restart network manager after if it is changed. 

```sh
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=false
```

2: Create a /etc/network/interfaces file using the correct name for your wireless nic. Substitute wireless nic for wired if that is what you are using. 
- Get the name of your nic from the command ```ip link```
- Then create the below interfaces file. It is creating a bridge that routes traffic through your host to the wireless network using NAT. Change the networks below to not conflict as needed. This is similar to running a docker host. 

```sh
auto lo
iface lo inet loopback

# Host-only bridge for Proxmox VE Web UI & VMs
auto vmbr0
iface vmbr0 inet static
        address 10.10.10.1/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0

        # NAT routing to forward VM traffic through the laptop's Wi-Fi
        post-up echo 1 > /proc/sys/net/ipv4/ip_forward
        post-up iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o wlp0s20f3 -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s 10.10.10.0/24 -o wlp0s20f3 -j MASQUERADE
```

3: Update /etc/hosts with your hostname
- Run ```hostname``` to see what is currently set. Use ```hostnamectl set-hostname host.domain.tld```
- Use the ip address above, 10.10.10.1 as the IP for your hostname in the file. 

Example below: 

```sh
cat /etc/hosts
# Standard host addresses
127.0.0.1  localhost
::1        localhost ip6-localhost ip6-loopback
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters
# This host address
127.0.1.1  diecore26
10.10.10.1 diecore26.local diecore26
```

- Then check with ```hostname --ip-address```


4: Install the Proxmox VE 9 Repositories 
- First the key

```sh
sudo wget https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg -O /usr/share/keyrings/proxmox-archive-keyring.gpg
```

- Then check the key
```sh
sha256sum /usr/share/keyrings/proxmox-archive-keyring.gpg
```

- Currently it is:
```sh
136673be77aba35dcce385b28737689ad64fd785a797e57897589aed08db6e45  /usr/share/keyrings/proxmox-archive-keyring.gpg
```

- Then add the repo
```sh
sudo bash -c 'cat > /etc/apt/sources.list.d/pve-install-repo.sources << EOL
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOL'
```

5: Now update, install the kernel, and install Proxmox

```sh
sudo apt update && sudo apt full-upgrade -y
```

- Then reboot
- Then install the Proxmox kernel
```sh
sudo apt install proxmox-default-kernel -y
```
- reboot again
```sh 
sudo systemctl reboot
```

- Then install Proxmox, when it asks about Postfix, choose local only and accept the hostname you set previously. 
```sh
sudo apt install proxmox-ve postfix open-iscsi chrony -y
```

- You have a bunch of kernels now. 
```sh
dpkg --list | grep -iE 'linux-image|proxmox-kernel'
rc  linux-image-6.12.43+deb13-amd64         6.12.43-1                            amd64        Linux 6.12 for 64-bit PCs (signed)
rc  linux-image-6.12.63+deb13-amd64         6.12.63-1                            amd64        Linux 6.12 for 64-bit PCs (signed)
ii  linux-image-6.12.69+deb13-amd64         6.12.69-1                            amd64        Linux 6.12 for 64-bit PCs (signed)
ii  linux-image-6.12.88+deb13-amd64         6.12.88-1                            amd64        Linux 6.12 for 64-bit PCs (signed)
ii  linux-image-amd64                       6.12.88-1                            amd64        Linux for 64-bit PCs (meta-package)
ii  proxmox-kernel-7.0                      7.0.2-4                              amd64        Latest Proxmox Kernel Image
ii  proxmox-kernel-7.0.2-4-pve-signed       7.0.2-4                              amd64        Proxmox Kernel Image (signed)
ii  proxmox-kernel-helper                   9.0.4                                all          Function for various kernel maintenance tasks.

```

- When done, remove the Debian kernel 
```sh
sudo apt remove linux-image-amd64 'linux-image-6.12*' -y && sudo update-grub
```

6: Configure nested virtualization
Nested virtualization is important for having nested Proxmox VE instances. 

- For Intel CPUs 
```sh
sudo bash -c 'echo "options kvm_intel nested=1" >> /etc/modprobe.d/kvm.conf'
```

- For AMD CPUs
```sh
sudo bash -c 'echo "options kvm_amd nested=1" >> /etc/modprobe.d/kvm.conf'
```

- Next update initramfs 
```sh
sudo update-initramfs -u -k all
```


7: My laptop required additional steps for the UEFI and was pointed out when I ran the finial initramfs step. 

```sh
echo 'grub-efi-amd64 grub2/force_efi_extra_removable boolean true' | sudo debconf-set-selections -v -u
```

- then
```sh
sudo apt install --reinstall grub-efi-amd64
```

- once more. 
```sh
sudo update-initramfs -u -k all
```

8: NetworkManager needed a little more love to still work. 

- I could see in ```nmcli device``` that my wifi card was still unmanaged and thus not working, not showing up in the GNOME GUI, etc.

To fix: 
- Create a file: /etc/NetworkManager/conf.d/10-globally-managed-devices.conf

```toml
[main]
   plugins=keyfile

   [keyfile]
   unmanaged-devices=none

   [device]
   match-device=interface-name:wlp0s20f3
   managed=1
```

- Then restart NetworkManager 
```
sudo systemctl restart NetworkManager
```

Now we can see it is managed. 
```sh
nmcli device
DEVICE             TYPE      STATE                   CONNECTION 
wlp0s20f3          wifi      connected               Public     
vmbr0              bridge    connected (externally)  vmbr0      
lo                 loopback  connected (externally)  lo         
docker0            bridge    connected (externally)  docker0    
p2p-dev-wlp0s20f3  wifi-p2p  disconnected            --         
vmbr1              bridge    unmanaged               --     
```





## Other packages to remove

You should remove os-prober package because it can mistakenly create grub boot entries for VMs. 
```
apt remove os-prober
```


## Links 

https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_13_Trixie

https://pve.proxmox.com/wiki/Developer_Workstations_with_Proxmox_VE_and_X11


# Steps for getting laptop Proxmox lab running at remote locations.

1) You want to use synergy to share mouse and keyboard. 
- Synergy client on the secondary laptop should connect back to the main laptop
- this is done by removing the existing computer, adding a new computer.

2) You may need to adjust firewall policies for pveproxy port 8006, example IP 
```
pvesh create /nodes/direcore26/firewall/rules --type in --action ACCEPT --proto tcp --source 192.168.1.20 --dport 8006 --comment "main laptop at community center" --enable 1
pvesh create /nodes/direcore26/firewall/rules --type in --action ACCEPT --proto tcp --source 192.168.1.20 --dport 22 --comment "main laptop at community center" --enable 1
```

```
pvesh get /nodes/$(hostname)/firewall/rules 
systemctl status pve-firewall.service
```


Multiple ports can be done with commas and a range cna be given with colon. 
```
pvesh create /nodes/direcore26/firewall/rules --type in --action ACCEPT --proto tcp --dport 444,555,7800:7810,8280 --comment "main laptop at community center" --enable 1
```


Create a route on your machine
```
sudo route add 10.10.10.0/24 via 10.0.0.125
```



