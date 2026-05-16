#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

log_section "Unit Tests - Stage 4: Alert Generation"

# Make sure stages 1 2 3 are done
if [ ! -f "$CHECKPOINT_STAGE1" ]; then bash "$STAGES_DIR/stage1_collect.sh" > /dev/null 2>&1; fi
if [ ! -f "$CHECKPOINT_STAGE2" ]; then bash "$STAGES_DIR/stage2_filter.sh" > /dev/null 2>&1; fi
if [ ! -f "$CHECKPOINT_STAGE3" ]; then bash "$STAGES_DIR/stage3_aggregate.sh" > /dev/null 2>&1; fi

# Reset stage 4
rm -f "$CHECKPOINT_STAGE4" "$ALERTS_LOG" "$CRITICAL_ALERTS" "$WARNING_ALERTS" "$FINAL_SUMMARY" 2>/dev/null

# Test 1 - Stage 3 outputs exist
echo "-- Test 1: Stage 3 outputs exist --"
if [ -f "$IP_SUMMARY" ] && [ -f "$ANOMALY_COUNTS" ]; then
    pass "Stage 3 output files exist"
else
    fail "Stage 3 output files missing"
fi

# Test 2 - Stage 4 runs without error
echo "-- Test 2: Stage 4 runs successfully --"
if bash "$STAGES_DIR/stage4_alert.sh" > /dev/null 2>&1; then
    pass "Stage 4 executed without errors"
else
    fail "Stage 4 execution failed"
fi

# Test 3 - Alerts log created
echo "-- Test 3: alerts.log created --"
if [ -f "$ALERTS_LOG" ]; then
    pass "alerts.log exists"
else
    fail "alerts.log not created"
fi

# Test 4 - Critical alerts detected
echo "-- Test 4: Critical alerts were generated --"
if [ -s "$CRITICAL_ALERTS" ]; then
    local count
    count=$(wc -l < "$CRITICAL_ALERTS")
    pass "Critical alerts file has $count alerts"
else
    fail "No critical alerts generated (expected some from test data)"
fi

# Test 5 - Known brute force IP alerted
echo "-- Test 5: Brute force IP 192.168.1.100 was alerted --"
if grep -q "192.168.1.100" "$CRITICAL_ALERTS" 2>/dev/null; then
    pass "Known brute force IP correctly alerted"
else
    fail "Known brute force IP was NOT alerted"
fi

# Test 6 - High error rate alerted
echo "-- Test 6: High error rate alert generated --"
if grep -qi "error rate\|HIGH ERROR" "$CRITICAL_ALERTS" 2>/dev/null; then
    pass "High error rate correctly alerted"
else
    fail "High error rate was NOT alerted"
fi

# Test 7 - Final report created
echo "-- Test 7: Final summary report created --"
if [ -f "$FINAL_SUMMARY" ]; then
    pass "final_summary.txt exists"
else
    fail "final_summary.txt not created"
fi

# Test 8 - Final report has content
echo "-- Test 8: Final report has content --"
if [ -s "$FINAL_SUMMARY" ]; then
    local lines
    lines=$(wc -l < "$FINAL_SUMMARY")
    pass "Final report has $lines lines"
else
    fail "Final report is empty"
fi

# Test 9 - Checkpoint saved
echo "-- Test 9: Checkpoint saved --"
if [ -f "$CHECKPOINT_STAGE4" ]; then
    pass "Stage 4 checkpoint exists"
else
    fail "Stage 4 checkpoint missing"
fi

# Summary
echo ""
echo "================================"
echo "  Stage 4 Test Results"
echo "================================"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo "================================"
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "  ${GREEN}ALL TESTS PASSED${NC}"
else
    echo -e "  ${RED}SOME TESTS FAILED${NC}"
fi