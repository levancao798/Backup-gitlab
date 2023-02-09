#!/bin/bash
#  Give user 'git' read permissions to GitLab's secrets, this script will running with user git
#       Check user and group in linux: less /etc/passwd|grep git
#       If 'git' user and 'gitlabsecrets' group not exists, do these command:
#       $ sudo groupadd gitlabsecrets
#       $ sudo usermod -a -G gitlabsecrets git
#       $ sudo usermod -a -G gitlabsecrets root
#       $ sudo chgrp -R gitlabsecrets /u01/gitlab_home_folder/gitlab/
#       $ sudo chgrp -R gitlabsecrets /etc/gitlab/
#       $ sudo chmod g+rw /u01/gitlab_home_folder/gitlab/gitlab_backups/ -R
#       $ sudo chmod g+rw /etc/gitlab/ -R


#highligh
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NONE='\033[0m' 

#paramaters
# GITLAB_RESTORE="/u01/gitlab_home_folder/gitlab/gitlab_backups/Weekly"
GITLAB_RESTORE="/u01/gitlab_home_folder/gitlab/gitlab_backups/Daily"
GITLAB_DATA="/u01/gitlab_home_folder/gitlab/data_gitlab/git-data"
GLB_HOME="/u01/gitlab_home_folder/backup_gitlab_new"
GLB_BACKUP=$GLB_HOME"/gitlab_backups"
GLB_SNAPSHOT=$GLB_BACKUP"/snapshot"
TMP=$GLB_HOME"/tmp"

# Checking if this script is executed by user 'git'
# if [ $(whoami) != "root" ]; then
#     printf "Please execute this script with user 'root'"
#     printf "Exiting without doing anything"
#     exit 1
# fi

# STEP1: Stop the processes
stopProcesses () {
    printf "${GREEN} STEP1. Stopping the processes ${NONE}\n"
    sudo gitlab-ctl stop unicorn && sudo gitlab-ctl stop puma && sudo gitlab-ctl stop sidekiq
}

# STEP2. Extract Backup file
extractBackupFile() {
  printf "${GREEN} STEP2. Extracting backup file ${NONE}\n"
  if [[ -w $GITLAB_RESTORE ]] 
  then
    cd $GITLAB_RESTORE/$version
    cp *gitlabBackup* /var/opt/gitlab/backups/$version"_gitlab_backup.tar" 
    chmod 755 /var/opt/gitlab/backups/$version"_gitlab_backup.tar"
    input="$TMP/list-gitlab-repositories-daily.txt"
    while read -r line
    do
    REPO_NAME=${line//$GLB_REPO/""}
    REPO_NAME=${REPO_NAME////"-"}
    echo "start compressing $REPO_NAME ..."
    tar --extract --list-incremental=/dev/null --file $GLB_SNAPSHOT/$REPO_NAME.sngz
    done < "$input"  
    mv u01/gitlab_home_folder/gitlab/data_gitlab/git-data/repositories/ /u01/gitlab_home_folder/gitlab/data_gitlab/git-data -n
    mv var/opt/gitlab/.ssh/authorized_keys /var/opt/gitlab/.ssh -n
    mv etc/gitlab/ /etc -n
  else
    printf "${RED} $GITLAB_RESTORE is not writable. ${NONE} \n"
  fi
}

restoreGitlab () {
    printf "Restoring GitLab..."
    gitlab-rake gitlab:backup:restore BACKUP=$version force=yes --quiet
}

reconfigureGitlab () {
    printf "Restarting ..."
    gitlab-ctl restart && gitlab-ctl reconfigure
    sec=20
    while [ $sec -ge 1 ]; do
        printf "Waiting for GitLab's internal API: $sec ... \r"
        sleep 1
        sec=$[$sec-1]
    done
    printf "Waiting for GitLab's internal API: DONE!!!"

    printf "Sanitizing the database ..."
    gitlab-rake gitlab:check SANITIZE=true
    gitlab-rake cache:clear
}
permsFixBase() {
	# Fix the permissions on the repository base
	sudo chmod -R 755 $GITLAB_DATA/repositories/
# 	
}

run () {
    version=$1
    printf "Backup version is: $version"    
    stopProcesses
    extractBackupFile
    permsFixBase
    restoreGitlab
    reconfigureGitlab
}
     
select version in $(ls -A $GITLAB_RESTORE) exit; do 
    case $version in
        exit) printf "Exiting"
            exit 1 ;;
           *) run $version
	    break ;;
    esac
done