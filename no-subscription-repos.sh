#!/bin/bash

# no-subscription-repos.sh
# 1) Disable enterprise repo
# 2) Create no subscription repo, proxmox-sources
# 3) Disable the enterprise ceph repo
# 4) Add the no subscription ceph tentacle repo


echo "Enabled: false" >> /etc/apt/sources.list.d/pve-enterprise.sources 
   
cat >/etc/apt/sources.list.d/proxmox.sources < 'EOF'   
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg

EOF


cat > /etc/apt/sources.list.d/ceph.source < 'EOF' 
Types: deb
URIs: https://enterprise.proxmox.com/debian/ceph-squid
Suites: trixie
Components: enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: false
  
Types: deb
URIs: http://download.proxmox.com/debian/ceph-tentacle
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
 > /etc/apt/sources.list.d/ceph.source

EOF

echo "Updated repos, disabled Enterprise Repos, enabled no subscription pve and ceph."
