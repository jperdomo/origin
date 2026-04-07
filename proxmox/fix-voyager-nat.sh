#!/bin/bash
set -e

echo "==> Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sh -c 'echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ip-forward.conf'

echo "==> Adding masquerade rule via firewalld..."
sudo firewall-cmd --zone=libvirt --add-masquerade 2>/dev/null \
  || sudo firewall-cmd --permanent --add-masquerade

sudo firewall-cmd --permanent --zone=libvirt --add-masquerade 2>/dev/null \
  || sudo firewall-cmd --permanent --add-masquerade

echo "==> Ensuring libvirt default network is defined and active..."
if ! sudo virsh net-info default &>/dev/null; then
  sudo virsh net-define /dev/stdin <<'EOF'
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
  echo "    Network defined."
fi

if ! sudo virsh net-list | grep -q default; then
  sudo virsh net-start default
  echo "    Network started."
fi

sudo virsh net-autostart default

echo "==> Reloading firewalld..."
sudo firewall-cmd --reload

# Get the default outbound interface
OUTIF=$(ip route show default | awk '{print $5; exit}')
echo "==> Adding FORWARD rules (outbound via $OUTIF)..."
sudo iptables -I FORWARD -i virbr0 -o "$OUTIF" -s 192.168.122.0/24 -j ACCEPT
sudo iptables -I FORWARD -i "$OUTIF" -o virbr0 -d 192.168.122.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "==> Installing persistent firewall rules via networkd-dispatcher..."
sudo mkdir -p /etc/networkd-dispatcher/routable.d
sudo tee /etc/networkd-dispatcher/routable.d/50-virbr0-forward.sh > /dev/null <<SCRIPT
#!/bin/bash
OUTIF=\$(ip route show default | awk '{print \$5; exit}')
iptables -C FORWARD -i virbr0 -o "\$OUTIF" -s 192.168.122.0/24 -j ACCEPT 2>/dev/null \\
  || iptables -I FORWARD -i virbr0 -o "\$OUTIF" -s 192.168.122.0/24 -j ACCEPT
iptables -C FORWARD -i "\$OUTIF" -o virbr0 -d 192.168.122.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null \\
  || iptables -I FORWARD -i "\$OUTIF" -o virbr0 -d 192.168.122.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT
SCRIPT
sudo chmod +x /etc/networkd-dispatcher/routable.d/50-virbr0-forward.sh

echo "==> Done. FORWARD rules will persist across reboots."
