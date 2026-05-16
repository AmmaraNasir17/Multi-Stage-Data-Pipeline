\# Troubleshooting Guide



\## Problem 1 — Pipeline already running error



ERROR: Pipeline already running!



Fix:

```bash

rm -f .pipeline.lock

bash main\_pipeline.sh

```



\## Problem 2 — Permission denied



bash: main\_pipeline.sh: Permission denied



Fix:

```bash

chmod +x main\_pipeline.sh

chmod +x scripts/stages/\*.sh

```



\## Problem 3 — Log files are empty



ERROR: All log files are empty



Fix:

```bash

bash scripts/utils/generate\_logs.sh

```



\## Problem 4 — Windows line ending errors



\\r: command not found



Fix:

```bash

sed -i 's/\\r//' scripts/stages/stage1\_collect.sh

```

Run for any affected file.



\## Problem 5 — Stage skipped unexpectedly

If a stage is being skipped when you want it to run:

```bash

rm checkpoints/stage2.done

bash main\_pipeline.sh --resume

```



\## Problem 6 — No alerts generated

Check thresholds in config.sh:

```bash

grep THRESHOLD config.sh

```

Lower the thresholds if needed.



\## Problem 7 — Out of disk space

```bash

bash scripts/recovery/cleanup.sh --all

```



\## Problem 8 — AWK parser errors

```bash

awk --version

```

If awk is missing:

```bash

sudo apt install gawk -y

```



\## Problem 9 — Cron job not running

Check cron service is running:

```bash

sudo service cron start

crontab -l

```



\## Problem 10 — Wrong project path

Always run from project root:

```bash

cd /mnt/c/Users/YourUsername/Desktop/multi\_stage\_data\_pipeline/Project

bash main\_pipeline.sh

```

