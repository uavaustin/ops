#!/bin/bash

###############################################################################
# Installs and configures the UAV Austin Rust Dev Environment locally. 
# 
# Sets up Docker and all the tools needed to X11 forward applications out of a
# Docker Container.
# 
# Finally, this script pulls an image from Docker Hub, ties it to a container
# with the appropriate mounts and devices, and adds some helpful aliases.
#
# Tested on x64 Linux and Windows 10 (Build 1703)
# 
# WARNING: May not work on non-standard installations (i.e. Custom Program 
# Files Directory Location)
############################################################################## 

# All or nothing:
set -e

DOCKER="docker"
DEPENDENCIES=("cat grep expr whoami xargs which")

# Configuration Variables #
IMAGE_NAME="uavaustin/rust-dev-env:latest"
CNTNR_NAME="uava-dev"
PRJCT_DIR="${HOME}/Documents/UAVA/"

aliases="true"
output="true"

# Colours #
BOLD='\033[0;1m' #(OR USE 31)
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
BROWN='\033[0;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color

CMD="/mnt/c/Windows/System32/cmd.exe"

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
        echo $n "${1}"
    elif [ "$#" -eq $((2 + $N)) ]; then
        printf ${2} && echo $n "${1}" && printf ${NC}
    else
        #printf ${RED} && echo "Error in print. Received: $*" && printf ${NC}
        printf ${RED} && echo "Received: $*" && printf ${NC}
    fi
}

function helpText
{

cat << EOF
usage: ./install-uav-rust-dev-env.sh [-i <image name>] [-p <project dir>] [-t <container tag>] [-a <alias file>| -A] [-D] [-q]
 
    -i <image name>     Image Name: Specific docker image to use for the container (default is uavaustin/rust-dev-env:latest)
    -p <project dir>    Shared Dir: Folder to mount into the Docker Container (default is ~/Documents/UAVA/)
    -t <container tag>  Custom Tag: Custom tag to use for the Docker Container (default is uava-dev)
    -a <alias file>     Alias File: Add aliases to a specified file (default is ~/.bash_aliases)             
    -A                  No Aliases: Skip adding aliases
    -D                  Debug Mode: Internally runs set -x (prints out all commands run, line by line)
    -q                  Quiet Mode: Supresses all feedback from the script (but not from other executables)
    -h                  Print Help: Prints this
EOF

exit $1

}

function badEnv
{
    print "Go to http://uavaustin.org/camp/rust/0 for instructions on how to configure your environment." $BOLD
    print "(and then try again)"
    exit $1
}

function processArguments
{
    while getopts ":i:p:t:a:ADqh" opt; do
        case "$opt" in
        h)  helpText 0
            ;;
        i)  IMAGE_NAME=("$OPTARG")
            ;;
        p)  PRJCT_DIR=$(echo "$OPTARG" | xargs)
            print "Using \"${PRJCT_DIR}\" as project directory" $CYAN
            ;;
        t)  CNTNR_NAME=("$OPTARG")
            ;;
        a)  ALIAS_FILE=("$OPTARG")
            ;;
        A)  aliases="false"
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

function checkDependenciesFinal
{
    dependencies=$DEPENDENCIES
    dependencies+=("$*")

    exitC=0

    for d in ${dependencies[@]}; do
        if ! hash ${d} 2>/dev/null; then
            print "Error: ${d} is not installed." $RED
            exitC=1
        fi
    done

    DOCKER=$(which ${DOCKER})

    return ${exitC}
}

function checkForDockerGroup
{
    runCount=$1

    if [[ $runCount -gt 1 ]]; then
        print "Sorry, something went wrong." $RED
        print "We couldn't add you to the docker group." $RED
        badEnv 1
    elif [[ $runCount -eq 1 ]]; then
        successString="You're now in the docker group! Great Success!"
    else
        successString="You're already in the docker group! Well done!"
    fi

    # First let's see if there even is a docker group:
    if cut -d: -f1 /etc/group | grep -q "docker"; then
        # If there is, see if we're in it
        if groups $(whoami) | grep -q "docker"; then
            # If we are, all is well.
            print "${successString}" $CYAN
        else
            # If not, let's try to add the user to it:
            print "We're going to try to add you to the docker group." $BOLD
            print "You're probably going to be prompted for your password." $RED
            print "This is necessary for us to add you to the docker group." $RED
            print "(it's perfectly safe)" $RED

            sudo usermod -aG docker $(whoami)

            # Now let's see if that actually worked:
            ((runCount++))
            return checkForDockerGroup $runCount
        fi
    else
        # If there is no docker group, throw an error:
        print "We couldn't find a docker group." $RED
        badEnv 1
    fi
}

function windowsCMD
{
    # Invoke the devil:
    # Invoking cmd does some funky quote parsing, hence the extra quotes
    output=$(/mnt/c/Windows/System32/cmd.exe /C "$*")
    
    # Clean up string because Windows and DOS were built for type writters
    # (yes, another carriage return issue)
    echo $output | tr -d '\r'
}

function dos2wslPath
{
    # Converts a Windows style path to something that we can access from bash
    # on windows.

    # Split on backslashes:
    IFS='\' read -ra DOS_PATH <<< "$*"

    # Grab first letter of path, switch to lowercase using a bash 4 feature
    # (bash on windows is guaranteed bash 4.0+)
    DRIVE_LETTER="${DOS_PATH[0]:0:1}"
    DRIVE_LETTER="${DRIVE_LETTER,,}"

    # Pop one element
    DOS_PATH=("${DOS_PATH[@]:1}")

    # Put together the new path:
    WSL_PATH="/mnt/${DRIVE_LETTER}"
    for i in "${DOS_PATH[@]}"; do
        WSL_PATH="${WSL_PATH}/${i}"
    done

    # Return:
    echo "$WSL_PATH"
}

function windowsDependency_DockerClient
{
    print "Checking for docker client..." $PURPLE

    if hash docker 2>/dev/null; then
        print "The docker client is already installed." $GREEN
    else
        print "Docker Client not installed." $RED
        print "We're going to try to install it with apt now:" $BROWN
        print "(Enter your password when prompted)" $BOLD

        # This is technically a little more wasteful (in terms of space) than
        # just downloading the client from http://dockr.ly/2wKcJva, but this
        # way, they get updates easily and I don't have so set PATHs, so I
        # don't care.

        sudo echo Installing Docker...
        sudo apt install -yy -q docker.io docker-compose
    fi

    if 
}

function windows_checkForHypervisor
{
    # There are 3 possibilites for Hyper-V support:
    #     - Enabled (and therefore supported)
    #       * "A hypervisor has been detected"
    #     - Supported (in Hardware and Software) but not enabled
    #       * "VM Monitor Mode Extensions: Yes"
    #       * "Virtualization Enabled In Firmware: Yes"
    #       * "Second Level Address Translation: Yes"
    #       * "Data Execution Prevention Available: Yes"
    #       * "Microsoft Windows 10 ['Pro' || 'Education' || 'Enterprise']"
    #           + Anything pre Windows 10 is automatically not supported.
    #     - Not Supported (in Hardware and/or Software)
    #       * Missing one of more of the above (^^^)
    #
    # 1st: Enabled/Not (0/1)
    # 2nd: Supported OS/Unsupported OS (0/1)
    # 3rd: VMM Exts/No (1/0)
    # 4th: VIF/No (1/0)
    # 5th: SLAT/No (1/0)
    # 6th: DEP/No (1/0)
    #
    # Therefore:
    # (0b000000) -> 0  => HyperV Enabled
    # (0b000001) -> 1  => Right OS, No H/W support, not enabled 
    # (0b`````0) -> -  => (IMPOSSIBLE; all the `'s must be 0)
    # (0b000011) -> 3  => Not supported in H/W or S/W, not enabled
    # (0b111101) -> 61 => H/W support and S/W support, just not enabled
    # (0b111111) -> 63 => H/W support, but no S/W support

    # Grab System Info:
    sysinfo=$(windowsCMD systeminfo)
    out=0

    # Check if Hypervisor is enabled -> if not enabled, add 1:
    if ! echo $sysinfo | grep -q "A hypervisor has been detected."; then
        ((out++))
    fi

    # Check for a supported OS:
    os=$(echo $sysinfo | awk 'BEGIN { FS = "OS" } { print $2 }')
    if echo "$os" | grep -q "Microsoft Windows 10 Pro" || \
       echo "$os" | grep -q "Microsoft Windows 10 Education" || \
       echo "$os" | grep -q "Microsoft Windows 10 Enterprise"; then
        ((out))
    else
        ((out+=2))
    fi

    # Check HW features:
    hwFs=("VM Monitor Mode Extensions: Yes" "Virtualization Enabled In Firmware: Yes"
        "Second Level Address Translation: Yes" "Data Execution Prevention Available: Yes")
    
    for ((i=0; i < ${#hwFs[@]}; i++)); do
        if echo $sysinfo | grep -q "${hwFs[$i]}"; then
            (( out += 2**($i+2) ))
        fi
    done

    echo $out

    return $out
}

function windows_InstallDockerToolbox
{
    # Check if the Toolbox is already installed:
    dockerToolboxPath=$(dos2wslPath "$(windowsCMD "echo %programfiles%")\\Docker Toolbox\\docker.exe")

    if [ -e "$dockerToolboxPath" ]; then
        print "Docker Toolbox is installed!" $PURPLE
        return 0
    else
        # Install Docker Toolbox:
        print "We couldn't find Docker Toolbox on your computer, so we're"
        print "going to try to install it."

        # First we need a download location that windows can access
        # Let's use the User's Downloads folder:
        WIN_HOME=$(windowsCMD echo %USERPROFILE%)
        dPathWin="${WIN_HOME}\\Downloads\\DockerToolbox.exe"
        dPath=$(dos2wslPath ${dPathWin})

        # Now download the latest stable docker toolbox:
        # (I believe Bash On Windows ships with wget so this should be safe)
        wget -q --show-progress -O "${dPath}" \
            "https://download.docker.com/win/stable/DockerToolbox.exe"

        print "In a few seconds, the Docker Toolbox Installation should begin." $BOLD
        print "Click Yes on the User Account Control Prompt." $BOLD
        print "Press Install on any driver prompts that appear" $BOLD

        sleep 5

        $CMD /C "$dPathWin" /COMPONENTS=docker,dockermachine,dockercompose,kitematic,virtualbox /SILENT  | more

        # Check if it really installed, just to be sure:
        return $(windows_InstallDockerToolbox)
    fi
}

function windows_ConfigureDockerToolbox
{
    # Basically make use of the Docker Quickstart Terminal:
    dockerToolboxPathWin="$(windowsCMD "echo %programfiles%")\\Docker Toolbox"
    dockerToolboxPath=$(dos2wslPath "${dockerToolboxPathWin}")
    # modifiedStartPath="/start2.sh"
    gitBashPath=$(dos2wslPath "$(windowsCMD "echo %programfiles%")\\Git\\bin\\bash.exe")

    # cp "${dockerToolboxPath}/start.sh" "${modifiedStartPath}"

    cd "${dockerToolboxPath}" && "${gitBashPath}" #--login -i "C:\Program Files\Docker Toolbox\start.sh"
    ##"${dockerToolboxPathWin}\\start.sh" && cd -

    echo fin
    sleep 10

    echo "potato out"
    # exit

    # $CMD /K "C:\Program Files\Docker Toolbox" /C "C:\Program Files\Git\bin\bash.exe" --login -i "C:\Program Files\Docker Toolbox\start.sh"
}

function windowsDependency_DockerServer
{
    print "Checking for docker server..." $PURPLE

    hyperV=$(windows_checkForHypervisor)

    HYPER_V_ENABLED=0   # Hypervisor currently enabled
    HYPER_V_SUPPORT=61  # Full support (HW/SW) but not enabled

    if [ $hyperV -eq $HYPER_V_ENABLED ]; then
        # If hypervisor is enabled, check if docker is already configured:
        if docker images > /dev/null 2>&1; then
            print "Docker Server already works! (With HyperV!!)" $GREEN
            return 0
        else
            # If hypervisor is enabled but docker isn't already set up,
            # alert the user:
            print \
"Hypervisor is enabled on your computer, which requires that you use Docker \
instead of Docker Toolbox or use docker-machine with the HyperV driver. \
However, as of now this tool can only configure Docker Toolbox installs. \
To continue, either disable Hypervisor or manually install and configure \
Docker. Once you do so, you can run this script again to proceed with \
installation." $RED

            exit 1
        fi
    # If Docker is supported but not enabled:
    elif [ $hyperV -eq $HYPER_V_SUPPORT ]; then
        # Check if docker is already configured:
        if docker images > /dev/null 2>&1; then
            print "Docker Server already works (without HyperV, though this computer supports it)."
            return 0
        fi

        # If not configured, warn the user // ask before continuing:
        print \
"Hypervisor is supported on your computer (in H/W and S/W) but not enabled; \
this allows you to use Docker for Windows (if you enable Hypervisor) instead \
of Docker Toolbox, which results in better performance. However, at this time \
this tool can only configure Docker Toolbox installs. So, if you wish to \
install and configure Docker for Windows manually, please run this script \
again after doing so. If you choose to continue, we will install Docker \
Toolbox on your computer." $RED
        

        print "Do you wish to continue with Docker Toolbox? (enter option #)" $BOLD
        select yn in "Yes" "No"; do
            case $yn in
                Yes )  break;;
                No  )  print "Install Docker for Windows and set up the Docker" $BOLD && \
                       print "Client in Bash on Windows and then run this script" $BOLD && \
                       print "again. " $BOLD -n && \
                       print "Good Luck!" $CYAN && \
                       exit 1;;
            esac
        done
            
    # Finally, if we have no real HyperV support:
    else
        #Check if docker is already configured just in case:
        if docker images > /dev/null 2>&1; then
            print "Docker Server already works! (Without HyperV)" $GREEN
            return 0
        fi
    fi

    # If we're still here, it means that we need to configure/install Docker
    # Toolbox:

    # First Let's Install it:
    windows_InstallDockerToolbox && \
    windows_ConfigureDockerToolbox

}

function windowsDependencies
{
    windowsDependency_DockerClient && \
    windowsDependency_DockerServer 
}

function windowsDocumentsPath
{
    # Get Windows Home Directory, windows style
    WIN_HOME=$(windowsCMD echo %USERPROFILE%)

    # Add our snippet to the path, windows style
    WIN_PROJ="${WIN_HOME}\\Documents\\UAVA"
    
    # Convert to something we can use
    PRJCT_DIR=$(dos2wslPath ${WIN_PROJ[@]})

    # And print
    print "Using ${PRJCT_DIR} as default Windows Path" $BOLD
    print "(can be accessed at ${WIN_PROJ} in Windows)" $BOLD
    #TODO: Make sure ^^^^ works w/o the echo trash
}

function windows
{
    print "Bash on Windows will work just fine!" $CYAN

    windowsDependencies

    exit

    DOCKER="docker.exe"
    print "Using ${DOCKER} for Docker!" $PURPLE

    print "Making some windows specific changes..." $PURPLE



    # Continue with .profile additions:
    PROF_TITLE="# Added automagically for Docker #"

    if grep -q "${PROF_TITLE}" "$HOME/.profile"; then
        print "Changes already present." $PURPLE
        return $?
    fi

    cat << EOF >> "$HOME/.profile"

${PROF_TITLE}
PATH="\$HOME/bin:\$HOME/.local/bin:\$PATH"
PATH="\$PATH:/mnt/c/Program\ Files/Docker/Docker/resources/bin"
export DISPLAY=:0
alias docker="docker.exe"
EOF

}

function macOSDependencies
{
    # Check for brew:
    return 0
}

function macOS
{
    print "Hey there macOS user!" $CYAN
    DEPENDENCIES+=("brew socat xquartz") # << TODO: check for the actual bin name for xquartz
}

function linuxDependencies
{
    # 
    return 0
}

function linux
{
    return 0
}

# # # # # # # # # #

function checkOS
{
    #Creds to SO: http://bit.ly/1pHeRRa
    if [ "$(uname)" == "Darwin" ]; then
        macOS
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        if grep -q Microsoft /proc/version; then
            windows
        else
            print "Another Linux user!" $CYAN
            linux
            # Check if we're in the docker group:
            if ! groups $(whoami) | grep &>/dev/null '\bdocker\b'; then
                print "Warning: You are not in the docker group!"
            fi
        fi
    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
        print "Sorry, Cygwin/MinGW are not supported at this time." $RED
        print "If you're on Windows 10, you can install Bash On Windows to"
        print "continue."
        badEnv 1
    fi

    print "Hang tight, and we'll get you set up." ${CYAN}

    return $?
}

function projectDirectory
{
    mkdir -p "$(echo ${PRJCT_DIR} | xargs)"

    return $?
}

function dockerRun
{
    cd ~ && \
    "${DOCKER}" run -it -d \
        --name "${CNTNR_NAME}" \
        -v "${PRJCT_DIR}":/opt/Projects \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -e DISPLAY=${DISPLAY} \
        "${IMAGE_NAME}" \
        cat && \
    cd -

    return $?
}

function installAliases
{
    if [[ "$aliases" != "true" ]]; then return; fi

    # ALIAS_FILE_LOC=${ALIAS_FILE-"~/.bash_aliases"}
    print "Using ${ALIAS_FILE:="${HOME}/.bash_aliases"} as alias file."

    echo ${CNTNR_NAME}

    if grep -q "# ${CNTNR_NAME} Aliases #" ${ALIAS_FILE}; then
        print "Aliases already installed." $PURPLE
        return $?
    fi

    cat << EOF >> "${ALIAS_FILE}"
# ${CNTNR_NAME} Aliases #
alias uava='cd "${PRJCT_DIR}"'
alias uavai='docker exec -it ${CNTNR_NAME} bash -c "intellij-idea-community"'
alias uavas='docker exec -it ${CNTNR_NAME} bash -c "subl"'
alias uavaD='docker exec -it ${CNTNR_NAME} /bin/zsh'
alias uavaS='docker start ${CNTNR_NAME}'
alias uavaE='docker stop ${CNTNR_NAME} -t 1'

EOF
}

function emergencyExit
{
    stty echo
    print "\nInstall incomplete; Are you sure you wish to exit? (enter option #)" $RED
    
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
    checkOS && \
    checkDependencies && \
    processArguments "$*" && \
    projectDirectory && \
    dockerRun && \
    installAliases && \
    print "You are all set up! Adieu, mon ami!" $CYAN
} || badEnv 1


##########################
# AUTHOR:  Rahul Butani  #
# DATE:    Sept 05, 2017 #
# VERSION: 0.0.0         #
##########################
