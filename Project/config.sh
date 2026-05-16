#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  config.sh — Central Configuration File
#  All pipeline settings, paths, and thresholds live here.
#  Every other script sources this file at the top.
#  Usage: source config.sh   OR   . config.sh
# ═══════════════════════════════════════════════════════════

# ────────────────────────────────────────
# 1. PROJECT ROOT
# ────────────────────────────────────────
# This dynamically finds the project root folder
# no matter where you run the script from.
# dirname $0        = folder of current script
# cd .. && pwd      = go one level up = project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ────────────────────────────────────────
# 2. DIRECTORY PATHS
# ────────────────────────────────────────
INPUT_DIR="$PROJECT_ROOT/input"
RAW_LOG_DIR="$INPUT_DIR/raw_logs"
TEST_DATA_DIR="$INPUT_DIR/test_data"

SCRIPTS_DIR="$PROJECT_ROOT/scripts"
STAGES_DIR="$SCRIPTS_DIR/stages"
UTILS_DIR="$SCRIPTS_DIR/utils"
PARSERS_DIR="$SCRIPTS_DIR/parsers"
ALERTS_DIR="$SCRIPTS_DIR/alerts"
RECOVERY_DIR="$SCRIPTS_DIR/recovery"

OUTPUT_DIR="$PROJECT_ROOT/output"
FILTERED_DIR="$OUTPUT_DIR/filtered"
AGGREGATED_DIR="$OUTPUT_DIR/aggregated"
ALERTS_OUT_DIR="$OUTPUT_DIR/alerts"
REPORTS_DIR="$OUTPUT_DIR/reports"

CHECKPOINT_DIR="$PROJECT_ROOT/checkpoints"
LOGS_DIR="$PROJECT_ROOT/logs"
TEMP_DIR="$PROJECT_ROOT/temp"
BACKUP_DIR="$PROJECT_ROOT/backups"
DOCS_DIR="$PROJECT_ROOT/docs"

# ────────────────────────────────────────
# 3. INPUT LOG FILES
# ────────────────────────────────────────
AUTH_LOG="$RAW_LOG_DIR/auth.log"
SYS_LOG="$RAW_LOG_DIR/syslog"
APACHE_LOG="$RAW_LOG_DIR/apache.log"
SAMPLE_LOG="$RAW_LOG_DIR/sample_logs.log"

# Test data files
NORMAL_LOGS="$TEST_DATA_DIR/normal_logs.txt"
ANOMALY_LOGS="$TEST_DATA_DIR/anomaly_logs.txt"
MIXED_LOGS="$TEST_DATA_DIR/mixed_logs.txt"

# ────────────────────────────────────────
# 4. OUTPUT FILES
# ────────────────────────────────────────
# Stage 1 output
RAW_COLLECTED="$OUTPUT_DIR/raw_collected.log"

# Stage 2 output (filtered results)
FAILED_LOGINS="$FILTERED_DIR/failed_logins.txt"
SUSPICIOUS_IPS="$FILTERED_DIR/suspicious_ips.txt"
SERVER_ERRORS="$FILTERED_DIR/server_errors.txt"

# Stage 3 output (aggregated results)
IP_SUMMARY="$AGGREGATED_DIR/ip_summary.txt"
ANOMALY_COUNTS="$AGGREGATED_DIR/anomaly_counts.txt"
USAGE_STATS="$AGGREGATED_DIR/usage_statistics.txt"

# Stage 4 output (alerts)
ALERTS_LOG="$ALERTS_OUT_DIR/alerts.log"
CRITICAL_ALERTS="$ALERTS_OUT_DIR/critical_alerts.txt"
WARNING_ALERTS="$ALERTS_OUT_DIR/warning_alerts.txt"

# Reports
DAILY_REPORT="$REPORTS_DIR/daily_report.txt"
FINAL_SUMMARY="$REPORTS_DIR/final_summary.txt"

# ────────────────────────────────────────
# 5. PIPELINE LOG FILES
# ────────────────────────────────────────
PIPELINE_LOG="$LOGS_DIR/pipeline.log"
ERROR_LOG="$LOGS_DIR/errors.log"
EXECUTION_LOG="$LOGS_DIR/execution.log"
DEBUG_LOG="$LOGS_DIR/debug.log"

# ────────────────────────────────────────
# 6. CHECKPOINT FILES
# ────────────────────────────────────────
CHECKPOINT_STAGE1="$CHECKPOINT_DIR/stage1.done"
CHECKPOINT_STAGE2="$CHECKPOINT_DIR/stage2.done"
CHECKPOINT_STAGE3="$CHECKPOINT_DIR/stage3.done"
CHECKPOINT_STAGE4="$CHECKPOINT_DIR/stage4.done"
PIPELINE_STATE="$CHECKPOINT_DIR/pipeline.state"

# ────────────────────────────────────────
# 7. LOCK FILE (prevents duplicate runs)
# ────────────────────────────────────────
LOCK_FILE="$PROJECT_ROOT/.pipeline.lock"

# ────────────────────────────────────────
# 8. ALERT THRESHOLDS
# ────────────────────────────────────────
# How many failed logins from one IP before we alert?
FAILED_LOGIN_THRESHOLD=5

# How many server errors before we alert?
ERROR_THRESHOLD=10

# How many requests from one IP before suspicious?
REQUEST_THRESHOLD=100

# ────────────────────────────────────────
# 9. PIPELINE BEHAVIOR FLAGS
# ────────────────────────────────────────
# Set to true to print extra details while running
VERBOSE=false

# Set to true to test pipeline without writing any files
DRY_RUN=false

# Set to true to keep temp files after pipeline finishes
KEEP_TEMP=false

# Pipeline version
PIPELINE_VERSION="1.0.0"

# ────────────────────────────────────────
# 10. DATE AND TIME
# ────────────────────────────────────────
# These are used for naming reports and log entries
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_TODAY=$(date '+%Y-%m-%d')
TIME_NOW=$(date '+%H:%M:%S')

# ────────────────────────────────────────
# 11. EXPORT EVERYTHING
# ────────────────────────────────────────
# This makes all variables available to child scripts
export PROJECT_ROOT INPUT_DIR RAW_LOG_DIR TEST_DATA_DIR
export SCRIPTS_DIR STAGES_DIR UTILS_DIR PARSERS_DIR
export ALERTS_DIR RECOVERY_DIR OUTPUT_DIR FILTERED_DIR
export AGGREGATED_DIR ALERTS_OUT_DIR REPORTS_DIR
export CHECKPOINT_DIR LOGS_DIR TEMP_DIR BACKUP_DIR
export AUTH_LOG SYS_LOG APACHE_LOG SAMPLE_LOG
export NORMAL_LOGS ANOMALY_LOGS MIXED_LOGS
export RAW_COLLECTED FAILED_LOGINS SUSPICIOUS_IPS SERVER_ERRORS
export IP_SUMMARY ANOMALY_COUNTS USAGE_STATS
export ALERTS_LOG CRITICAL_ALERTS WARNING_ALERTS
export DAILY_REPORT FINAL_SUMMARY
export PIPELINE_LOG ERROR_LOG EXECUTION_LOG DEBUG_LOG
export CHECKPOINT_STAGE1 CHECKPOINT_STAGE2
export CHECKPOINT_STAGE3 CHECKPOINT_STAGE4 PIPELINE_STATE
export LOCK_FILE
export FAILED_LOGIN_THRESHOLD ERROR_THRESHOLD REQUEST_THRESHOLD
export VERBOSE DRY_RUN KEEP_TEMP PIPELINE_VERSION
export TIMESTAMP DATE_TODAY TIME_NOW
