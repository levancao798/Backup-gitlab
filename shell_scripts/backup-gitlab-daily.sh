#!/bin/bash
# On server 10.255.60.6:
#   1. Create folders: 
#       + /u01/gitlab_home_folder/gitlab/gitlab_backups
#       + /u01/gitlab_home_folder/gitlab/gitlab_backups/Weekly
#       + /u01/gitlab_home_folder/gitlab/gitlab_backups/Daily
#       + /u01/gitlab_home_folder/gitlab/tmp
#       + /u01/gitlab_home_folder/gitlab/shell-script
#
#   2. Give user 'git' read permissions to GitLab's secrets
#       Check user and group in linux: less /etc/passwd|grep git
#       If 'git' user and 'gitlabsecrets' group not exists, do these command:
#       $ sudo groupadd gitlabsecrets
#       $ sudo usermod -a -G gitlabsecrets git
#       $ sudo usermod -a -G gitlabsecrets root
#       $ sudo chgrp -R gitlabsecrets /u01/gitlab_home_folder/gitlab/
#       $ sudo chgrp -R gitlabsecrets /etc/gitlab/
#       $ sudo chmod g+rw /u01/gitlab_home_folder/gitlab/gitlab_backups/ -R
#       $ sudo chmod g+rw /etc/gitlab/ -R
#
#   3. Create ssh key for user 'git'
#       Check ssh public key first: cat ~/.ssh/id_rsa.pub, if dont have ssh public key, create it by:
#       $ sudo su git && cd
#       $ ssh-keygen
#
# On remote server: 
#   1. Create folder 
#       + /u01/gitlab_home_folder/gitlab/gitlab_backups/Daily/
#       + /u01/gitlab_home_folder/gitlab/gitlab_backups/Weekly/
#       + /u01/gitlab_home_folder/gitlab/gitlab_backups/ 
#   2. Add git@10.255.60.6's public key to remote server authorized keys
#       + Copy git@10.255.60.6's id_rsa.pub
#       + Paste into git@remote_server's ~/.ssh/authorized_keys
#
# How to run manually:
#      Change Hostname to correctly "vim backup-gitlab-daily.sh"
#      $ cd /u01/gitlab_home_folder/gitlab/shell-script/
#      $ sudo chmod +x backup-gitlab-daily.sh
#      $ ./backup-gitlab-daily.sh
#
# Crontab:
#      $ crontab -e
#      $ "0 0 * * 1-5 bash /u01/gitlab_home_folder/gitlab/shell-script/backup-gitlab-daily.sh" #At 00:00 workday

#highligh
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NONE='\033[0m' 

#paramaters
quietRake=1 #default flag to run
TIMESTAMP=`date +"%Y-%m-%d"`
HOSTNAME="10.255.60.7"
REMOTE_FILE_PATH="git@$HOSTNAME:"
GLB_ETC="/etc/gitlab"
#GLB_HOME="/u01/gitlab_home_folder/backup_gitlab_new"
GLB_HOME="/u01/gitlab_home_folder/cnspht/projects/gitlab_backup"
GLB_BACKUP=$GLB_HOME"/gitlab_backups"
GLB_SNAPSHOT=$GLB_BACKUP"/snapshot"
TMP=$GLB_HOME"/tmp"
GLB_WEEKLY=$GLB_BACKUP"/Weekly"
GLB_DAILY=$GLB_BACKUP"/Daily"
GLB_DATA="/u01/gitlab_home_folder/gitlab/data_gitlab/git-data"
GLB_REPO=$GLB_DATA"/repositories/"
GLB_SSH_KEY="/var/opt/gitlab/.ssh"
#snapshotFile=$(ls $GLB_SNAPSHOT -lt|tail -1)
#LAST_BACKUP_TIME=$(strings $snapshotFile | awk 'NR==2{print}' | xargs -I {} date +'+%Y-%m-%d' -d @{})
LAST_BACKUP_TIME=$(find $GLB_SNAPSHOT -type f -name '*.sngz' -exec sh -c "strings {} | awk 'NR==2{print}'" \; | sort -n | head -1 | xargs -I {} date +'%Y-%m-%dT%H:%M:%S' -d @{})

#STEP1. Backup gitlab (skip repository)
rakeBackup() {
  printf "${GREEN} STEP1. Backup current gitlab (skip repository) ${NONE}\n"
  echo "start compressing meta-data ..."
  echo start time: `date`
  if [[ $quietRake == 1 ]]
  then
    gitlab-rake gitlab:backup:create SKIP=repositories,lfs
    backupFilename=$(ls /var/opt/gitlab/backups -t|head -n 1)
    BACKUP_VERSION=${backupFilename%_gitlab_backup.tar}
    mkdir $GLB_DAILY/$BACKUP_VERSION
    cp -a /var/opt/gitlab/backups/$backupFilename $GLB_DAILY/$BACKUP_VERSION"/$TIMESTAMP-gitlabBackup.tar"
    printf "${YELLOW} Backup version is $BACKUP_VERSION ${NONE}\n"
  else
    printf "${RED} Fail to backup ${NONE} \n"
    exit 1
  fi
  echo end time:`date`
}

#STEP2. Backup gitlab configuration
archiveConfig() {
  printf "${GREEN} STEP2. Backup gitlab configuration ${NONE}\n"
  # echo start time: `date`
  echo "start compressing configuration ..."
  time tar czfP "$GLB_DAILY/$BACKUP_VERSION/$TIMESTAMP-gitlabConf.tar.gz" $GLB_ETC"/gitlab.rb" $GLB_ETC"/gitlab-secrets.json" $GLB_ETC"/trusted-certs" $GLB_SSH_KEY  
  # echo end time:`date`
}

#STEP3. Backup gitlab LFS
archiveLFS() {
  printf "${GREEN} STEP3. Backup gitlab LFS ${NONE}\n"
  echo "start compressing LFS ..."
   echo start time: `date`
  time tar cgP $GLB_SNAPSHOT/snapshot-LFS.sngz $GLB_LFS -f $GLB_WEEKLY/$BACKUP_VERSION/$TIMESTAMP-LFS.tar
   echo end time: `date`
}

#STEP4. Backup repository
# Backup repository by time
archiveByTime() {
  printf "${GREEN} STEP4. Backup gitlab repository by time [DAILY] ${NONE}\n"
  echo start time: `date`
  echo $LAST_BACKUP_TIME
  gitlab-rake gitlab:list_repos SINCE=$LAST_BACKUP_TIME | grep git > $TMP/list-gitlab-repositories-daily.txt
  input="$TMP/list-gitlab-repositories-daily.txt"
  if [[ -w $GLB_DATA ]]
  then
    while read -r line
    do
	  REPO_NAME=${line//$GLB_REPO/""}
	  REPO_NAME=${REPO_NAME////"-"}
	   echo start time: $REPO_NAME: `date`
    echo "start compressing $REPO_NAME ..."
    # tar czfP "$GLB_DAILY/$BACKUP_VERSION/$TIMESTAMP-$REPO_NAME.tar.gz" $line
    time tar cgP $GLB_SNAPSHOT/$REPO_NAME.sngz $line -f $GLB_DAILY/$BACKUP_VERSION/$TIMESTAMP-$REPO_NAME.tar
	   echo end time: $REPO_NAME: `date`
    done < "$input"  
  else
      printf "${RED} $GLB_DATA is not writable. ${NONE} \n"
      exit 1
  fi
  echo end time:`date`
}

#STEP5. Sync backup folder to Backup server
syncBackup(){
  printf "${GREEN} STEP5. Sync backup folder to Backup server ${NONE}\n"
  printf "${GREEN}Starting transfer ${NONE}\n"
  echo start time: `date`
  ssh git@$HOSTNAME "mkdir /u01/gitlab_home_folder/gitlab/gitlab_backups/Daily/$BACKUP_VERSION"
  cd $GLB_DAILY
  rsync $BACKUP_VERSION $REMOTE_FILE_PATH/$BACKUP_VERSION
  OUT=$?
  if [ $OUT = 0 ]; then
    printf "${GREEN}Successful backup! ${NONE}\n"
    printf "${YELLOW} Backup version is $BACKUP_VERSION ${NONE}\n"
  else
    printf "${RED}Transfer fail! ${NONE}\n"
    exit 1
  fi
  echo end time:`date`
}

rakeBackup
archiveConfig
archiveLFS
archiveByTime
#syncBackup

