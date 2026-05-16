#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

log_section "Integration Test - Full Pipeline"

# Test 1 - Reset and run full pipeline
echo "-- Test 1: Full pipeline runs from scratch --"
bash "$PROJECT_ROOT/main_pipeline.sh" --reset > /dev/null 2>&1
if bash "$PROJECT_ROOT/main_pipeline.sh" > /dev/null 2>&1; then
    pass "Full pipeline completed successfully"
else
    fail "Full pipeline failed"
fi

# Test 2 - All checkpoints exist after run
echo "-- Test 2: All checkpoints exist after full run --"
all_done=true
for stage in 1 2 3 4; do
    if [ ! -f "$CHECKPOINT_DIR/stage${stage}.done" ]; then
        all_done=false
        break
    fi
done
if [ "$all_done" = true ]; then
    pass "All 4 stage checkpoints exist"
else
    fail "Some checkpoints missing after full run"
fi

# Test 3 - All output files exist
echo "-- Test 3: All output files created --"
all_exist=true
for f in "$RAW_COLLECTED" "$FAILED_LOGINS" "$SUSPICIOUS_IPS" \
          "$SERVER_ERRORS" "$IP_SUMMARY" "$ANOMALY_COUNTS" \
          "$USAGE_STATS" "$ALERTS_LOG" "$FINAL_SUMMARY"; do
    if [ ! -f "$f" ]; then
        all_exist=false
        fail "Missing: $(basename "$f")"
    fi
done
if [ "$all_exist" = true ]; then
    pass "All output files exist"
fi

# Test 4 - Pipeline state shows COMPLETED
echo "-- Test 4: Pipeline state is COMPLETED --"
if grep -q "STATUS=COMPLETED" "$PIPELINE_STATE" 2>/dev/null; then
    pass "Pipeline state correctly shows COMPLETED"
else
    fail "Pipeline state does not show COMPLETED"
fi

# Test 5 - Lock file removed after clean run
echo "-- Test 5: Lock file removed after run --"
if [ ! -f "$LOCK_FILE" ]; then
    pass "Lock file correctly removed after pipeline"
else
    fail "Lock file still exists after pipeline finished"
fi

# Test 6 - Backup was created
echo "-- Test 6: Backup created --"
local backup_count
backup_count=$(find "$BACKUP_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | wc -l)
if [ "$backup_count" -gt 0 ]; then
    pass "Backup directory created ($backup_count backups found)"
else
    fail "No backup created after pipeline run"
fi

# Test 7 - Critical alerts detected
echo "-- Test 7: Critical alerts generated --"
if [ -s "$CRITICAL_ALERTS" ]; then
    local count
    count=$(wc -l < "$CRITICAL_ALERTS")
    pass "Pipeline generated $count critical alerts"
else
    fail "No critical alerts generated"
fi

# Test 8 - Pipeline log has entries
echo "-- Test 8: Pipeline log has entries --"
if [ -s "$PIPELINE_LOG" ]; then
    local lines
    lines=$(wc -l < "$PIPELINE_LOG")
    pass "Pipeline log has $lines entries"
else
    fail "Pipeline log is empty"
fi

# Summary
echo ""
echo "================================"
echo "  Integration Test Results"
echo "================================"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo "================================"
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "  ${GREEN}ALL INTEGRATION TESTS PASSED${NC}"
else
    echo -e "  ${RED}SOME INTEGRATION TESTS FAILED${NC}"
fi