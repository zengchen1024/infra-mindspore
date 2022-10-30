#!/bin/bash

set -euox pipefail

cd $(dirname $0)
me=$(basename $0)
pn=$#
all_param=${@-""}

upstream_org=opensourceways
upstream_repo=infra-mindspore
upstream=https://github.com/${upstream_org}/${upstream_repo}.git

fetch_parameter() {
    local index=$1
    if [ $pn -lt $index ]; then
        echo ""
    else
        local all=( $all_param )
        echo "${all[@]:${index}-1}"
    fi
}

timestamp() {
    echo $(date +%s)
}

clone_infra_mindspore() {
    local git_user=$1
    local git_password=$2
    local git_user_email=$3

    local path=$(pwd)
    local repo=${upstream_repo}

    test -d $repo && rm -fr $repo

    git clone https://${git_user}:${git_password}@github.com/${git_user}/${repo}.git
    cd $repo

    git config user.name $git_user
    git config user.email $git_user_email

    git remote add upstream ${upstream}
    git fetch upstream
    git rebase upstream/master

    cd $path
}

reset_image(){
    local image=$1
    kustomize edit set image swr.cn-north-4.myhuaweicloud.com/opensourceway/xihe/xihe=$image
}

update_image() {
    local bot=$1
    local image=$2
    local namespace=$3
    local path=$(pwd)

    cd applications/$namespace

    cd $bot

    reset_image $image

    cd $path
}

submit_pr() {
    local bot=$1
    local git_user=$2
    local git_password=$3
    local commit_msg=$4

    local branch=${bot}_$(timestamp)
    git checkout -b $branch

    git add .
    git commit -am "$commit_msg"

    git push -u origin $branch

    title=$commit_msg

    curl \
      -u ${git_user}:${git_password} \
      -X POST \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/${upstream_org}/${upstream_repo}/pulls \
      -d "{\"title\":\"${title}\",\"head\":\"${git_user}:${branch}\",\"base\":\"master\",\"prune_source_branch\":\"true\"}"
}

update_bot_image() {
    if [ $# -lt 6 ]; then
        cmd_help "update_bot_image"
        exit 1
    fi

    local bot=$1
    local image=$2
    local namespace=$3
    local git_user=$4
    local git_user_password=$5
    local git_user_email=$6

    clone_infra_mindspore $git_user $git_user_password $git_user_email

    cd ${upstream_repo}

    update_image $bot $image $namespace

    #submit_pr $bot $git_user $git_user_password "update image for bot ${namespace}/${bot}"
}

cmd_help(){
    if [ $# -eq 0 ]; then
cat << EOF
This deploy tool depends on the structure of ${upstream}.

usage: $me cmd
supported cmd:
    update_bot_image: update the image of bot.
    help: show the usage for each commands.
EOF
        return 0
    fi

    local cmd=$1
    case $cmd in
        "update_bot_image")
            echo "$me update_bot_image bot-name image namespace git-user git-user-password git-user-email"
            ;;
        "help")
            echo "$me help other-child-cmd"
            ;;
        *)
            echo "error: unknown child cmd: $cmd"
            ;;
     esac
}


check_param() {
    local n=$1

    if [ $pn -lt $n ]; then
        cmd_help $all_param
        return 1
    fi
}

check_param 1

cmd=$1
case $cmd in
    "update_bot_image")
        check_param 7
        update_bot_image "$2" "$3" "$4" "$5" "$6" "$7"
        ;;
    "--help")
        cmd_help
        ;;
    "help")
        cmd_help $(fetch_parameter 2)
        ;;
    *)
        echo "error: unknown cmd: $cmd"
        ;;
esac
