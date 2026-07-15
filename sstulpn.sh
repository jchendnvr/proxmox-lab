#!/bin/bash

echo "=== HOST ===" && ss -tulnp; \
for vmid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do \
  pid=$(lxc-info -n $vmid -p 2>/dev/null | awk '{print $2}'); \
  if [ ! -z "$pid" ] && [ "$pid" != "-1" ]; then \
    echo "\n=== LXC $vmid ==="; \
    pct exec $vmid hostname; \
    echo "  \n"; \
    nsenter -t $pid -n ss -tulnp; \
  fi; \
done; \
for vmid in $(qm list 2>/dev/null | awk 'NR>1 {print $1}'); do \
  status=$(qm status $vmid | awk '{print $2}'); \
  if [ "$status" = "running" ]; then \
    echo "\n\n=== VM $vmid ==="; \
    qm guest exec $vmid -- hostname 2>/dev/null | jq -r '.["out-data"]' || echo "QEMU Guest Agent not responding"; \
    qm guest exec $vmid -- ss -tulnp 2>/dev/null | jq -r '.["out-data"]' || echo "QEMU Guest Agent not responding"; \
  fi; \
done
