# Deferred Sysctl Tweaks

These are not currently deployed but may be needed later.

## Discord RTC Fix (bridge networking)

Only needed if br0 bridge interface is configured (for VMs). Prevents bridge traffic from going through iptables, which causes Discord voice to drop.

```ini
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-ip6tables = 0
net.netfilter.nf_conntrack_udp_timeout = 120
net.netfilter.nf_conntrack_udp_timeout_stream = 180
```

Deploy to `/etc/sysctl.d/99-bridge-netfilter.conf` when br0 is set up.

## AI/ML Tuning

Reduces swap aggressiveness and increases network buffer sizes for local AI API traffic (Ollama, etc).

```ini
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
```

Deploy to `/etc/sysctl.d/99-ai-tuning.conf` when Ollama/ROCm stack is configured.
