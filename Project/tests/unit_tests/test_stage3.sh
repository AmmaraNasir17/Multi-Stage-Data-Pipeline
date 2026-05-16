#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

log_section "Unit Tests - Stage 3: Data Aggregation"

# Make sure stages 1 and 2 are done
if [ ! -f "$CHECKPOINT_STAGE1" ]; then
    bash "$STAGES_DIR/stage1_collect.sh" > /dev/null 2>&1
fi
if [ ! -f "$CHECKPOINT_STAGE2" ]; then
    bash "$STAGES_DIR/stage2_filter.sh" > /dev/null 2>&1
fi

# Reset stage 3
rm -f "$CHECKPOINT_STAGE3" "$IP_SUMMARY" "$ANOMALY_COUNTS" "$USAGE_STATS" 2>/dev/null

# Test 1 - Stage 2 outputs exist
echo "-- Test 1: Stage 2 outputs exist --"
if [ -f "$FAILED_LOGINS" ] && [ -f "$SUSPICIOUS_IPS" ]; then
    pass "Stage 2 output files exist"
else
    fail "Stage 2 output files missing"
fi

# Test 2 - Stage 3 runs without error
echo "-- Test 2: Stage 3 runs successfully --"
if bash "$STAGES_DIR/stage3_aggregate.sh" > /dev/null 2>&1; then
    pass "Stage 3 executed without errors"
else
    fail "Stage 3 execution failed"
fi

# Test 3 - IP summary created
echo "-- Test 3: ip_summary.txt created --"
if [ -f "$IP_SUMMARY" ]; then
    pass "ip_summary.txt exists"
else
    fail "ip_summary.txt not created"
fi

# Test 4 - IP summary has content
echo "-- Test 4: IP summary has IP entries --"
if grep -qE "([0-9]{1,3}\.){3}[0-9]{1,3}" "$IP_SUMMARY" 2>/dev/null; then
    local count
    count=$(grep -cE "([0-9]{1,3}\.){3}[0-9]{1,3}" "$IP_SUMMARY")
    pass "IP summary contains $count IP entries"
else
    fail "IP summary has no IP addresses"
fi

# Test 5 - Anomaly counts created
echo "-- Test 5: anomaly_counts.txt created --"
if [ -f "$ANOMALY_COUNTS" ]; then
    pass "anomaly_counts.txt exists"
else
    fail "anomaly_counts.txt not created"
fi

# Test 6 - Anomaly counts has data
echo "-- Test 6: Anomaly counts has numbers --"
if grep -qE "[0-9]+" "$ANOMALY_COUNTS" 2>/dev/null; then
    pass "Anomaly counts contains numeric data"
else
    fail "Anomaly counts has no numeric data"
fi

# Test 7 - Usage stats created
echo "-- Test 7: usage_statistics.txt created --"
if [ -f "$USAGE_STATS" ]; then
    pass "usage_statistics.txt exists"
else
    fail "usage_statistics.txt not created"
fi

# Test 8 - Risk levels assigned
echo "-- Test 8: Risk levels assigned in IP summary --"
if grep -qE "CRITICAL|HIGH|MEDIUM|LOW" "$IP_SUMMARY" 2>/dev/null; then
    pass "Risk levels found in IP summary"
else
    fail "No risk levels in IP summary"
fi

# Test 9 - Checkpoint saved
echo "-- Test 9: Checkpoint saved --"
if [ -f "$CHECKPOINT_STAGE3" ]; then
    pass "Stage 3 checkpoint exists"
else
    fail "Stage 3 checkpoint missing"
fi

# Summary
echo ""
echo "================================"
echo "  Stage 3 Test Results"
echo "================================"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo "================================"
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "  ${GREEN}ALL TESTS PASSED${NC}"
else
    echo -e "  ${RED}SOME TESTS FAILED${NC}"
fi