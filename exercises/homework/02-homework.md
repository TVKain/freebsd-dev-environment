# Exercise 2: Homework Assignment

## Assignment: Advanced Kernel Module with Multiple Sysctl Parameters

### Objective
Create a kernel module that implements a simple counter system with multiple sysctl parameters. This will build on the basic module from the exercise and add more complexity.

### Requirements

Your module must implement the following features:

1. **Counter System**
   - A counter that starts at 0
   - Can be incremented by a custom sysctl parameter
   - Can be reset to 0 by another sysctl parameter
   - Current counter value should be readable via sysctl

2. **Multiple Data Types**
   - At least one integer parameter (the counter)
   - At least one string parameter (e.g., a name or description)
   - At least one boolean parameter (e.g., enable/disable feature)

3. **Parameter Validation**
   - The counter should not go below 0
   - The string parameter should have a maximum length (e.g., 32 characters)
   - The boolean parameter should only accept 0 or 1

4. **Module State**
   - Track how many times the module has been loaded
   - Display this information in kernel messages when loading/unloading
   - Store this value persistently (it should survive module unload/reload)

5. **Custom Sysctl Namespace**
   - Create your own sysctl namespace (not under `_dev`)
   - Organize your parameters logically under this namespace

6. **Thread Safety (Advanced)**
   - Protect the counter with a mutex to prevent race conditions
   - Understand that sysctl calls can happen from different threads/contexts
   - Handle concurrent access to shared data properly
   - Demonstrate understanding of kernel locking mechanisms

### Expected Sysctl Interface

Your module should create sysctl parameters like:
```
mycounter.counter          - Current counter value (read/write)
mycounter.increment        - Write to increment counter (write-only)
mycounter.reset           - Write to reset counter (write-only)
mycounter.enabled         - Enable/disable counter (read/write boolean)
mycounter.description     - Description string (read/write string)
mycounter.load_count      - How many times module loaded (read-only)
```

### Grading Criteria

**Total Points: 100**

#### Functionality (45 points)
- [ ] 10 points: Module compiles without errors
- [ ] 10 points: Module loads and unloads cleanly
- [ ] 10 points: Counter sysctl parameter works (can read and write)
- [ ] 10 points: Increment parameter works and increments counter
- [ ] 5 points: Reset parameter works and resets counter to 0

#### Thread Safety (20 points)
- [ ] 5 points: Mutex properly initialized and destroyed
- [ ] 5 points: Counter access protected by mutex in all operations
- [ ] 5 points: No race conditions in concurrent access scenarios
- [ ] 5 points: Proper understanding of kernel locking mechanisms

#### Data Types (15 points)
- [ ] 5 points: Integer parameter implemented correctly
- [ ] 5 points: String parameter implemented correctly
- [ ] 5 points: Boolean parameter implemented correctly

#### Validation (10 points)
- [ ] 5 points: Counter cannot go below 0
- [ ] 5 points: String parameter has length validation

#### Code Quality (10 points)
- [ ] 5 points: Code is well-commented
- [ ] 5 points: Code follows FreeBSD kernel coding style

#### Extra Credit (10 points)
- [ ] 5 points: Implement a custom sysctl handler function
- [ ] 5 points: Add a sysctl parameter that shows statistics (e.g., total increments)

### Hints

#### Hint 1: Multiple SYSCTL Parameters
You can add multiple SYSCTL macros in your module. Each one creates a different parameter:

```c
static int my_counter = 0;
SYSCTL_INT(_mycounter, OID_AUTO, counter, CTLFLAG_RW, &my_counter, 0,
    "Current counter value");

static int my_enabled = 1;
SYSCTL_INT(_mycounter, OID_AUTO, enabled, CTLFLAG_RW, &my_enabled, 0,
    "Enable counter feature");
```

#### Hint 2: Custom Sysctl Namespace
To create your own namespace, use a custom identifier instead of `_dev`:

```c
SYSCTL_INT(_mycounter, OID_AUTO, counter, CTLFLAG_RW, &my_counter, 0,
    "Current counter value");
```

This will create parameters under `mycounter.counter` instead of `dev.mycounter.counter`.

#### Hint 3: Write-Only Parameters
For write-only parameters (like increment), use `CTLFLAG_WR` instead of `CTLFLAG_RW`:

```c
SYSCTL_INT(_mycounter, OID_AUTO, increment, CTLFLAG_WR, &increment_value, 0,
    "Write to increment counter");
```

#### Hint 4: Custom Handler Functions
For validation and custom behavior, you can use a custom handler function:

```c
static int
sysctl_handle_counter(SYSCTL_HANDLER_ARGS)
{
    int error, new_value;
    
    // Get the new value from user
    new_value = arg1;
    error = sysctl_handle_int(oidp, &new_value, 0, req);
    if (error != 0 || req->newptr == NULL)
        return (error);
    
    // Validate the value
    if (new_value < 0)
        return (EINVAL);
    
    // Update the actual variable
    arg1 = new_value;
    return (0);
}
```

#### Hint 5: String Parameters
For string parameters, use SYSCTL_STRING and a character array:

```c
static char my_description[32] = "My counter module";
SYSCTL_STRING(_mycounter, OID_AUTO, description, CTLFLAG_RW,
    my_description, sizeof(my_description), "Module description");
```

#### Hint 6: Persistent State
To track load count across module reloads, you can use a sysctl parameter that persists:

```c
static int load_count = 0;
SYSCTL_INT(_mycounter, OID_AUTO, load_count, CTLFLAG_RD, &load_count, 0,
    "Number of times module loaded");

// In your MOD_LOAD case:
load_count++;
```

#### Hint 7: Kernel Messages
Use `printf` for kernel messages that appear in `dmesg`:

```c
case MOD_LOAD:
    printf("mycounter: Module loaded (load count: %d)\n", load_count);
    break;
```

#### Hint 8: Boolean Parameters
For boolean parameters, you can use integer with validation:

```c
static int my_enabled = 1;

static int
sysctl_handle_enabled(SYSCTL_HANDLER_ARGS)
{
    int error, new_value;

    new_value = my_enabled;
    error = sysctl_handle_int(oidp, &new_value, 0, req);
    if (error != 0 || req->newptr == NULL)
        return (error);

    // Only allow 0 or 1
    if (new_value != 0 && new_value != 1)
        return (EINVAL);

    my_enabled = new_value;
    return (0);
}
```

#### Hint 9: Thread Safety with Mutexes
In the kernel, multiple threads can access your module's data simultaneously. You need to protect shared data with mutexes:

```c
#include <sys/mutex.h>

// Declare a mutex
static struct mtx my_counter_mtx;

// Initialize the mutex in MOD_LOAD
static int
mycounter_modevent(module_t mod __unused, int type, void *data __unused)
{
    int error = 0;

    switch (type) {
    case MOD_LOAD:
        mtx_init(&my_counter_mtx, "mycounter lock", NULL, MTX_DEF);
        printf("mycounter: Module loaded\n");
        break;
    case MOD_UNLOAD:
        mtx_destroy(&my_counter_mtx);
        printf("mycounter: Module unloaded\n");
        break;
    default:
        error = EOPNOTSUPP;
        break;
    }
    return (error);
}
```

#### Hint 10: Protecting Counter Access
Always lock the mutex before accessing shared data and unlock after:

```c
static int my_counter = 0;

static int
sysctl_handle_counter(SYSCTL_HANDLER_ARGS)
{
    int error, new_value;

    // Lock the mutex before reading
    mtx_lock(&my_counter_mtx);
    new_value = my_counter;
    mtx_unlock(&my_counter_mtx);

    error = sysctl_handle_int(oidp, &new_value, 0, req);
    if (error != 0 || req->newptr == NULL)
        return (error);

    // Lock the mutex before writing
    mtx_lock(&my_counter_mtx);
    my_counter = new_value;
    mtx_unlock(&my_counter_mtx);

    return (0);
}
```

#### Hint 11: Understanding Context Switches
When your sysctl handler is called, it can be interrupted by context switches:
- **Context Switch**: The operating system switches from one thread to another
- **Race Condition**: Two threads access shared data simultaneously, causing incorrect results
- **Critical Section**: Code that accesses shared data and must be protected

Without mutex protection:
```c
// UNSAFE: Race condition possible
Thread 1: reads counter (value = 5)
Thread 2: reads counter (value = 5)  // Context switch
Thread 1: writes counter + 1 (value = 6)
Thread 2: writes counter + 1 (value = 6)  // Lost increment!
```

With mutex protection:
```c
// SAFE: Only one thread can access at a time
Thread 1: locks mutex, reads counter (value = 5)
Thread 2: tries to lock mutex, blocks until Thread 1 releases
Thread 1: writes counter + 1 (value = 6), unlocks mutex
Thread 2: acquires lock, reads counter (value = 6)
Thread 2: writes counter + 1 (value = 7), unlocks mutex
```

#### Hint 12: Increment with Mutex Protection
For the increment operation, you need to lock, modify, and unlock atomically:

```c
static int
sysctl_handle_increment(SYSCTL_HANDLER_ARGS)
{
    int error, dummy;

    error = sysctl_handle_int(oidp, &dummy, 0, req);
    if (error != 0 || req->newptr == NULL)
        return (error);

    // Lock, increment, unlock - all as one atomic operation
    mtx_lock(&my_counter_mtx);
    my_counter++;
    mtx_unlock(&my_counter_mtx);

    return (0);
}
```

### Testing Your Module

Use these commands to test your implementation:

```bash
# Build and load
cd /mnt/shared/freebsd-src/sys/modules/mycounter
make
kldload ./mycounter.ko

# Test basic functionality
sysctl mycounter
sysctl mycounter.counter
sysctl mycounter.counter=10
sysctl mycounter.counter

# Test increment
sysctl mycounter.increment=1
sysctl mycounter.counter

# Test reset
sysctl mycounter.reset=1
sysctl mycounter.counter

# Test validation
sysctl mycounter.counter=-5  # Should fail
sysctl mycounter.enabled=2  # Should fail

# Test string parameter
sysctl mycounter.description
sysctl mycounter.description="My custom counter"
sysctl mycounter.description

# Check kernel messages
dmesg | tail -20

# Test persistence
kldunload mycounter
kldload ./mycounter.ko
sysctl mycounter.load_count  # Should be incremented

# Test thread safety (advanced)
# Run multiple sysctl commands in parallel to test mutex protection
for i in {1..10}; do sysctl mycounter.increment=1 & done
wait
sysctl mycounter.counter  # Should be 10 if thread-safe

# Cleanup
kldunload mycounter
```

### Testing Thread Safety
To properly test thread safety, you can create a simple test script:

```bash
#!/bin/sh
# Test concurrent access to the counter

# Load the module
kldload ./mycounter.ko

# Reset counter
sysctl mycounter.reset=1

# Perform 100 concurrent increments
for i in $(seq 1 100); do
    sysctl mycounter.increment=1 &
done
wait

# Check final value
FINAL_VALUE=$(sysctl -n mycounter.counter)
echo "Final counter value: $FINAL_VALUE"
echo "Expected: 100"

if [ "$FINAL_VALUE" -eq 100 ]; then
    echo "Thread safety test PASSED"
else
    echo "Thread safety test FAILED (race condition detected)"
fi

# Unload module
kldunload mycounter
```

### Automated Grading

An automated grading tool is provided to test your implementation:

**From WSL Host:**
```bash
cd /home/ktran/freebsd_dev/exercises/tools
./grade-homework.sh
```

**From FreeBSD VM:**
```bash
cd /mnt/shared/freebsd_dev/exercises/tools
sh 02-grading-tool.sh
```

The grading tool will automatically:
- Compile your module
- Load and test all sysctl parameters
- Test thread safety with concurrent access
- Validate input handling
- Test persistence across module reloads
- Calculate your score based on the grading criteria

**Grading Breakdown:**
- Module Compilation: 10 points
- Module Loading: 10 points
- Custom Sysctl Namespace: 5 points
- Counter Parameter: 10 points
- Increment Parameter: 10 points
- Reset Parameter: 5 points
- String Parameter: 5 points
- Boolean Parameter: 5 points
- Counter Validation: 5 points
- Load Count Persistence: 5 points
- Thread Safety - Basic: 10 points
- Thread Safety - Stress: 10 points
- Module Unloading: 5 points
- Code Quality (manual): 5 points

**Total: 100 points**

### Submission

When you're ready to submit your homework:
1. Run the automated grading tool to verify your implementation
2. Ensure you achieve at least 70 points (passing grade)
3. Document any issues or limitations in comments
4. Be prepared to explain your implementation choices
5. Submit your module code and grading results

### Common Pitfalls

- **Forgetting to increment load count**: Make sure you increment it in MOD_LOAD
- **Not validating input**: Always validate user input in custom handlers
- **Wrong sysctl flags**: Use CTLFLAG_RD for read-only, CTLFLAG_WR for write-only
- **String buffer overflow**: Always specify the correct size for string parameters
- **Memory issues**: Be careful with pointers in custom handlers
- **Race conditions**: Without mutex protection, concurrent access can corrupt data
- **Deadlocks**: Always unlock mutexes in all code paths (including error paths)
- **Context switch issues**: Kernel code can be preempted at any time, so always protect shared data
- **Forgetting mutex cleanup**: Always destroy mutexes in MOD_UNLOAD to avoid resource leaks

### Why Thread Safety Matters in Kernel Development

In kernel development, thread safety is critical because:

1. **Preemptive Multitasking**: The kernel can switch between threads at any time
2. **Multiple CPUs**: On multi-core systems, your code can run simultaneously on different CPUs
3. **Interrupt Context**: Your code can be interrupted by hardware interrupts
4. **Shared Resources**: Many kernel components share the same data structures

**Context Switch Scenario:**
```
Time  Thread 1              Thread 2
----  --------------------  --------------------
T1    Read counter (5)
T2                         Read counter (5)  ← Context switch
T3    Write counter (6)
T4                         Write counter (6)  ← Lost increment!
```

**With Mutex Protection:**
```
Time  Thread 1              Thread 2
----  --------------------  --------------------
T1    Lock mutex
T2                         Try lock (blocked)
T3    Read counter (5)
T4    Write counter (6)
T5    Unlock mutex
T6                         Acquire lock
T7                         Read counter (6)
T8                         Write counter (7)
T9                         Unlock mutex
```

This is why proper mutex usage is essential for correct kernel programming.

### Resources

- FreeBSD Kernel Developer's Manual: https://www.freebsd.org/doc/en_US.ISO8859-1/books/developers-handbook/
- Sysctl(9) manual page: `man 9 sysctl`
- Module(9) manual page: `man 9 module`
- Mutex(9) manual page: `man 9 mutex` (for thread safety)
- Locking(9) manual page: `man 9 locking` (for kernel locking overview)
- Look at existing modules in `/sys/modules/` for examples
- FreeBSD source code: `/sys/kern/` for kernel examples, `/sys/modules/` for module examples