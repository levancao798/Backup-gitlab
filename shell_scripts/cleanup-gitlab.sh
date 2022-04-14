#!/bin/bash
# How to run:
#   1. Place this script in /u01/os_vtt_gitlab/gitlab/shell_scripts/
#   2. Switch to user 'git' and open crontab
#       $ sudo su git && crontab -e
#   3. Paste the following script:
#       "0 0 * * * bash /u01/os_vtt_gitlab/gitlab/shell-script/cleanup-gitlab.sh"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NONE='\033[0m'

GLB_BACKUP_DAILY="/u01/os_vtt_gitlab/backup_gitlab_new/gitlab_backups/Daily"
GLB_BACKUP_WEEKLY="/u01/os_vtt_gitlab/backup_gitlab_new/gitlab_backups/Weekly"

#before: into folder need actions
cd $GLB_BACKUP_DAILY
#perform delete versions but not the last 7 versions
(ls -t|head -n 7;ls)|sort|uniq -u|xargs rm -rf
printf "${GREEN} BACKUP_DAILY CLEANUP! ${NONE}\n"

#before: into folder need actions
cd $GLB_BACKUP_WEEKLY
#perform delete versions but not the last 2 versions
(ls -t|head -n 2;ls)|sort|uniq -u|xargs rm -rf
