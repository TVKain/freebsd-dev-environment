# Exercise 2: Add a Custom Kernel Module with Sysctl

## Objective
Create a simple kernel module that adds a custom sysctl parameter to the FreeBSD kernel. This exercise will teach you:
- How FreeBSD kernel modules are structured
- How to create a basic loadable kernel module
- How to add custom sysctl parameters for runtime configuration
- How to build, load, and test kernel modules

## Background
Kernel modules in FreeBSD are loadable kernel components that can be dynamically loaded and unloaded without rebooting. Sysctl (system control) is a mechanism for querying and modifying kernel parameters at runtime. This exercise combines both concepts.

## Detailed Steps

### Step 1: Understand the Basic Concepts
Before we start coding, let's understand the key concepts:

**What is a Kernel Module?**
- A kernel module is a piece of code that can be loaded into the running kernel without rebooting
- Think of it like a plugin for the kernel - you can add functionality dynamically
- Modules can be loaded with `kldload` and unloaded with `kldunload`

**What is Sysctl?**
- Sysctl (system control) is a way to view and change kernel parameters at runtime
- It's like a control panel for kernel settings
- You can access sysctl parameters with the `sysctl` command
- Examples: `sysctl vm.loadavg` shows system load averages

**What We're Building:**
- A simple kernel module that adds a custom sysctl parameter
- This parameter will be an integer that you can read and change while the system is running
- It will appear under `dev.mysysctl.mysysctl` in the sysctl tree

### Step 2: Understand the Sysctl Pattern
Here's the basic pattern for creating a sysctl parameter:

```c
static int my_value = 42;
SYSCTL_INT(_dev, OID_AUTO, mysysctl, CTLFLAG_RW, &my_value, 0,
    "My custom sysctl parameter");
```

**Breakdown of the SYSCTL_INT macro:**
- `static int my_value = 42;`: This is the actual variable that stores the value
- `_dev`: The sysctl namespace (first level - this puts it under "dev")
- `OID_AUTO`: Automatically generate the object identifier (don't worry about the technical details)
- `mysysctl`: The name of your parameter (this will be the second part of the path)
- `CTLFLAG_RW`: Read/write flag (allows you to change the value at runtime)
- `&my_value`: Pointer to the variable that stores the value
- `0`: Extra argument (not used for integer type, always 0)
- `"My custom sysctl parameter"`: Description that appears when you ask for help

**What this creates:**
- A sysctl parameter at `dev.mysysctl.mysysctl`
- Initially set to 42
- You can read it with `sysctl dev.mysysctl.mysysctl`
- You can change it with `sysctl dev.mysysctl.mysysctl=100`

### Step 3: Create Your Module Directory
Create a new directory for your custom module:

```bash
# Create a new module directory
mkdir /mnt/shared/freebsd-src/sys/modules/mysysctl
cd /mnt/shared/freebsd-src/sys/modules/mysysctl
```

**Why this location:** FreeBSD kernel modules are organized under `/sys/modules/` with each module having its own subdirectory. This is the standard location for custom kernel modules.

### Step 4: Write the Module Code
Create a `mysysctl.c` file with the following code:

```c
#include <sys/param.h>
#include <sys/systm.h>
#include <sys/conf.h>
#include <sys/kernel.h>
#include <sys/module.h>
#include <sys/errno.h>

// Define a variable that will be exposed via sysctl
static int my_value = 42;

// Create the sysctl parameter
// This will appear as dev.mysysctl.mysysctl
SYSCTL_INT(_dev, OID_AUTO, mysysctl, CTLFLAG_RW, &my_value, 0,
    "My custom sysctl parameter");

// Module load/unload event handler
static int
mysysctl_modevent(module_t mod __unused, int type, void *data __unused)
{
    int error = 0;

    switch (type) {
    case MOD_LOAD:
        // Code to run when module is loaded
        printf("mysysctl: module loaded\n");
        break;
    case MOD_UNLOAD:
        // Code to run when module is unloaded
        printf("mysysctl: module unloaded\n");
        break;
    default:
        error = EOPNOTSUPP;
        break;
    }
    return (error);
}

// Module declaration macros
DEV_MODULE(mysysctl, mysysctl_modevent, NULL);
MODULE_VERSION(mysysctl, 1);
```

**Code explanation:**
- **Headers**: Include necessary FreeBSD kernel headers (these are standard for kernel modules)
- **Static variable**: `my_value` is the integer value we'll expose via sysctl
- **SYSCTL_INT**: Creates a read/write integer sysctl parameter
- **modevent function**: Handles module load/unload events (this is called by the kernel when you load/unload)
- **DEV_MODULE**: Declares this as a device module (standard module declaration)
- **MODULE_VERSION**: Sets module version information (required for all modules)

**Understanding the modevent function:**
- This function is called by the kernel when the module is loaded or unloaded
- `MOD_LOAD`: Runs when you load the module with `kldload`
- `MOD_UNLOAD`: Runs when you unload the module with `kldunload`
- The `printf` statements will appear in `dmesg` (kernel messages)
- `EOPNOTSUPP` is returned for unsupported operations

### Step 5: Create the Makefile
Create a `Makefile` in the same directory:

```makefile
KMOD=mysysctl
SRCS=mysysctl.c

.include <bsd.kmod.mk>
```

**Makefile explanation:**
- **KMOD**: Specifies the kernel module name
- **SRCS**: Lists the source files to compile
- **.include <bsd.kmod.mk>**: Includes the standard FreeBSD kernel module makefile template

### Step 6: Build the Module
Now let's compile your module:

```bash
# Build from the module directory
cd /mnt/shared/freebsd-src/sys/modules/mysysctl
make
```

**What happens:**
- The build system compiles your C code
- It links against the kernel headers
- It creates a `.ko` (kernel object) file
- If successful, you'll see `mysysctl.ko` in the directory

**Common build issues:**
- If you get "make: command not found" errors, you may need to install build tools
- If you get header errors, ensure you're in the correct directory
- If you get permission errors, make sure you have write access to the shared directory

### Step 7: Load and Test the Module
Now let's load and test your module:

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

# Verify the change
sysctl dev.mysysctl.mysysctl

# Check kernel messages
dmesg | tail -10

# Unload when done
kldunload mysysctl
```

**Testing explanation:**
- **kldload**: Loads the kernel module into the running kernel
- **kldstat**: Lists all loaded kernel modules
- **sysctl dev.mysysctl**: Shows all sysctl parameters under dev.mysysctl
- **sysctl dev.mysysctl.mysysctl**: Shows/sets your specific parameter
- **dmesg**: Shows kernel messages (including our printf statements)
- **kldunload**: Unloads the module from the kernel

## Expected Outcome
You should be able to:
- Build a kernel module without errors
- Load it with `kldload` and see it in `kldstat`
- See your custom sysctl parameter in the sysctl tree
- Read and modify your sysctl parameter at runtime
- See your printf messages in `dmesg`
- Unload the module cleanly with `kldunload`

## Common Issues and Solutions

### Build Fails with "make: command not found"
**Solution:** Ensure you have the FreeBSD build tools installed. On the FreeBSD VM, you may need to install the build tools.

### Module Fails to Load with "Exec format error"
**Solution:** This usually means the module was compiled for a different kernel version. Ensure you're building against the running kernel source.

### Sysctl Parameter Not Visible
**Solution:** Check that:
1. The module is loaded (`kldstat`)
2. You're using the correct sysctl path (`dev.mysysctl.mysysctl`)
3. There are no typos in the SYSCTL_INT macro

### Module Won't Unload
**Solution:** This can happen if something is still using the module. Check for open file handles or processes using the module.

## Advanced Options

Once you have the basic module working, you can try:

### Different Sysctl Types
- **SYSCTL_STRING**: For string parameters
- **SYSCTL_UINT**: For unsigned integers
- **SYSCTL_LONG**: For long integers
- **SYSCTL_STRUCT**: For complex data structures

### Custom Sysctl Namespace
Instead of `_dev`, you can create your own namespace:
```c
SYSCTL_INT(_mysysctl, OID_AUTO, my_value, CTLFLAG_RW, &my_value, 0,
    "My custom sysctl parameter");
```
This would appear as `mysysctl.my_value` instead of `dev.mysysctl.my_value`.

### Multiple Sysctl Parameters
You can add multiple SYSCTL macros in a single module to expose several parameters.

## Tips
- Start with a simple integer sysctl parameter before trying more complex types
- Look at `/sys/kern/sysctl` for more sysctl examples in kernel code
- Check `/sys/conf/files` for how modules are registered in the build system
- Use `dmesg` to see any kernel messages from your module (like our printf statements)
- Always unload your module when done testing to avoid conflicts
- If you make changes to the code, you need to rebuild with `make` before loading again