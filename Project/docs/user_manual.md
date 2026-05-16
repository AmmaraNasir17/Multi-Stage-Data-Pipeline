\# User Manual



\## Running the Pipeline



\### Full Run (recommended)

```bash

bash main\_pipeline.sh

```



\### Resume After Crash

```bash

bash main\_pipeline.sh --resume

```



\### Full Reset and Restart

```bash

bash main\_pipeline.sh --reset

```



\### Test Without Writing Files

```bash

bash main\_pipeline.sh --dry-run

```



\### See Detailed Output

```bash

bash main\_pipeline.sh --verbose

```



\### Check Current Status

```bash

bash main\_pipeline.sh --status

```



\### Get Help

```bash

bash main\_pipeline.sh --help

```



\---



\## Checking Results



\### View Final Report

```bash

cat output/reports/final\_summary.txt

```



\### View Critical Alerts

```bash

cat output/alerts/critical\_alerts.txt

```



\### View Warning Alerts

```bash

cat output/alerts/warning\_alerts.txt

```



\### View IP Summary

```bash

cat output/aggregated/ip\_summary.txt

```



\### View Pipeline Log

```bash

cat logs/pipeline.log

```



\---



\## Running Individual Stages



```bash

bash scripts/stages/stage1\_collect.sh

bash scripts/stages/stage2\_filter.sh

bash scripts/stages/stage3\_aggregate.sh

bash scripts/stages/stage4\_alert.sh

```



\---



\## Recovery Operations



\### Resume from last checkpoint

```bash

bash scripts/recovery/resume\_pipeline.sh

```



\### Rollback a specific stage

```bash

bash scripts/recovery/rollback.sh 3

```



\### Rollback everything

```bash

bash scripts/recovery/rollback.sh all

```



\### Clean temp files

```bash

bash scripts/recovery/cleanup.sh --temp

```



\### Full cleanup

```bash

bash scripts/recovery/cleanup.sh --all

```



\---



\## Alert Operations



\### Generate detailed alerts

```bash

bash scripts/alerts/generate\_alerts.sh

```



\### Check all thresholds

```bash

bash scripts/alerts/threshold\_checker.sh scan

```



\### Check one value

```bash

bash scripts/alerts/threshold\_checker.sh check 40 5 "Failed logins"

```



\### Show current thresholds

```bash

bash scripts/alerts/threshold\_checker.sh show

```



\### Generate email report

```bash

bash scripts/alerts/email\_alert.sh

```



\---



\## Changing Settings



Open `config.sh` and edit:



```bash

FAILED\_LOGIN\_THRESHOLD=5    # Change alert threshold for failed logins

ERROR\_THRESHOLD=10          # Change alert threshold for server errors

VERBOSE=false               # Set true for detailed output

DRY\_RUN=false               # Set true to test without writing

KEEP\_TEMP=false             # Set true to keep temp files

```



\---



\## Running Tests



```bash

bash tests/unit\_tests/test\_stage1.sh

bash tests/unit\_tests/test\_stage2.sh

bash tests/unit\_tests/test\_stage3.sh

bash tests/unit\_tests/test\_stage4.sh

bash tests/integration\_tests/test\_full\_pipeline.sh

bash tests/recovery\_tests/test\_resume.sh

bash tests/recovery\_tests/test\_failure\_handling.sh

```

