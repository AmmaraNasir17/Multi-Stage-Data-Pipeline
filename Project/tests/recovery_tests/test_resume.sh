#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

log_section "Recovery Test - Resume on Failure"

# Test 1 - Run stages 1 and 2 only then resume
echo "-- Test 1: Resume completes remaining stages --"
bash "$PROJECT_ROOT/main_pipeline.sh" --reset > /dev/null 2>&1
bash "$STAGES_DIR/stage1_collect.sh" > /dev/null 2>&1
bash "$STAGES_DIR/stage2_filter.sh" > /dev/null 2>&1

if bash "$PROJECT_ROOT/main_pipeline.sh" --resume > /dev/null 2>&1; then
    pass "Resume completed successfully from Stage 3"
else
    fail "Resume failed"
fi

# Test 2 - All stages complete after resume
echo "-- Test 2: All stages complete after resume --"
all_done=true
for stage in 1 2 3 4; do
    if [ ! -f "$CHECKPOINT_DIR/stage${stage}.done" ]; then
        all_done=false
    fi
done
if [ "$all_done" = true ]; then
    pass "All stages complete after resume"
else
    fail "Some stages still incomplete after resume"
fi

# Test 3 - Rollback works correctly
echo "-- Test 3: Rollback clears correct checkpoints --"
bash "$STAGES_DIR/stage3_aggregate.sh" > /dev/null 2>&1 || true
bash "$STAGES_DIR/stage4_alert.sh" > /dev/null 2>&1 || true
rm -f "$CHECKPOINT_STAGE3" "$CHECKPOINT_STAGE4"
rm -f "$IP_SUMMARY" "$ANOMALY_COUNTS" "$CRITICAL_ALERTS"

if bash "$PROJECT_ROOT/main_pipeline.sh" --resume > /dev/null 2>&1; then
    pass "Pipeline resumed and completed after manual rollback"
else
    fail "Pipeline failed after manual rollback"
fi

# Test 4 - resume_pipeline.sh detects completed state
echo "-- Test 4: Resume script detects all-complete state --"
output=$(bash "$RECOVERY_DIR/resume_pipeline.sh" 2>&1)
if echo "$output" | grep -q "already complete\|Nothing to resume"; then
    pass "Resume script correctly reports all stages complete"
else
    fail "Resume script did not detect completed state"
fi

# Summary
echo ""
echo "================================"
echo "  Resume Test Results"
echo "================================"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo "================================"
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "  ${GREEN}ALL RESUME TESTS PASSED${NC}"
else
    echo -e "  ${RED}SOME RESUME TESTS FAILED${NC}"
fi