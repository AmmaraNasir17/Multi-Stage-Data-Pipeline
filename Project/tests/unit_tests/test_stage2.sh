#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

log_section "Unit Tests - Stage 2: Anomaly Filtering"

# Make sure stage 1 is done first
if [ ! -f "$CHECKPOINT_STAGE1" ]; then
    log_warn "Stage 1 not done - running it first..."
    bash "$STAGES_DIR/stage1_collect.sh" > /dev/null 2>&1
fi

# Reset stage 2
rm -f "$CHECKPOINT_STAGE2" "$FAILED_LOGINS" "$SUSPICIOUS_IPS" "$SERVER_ERRORS" 2>/dev/null

# Test 1 - Stage 1 output exists as input
echo "-- Test 1: Stage 1 output exists --"
if [ -s "$RAW_COLLECTED" ]; then
    pass "raw_collected.log exists and has content"
else
    fail "raw_collected.log missing or empty"
fi

# Test 2 - Stage 2 runs without error
echo "-- Test 2: Stage 2 runs successfully --"
if bash "$STAGES_DIR/stage2_filter.sh" > /dev/null 2>&1; then
    pass "Stage 2 executed without errors"
else
    fail "Stage 2 execution failed"
fi

# Test 3 - Failed logins file created
echo "-- Test 3: failed_logins.txt created --"
if [ -f "$FAILED_LOGINS" ]; then
    pass "failed_logins.txt exists"
else
    fail "failed_logins.txt not created"
fi

# Test 4 - Failed logins actually contain failed login entries
echo "-- Test 4: Failed logins file has correct content --"
if grep -qi "failed\|invalid" "$FAILED_LOGINS" 2>/dev/null; then
    local count
    count=$(wc -l < "$FAILED_LOGINS")
    pass "failed_logins.txt has $count suspicious entries"
else
    fail "failed_logins.txt does not contain expected content"
fi

# Test 5 - Suspicious IPs file created
echo "-- Test 5: suspicious_ips.txt created --"
if [ -f "$SUSPICIOUS_IPS" ]; then
    pass "suspicious_ips.txt exists"
else
    fail "suspicious_ips.txt not created"
fi

# Test 6 - Server errors file created
echo "-- Test 6: server_errors.txt created --"
if [ -f "$SERVER_ERRORS" ]; then
    pass "server_errors.txt exists"
else
    fail "server_errors.txt not created"
fi

# Test 7 - AWK temp analysis files created
echo "-- Test 7: AWK analysis files created --"
if [ -f "$TEMP_DIR/stage2_temp/auth_analysis.txt" ]; then
    pass "AWK auth analysis file exists"
else
    fail "AWK auth analysis file missing"
fi

# Test 8 - Known bad IPs are in suspicious list
echo "-- Test 8: Known bad IPs detected --"
if grep -q "192.168.1.100\|10.0.0.55" "$FAILED_LOGINS" 2>/dev/null; then
    pass "Known suspicious IPs found in failed logins"
else
    fail "Known suspicious IPs NOT found — filtering may be broken"
fi

# Test 9 - Checkpoint saved
echo "-- Test 9: Checkpoint saved --"
if [ -f "$CHECKPOINT_STAGE2" ]; then
    pass "Stage 2 checkpoint exists"
else
    fail "Stage 2 checkpoint missing"
fi

# Summary
echo ""
echo "================================"
echo "  Stage 2 Test Results"
echo "================================"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo "================================"
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "  ${GREEN}ALL TESTS PASSED${NC}"
else
    echo -e "  ${RED}SOME TESTS FAILED${NC}"
fi