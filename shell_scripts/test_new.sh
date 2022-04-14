#GLB_DATA="/u01/os_vtt_gitlab/gitlab/data_gitlab/git-data"
#GLB_REPO=$GLB_DATA"/repositories/"
#REPO_NAME="/u01/os_vtt_gitlab/gitlab/data_gitlab/git-data/repositories/vtt_pmvt_qt06_18002_mbccs_vtg/mbccs_natcom_subgroup/r3983069_mbccs_android_lite.git"
#echo $GLB_REPO
#REPO_NAME=${REPO_NAME//$GLB_REPO/""}
#REPO_NAME=${REPO_NAME////"-"}
#echo $REPO_NAME
SINCE_TIME=`date -d "yesterday" '+%Y-%m-%d'`
gitlab-rake gitlab:list_repos SINCE=$SINCE_TIME
