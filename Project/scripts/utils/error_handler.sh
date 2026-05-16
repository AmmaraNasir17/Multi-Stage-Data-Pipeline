#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  error_handler.sh — Error & Signal Handling
#  Catches crashes and unexpected exits, logs them,
#  and cleans up so the system stays in a good state.
#  Usage: source scripts/utils/error_handler.sh
#         setup_error_handling   ← call this once at start
# ═══════════════════════════════════════════════════════════

# ────────────────────────────────────────
# WHAT IS A TRAP?
# 'trap' tells bash: "when THIS event happens,
# run THIS function instead of just dying."
#
# Events we handle:
#   EXIT   = script finished (success or fail)
#   ERR    = any command returned non-zero exit code
#   INT    = user pressed Ctrl+C
#   TERM   = system sent kill signal
# ────────────────────────────────────────

# Called when any command fails (non-zero exit)
_on_error() {
    local exit_code=$?       # exit code of failed command
    local line_number=$1     # line number where it failed
    log_error "Command failed at line $line_number with exit code $exit_code"
    log_error "Check $ERROR_LOG for details"
    _save_failure_state "$line_number" "$exit_code"
}

# Called when script exits (for any reason)
_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_warn "Pipeline exited with code $exit_code"
        # Remove lock file so pipeline can run again
        rm -f "$LOCK_FILE"
    fi
}

# Called when user presses Ctrl+C
_on_interrupt() {
    echo ""
    log_warn "Pipeline interrupted by user (Ctrl+C)"
    log_warn "Progress saved in checkpoints — run again to resume"
    rm -f "$LOCK_FILE"
    exit 130   # 130 is standard exit code for Ctrl+C
}

# Called when system sends kill signal
_on_terminate() {
    log_warn "Pipeline terminated by system signal"
    rm -f "$LOCK_FILE"
    exit 143   # 143 is standard exit code for SIGTERM
}

# ────────────────────────────────────────
# SAVE FAILURE STATE
# Writes where we failed so resume knows
# ────────────────────────────────────────
_save_failure_state() {
    local line="$1"
    local code="$2"
    {
        echo "FAILED_AT_LINE=$line"
        echo "EXIT_CODE=$code"
        echo "TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')"
    } >> "$PIPELINE_STATE"
}

# ────────────────────────────────────────
# SETUP — Register all traps
# Call this once at the start of pipeline
# ────────────────────────────────────────
setup_error_handling() {
    # ERR trap passes the current line number
    trap '_on_error $LINENO' ERR
    trap '_on_exit'          EXIT
    trap '_on_interrupt'     INT
    trap '_on_terminate'     TERM

    # set -e  = exit immediately if a command fails
    # set -u  = treat unset variables as errors
    # set -o pipefail = if any command in a pipe fails, the whole pipe fails
    set -e
    set -u
    set -o pipefail

    log_info "Error handling initialized"
}

# ────────────────────────────────────────
# SAFE EXECUTE
# Run a command and handle its failure
# gracefully with a custom message
# Usage: safe_exec "description" command args
# ────────────────────────────────────────
safe_exec() {
    local description="$1"
    shift                     # remove first argument, rest is the command
    log_debug "Running: $description"
    if "$@"; then
        log_debug "✔ Done: $description"
        return 0
    else
        local code=$?
        log_error "Failed: $description (exit code: $code)"
        return $code
    fi
}
