#!/bin/bash

# FreeBSD Development Environment Installation Script
# This script automates the setup of a FreeBSD VM for kernel development
# with static IP configuration and NFS file sharing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$SCRIPT_DIR/shared"
CLOUD_INIT_DIR="/var/lib/libvirt/images/freebsd-dev/cloud-init"
VM_NAME="freebsd-dev"
NETWORK_NAME="mgmt-net"
STATIC_IP="192.168.0.50"
GATEWAY="192.168.0.1"
HOST_SHARED_DIR="/home/ktran/freebsd_dev/shared"

echo "=== FreeBSD Development Environment Setup ==="
echo "This script will:"
echo "1. Configure NFS server on WSL"
echo "2. Create libvirt network without DHCP"
echo "3. Generate cloud-init configuration with static IP"
echo "4. Define and start the FreeBSD VM"
echo "5. Configure autostart for VM and network"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Step 1: Install and configure NFS server
echo "Step 1: Configuring NFS server..."
if ! command -v exportfs &> /dev/null; then
    echo "Installing nfs-kernel-server..."
    apt-get update
    apt-get install -y nfs-kernel-server
fi

# Create shared directory if it doesn't exist
mkdir -p "$HOST_SHARED_DIR"

# Configure NFS exports
if ! grep -q "$HOST_SHARED_DIR" /etc/exports; then
    echo "$HOST_SHARED_DIR 192.168.0.0/24(rw,sync,no_subtree_check)" >> /etc/exports
    exportfs -ra
fi

# Enable and start NFS server
systemctl enable nfs-kernel-server
systemctl start nfs-kernel-server
echo "NFS server configured and running"

# Step 2: Create libvirt network without DHCP
echo "Step 2: Configuring libvirt network..."
if virsh net-list --all | grep -q "$NETWORK_NAME"; then
    echo "Network $NETWORK_NAME already exists, updating..."
    virsh net-destroy "$NETWORK_NAME" 2>/dev/null || true
    virsh net-undefine "$NETWORK_NAME" 2>/dev/null || true
fi

# Create network XML
cat > /tmp/$NETWORK_NAME.xml <<EOF
<network>
  <name>$NETWORK_NAME</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr1' stp='on' delay='0'/>
  <mac address='52:54:00:92:5a:58'/>
  <ip address='$GATEWAY' netmask='255.255.255.0'>
  </ip>
</network>
EOF

virsh net-define /tmp/$NETWORK_NAME.xml
virsh net-start "$NETWORK_NAME"
virsh net-autostart "$NETWORK_NAME"
echo "Network $NETWORK_NAME created and started"

# Step 3: Generate cloud-init configuration
echo "Step 3: Generating cloud-init configuration..."
mkdir -p "$CLOUD_INIT_DIR"

# Meta-data
cat > "$CLOUD_INIT_DIR/meta-data" <<EOF
instance-id: $VM_NAME
local-hostname: $VM_NAME
EOF

# User-data with static IP configuration
cat > "$CLOUD_INIT_DIR/user-data" <<'EOF'
#cloud-config

hostname: freebsd-dev
manage_etc_hosts: true

ssh_authorized_keys:
  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGGhb0oLnSCJ3/yVsa0hgMWACtse56zKuUARGjn47Qfe ktran@W-9NVXZF4

users:
  - name: root
    shell: /bin/sh
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGGhb0oLnSCJ3/yVsa0hgMWACtse56zKuUARGjn47Qfe ktran@W-9NVXZF4

runcmd:
  - mount -u -o rw /
  - sysrc sshd_enable=YES
  - sysrc sshd_permitrootlogin=YES
  - sysrc hostname=freebsd-dev
  - hostname freebsd-dev
  - sysrc ifconfig_vtnet0="inet 192.168.0.50 netmask 255.255.255.0"
  - sysrc defaultrouter="192.168.0.1"
  - sysrc nameserver="8.8.8.8 8.8.4.4"
  - sysrc dhclient_enable=NO
  - sysrc nuageinit_enable=NO
  - grep -v 'ifconfig_DEFAULT' /etc/rc.conf > /tmp/rc.conf.tmp && mv /tmp/rc.conf.tmp /etc/rc.conf
  - grep -v 'dhclient' /etc/rc.conf > /tmp/rc.conf.tmp && mv /tmp/rc.conf.tmp /etc/rc.conf
  - grep -v 'nuageinit' /etc/rc.conf > /tmp/rc.conf.tmp && mv /tmp/rc.conf.tmp /etc/rc.conf
  - rm -f /var/db/dhclient.leases.*
  - service netif restart
  - service routing restart
  - service sshd start
  - mkdir -p /mnt/shared
  - echo "192.168.0.1:/home/ktran/freebsd_dev/shared /mnt/shared nfs rw,late 0 0" >> /etc/fstab
  - mount -t nfs 192.168.0.1:/home/ktran/freebsd_dev/shared /mnt/shared

packages:
  - git
  - vim
  - bash
  - sudo

system_info:
  distro: freebsd
  network:
    renderers: ['freebsd']
  paths:
    run_dir: /var/run/cloud-init/
EOF

# Generate seed.iso
cd "$CLOUD_INIT_DIR"
genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data
echo "Cloud-init configuration generated"

# Step 4: Define and start VM
echo "Step 4: Configuring VM..."
if virsh list --all | grep -q "$VM_NAME"; then
    echo "VM $VM_NAME already exists, removing..."
    virsh destroy "$VM_NAME" 2>/dev/null || true
    virsh undefine "$VM_NAME" 2>/dev/null || true
fi

# Create VM XML
cat > /tmp/$VM_NAME.xml <<EOF
<domain type='kvm'>
  <name>$VM_NAME</name>
  <uuid>f68c7a46-d3da-45d7-8604-0c56ff798348</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://freebsd.org/freebsd/15.1"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit='KiB'>16777216</memory>
  <currentMemory unit='KiB'>16777216</currentMemory>
  <memoryBacking>
    <source type='memfd'/>
    <access mode='shared'/>
  </memoryBacking>
  <vcpu placement='static'>8</vcpu>
  <resource>
    <partition>/machine</partition>
  </resource>
  <os>
    <type arch='x86_64' machine='pc-i440fx-resolute'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <vmport state='off'/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'/>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/freebsd-dev/FreeBSD-15.1-RELEASE-amd64-BASIC-CLOUDINIT-ufs.qcow2'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='$CLOUD_INIT_DIR/seed.iso'/>
      <target dev='hda' bus='ide'/>
      <readonly/>
      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>
    <controller type='ide' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x1'/>
    </controller>
    <controller type='usb' index='0' model='ich9-ehci1'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x7'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci1'>
      <master startport='0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0' multifunction='on'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci2'>
      <master startport='2'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x1'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci3'>
      <master startport='4'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'/>
    <controller type='virtio-serial' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
    </controller>
    <interface type='network'>
      <mac address='52:54:00:12:34:56'/>
      <source network='$NETWORK_NAME'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>
    <serial type='pty'>
      <target type='isa-serial' port='0'>
        <model name='isa-serial'/>
      </target>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <input type='tablet' bus='usb'>
      <address type='usb' bus='0' port='1'/>
    </input>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='spice' port='5900' autoport='yes' listen='127.0.0.1'>
      <listen type='address' address='127.0.0.1'/>
      <image compression='off'/>
    </graphics>
    <sound model='ich6'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </sound>
    <audio id='1' type='spice'/>
    <video>
      <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1' primary='yes'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x08' function='0x0'/>
    </memballoon>
  </devices>
  <seclabel type='dynamic' model='dac' relabel='yes'>
    <label>+64055:+991</label>
    <imagelabel>+64055:+991</label>
  </seclabel>
</domain>
EOF

virsh define /tmp/$VM_NAME.xml
virsh start "$VM_NAME"
virsh autostart "$VM_NAME"
echo "VM $VM_NAME defined and started"

# Step 5: Wait for VM to boot and verify connectivity
echo "Step 5: Waiting for VM to boot and acquire IP..."
echo "This may take 30-60 seconds..."

for i in {1..30}; do
    if ping -c 1 -W 2 "$STATIC_IP" &> /dev/null; then
        echo "VM is reachable at $STATIC_IP"
        break
    fi
    echo "Waiting for VM... ($i/30)"
    sleep 2
done

if ! ping -c 1 -W 2 "$STATIC_IP" &> /dev/null; then
    echo "Warning: VM did not respond to ping. You may need to check the console."
    echo "Connect with: sudo virsh console $VM_NAME"
fi

echo ""
echo "=== Setup Complete ==="
echo "VM Name: $VM_NAME"
echo "Static IP: $STATIC_IP"
echo "Gateway: $GATEWAY"
echo "Shared Directory: $HOST_SHARED_DIR (host) -> /mnt/shared (VM)"
echo ""
echo "SSH Access:"
echo "  ssh root@$STATIC_IP"
echo ""
echo "VM Management:"
echo "  Start: sudo virsh start $VM_NAME"
echo "  Stop: sudo virsh shutdown $VM_NAME"
echo "  Console: sudo virsh console $VM_NAME"
echo "  Status: sudo virsh list"
echo ""
echo "The VM and network are configured to autostart on system boot."