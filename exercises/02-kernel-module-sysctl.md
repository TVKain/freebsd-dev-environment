# Exercise 2: Add a Custom Kernel Module with Sysctl

## Objective
Create a simple kernel module that adds a custom sysctl parameter to the FreeBSD kernel.

## Detailed Steps

### Step 1: Explore Existing Modules
```bash
# Look at the modules directory
ls /mnt/shared/freebsd-src/sys/modules/

# Check out a simple module structure
cat /mnt/shared/freebsd-src/sys/modules/dtrace/dtraceall/dtraceall.c
cat /mnt/shared/freebsd-src/sys/modules/dtrace/dtraceall/Makefile
```

### Step 2: Look at Sysctl Examples
```bash
# See how sysctl is used in kernel code
grep -A5 -B5 'SYSCTL_INT.*write_behind' /mnt/shared/freebsd-src/sys/kern/vfs_cluster.c
```

This shows the pattern:
```c
static int write_behind = 1;
SYSCTL_INT(_vfs, OID_AUTO, write_behind, CTLFLAG_RW, &write_behind, 0,
    "Cluster write-behind; 0: disable, 1: enable, 2: backed off");
```

### Step 3: Create Your Module Directory
```bash
# Create a new module directory
mkdir /mnt/shared/freebsd-src/sys/modules/mysysctl
cd /mnt/shared/freebsd-src/sys/modules/mysysctl
```

### Step 4: Write the Module Code
Create a `mysysctl.c` file based on the dtraceall example and sysctl pattern:

**Basic structure from dtraceall.c:**
```c
#include <sys/param.h>
#include <sys/systm.h>
#include <sys/conf.h>
#include <sys/kernel.h>
#include <sys/module.h>
#include <sys/errno.h>

static int my_value = 42;
SYSCTL_INT(_dev, OID_AUTO, mysysctl, CTLFLAG_RW, &my_value, 0,
    "My custom sysctl parameter");

static int
mysysctl_modevent(module_t mod __unused, int type, void *data __unused)
{
    int error = 0;

    switch (type) {
    case MOD_LOAD:
        break;
    case MOD_UNLOAD:
        break;
    default:
        error = EOPNOTSUPP;
        break;
    }
    return (error);
}

DEV_MODULE(mysysctl, mysysctl_modevent, NULL);
MODULE_VERSION(mysysctl, 1);
```

### Step 5: Create the Makefile
Create a `Makefile`:
```makefile
KMOD=mysysctl
SRCS=mysysctl.c

.include <bsd.kmod.mk>
```

### Step 6: Build the Module
```bash
# Build from the module directory
cd /mnt/shared/freebsd-src/sys/modules/mysysctl
make
```

### Step 7: Load and Test
```bash
# Load the module
kldload ./mysysctl.ko

# Check if it's loaded
kldstat

# Test your sysctl parameter
sysctl dev.mysysctl
sysctl dev.mysysctl.mysysctl

# Try changing the value
sysctl dev.mysysctl.mysysctl=100

# Unload when done
kldunload mysysctl
```

## Expected Outcome
You should be able to:
- Build a kernel module without errors
- Load it with `kldload`
- See your custom sysctl parameter in the sysctl tree
- Read and potentially modify your sysctl parameter

## Tips
- Start with a simple integer sysctl parameter
- Look at `/sys/kern/sysctl` for sysctl examples in kernel code
- Check `/sys/conf/files` for how modules are registered
- Use `dmesg` to see any kernel messages from your module
