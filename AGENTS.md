# FreeBSD Development Environment

## Environment Setup
- **Platform**: WSL2 on Linux 6.18.33.2-microsoft-standard-WSL2
- **Virtualization**: KVM QEMU installed
- **Goal**: Install and run FreeBSD VM for kernel development
- **Code Location**: WSL filesystem, to be shared with FreeBSD VM

## Project Context
This environment is set up for FreeBSD kernel development. The development code resides on the WSL filesystem and needs to be shared with the FreeBSD VM through an appropriate mechanism.

## File Sharing Options
**Selected Method**: NFS (Network File System)
- Virtio-fs was not available for FreeBSD 15.1 (no kernel module or package)
- NFS provides reliable file sharing with good performance for development
- Well-supported on both Linux (WSL) and FreeBSD

## Certificate Issues Fixed
The pkg system had SSL certificate verification errors due to Dell's corporate network:
- Changed FreeBSD pkg repository from HTTPS to HTTP
- Disabled problematic FreeBSD-ports and FreeBSD-ports-kmods repositories
- Used base FreeBSD repository with HTTP protocol
- Package system now works correctly

## NFS Configuration
**Host (WSL) Setup**:
- Installed `nfs-kernel-server` on WSL
- Exported `/home/ktran/freebsd_dev/shared` to `192.168.0.0/24` network
- NFS server running on WSL host

**FreeBSD VM Setup**:
- Mounted NFS share: `mount -t nfs 192.168.0.1:/home/ktran/freebsd_dev/shared /mnt/shared`
- Added to `/etc/fstab` for persistent mounting across reboots
- Verified file access works in both directions

## SSH Configuration
SSH root login is properly configured using FreeBSD's `sysrc` mechanism:
- `sysrc sshd_permitrootlogin=YES` sets the permit root login in `/etc/rc.conf`
- This is more reliable than writing the sshd_config file directly via cloud-init
- The setting persists across reboots

## Hostname Configuration
The VM hostname is properly set via cloud-init:
- `hostname: freebsd-dev` in cloud-config sets the hostname
- `local-hostname: freebsd-dev` in meta-data provides the hostname to nuageinit
- Cloud-init's native hostname configuration is used instead of manual commands
- Verified to persist across reboots

## VM Configuration
- **VM Name**: freebsd-dev
- **Hypervisor**: libvirt (virsh)
- **FreeBSD Version**: 15.1-RELEASE
- **Shared Directory**: /home/ktran/freebsd_dev/shared
- **NFS Mount Point**: /mnt/shared (inside FreeBSD VM)
- **Fixed IP Address**: 192.168.0.50
- **MAC Address**: 52:54:00:12:34:56
- **Status**: Running (only VM in the system)

## Known Issues and Solutions

### Issue 1: IP Address Not Persisting Across Reboots
**Problem**: The VM would lose its static IP address (192.168.0.50) after reboots and fail to respond to ping.

**Root Causes**:
1. **DHCP Client Still Running**: Despite configuring static IP via `sysrc`, the DHCP client (dhclient) was still running and attempting to obtain IP addresses
2. **ifconfig_DEFAULT DHCP Fallback**: The `ifconfig_DEFAULT="SYNCDHCP accept_rtadv"` setting in `/etc/rc.conf` was causing the system to fall back to DHCP
3. **DHCP Lease Files**: Old DHCP lease files in `/var/db/dhclient.leases.vtnet0` were causing conflicts
4. **nuageinit Service**: The cloud-init service was configured to run on subsequent boots, potentially interfering with static configuration

**Solution**:
- Added `sysrc dhclient_enable=NO` to disable DHCP client
- Removed `ifconfig_DEFAULT` entry from `/etc/rc.conf` via grep filtering
- Added cleanup of DHCP lease files: `rm -f /var/db/dhclient.leases.*`
- Added network configuration to cloud-init's native `network` section for proper static IP setup
- Configured libvirt network without DHCP server

**Configuration**:
```yaml
network:
  version: 2
  ethernets:
    vtnet0:
      dhcp4: false
      addresses:
        - 192.168.0.50/24
      gateway4: 192.168.0.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

### Issue 2: Hostname Not Persisting Across Reboots
**Problem**: The hostname would revert to "freebsd-build-node" instead of staying as "freebsd-dev" after reboots.

**Root Causes**:
1. **Leftover Configuration File**: The file `/etc/rc.conf.d/hostname` existed from the initial installation and contained `hostname="freebsd-build-node"`
2. **File Override Priority**: The `/etc/rc.conf.d/hostname` file was taking precedence over both the cloud-init hostname setting and the `/etc/rc.conf` hostname setting
3. **Manual Command Approach**: Initially tried to set hostname via manual commands in runcmd, but this was being overridden by the leftover file

**Solution**:
- Removed manual hostname commands from runcmd section
- Relied on cloud-init's native hostname configuration (`hostname: freebsd-dev` in cloud-config)
- Added `rm -f /etc/rc.conf.d/hostname` to cleanup the problematic file
- Used cloud-init's `network` section for network configuration instead of manual sysrc commands
- Let nuageinit (FreeBSD's cloud-init implementation) handle hostname naturally

**Configuration**:
```yaml
hostname: freebsd-dev
manage_etc_hosts: true
```

**Meta-data**:
```yaml
instance-id: freebsd-dev
local-hostname: freebsd-dev
```

## Important Notes
- **Cloud-Init Works**: FreeBSD's nuageinit (cloud-init implementation) properly handles hostname and network configuration when using the native cloud-config format
- **File Cleanup**: The `/etc/rc.conf.d/` directory can contain files that override `/etc/rc.conf` settings, so cleanup is essential
- **DHCP Conflicts**: Even with static IP configuration, DHCP client must be explicitly disabled to prevent conflicts
- **Network Configuration**: Using cloud-init's native `network` section is more reliable than manual network configuration commands

## Setup Instructions

### File Sharing (NFS)
The NFS share is already configured and mounted:
- **Host (WSL)**: `/home/ktran/freebsd_dev/shared` 
- **VM (FreeBSD)**: `/mnt/shared`
- Files placed in the WSL directory are immediately available in the VM
- The mount is persistent across VM reboots (configured in /etc/fstab)

### FreeBSD Source Code
The FreeBSD source tree has been cloned into the shared directory:
- **Location**: `/home/ktran/freebsd_dev/shared/freebsd-src` (WSL) → `/mnt/shared/freebsd-src` (VM)
- **Size**: 3.9GB
- **Repository**: https://git.freebsd.org/src.git
- **Key directories**:
  - `sys/` - Kernel source code
  - `usr.bin/` - Userland binaries
  - `usr.sbin/` - Userland system binaries
  - `lib/` - Libraries
  - `include/` - Header files

### Additional NFS Mount (if needed)
If you need to manually mount the NFS share:
```sh
mount -t nfs 192.168.0.1:/home/ktran/freebsd_dev/shared /mnt/shared
```

### SSH Access
- Root login is enabled via SSH with your SSH key (configured via sysrc)
- SSH as root: `ssh root@192.168.0.50`
- Fixed IP: 192.168.0.50

### VM Management Commands
- Start VM: `sudo virsh start freebsd-dev`
- Stop VM: `sudo virsh shutdown freebsd-dev`
- Connect to console: `sudo virsh console freebsd-dev`
- Check status: `sudo virsh list`

### File Access
- Files placed in `/home/ktran/freebsd_dev/shared` on WSL will be available in `/mnt/shared` inside FreeBSD
- This provides high-performance shared access for kernel development
