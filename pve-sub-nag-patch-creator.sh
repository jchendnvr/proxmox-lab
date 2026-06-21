#!/bin/bash
# pve-sub-nag-patch-creator.sh
# 1) The patch is created, and permissions set for execution. 
# 2) The patch is called to correct
# 3) A call to the patch is added to apt.conf.d so that if future updates erase over the patch, it is repatched. 
 
cat >/usr/local/bin/pve-sub-nag-patch.sh <<'EOF'
#!/bin/bash
# PVE-SUB-NAG-PATCH 
# File is idempotent, based on combination of community and h2dcomputers gist. 

JS_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

# Check if the marker is absent from the file
if ! grep -q "// PVE-SUB-NAG-PATCH" "$JS_FILE"; then
    echo "Applying patch..."
    
    # Inject the comment marker and the payload using a newline (\n)
    sed -i '/checked_command: function (orig_cmd) {$/a\    // PVE-SUB-NAG-PATCH\n    return (typeof orig_cmd === "function" && (orig_cmd(), true));' "$JS_FILE"
    
    systemctl restart pveproxy.service
else
    echo "Patch already applied. Skipping."
fi

EOF


chmod 755 /usr/local/bin/pve-sub-nag-patch.sh

/usr/local/bin/pve-sub-nag-patch.sh

cat >/etc/apt/apt.conf.d/pve-sub-nag-patch <<'EOF'
DPkg::Post-Invoke { "/usr/local/bin/pve-sub-nag-patch.sh"; };

EOF

chmod 644 /etc/apt/apt.conf.d/pve-sub-nag-patch

