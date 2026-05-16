#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

log_section "Recovery Test - Failure Handling"

echo "-- Test 1: Lock file prevents duplicate pipeline runs --"
echo "fake_pid" > "$LOCK_FILE"
output=$(bash "$PROJECT_ROOT/main_pipeline.sh" 2>&1)
if echo "$output" | grep -q "already running\|lock"; then
    pass "Lock file correctly prevents duplicate run"
else
    fail "Lock file did not prevent duplicate run"
fi
rm -f "$LOCK_FILE"

echo "-- Test 2: Pipeline handles missing input files --"
bash "$PROJECT_ROOT/main_pipeline.sh" --reset > /dev/null 2>&1
mv "$AUTH_LOG" "${AUTH_LOG}.bak" 2>/dev/null
mv "$APACHE_LOG" "${APACHE_LOG}.bak" 2>/dev/null
mv "$SYS_LOG" "${SYS_LOG}.bak" 2>/dev/null
output=$(bash "$STAGES_DIR/stage1_collect.sh" 2>&1)
mv "${AUTH_LOG}.bak" "$AUTH_LOG" 2>/dev/null
mv "${APACHE_LOG}.bak" "$APACHE_LOG" 2>/dev/null
mv "${SYS_LOG}.bak" "$SYS_LOG" 2>/dev/null
if echo "$output" | grep -q "empty\|missing\|generated\|No log\|generate"; then
    pass "Pipeline handles missing input files gracefully"
elif [ -f "$RAW_COLLECTED" ]; then
    pass "Pipeline auto-generated logs and continued gracefully"
else
    fail "Pipeline did not handle missing input gracefully"
fi

echo "-- Test 3: Stage 2 requires Stage 1 checkpoint --"
rm -f "$CHECKPOINT_STAGE1" "$CHECKPOINT_STAGE2" "$CHECKPOINT_STAGE3" "$CHECKPOINT_STAGE4" "$RAW_COLLECTED" 2>/dev/null
output=$(bash "$STAGES_DIR/stage2_filter.sh" 2>&1)
if echo "$output" | grep -q "Stage 1 has not completed\|not completed\|not yet"; then
    pass "Stage 2 correctly refuses without Stage 1"
else
    fail "Stage 2 ran without Stage 1 checkpoint"
fi

echo "-- Test 4: Stage 3 requires Stage 2 checkpoint --"
rm -f "$CHECKPOINT_STAGE1" "$CHECKPOINT_STAGE2" "$CHECKPOINT_STAGE3" "$CHECKPOINT_STAGE4" 2>/dev/null
bash "$STAGES_DIR/stage1_collect.sh" > /dev/null 2>&1
rm -f "$CHECKPOINT_STAGE2" "$FAILED_LOGINS" "$SUSPICIOUS_IPS" 2>/dev/null
output=$(bash "$STAGES_DIR/stage3_aggregate.sh" 2>&1)
if echo "$output" | grep -q "Stage 2 has not completed\|not completed\|not yet"; then
    pass "Stage 3 correctly refuses without Stage 2"
else
    fail "Stage 3 ran without Stage 2 checkpoint"
fi

echo "-- Test 5: Cleanup removes temp files --"
mkdir -p "$TEMP_DIR/stage1_temp"
echo "test" > "$TEMP_DIR/stage1_temp/testfile.txt"
bash "$RECOVERY_DIR/cleanup.sh" --temp > /dev/null 2>&1
if [ ! -f "$TEMP_DIR/stage1_temp/testfile.txt" ]; then
    pass "Cleanup correctly removed temp files"
else
    fail "Cleanup did not remove temp files"
fi

log_info "Restoring pipeline to working state..."
bash "$PROJECT_ROOT/main_pipeline.sh" > /dev/null 2>&1

echo ""
echo "================================"
echo "  Failure Handling Test Results"
echo "================================"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo "================================"
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "  ${GREEN}ALL FAILURE TESTS PASSED${NC}"
else
    echo -e "  ${RED}SOME FAILURE TESTS FAILED${NC}"
fi