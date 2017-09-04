#!/bin/bash

###############################################################################
# Builds the UAV Austin Rust Dev Environment and uploads its image to Docker 
# Hub.
############################################################################### 

# All or nothing:
set -e

# Configuration Variables #
VERSION="0.0.0"
USER=

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

}

function processArguments
{

}

function checkDependencies
{

}

# Check for docker
# Process args
# 	version, user, tag
# Run docker build
# Upload image

##########################
# AUTHOR:  Rahul Butani  #
# DATE:    Sept 03, 2017 #
# VERSION: 0.0.0         #
##########################