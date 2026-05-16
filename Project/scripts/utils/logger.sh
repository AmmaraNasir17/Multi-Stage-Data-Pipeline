#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  logger.sh — Logging Utility
#  Provides colored terminal output + writes to log files
#  Usage: source scripts/utils/logger.sh
# ═══════════════════════════════════════════════════════════

# ────────────────────────────────────────
# COLORS
# These are ANSI escape codes — they tell
# the terminal to print in a specific color
# \033[ = start color code
# 0m    = reset (No Color)
# ────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'  # No Color — always put this at end of colored text

# ────────────────────────────────────────
# CORE LOG FUNCTION
# Writes to terminal AND to log files
# ────────────────────────────────────────
_write_log() {
    local level="$1"      # INFO, WARN, ERROR, DEBUG
    local message="$2"
    local logfile="$3"    # which log file to write to
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[$timestamp] [$level] $message"

    # Write to the specific log file
    echo "$entry" >> "$logfile" 2>/dev/null

    # Also always write to the main pipeline log
    echo "$entry" >> "$PIPELINE_LOG" 2>/dev/null
}

# ────────────────────────────────────────
# PUBLIC LOGGING FUNCTIONS
# These are what other scripts will call
# ────────────────────────────────────────

# Green  — general information
log_info() {
    echo -e "${GREEN}[INFO]${NC}  $1"
    _write_log "INFO" "$1" "$EXECUTION_LOG"
}

# Yellow — something to be aware of
log_warn() {
    echo -e "${YELLOW}[WARN]${NC}  $1"
    _write_log "WARN" "$1" "$PIPELINE_LOG"
}

# Red    — something went wrong
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    _write_log "ERROR" "$1" "$ERROR_LOG"
}

# Cyan   — step-by-step detail (only shown if VERBOSE=true)
log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
    _write_log "DEBUG" "$1" "$DEBUG_LOG"
}

# Blue   — marks the start of a major section
log_section() {
    echo -e "\n${BLUE}═══════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════${NC}\n"
    _write_log "SECTION" "$1" "$EXECUTION_LOG"
}

# Green banner — marks successful completion
log_success() {
    echo -e "${GREEN}✔ SUCCESS:${NC} $1"
    _write_log "SUCCESS" "$1" "$EXECUTION_LOG"
}

# Magenta — marks start/end of pipeline stages
log_stage() {
    echo -e "${MAGENTA}[STAGE $1]${NC} $2"
    _write_log "STAGE$1" "$2" "$EXECUTION_LOG"
}

# ────────────────────────────────────────
# INIT LOGGER
# Creates log files if they don't exist
# Call this once at the start of pipeline
# ────────────────────────────────────────
init_logger() {
    mkdir -p "$LOGS_DIR"
    touch "$PIPELINE_LOG" "$ERROR_LOG" "$EXECUTION_LOG" "$DEBUG_LOG"
    log_info "Logger initialized. Version: $PIPELINE_VERSION"
    log_info "Run started at: $TIMESTAMP"
}
