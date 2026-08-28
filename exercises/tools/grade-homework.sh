#!/bin/bash

# Grading Utility - Run the grading tool on the FreeBSD VM
# This script executes the grading tool remotely via SSH

set -e

VM_IP="192.168.0.50"
VM_USER="root"
GRADING_SCRIPT="/mnt/shared/freebsd_dev/exercises/tools/02-grading-tool.sh"

echo "=========================================="
echo "  FreeBSD Kernel Module Grading Utility"
echo "=========================================="
echo ""

# Check if VM is accessible
echo "Checking VM connectivity..."
if ! ping -c 1 -W 2 "$VM_IP" >/dev/null 2>&1; then
    echo "Error: Cannot reach VM at $VM_IP"
    echo "Please ensure the FreeBSD VM is running"
    exit 1
fi

echo "VM is accessible"
echo ""

# Check if grading script exists on VM
echo "Checking for grading script on VM..."
if ! ssh "$VM_USER@$VM_IP" "test -f $GRADING_SCRIPT"; then
    echo "Error: Grading script not found on VM: $GRADING_SCRIPT"
    echo "Please ensure the exercises directory is shared via NFS"
    exit 1
fi

echo "Grading script found"
echo ""

# Run the grading tool
echo "Running grading tool on VM..."
echo ""
ssh "$VM_USER@$VM_IP" "sh $GRADING_SCRIPT"

echo ""
echo "=========================================="
echo "  Grading Complete"
echo "=========================================="