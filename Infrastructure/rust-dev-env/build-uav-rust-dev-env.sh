#!/bin/bash

###############################################################################
# Builds the UAV Austin Rust Dev Environment and uploads its image to Docker 
# Hub.
# Tested on x64 Linux.
############################################################################### 

# All or nothing:
set -e

# Configuration Variables #
VERSION="0.0.0"
USER="padawan"
USERF="Padawan"
TAG="uavaustin/rust-dev-env"

push="false"
output="true"

# Colours #
BOLD='\033[0;1m' #(OR USE 31)
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
BROWN='\033[0;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color


# Functions:

function print
{
    if [[ "$output" != "true" ]]; then return; fi

    N=0
    n="-e"

    if [[ "$*" == *" -n"* ]]; then
        N=1
        n="-ne"
    fi

    if [ "$#" -eq $((1 + $N)) ]; then
        echo $n $1
    elif [ "$#" -eq $((2 + $N)) ]; then
        printf ${2} && echo $n $1 && printf ${NC}
    else
        #printf ${RED} && echo "Error in print. Received: $*" && printf ${NC}
        printf ${RED} && echo "Received: $*" && printf ${NC}
    fi
}

function helpText
{

cat << EOF
usage: ./build-uav-rust-dev-env.sh [-v <version>] [-u <user>] [-t <image tag>] [-P] [-D] [-q]
 
    -v <version>        SemVer Num: Version to use to label the created image with (default is 0.0.0)
    -u <user>           Image User: User account to create in image during Docker Build (default is padawan)
    -U <User Name>      Image User: Friendly name for user account to create (default is Padawan)
    -t <container tag>  Custom Tag: Custom tag to use for the Docker Container (default is "uavaustin/rust-dev-env")
    -D                  Debug Mode: Internally runs set -x (prints out all commands run, line by line)
    -P                  Push to DC: Push built image to Docker Cloud
    -q                  Quiet Mode: Supresses all feedback from the script (but not from other executables)
    -h                  Print Help: Prints this
EOF

exit $1

}

function processArguments
{
    while getopts ":v:u:U:t:PDqh" opt; do
        case "$opt" in
        h)  helpText 0
            ;;
        v)  VERSION=("$OPTARG")
            ;;
        u)  USER=("$OPTARG")
            ;;
        U)  USERF=("$OPTARG")
            ;;
        t)  TAG=("$OPTARG")
            ;;
        P)  push="true"
            ;;
        D)  set -x
            ;;
        q)  output="false"
            ;;
        \?) helpText 1
            ;;
        esac
    done
}

function checkDependencies
{
    dependencies=("docker whoami")
    exitC=0

    for d in ${dependencies[@]}; do
        if ! hash ${d} 2>/dev/null; then
            print "Error: ${d} is not installed." $RED
            exitC=1
        fi
    done

    # Check if we're in the docker group:
    if ! groups $(whoami) | grep &>/dev/null '\bdocker\b'; then
        print "Error: You are not in the docker group!"
        exitC=1
    fi

    return ${exitC}
}

function dockerBuild
{
    time \
    docker build -t "${TAG}:${VERSION}" -t "${TAG}:latest" \
        --build-arg NEWUSER=${USER} \
        --build-arg NEWUSERF=${USERF} \
        --build-arg VERSION=${VERSION} \
        . && \
    print "Build completed successfully in: ^" $CYAN

    return $?
}

function dockerPush
{
    if [[ "$push" != "true" ]]; then return; fi

    docker push ${TAG}

    return $?
}

function emergencyExit
{
    stty echo
    print "\nBuild incomplete; Are you sure you wish to exit? (enter option #)" $RED
    
    select yn in "Yes" "No"; do
        case $yn in
            Yes )  break;;
            No  )  return;;
        esac
    done

    # Failsafe exit actions go here:
    stty echo

    exit 1
}

trap emergencyExit SIGINT SIGTERM

{

checkDependencies && \
processArguments "$*" && \
dockerBuild && \
dockerPush && \
print "Fin." $CYAN &&
exit $?

} || print "Something went wrong." $RED

##########################
# AUTHOR:  Rahul Butani  #
# DATE:    Sept 04, 2017 #
# VERSION: 0.0.0         #
##########################