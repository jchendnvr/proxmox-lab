#!/bin/bash

# pve-sub-nag-patch-creator.sh
# 1) The patch is created, and permissions set for execution. 
# 2) The patch is called to correct
# 3) A call to the patch is added to apt.conf.d so that if future updates erase over the patch, it is repatched. 
# This patch looks for a specific line 'checked_command: function (orig_cmd) {'
# It then adds a new line with a comment, and another new line with a return statement. 
# This return statement ensures the subscription nag call doesn't run. 
# The file is checked on future runs for the comment, and if the comment is found, it does not need patching
# As of 20260620 and pve-manager/9.2.2/b9984c6d90a4bd80 (running kernel: 7.0.2-6-pve) this line is on 601
# As of 20260621 and pve-manager/9.2.3/d0fde103346cf89a (running kernel: 7.0.2-6-pve) this line is on 611


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

echo "Patched the subscription nag screens"
