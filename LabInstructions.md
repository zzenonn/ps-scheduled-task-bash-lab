---
tags: Pluralsight, Security, Labs
---

# Scheduled Tasks using Bash

## Scenario

Globomatics is trying to build an infrastructure for the "ideal society," and they need your help to make sure their infrastructure stays secure.

## Running the Security Scanning Service

Globomantics makes use of an open source tool called *lynis* to check their system for possible security misconfigurations, and to make sure that their systems adhere to industry benchmarks. In this task, you are going to try and run this tool.

1. Run `cd /usr/local/lynis` to enter the program directory.
2. Run `sudo ./lynis audit system`
You should see an lynis begin the scan and output files, scan results, and suggestions on how to harden and secure your environment.

## Schedule the Scans

Globomantics does not have the manpower to run daily scans of their environment. In this task, you are going to configure the scans to run as a scheduled job.

1. Install *cron*, the linux task scheduler by running `sudo apt-get install cron -y`.
2. To test if it's running, run `crontab -e`, and add the following line at the end of the file.
```
*/2 * * * * /usr/local/lynis/lynis audit system
```
**Note**: If you are unfamiliar with the `vim` text editor, press `i` to go into insert mode to type the line, then press `ESC` and `:wq` to save and exit. 

3. Cron should run the task every two minutes. Run `sudo tail -f /var/log/lynis.log`. After a few seconds, it should populate with logs from the latest run.
4. To make the command run at 3:00am every day, run `crontab -e` and change the line you wrote from step 2 into the following:
```
0 3 * * * /usr/local/lynis/lynis audit system
```
You should get a message saying "crontab: installing new crontab"

5. Congratulations! You have created a scheduled task on bash.
