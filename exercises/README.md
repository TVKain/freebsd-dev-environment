# FreeBSD Kernel Development Exercises

This directory contains exercises, homework assignments, and tools for learning FreeBSD kernel development.

## Directory Structure

```
exercises/
├── guides/              # Exercise guides and tutorials
│   ├── 01-modify-cat.md
│   └── 02-kernel-module-sysctl.md
├── homework/            # Homework assignments
│   └── 02-homework.md
├── tools/               # Grading and utility tools
│   ├── 02-grading-tool.sh
│   └── grade-homework.sh
└── README.md            # This file
```

## Exercise Guides

### Exercise 1: Modify Cat Command
- **File**: `guides/01-modify-cat.md`
- **Objective**: Modify a simple userland command (cat)
- **Difficulty**: Beginner
- **Status**: Completed

### Exercise 2: Kernel Module with Sysctl
- **File**: `guides/02-kernel-module-sysctl.md`
- **Objective**: Create a kernel module with custom sysctl parameters
- **Difficulty**: Intermediate
- **Status**: In Progress

## Homework Assignments

### Exercise 2 Homework
- **File**: `homework/02-homework.md`
- **Objective**: Advanced kernel module with thread safety
- **Grading**: Automated grading tool provided
- **Points**: 100 points total
- **Prerequisites**: Complete Exercise 2 guide first

## Grading Tools

### Automated Grading Tool
- **File**: `tools/02-grading-tool.sh` (runs on FreeBSD VM)
- **Purpose**: Automatically tests and grades kernel module implementations
- **Features**:
  - Compilation testing
  - Module load/unload testing
  - Sysctl parameter validation
  - Thread safety testing
  - Concurrent access stress testing
  - Score calculation

### Grading Utility
- **File**: `tools/grade-homework.sh` (runs on WSL host)
- **Purpose**: Wrapper script to run grading tool remotely
- **Usage**: `./grade-homework.sh`

## Usage

### Running the Grading Tool

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

### Grading Criteria

The automated grading tool tests the following:

1. **Module Compilation** (10 points)
   - Compiles without errors
   - Produces .ko file

2. **Module Loading** (10 points)
   - Loads successfully
   - Appears in kldstat

3. **Custom Sysctl Namespace** (5 points)
   - Creates custom namespace
   - Parameters accessible

4. **Counter Parameter** (10 points)
   - Read/write functionality
   - Correct value handling

5. **Increment Parameter** (10 points)
   - Increments counter correctly
   - Write-only operation

6. **Reset Parameter** (5 points)
   - Resets counter to 0
   - Write-only operation

7. **String Parameter** (5 points)
   - Read/write functionality
   - String handling

8. **Boolean Parameter** (5 points)
   - Accepts 0/1 values
   - Read/write functionality

9. **Counter Validation** (5 points)
   - Rejects negative values
   - Input validation

10. **Load Count Persistence** (5 points)
    - Tracks module loads
    - Persists across reloads

11. **Thread Safety - Basic** (10 points)
    - Handles concurrent access
    - No race conditions (10 concurrent operations)

12. **Thread Safety - Stress** (10 points)
    - Stress testing
    - No race conditions (100 concurrent operations)

13. **Module Unloading** (5 points)
    - Unloads cleanly
    - No resource leaks

14. **Code Quality** (5 points)
    - Manual review
    - Comments and style

**Total: 100 points**

### Passing Grade

- **70+ points**: Passing grade
- **80+ points**: Good (B)
- **90+ points**: Excellent (A)

## Environment Setup

Ensure your FreeBSD VM is running and accessible:
- VM IP: 192.168.0.50
- NFS mount: /mnt/shared
- SSH access: root@192.168.0.50

## Troubleshooting

### Grading Tool Issues

**"Module directory not found"**
- Ensure your module is in: `/mnt/shared/freebsd-src/sys/modules/mycounter`
- Check NFS mount is working: `ls /mnt/shared`

**"Module load failed"**
- Check compilation errors in the module directory
- Verify kernel headers are available
- Check for missing dependencies

**"Thread safety test failed"**
- Ensure mutex is properly initialized
- Check that all counter access is protected
- Verify mutex is locked/unlocked correctly

**"Sysctl parameter not found"**
- Check sysctl namespace is correct
- Verify SYSCTL macros are properly defined
- Ensure module is loaded before testing

## Development Workflow

1. **Read the exercise guide**: `guides/02-kernel-module-sysctl.md`
2. **Read the homework assignment**: `homework/02-homework.md`
3. **Implement the module**: Follow the hints and requirements
4. **Test manually**: Use the testing commands provided in homework
5. **Run automated grading**: `tools/grade-homework.sh`
6. **Fix issues**: Address any failing tests
7. **Submit**: When you achieve passing grade

## Resources

- FreeBSD Kernel Developer's Manual
- Man pages: sysctl(9), module(9), mutex(9), locking(9)
- FreeBSD source code: `/sys/kern/`, `/sys/modules/`
- Exercise guides: `guides/` directory
- Homework assignments: `homework/` directory
- Grading tools: `tools/` directory