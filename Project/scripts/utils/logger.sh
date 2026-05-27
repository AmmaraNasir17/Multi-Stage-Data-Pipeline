#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

_write_log() {
    local level="$1"
    local message="$2"
    local logfile="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$logfile" 2>/dev/null
    echo "[$timestamp] [$level] $message" >> "$PIPELINE_LOG" 2>/dev/null
}

log_info()    { printf "  ${GREEN}+${NC} %-50s\n" "$1";           _write_log "INFO"    "$1" "$EXECUTION_LOG"; }
log_warn()    { printf "  ${YELLOW}!${NC} %-50s\n" "$1";           _write_log "WARN"    "$1" "$PIPELINE_LOG";  }
log_error()   { printf "  ${RED}X${NC} ${RED}%-50s${NC}\n" "$1";  _write_log "ERROR"   "$1" "$ERROR_LOG";     }
log_success() { printf "  ${GREEN}${BOLD}>>>${NC} %-47s\n" "$1";  _write_log "SUCCESS" "$1" "$EXECUTION_LOG"; }

log_debug() {
    if [ "$VERBOSE" = true ]; then
        printf "  ${DIM}~ %-50s${NC}\n" "$1"
    fi
    _write_log "DEBUG" "$1" "$DEBUG_LOG"
}

log_section() {
    local title="$1"
    local width=51
    local pad=$(( (width - ${#title}) / 2 ))
    echo ""
    echo -e "${CYAN}${BOLD}  $(printf '=%.0s' $(seq 1 $width))${NC}"
    printf  "${CYAN}${BOLD}  =%*s%s%*s=\n${NC}" $pad "" "$title" $((width - pad - ${#title} - 2)) ""
    echo -e "${CYAN}${BOLD}  $(printf '=%.0s' $(seq 1 $width))${NC}"
    echo ""
    _write_log "SECTION" "$1" "$EXECUTION_LOG"
}

log_stage() {
    local num="$1"
    local title="$2"
    local label="STAGE $num : $title"
    local width=51
    local pad=$(( (width - ${#label}) / 2 ))
    echo ""
    echo -e "${BLUE}${BOLD}  $(printf '=%.0s' $(seq 1 $width))${NC}"
    printf  "${BLUE}${BOLD}  =%*s%s%*s=\n${NC}" $pad "" "$label" $((width - pad - ${#label} - 2)) ""
    echo -e "${BLUE}${BOLD}  $(printf '=%.0s' $(seq 1 $width))${NC}"
    echo ""
    _write_log "STAGE$1" "$2" "$EXECUTION_LOG"
}
log_divider() {
    echo -e "  ${DIM}------------------------------------------------${NC}"
}

init_logger() {
    mkdir -p "$LOGS_DIR"
    touch "$PIPELINE_LOG" "$ERROR_LOG" "$EXECUTION_LOG" "$DEBUG_LOG"
    _write_log "INFO" "Logger initialized v$PIPELINE_VERSION" "$EXECUTION_LOG"
    _write_log "INFO" "Run started: $(date '+%Y-%m-%d %H:%M:%S')" "$EXECUTION_LOG"
}