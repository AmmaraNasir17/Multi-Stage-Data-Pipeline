\# System Architecture



\## Overview



The pipeline follows a linear ETL architecture with 4 stages,

checkpoint-based recovery, and centralized configuration.



\## Pipeline Flow

Input Logs

|

v

Stage 1: Log Collection



Reads all raw log files

Validates and merges them

Output: raw\_collected.log

|

v

Stage 2: Anomaly Filtering

grep filters suspicious lines

AWK parsers analyze patterns

Output: filtered/\*.txt

|

v

Stage 3: Data Aggregation

Bash associative arrays count IPs

Summarizes anomaly types

Output: aggregated/\*.txt

|

v

Stage 4: Alert Generation

Compares counts to thresholds

Writes critical and warning alerts

Output: alerts/\*.txt + reports/



\## Key Components



\### config.sh

Central settings file. All paths and thresholds defined here.

Every script sources this file first.



\### utils/logger.sh

Provides colored terminal output and timestamped log file writing.



\### utils/checkpoint\_manager.sh

Creates .done files after each stage.

Resume logic reads these to skip completed stages.



\### utils/error\_handler.sh

Registers trap handlers for ERR, EXIT, INT, TERM signals.

Ensures lock file is always removed on exit.



\### utils/validator.sh

Validates files, directories, and tools exist before processing.



\### utils/helpers.sh

Lock file management, disk space checking, runtime timer, backup.



\## Resume-on-Failure Design



Pipeline starts

|

v

Check checkpoint files

|

|-- stage1.done exists? --> Skip Stage 1

|-- stage2.done exists? --> Skip Stage 2

|-- stage3.done exists? --> Skip Stage 3

|-- stage4.done exists? --> Skip Stage 4

|

v

Run first incomplete stage

Save checkpoint after success

Continue to next stage



\## File Organization



Input:       input/raw\_logs/

Processing:  temp/

Output:      output/filtered/ aggregated/ alerts/ reports/

Logs:        logs/

Checkpoints: checkpoints/

Backups:     backups/



