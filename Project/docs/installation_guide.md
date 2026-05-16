\# Installation Guide



\## System Requirements



\- Operating System: Linux or Windows with WSL

\- Shell: Bash 4.0 or higher

\- Tools: grep, awk, sed, sort, uniq (all built into Linux)

\- Disk Space: Minimum 500MB free

\- RAM: Minimum 512MB



\## Step 1 — Install WSL (Windows only)



Open PowerShell as Administrator and run:

wsl --install

Restart your computer when prompted.



\## Step 2 — Open WSL Terminal



Press Windows Key + R, type `wsl`, press Enter.



\## Step 3 — Update System



```bash

sudo apt update \&\& sudo apt upgrade -y

sudo apt install vim tree -y

```



\## Step 4 — Navigate to Project



```bash

cd /mnt/c/Users/YourUsername/Desktop/multi\_stage\_data\_pipeline/Project

```



\## Step 5 — Make Scripts Executable



```bash

chmod +x main\_pipeline.sh

chmod +x scripts/stages/\*.sh

chmod +x scripts/utils/\*.sh

chmod +x scripts/alerts/\*.sh

chmod +x scripts/recovery/\*.sh

chmod +x tests/unit\_tests/\*.sh

chmod +x tests/integration\_tests/\*.sh

chmod +x tests/recovery\_tests/\*.sh

```



\## Step 6 — Generate Sample Logs



```bash

bash scripts/utils/generate\_logs.sh

```



\## Step 7 — Run the Pipeline



```bash

bash main\_pipeline.sh

```



\## Step 8 — Install Cron Jobs (Optional)



```bash

crontab -e

```

Copy contents of `cron/pipeline\_cronjob.txt` and paste.



\## Verify Installation



```bash

bash tests/integration\_tests/test\_full\_pipeline.sh

```

All tests should pass.

