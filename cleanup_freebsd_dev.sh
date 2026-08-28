#!/bin/bash

# FreeBSD Development Environment Cleanup Script
# This script removes the FreeBSD VM, network configuration, and optionally the downloaded image

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_IMAGE_DIR="/var/lib/libvirt/images/freebsd-dev"
CLOUD_INIT_DIR="/var/lib/libvirt/images/freebsd-dev/cloud-init"
VM_NAME="freebsd-dev"
NETWORK_NAME="mgmt-net"
FREEBSD_VERSION="15.1"
FREEBSD_IMAGE="FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64-BASIC-CLOUDINIT-ufs.qcow2"

echo "=== FreeBSD Development Environment Cleanup ==="
echo "This script will:"
echo "1. Stop and remove the FreeBSD VM"
echo "2. Remove the libvirt network configuration"
echo "3. Optionally remove the downloaded FreeBSD image"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Ask for confirmation
read -p "Do you want to remove the downloaded FreeBSD image as well? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    REMOVE_IMAGE=true
else
    REMOVE_IMAGE=false
fi

# Step 1: Stop and remove VM
echo "Step 1: Stopping and removing VM..."
if virsh list --all | grep -q "$VM_NAME"; then
    echo "Stopping VM $VM_NAME..."
    virsh shutdown "$VM_NAME" 2>/dev/null || virsh destroy "$VM_NAME" 2>/dev/null || true
    
    echo "Waiting for VM to stop..."
    for i in {1..30}; do
        if ! virsh list | grep -q "$VM_NAME"; then
            break
        fi
        echo "Waiting... ($i/30)"
        sleep 2
    done
    
    echo "Undefining VM $VM_NAME..."
    virsh undefine "$VM_NAME" 2>/dev/null || true
    echo "VM $VM_NAME removed"
else
    echo "VM $VM_NAME does not exist, skipping"
fi

# Step 2: Remove network configuration
echo "Step 2: Removing network configuration..."
if virsh net-list --all | grep -q "$NETWORK_NAME"; then
    echo "Destroying network $NETWORK_NAME..."
    virsh net-destroy "$NETWORK_NAME" 2>/dev/null || true
    
    echo "Undefining network $NETWORK_NAME..."
    virsh net-undefine "$NETWORK_NAME" 2>/dev/null || true
    echo "Network $NETWORK_NAME removed"
else
    echo "Network $NETWORK_NAME does not exist, skipping"
fi

# Step 3: Remove cloud-init configuration
echo "Step 3: Removing cloud-init configuration..."
if [ -d "$CLOUD_INIT_DIR" ]; then
    echo "Removing cloud-init directory $CLOUD_INIT_DIR..."
    rm -rf "$CLOUD_INIT_DIR"
    echo "Cloud-init configuration removed"
else
    echo "Cloud-init directory does not exist, skipping"
fi

# Step 4: Optionally remove the downloaded image
if [ "$REMOVE_IMAGE" = true ]; then
    echo "Step 4: Removing downloaded FreeBSD image..."
    if [ -f "$VM_IMAGE_DIR/$FREEBSD_IMAGE" ]; then
        echo "Removing $VM_IMAGE_DIR/$FREEBSD_IMAGE..."
        rm -f "$VM_IMAGE_DIR/$FREEBSD_IMAGE"
        echo "FreeBSD image removed"
    else
        echo "FreeBSD image does not exist, skipping"
    fi
    
    # Remove the entire VM image directory if empty
    if [ -d "$VM_IMAGE_DIR" ] && [ -z "$(ls -A $VM_IMAGE_DIR)" ]; then
        echo "Removing empty VM image directory $VM_IMAGE_DIR..."
        rmdir "$VM_IMAGE_DIR"
        echo "VM image directory removed"
    fi
else
    echo "Step 4: Skipping FreeBSD image removal (as requested)"
fi

# Step 5: Stop NFS server (optional)
read -p "Do you want to stop and disable the NFS server? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Step 5: Stopping NFS server..."
    systemctl stop nfs-kernel-server 2>/dev/null || true
    systemctl disable nfs-kernel-server 2>/dev/null || true
    echo "NFS server stopped and disabled"
else
    echo "Step 5: Skipping NFS server stop (as requested)"
fi

echo ""
echo "=== Cleanup Complete ==="
echo "VM: $VM_NAME - Removed"
echo "Network: $NETWORK_NAME - Removed"
echo "Cloud-init: Removed"
if [ "$REMOVE_IMAGE" = true ]; then
    echo "FreeBSD image: Removed"
else
    echo "FreeBSD image: Preserved at $VM_IMAGE_DIR/$FREEBSD_IMAGE"
fi
echo ""
echo "To reinstall, run: sudo ./install_freebsd_dev.sh"