#!/bin/sh

# Automated Grading Tool for Exercise 2 Homework
# This script tests the mycounter kernel module implementation

set -e

MODULE_NAME="mycounter"
MODULE_PATH="/mnt/shared/freebsd-src/sys/modules/${MODULE_NAME}"
GRADING_DIR="/mnt/shared/freebsd_dev/exercises/tools"
TOTAL_POINTS=100
SCORE=0
PASSED_TESTS=0
FAILED_TESTS=0
TEST_RESULTS=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo "${GREEN}✓ $1${NC}"
}

print_failure() {
    echo "${RED}✗ $1${NC}"
}

print_info() {
    echo "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo "${YELLOW}⚠ $1${NC}"
}

# Function to add test result
add_test_result() {
    local test_name="$1"
    local points="$2"
    local passed="$3"
    local message="$4"
    
    if [ "$passed" = "true" ]; then
        TEST_RESULTS="${TEST_RESULTS}${GREEN}✓${NC} ${test_name} (+${points} points)\n"
        SCORE=$((SCORE + points))
        PASSED_TESTS=$((PASSED_TESTS + 1))
        print_success "${test_name}: ${message}"
    else
        TEST_RESULTS="${TEST_RESULTS}${RED}✗${NC} ${test_name} (0 points) - ${message}\n"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        print_failure "${test_name}: ${message}"
    fi
}

# Function to check if module is loaded
is_module_loaded() {
    kldstat | grep -q "${MODULE_NAME}"
}

# Function to get sysctl value
get_sysctl() {
    sysctl -n "$1" 2>/dev/null || echo ""
}

# Function to set sysctl value
set_sysctl() {
    sysctl "$1=$2" >/dev/null 2>&1
}

# Function to cleanup
cleanup() {
    print_info "Cleaning up..."
    if is_module_loaded; then
        kldunload "${MODULE_NAME}" 2>/dev/null || true
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

echo "=========================================="
echo "  Homework Grading Tool - Exercise 2"
echo "  Module: ${MODULE_NAME}"
echo "=========================================="
echo ""

# Check if module directory exists
if [ ! -d "${MODULE_PATH}" ]; then
    print_failure "Module directory not found: ${MODULE_PATH}"
    echo "Please create your module in: ${MODULE_PATH}"
    exit 1
fi

print_info "Module directory found: ${MODULE_PATH}"
echo ""

# Test 1: Module Compilation (10 points)
print_info "Test 1: Module Compilation"
cd "${MODULE_PATH}"
if make clean >/dev/null 2>&1; then
    if make >/dev/null 2>&1; then
        if [ -f "${MODULE_NAME}.ko" ]; then
            add_test_result "Module Compilation" 10 true "Module compiled successfully"
        else
            add_test_result "Module Compilation" 10 false "Module .ko file not found"
        fi
    else
        add_test_result "Module Compilation" 10 false "Compilation failed"
    fi
else
    add_test_result "Module Compilation" 10 false "Make clean failed"
fi
echo ""

# Test 2: Module Loading (10 points)
print_info "Test 2: Module Loading"
if [ -f "${MODULE_NAME}.ko" ]; then
    if kldload "./${MODULE_NAME}.ko" >/dev/null 2>&1; then
        if is_module_loaded; then
            add_test_result "Module Loading" 10 true "Module loaded successfully"
        else
            add_test_result "Module Loading" 10 false "Module load command succeeded but module not in kldstat"
        fi
    else
        add_test_result "Module Loading" 10 false "Module load failed"
    fi
else
    add_test_result "Module Loading" 10 false "Module .ko file not found (skipping load test)"
fi
echo ""

# If module failed to load, we can't continue with most tests
if ! is_module_loaded; then
    print_warning "Module not loaded, skipping remaining tests"
    echo ""
    echo "=========================================="
    echo "  Final Score: ${SCORE}/${TOTAL_POINTS}"
    echo "  Passed: ${PASSED_TESTS}, Failed: ${FAILED_TESTS}"
    echo "=========================================="
    echo ""
    echo "Test Results:"
    echo -e "${TEST_RESULTS}"
    exit 1
fi

# Test 3: Custom Sysctl Namespace (5 points)
print_info "Test 3: Custom Sysctl Namespace"
if sysctl mycounter >/dev/null 2>&1; then
    add_test_result "Custom Sysctl Namespace" 5 true "Custom namespace 'mycounter' exists"
else
    add_test_result "Custom Sysctl Namespace" 5 false "Custom namespace 'mycounter' not found"
fi
echo ""

# Test 4: Counter Parameter (10 points)
print_info "Test 4: Counter Parameter"
if sysctl mycounter.counter >/dev/null 2>&1; then
    # Test reading
    initial_value=$(get_sysctl mycounter.counter)
    if [ -n "$initial_value" ]; then
        # Test writing
        set_sysctl mycounter.counter 42
        new_value=$(get_sysctl mycounter.counter)
        if [ "$new_value" = "42" ]; then
            # Reset to initial value
            set_sysctl mycounter.counter "$initial_value"
            add_test_result "Counter Parameter" 10 true "Counter parameter works (read/write)"
        else
            add_test_result "Counter Parameter" 10 false "Counter write failed"
        fi
    else
        add_test_result "Counter Parameter" 10 false "Counter read failed"
    fi
else
    add_test_result "Counter Parameter" 10 false "Counter parameter not found"
fi
echo ""

# Test 5: Increment Parameter (10 points)
print_info "Test 5: Increment Parameter"
if sysctl mycounter.increment >/dev/null 2>&1; then
    # Set counter to known value
    set_sysctl mycounter.counter 0
    initial_value=$(get_sysctl mycounter.counter)
    
    # Try to increment
    set_sysctl mycounter.increment 1
    new_value=$(get_sysctl mycounter.counter)
    
    if [ "$new_value" -gt "$initial_value" ]; then
        add_test_result "Increment Parameter" 10 true "Increment parameter works"
    else
        add_test_result "Increment Parameter" 10 false "Increment did not increase counter"
    fi
else
    add_test_result "Increment Parameter" 10 false "Increment parameter not found"
fi
echo ""

# Test 6: Reset Parameter (5 points)
print_info "Test 6: Reset Parameter"
if sysctl mycounter.reset >/dev/null 2>&1; then
    # Set counter to non-zero value
    set_sysctl mycounter.counter 100
    
    # Try to reset
    set_sysctl mycounter.reset 1
    new_value=$(get_sysctl mycounter.counter)
    
    if [ "$new_value" = "0" ]; then
        add_test_result "Reset Parameter" 5 true "Reset parameter works"
    else
        add_test_result "Reset Parameter" 5 false "Reset did not set counter to 0 (value: ${new_value})"
    fi
else
    add_test_result "Reset Parameter" 5 false "Reset parameter not found"
fi
echo ""

# Test 7: String Parameter (5 points)
print_info "Test 7: String Parameter"
if sysctl mycounter.description >/dev/null 2>&1; then
    # Test reading
    initial_desc=$(get_sysctl mycounter.description)
    if [ -n "$initial_desc" ]; then
        # Test writing
        set_sysctl mycounter.description "Test Description"
        new_desc=$(get_sysctl mycounter.description)
        if [ "$new_desc" = "Test Description" ]; then
            add_test_result "String Parameter" 5 true "String parameter works (read/write)"
        else
            add_test_result "String Parameter" 5 false "String write failed"
        fi
    else
        add_test_result "String Parameter" 5 false "String read failed"
    fi
else
    add_test_result "String Parameter" 5 false "String parameter not found"
fi
echo ""

# Test 8: Boolean Parameter (5 points)
print_info "Test 8: Boolean Parameter"
if sysctl mycounter.enabled >/dev/null 2>&1; then
    # Test setting to 1
    set_sysctl mycounter.enabled 1
    value=$(get_sysctl mycounter.enabled)
    if [ "$value" = "1" ]; then
        # Test setting to 0
        set_sysctl mycounter.enabled 0
        value=$(get_sysctl mycounter.enabled)
        if [ "$value" = "0" ]; then
            add_test_result "Boolean Parameter" 5 true "Boolean parameter works"
        else
            add_test_result "Boolean Parameter" 5 false "Boolean parameter didn't accept 0"
        fi
    else
        add_test_result "Boolean Parameter" 5 false "Boolean parameter didn't accept 1"
    fi
else
    add_test_result "Boolean Parameter" 5 false "Boolean parameter not found"
fi
echo ""

# Test 9: Counter Validation (5 points)
print_info "Test 9: Counter Validation (no negative values)"
set_sysctl mycounter.counter 10
# Try to set negative value
if set_sysctl mycounter.counter -5 2>/dev/null; then
    new_value=$(get_sysctl mycounter.counter)
    if [ "$new_value" -lt 0 ]; then
        add_test_result "Counter Validation" 5 false "Counter accepted negative value"
    else
        add_test_result "Counter Validation" 5 true "Counter rejected negative value"
    fi
else
    # Command failed, which is good (validation worked)
    add_test_result "Counter Validation" 5 true "Counter rejected negative value (command failed)"
fi
echo ""

# Test 10: Load Count Persistence (5 points)
print_info "Test 10: Load Count Persistence"
if sysctl mycounter.load_count >/dev/null 2>&1; then
    initial_load_count=$(get_sysctl mycounter.load_count)
    
    # Reload module
    kldunload "${MODULE_NAME}" 2>/dev/null || true
    sleep 1
    kldload "./${MODULE_NAME}.ko" >/dev/null 2>&1
    
    new_load_count=$(get_sysctl mycounter.load_count)
    
    if [ "$new_load_count" -gt "$initial_load_count" ]; then
        add_test_result "Load Count Persistence" 5 true "Load count incremented after reload"
    else
        add_test_result "Load Count Persistence" 5 false "Load count did not increment"
    fi
else
    add_test_result "Load Count Persistence" 5 false "Load count parameter not found"
fi
echo ""

# Test 11: Thread Safety - Basic Test (10 points)
print_info "Test 11: Thread Safety - Concurrent Access"
set_sysctl mycounter.counter 0

# Perform concurrent increments
for i in $(seq 1 10); do
    set_sysctl mycounter.increment 1 &
done
wait

final_value=$(get_sysctl mycounter.counter)
if [ "$final_value" = "10" ]; then
    add_test_result "Thread Safety - Basic" 10 true "Concurrent increments produced correct result (10)"
else
    add_test_result "Thread Safety - Basic" 0 false "Concurrent increments produced incorrect result (${final_value} instead of 10) - possible race condition"
fi
echo ""

# Test 12: Thread Safety - Stress Test (10 points)
print_info "Test 12: Thread Safety - Stress Test"
set_sysctl mycounter.counter 0

# Perform 100 concurrent increments
for i in $(seq 1 100); do
    set_sysctl mycounter.increment 1 &
done
wait

final_value=$(get_sysctl mycounter.counter)
if [ "$final_value" = "100" ]; then
    add_test_result "Thread Safety - Stress" 10 true "Stress test passed (100 concurrent increments)"
else
    add_test_result "Thread Safety - Stress" 0 false "Stress test failed (${final_value} instead of 100) - race condition detected"
fi
echo ""

# Test 13: Module Unloading (5 points)
print_info "Test 13: Module Unloading"
if kldunload "${MODULE_NAME}" >/dev/null 2>&1; then
    if ! is_module_loaded; then
        add_test_result "Module Unloading" 5 true "Module unloaded cleanly"
        
        # Reload for cleanup
        kldload "./${MODULE_NAME}.ko" >/dev/null 2>&1
    else
        add_test_result "Module Unloading" 5 false "Module unload command succeeded but module still loaded"
        
        # Force unload for cleanup
        kldunload "${MODULE_NAME}" 2>/dev/null || true
        kldload "./${MODULE_NAME}.ko" >/dev/null 2>&1
    fi
else
    add_test_result "Module Unloading" 5 false "Module unload failed"
    
    # Force unload for cleanup
    kldunload "${MODULE_NAME}" 2>/dev/null || true
    kldload "./${MODULE_NAME}.ko" >/dev/null 2>&1
fi
echo ""

# Test 14: Code Quality (Manual - 5 points)
print_info "Test 14: Code Quality (Manual Review)"
print_warning "This requires manual review - checking for comments and coding style"
print_info "Please review the code for:"
echo "  - Proper comments explaining functionality"
echo "  - FreeBSD kernel coding style"
echo "  - Proper error handling"
echo ""
read -p "Does the code meet quality standards? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    add_test_result "Code Quality" 5 true "Manual review passed"
else
    add_test_result "Code Quality" 0 false "Manual review failed"
fi
echo ""

# Final Results
echo "=========================================="
echo "  Final Score: ${SCORE}/${TOTAL_POINTS}"
echo "  Passed: ${PASSED_TESTS}, Failed: ${FAILED_TESTS}"
echo "=========================================="
echo ""
echo "Detailed Test Results:"
echo -e "${TEST_RESULTS}"

# Grade calculation
PERCENTAGE=$((SCORE * 100 / TOTAL_POINTS))
echo "Grade: ${PERCENTAGE}%"

if [ $PERCENTAGE -ge 90 ]; then
    echo "Letter Grade: A"
elif [ $PERCENTAGE -ge 80 ]; then
    echo "Letter Grade: B"
elif [ $PERCENTAGE -ge 70 ]; then
    echo "Letter Grade: C"
elif [ $PERCENTAGE -ge 60 ]; then
    echo "Letter Grade: D"
else
    echo "Letter Grade: F"
fi

echo ""
if [ $PERCENTAGE -ge 70 ]; then
    print_success "Homework PASSED"
else
    print_failure "Homework FAILED - needs improvement"
fi