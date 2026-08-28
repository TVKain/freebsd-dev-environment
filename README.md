# FreeBSD Development Environment

Automated setup for FreeBSD kernel development environment using libvirt/KVM on WSL2.

## Features

- **Static IP Configuration**: FreeBSD VM configured with static IP (192.168.0.50) - no DHCP dependency
- **NFS File Sharing**: Automatic NFS mount of shared directory between WSL host and FreeBSD VM
- **Autostart**: Both VM and network configured to start automatically on system boot
- **SSH Access**: Pre-configured SSH access for root and user accounts
- **Cloud-Init**: Automated configuration using cloud-init for consistent deployments

## Prerequisites

- WSL2 on Linux
- KVM/QEMU installed
- libvirt installed
- FreeBSD 15.1-RELEASE cloud-init image

## Quick Start

Run the installation script:

```bash
sudo ./install_freebsd_dev.sh
```

This script will:
1. Install and configure NFS server on WSL
2. Create libvirt network without DHCP
3. Generate cloud-init configuration with static IP
4. Define and start the FreeBSD VM
5. Configure autostart for VM and network

## Configuration

### Network Configuration
- **VM Name**: freebsd-dev
- **Static IP**: 192.168.0.50
- **Gateway**: 192.168.0.1
- **Network**: mgmt-net (libvirt)

### File Sharing
- **Host Directory**: `/home/ktran/freebsd_dev/shared`
- **VM Mount Point**: `/mnt/shared`
- **Protocol**: NFS

### SSH Access
```bash
# SSH as root
ssh root@192.168.0.50

# SSH as user
ssh ktran@192.168.0.50
```

## VM Management

```bash
# Start VM
sudo virsh start freebsd-dev

# Stop VM
sudo virsh shutdown freebsd-dev

# Connect to console
sudo virsh console freebsd-dev

# Check status
sudo virsh list

# Force stop if needed
sudo virsh destroy freebsd-dev
```

## Network Management

```bash
# Start network
sudo virsh net-start mgmt-net

# Stop network
sudo virsh net-destroy mgmt-net

# Check network status
sudo virsh net-list
```

## File Access

Files placed in `/home/ktran/freebsd_dev/shared` on WSL are immediately available in `/mnt/shared` inside the FreeBSD VM.

## Troubleshooting

### VM not responding to ping
1. Check if VM is running: `sudo virsh list`
2. Connect to console: `sudo virsh console freebsd-dev`
3. Check network configuration: `ifconfig` inside VM
4. Verify network is running: `sudo virsh net-list`

### NFS mount issues
1. Check NFS server status: `sudo systemctl status nfs-kernel-server`
2. Restart NFS server: `sudo systemctl restart nfs-kernel-server`
3. Check exports: `sudo exportfs -v`
4. Manual mount inside VM: `mount -t nfs 192.168.0.1:/home/ktran/freebsd_dev/shared /mnt/shared`

### Read-only filesystem in VM
The cloud-init script handles this by running `mount -u -o rw /` before making configuration changes.

## Project Structure

```
freebsd_dev/
├── install_freebsd_dev.sh    # Main installation script
├── shared/                   # Shared directory (NFS mount)
│   └── freebsd-src/         # FreeBSD source code
├── AGENTS.md                 # Project documentation
└── README.md                 # This file
```

## License

This project is for personal development use.