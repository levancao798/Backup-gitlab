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

quietRake=1 #default flag to run
TIMESTAMP=`date +"%Y-%m-%d"`
HOSTNAME="192.168.3.57"
REMOTE_FILE_PATH="git@$HOSTNAME:"
GLB_ETC="/etc/gitlab"
GLB_LFS="/var/opt/gitlab/gitlab-rails/shared/lfs-objects"
#GLB_HOME="/u01/gitlab_home_folder/backup_gitlab_new"
# GLB_HOME="/u01/gitlab_home_folder/cnspht/projects/gitlab_backup"
GLB_HOME="/u01/gitlab_home_folder/gitlab"

GLB_BACKUP=$GLB_HOME"/gitlab_backups"
GLB_SNAPSHOT=$GLB_BACKUP"/snapshot"
TMP=$GLB_HOME"/tmp"
# GLB_WEEKLY=$GLB_BACKUP"/Full-backup"
GLB_WEEKLY=$GLB_BACKUP"/Weekly"
GLB_DAILY=$GLB_BACKUP"/Daily"
GLB_DATA="/u01/gitlab_home_folder/gitlab/data_gitlab/git-data"
GLB_REPO=$GLB_DATA"/repositories/"
GLB_SSH_KEY="/var/opt/gitlab/.ssh"
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
extractFile() {
  printf "${GREEN} STEP2. Extracting backup file ${NONE}\n"
  if [[ -w $GLB_BACKUP ]] 
  then
    cd $1
    cp *gitlabBackup* /var/opt/gitlab/backups/$1"_gitlab_backup.tar" 
    chmod 755 /var/opt/gitlab/backups/$1"_gitlab_backup.tar"
    ls *.tar |xargs -n1 tar -xvf
    mv u01/gitlab_home_folder/gitlab/data_gitlab/git-data/repositories/ /u01/gitlab_home_folder/gitlab/data_gitlab/git-data -n
    mv var/opt/gitlab/.ssh/authorized_keys /var/opt/gitlab/.ssh -n
    mv etc/gitlab/ /etc -n
  else
    printf "${RED} $GLB_BACKUP is not writable. ${NONE} \n"
  fi
}
restoreBackupfile(){
    cd $GLB_WEEKLY
    version_full=
    extractFile "$version_full"
    
    cd $GLB_DAILY
    version_incre= 
    list=
    for i in $list; do 
        ls -d */|sort -n |xargs extractFile
    done
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

# selectFull(){
    
# }

run () {
    version_full=$1
    version_incre=$2
    printf "version full is: $version_full" 
    printf "version incre is: $version_incre"    
    
    # stopProcesses
    # extractFile $version_full

    # extractFile $version_incre
    # extractBackupFile
    # permsFixBase
    # restoreGitlab
    # reconfigureGitlab
}
     
select version_full in $(ls -A $GLB_WEEKLY) exit; do 
    select version_incre in $(ls -A $GLB_DAILY) exit; do
        case $version_incre in
            exit) printf "Exiting"
                exit 1 ;;
            *) run $version_full $version_incre
            break ;;
            
        esac
    done
done