#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

log_section "Unit Tests - Stage 1: Log Collection"

# Reset stage 1 first
rm -f "$CHECKPOINT_STAGE1" "$RAW_COLLECTED" 2>/dev/null

# Test 1 - Log files exist
echo "-- Test 1: Input log files exist --"
if [ -f "$AUTH_LOG" ] && [ -f "$APACHE_LOG" ] && [ -f "$SYS_LOG" ]; then
    pass "All input log files exist"
else
    fail "One or more input log files missing"
    echo "  Run: bash scripts/utils/generate_logs.sh"
fi

# Test 2 - Log files are not empty
echo "-- Test 2: Input log files are not empty --"
if [ -s "$AUTH_LOG" ] && [ -s "$APACHE_LOG" ] && [ -s "$SYS_LOG" ]; then
    pass "All input log files have content"
else
    fail "One or more log files are empty"
fi

# Test 3 - Stage 1 runs without error
echo "-- Test 3: Stage 1 runs successfully --"
if bash "$STAGES_DIR/stage1_collect.sh" > /dev/null 2>&1; then
    pass "Stage 1 executed without errors"
else
    fail "Stage 1 execution failed"
fi

# Test 4 - Output file created
echo "-- Test 4: raw_collected.log was created --"
if [ -f "$RAW_COLLECTED" ]; then
    pass "raw_collected.log exists"
else
    fail "raw_collected.log was not created"
fi

# Test 5 - Output file not empty
echo "-- Test 5: raw_collected.log has content --"
if [ -s "$RAW_COLLECTED" ]; then
    local lines
    lines=$(wc -l < "$RAW_COLLECTED")
    pass "raw_collected.log has $lines lines"
else
    fail "raw_collected.log is empty"
fi

# Test 6 - Checkpoint was saved
echo "-- Test 6: Checkpoint was saved --"
if [ -f "$CHECKPOINT_STAGE1" ]; then
    pass "Stage 1 checkpoint exists"
else
    fail "Stage 1 checkpoint missing"
fi

# Test 7 - Resume skips stage if already done
echo "-- Test 7: Stage 1 skips if checkpoint exists --"
output=$(bash "$STAGES_DIR/stage1_collect.sh" 2>&1)
if echo "$output" | grep -q "already completed\|Skipping"; then
    pass "Stage 1 correctly skipped when checkpoint exists"
else
    fail "Stage 1 did not skip when checkpoint exists"
fi

# Summary
echo ""
echo "================================"
echo "  Stage 1 Test Results"
echo "================================"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo "================================"
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "  ${GREEN}ALL TESTS PASSED${NC}"
else
    echo -e "  ${RED}SOME TESTS FAILED${NC}"
fi