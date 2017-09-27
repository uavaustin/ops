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
# Files Location)
##############################################################################

# All or nothing:
set -e

DOCKER="docker"
DEPENDENCIES=("cat grep expr whoami xargs which docker")

# Configuration Variables #
IMAGE_NAME="uavaustin/rust-dev-env:latest"
CNTNR_NAME="uava-dev"
PRJCT_DIR="${HOME}/Documents/UAVA/"

aliases="true"
output="true"

OS=0
MACOS=1
LINUX=2
WSLIN=3

DISPLAY="${DISPLAY:-:0}"

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
    print "Go to http://bit.ly/2foRMj0 for instructions on how to configure your environment." $BOLD
    print "(and then try again)" $BOLD
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

    return ${exitC}
}

function checkForDockerGroup
{
    runCount=$1

    if [[ $runCount -gt 2 ]]; then
        print "Sorry, something went wrong." $RED
        print "We couldn't add you to the docker group." $RED
        badEnv 1
    elif [[ $runCount -gt 0 ]]; then
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

            if [ ${OS} -eq ${MACOS} ]; then
                sudo dscl . append /Groups/docker GroupMembership $(whoami)
            else
                sudo usermod -aG docker $(whoami)
                if [ ${OS} -eq ${WSLIN} ]; then
                    print "Now reopen Bash and re-run this script." $BOLD
                    exit 1
                fi
                print "Now, run sudo login and then re-run this script." $BOLD
                print "Or just log in again (reccomended)" $BOLD
                exit 1
            fi

            # Now let's see if that actually worked:
            ((runCount++))
            checkForDockerGroup $runCount
            return $?
        fi
    else
        # If there is no docker group, add one:
        # This will not work on macOS and that is probably fine.
        print "Creating a docker group..." $BROWN
        sudo groupadd docker

        ((runCount++))
        checkForDockerGroup $runCount
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

function windowsDependency_Xming
{
    print "Checking for Xming..." $PURPLE

    xmingWinPath=$(dos2wslPath "$(windowsCMD "echo %programfiles(x86)%")\\Xming\\Xming.exe")

    if [ -e "$xmingWinPath" ]; then
        print "Xming is installed!" $GREEN
        return 0
    else
        # Install Xming:
        print "We couldn't find Xming on your computer, so we're"
        print "going to try to install it."

        # First we need a download location that windows can access
        # Let's use the User's Downloads folder:
        WIN_HOME=$(windowsCMD echo %USERPROFILE%)
        dPathWin="${WIN_HOME}\\Downloads\\Xming-6-9-0-31.exe"
        dPath=$(dos2wslPath ${dPathWin})

        # Now download the latest stable xming:
        # (I believe Bash On Windows ships with wget so this should be safe)
        wget -q --show-progress -O "${dPath}" \
            "https://osdn.net/frs/g_redir.php?m=netix&f=%2Fxming%2FXming%2F6.9.0.31%2FXming-6-9-0-31-setup.exe"

        print "In a few seconds, the Xming Installation should begin." $BOLD
        print "Click Yes on the User Account Control Prompt." $BOLD

        sleep 3

        $CMD /C "$dPathWin" /SILENT  | more

        # Check if it really installed, just to be sure:
        windowsDependency_Xming
        return $?
    fi
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

        sudo echo Installing Docker...
        sudo apt -qq update && \
        sudo apt install -y -qq \
            apt-transport-https \
            ca-certificates \
            curl \
            software-properties-common && \
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        # Have to do the var stuff here because Bash on Windows is stupid and returns Ubuntu instead of ubuntu
        # which causes the docker server to 404
        release=$(lsb_release -is)
        release=${release,,} # Bash 4+ feature, fine for WSL
        sudo add-apt-repository -y \
           "deb [arch=amd64] https://download.docker.com/linux/${release} \
           $(lsb_release -cs) \
           stable" && \
        sudo apt update -qq && \
        sudo apt install -y -qq --allow-unauthenticated docker-ce

        return $?
    fi
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

# TODO: Test this function // add proper Docker for Windows support:
function windows_InstallDockerForWindows
{
    # Check if Docker for Windows is already installed:
    docker4WinPath=$(dos2wslPath "$(windowsCMD "echo %programfiles%")\\Docker\\Docker\\Docker for Windows.exe")

    if [ -e "$docker4WinPath" ]; then
        print "Docker For Windows is installed!" $PURPLE
        return 0
    else
        # Install Docker Toolbox:
        print "We couldn't find Docker For Windows on your computer, so we're"
        print "going to try to install it."

        # First we need a download location that windows can access
        # Let's use the User's Downloads folder:
        WIN_HOME=$(windowsCMD echo %USERPROFILE%)
        dPathWin="${WIN_HOME}\\Downloads\\DockerForWindows.exe"
        dPath=$(dos2wslPath ${dPathWin})

        # Now download the latest stable docker toolbox:
        # (I believe Bash On Windows ships with wget so this should be safe)
        wget -q --show-progress -O "${dPath}" \
            "https://download.docker.com/win/stable/Docker%20for%20Windows%20Installer.exe"

        print "In a few seconds, the Docker For Windows Installation should begin." $BOLD
        print "Click Yes on the User Account Control Prompt." $BOLD
        print "Press Install on any driver prompts that appear" $BOLD

        sleep 5

        $CMD /C "$dPathWin" install --quiet | more

        # Check if it really installed, just to be sure:
        windows_InstallDockerForWindows
        return $?
    fi
}

# TODO: Test this disaster!
function windows_ConfigureForDockerForWindows
{
    print "We're going to configure Docker For Windows to work with Bash now." $BROWN
    print "If you're prompted for your password enter it." $BOLD

    # Make links for drives to match Git Bash Paths:
    for d in /mnt/*; do
        s="/$(basename $d)/"
        if [[ ! -e "${s}" ]]; then
            sudo ln -s "${d}" /
        fi
    done

    # Add necessary things to .bashrc
    PROF_TITLE="# Additions for Docker For Windows #"

    if grep -q "${PROF_TITLE}" "$HOME/.bashrc"; then
        print ".bashrc changes already present." $PURPLE
    else
        # TODO: Update with program files var
        cat << EOF >> "$HOME/.bashrc"

${PROF_TITLE}
pushd '/c/Program Files/Docker/Docker/resources/bin/' > /dev/null
# Get env variables from docker-machine, convert paths, ignore comments, and strip double quotes. 
arr=\$(./docker-machine.exe env --shell bash | sed 's/C:/\/c/' | sed 's/\\\\/\//g' | sed 's:#.*$::g' | sed 's/"/\x27/g')
readarray -t y <<<"\$arr"
for ((i=0; i< \${#y[@]}; i++)); do eval "\${y[\$i]}"; done
popd > /dev/null
# Change /mnt/c/ to /c/ in current working directory path
cd \$(pwd | sed 's/\/mnt\/c\//\/c\//')
EOF
    fi

    # Now run the same commands:
    pushd '/c/Program Files/Docker/Docker/resources/bin/' > /dev/null
    # Get env variables from docker-machine, convert paths, ignore comments, and strip double quotes. 
    arr=$(./docker-machine.exe env --shell bash | sed 's/C:/\/c/' | sed 's/\\/\//g' | sed 's:#.*$::g' | sed 's/"/\x27/g')
    readarray -t y <<<"$arr"
    for ((i=0; i< ${#y[@]}; i++)); do eval "${y[$i]}"; done
    popd > /dev/null

    docker images
}

function windows_InstallDockerToolbox
{
    # Check if the Toolbox is already installed:
    dockerToolboxPath=$(dos2wslPath "$(windowsCMD "echo %programfiles%")\\Docker Toolbox\\docker.exe")

    if [ -e "$dockerToolboxPath" ]; then
        print "Docker Toolbox is installed!" $GREEN
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
        windows_InstallDockerToolbox
        return $?
    fi
}

# TODO: This is currently broken and very low priority.
# Need to actually start docker, I think.
function windows_ConfigureForDockerToolbox
{
    print "We're going to configure Docker Toolbox to work with Bash now." $BROWN
    print "If you're prompted for your password enter it." $BOLD

    # Make links for drives to match Git Bash Paths:
    for d in /mnt/*; do
        s="/$(basename $d)/"
        if [[ ! -e "${s}" ]]; then
            sudo ln -s "${d}" /
        fi
    done

    # Add necessary things to .bashrc
    PROF_TITLE="# Additions for Docker Toolbox #"

    if grep -q "${PROF_TITLE}" "$HOME/.bashrc"; then
        print ".bashrc changes already present." $PURPLE
    else
        # TODO: Update with program files var
        cat << EOF >> "$HOME/.bashrc"

${PROF_TITLE}
export VBOX_MSI_INSTALL_PATH='/c/Program Files/Oracle/VirtualBox/'
pushd '/c/Program Files/Docker Toolbox/' > /dev/null
./start.sh exit > /dev/null 2>&1
# Get env variables from docker-machine, convert paths, ignore comments, and strip double quotes.
arr=\$(./docker-machine.exe env --shell bash | sed 's/C:/\/c/' | sed 's/\\\\/\//g' | sed 's:#.*$::g' | sed 's/"/\x27/g')
readarray -t y <<<"\$arr"
for ((i=0; i< \${#y[@]}; i++)); do eval "\${y[\$i]}"; done
popd > /dev/null
# Change /mnt/c/ to /c/ in current working directory path
cd \$(pwd | sed 's/\/mnt\/c\//\/c\//')
EOF
    fi

    # Now run the same commands:
    export VBOX_MSI_INSTALL_PATH='/c/Program Files/Oracle/VirtualBox/'
    pushd '/c/Program Files/Docker Toolbox/' > /dev/null
    ./start.sh exit
    # Get env variables from docker-machine, convert paths, ignore comments, and strip double quotes.
    arr=$(./docker-machine.exe env --shell bash | sed 's/C:/\/c/' | sed 's/\\/\//g' | sed 's:#.*$::g' | sed 's/"/\x27/g')
    readarray -t y <<<"$arr"
    for ((i=0; i< ${#y[@]}; i++)); do eval "${y[$i]}"; done
    popd > /dev/null

    docker images
    return $?
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
(Or you're running Windows in a VM, which isn't supported by this script) \
However, as of now this tool is only tested for Docker Toolbox installs. \
To continue, either disable Hypervisor or manually install and configure \
Docker. Once you do so, you can run this script again to proceed with \
installation. Or, attempt to install Docker For Windows using this script. \
(This is untested!!)" $RED

            print "Do you wish to try to install Docker For Windows (not tested!!)? (enter option #)" $BOLD
            select yn in "Yes" "No"; do
                case $yn in
                    Yes )  windows_InstallDockerForWindows && \
                           windows_ConfigureForDockerForWindows && \
                           return $?;;
                    No  )  print "Install Docker for Windows and set up the Docker" $BOLD && \
                           print "Client in Bash on Windows and then run this script" $BOLD && \
                           print "again. (or disable HyperV) " $BOLD -n && \
                           print "Good Luck!" $CYAN && \
                           exit 1;;
                esac
            done
        fi
    # If Docker is supported but not enabled:
    elif [ $hyperV -eq $HYPER_V_SUPPORT ]; then
        # Check if docker is already configured:
        if docker images > /dev/null 2>&1; then
            print "Docker Server already works (without HyperV, though this computer supports it)." $GREEN
            return 0
        fi

        # If not configured, warn the user // ask before continuing:
        print \
"Hypervisor is supported on your computer (in H/W and S/W) but not enabled; \
this allows you to use Docker for Windows (if you enable Hypervisor) instead \
of Docker Toolbox, which results in better performance. However, at this time \
this tool is only tested on Docker Toolbox installs. So, if you wish to \
install and configure Docker for Windows manually, please run this script \
again after doing so. If you choose to continue, you can install Docker Toolbox \
or try the untested Docker For Windows installation process." $RED


        print "What do you wish to install? (enter option #)" $BOLD
        select yn in "Toolbox" "Docker For Windows" "Nothing"; do
            case $yn in
                Toolbox)  break;;
                "Docker For Windows") windows_InstallDockerForWindows && \
                           windows_ConfigureForDockerForWindows && \
                           return $?;;
                Nothing)  print "Install Docker for Windows and set up the Docker" $BOLD && \
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

    {
        windows_InstallDockerToolbox && \
        windows_ConfigureForDockerToolbox
    } || print "Failed to set up Docker Toolbox." $RED && badEnv 1

    return $?
}

function windowsDependencies
{
    {
        windowsDependency_DockerClient && \
        checkForDockerGroup && \
        windowsDependency_DockerServer && \
        windowsDependency_Xming
    } || print "Failed to install dependencies." $RED && badEnv 1

    return $?
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
}

function windows
{
    print "Bash on Windows will work just fine!" $CYAN

    print "Before we begin, let's make sure you're on the latest version" $BOLD
    print "of Bash on Windows." $BOLD

    if do-release-upgrade --check-dist-upgrade-only -q; then
        print "There's a newer version of Bash on Windows available!" $BOLD
        print "We're going to try to install it. Enter your password if prompted" $RED
        do-release-upgrade || badEnv 1
    else
        print "You're already up to date!" $GREEN
    fi

    windowsDependencies

    print "Making some windows specific changes..." $PURPLE

    windowsDocumentsPath

    DISP="$("/c/Program Files/Docker Toolbox/docker-machine.exe" ip)"
    DISPLAY="$(echo $DISP | awk 'BEGIN {FS="."} {print $1"."$2"."$3"."1}'):0"

    print "Using ${DISPLAY} as \$DISPLAY..." $PURPLE

    # Continue with .bashrc additions:
    PROF_TITLE="# Added automagically for Docker #"

    if grep -q "${PROF_TITLE}" "$HOME/.bashrc"; then
        print "Changes already present." $PURPLE
        return $?
    fi

    cat << EOF >> "$HOME/.bashrc"

${PROF_TITLE}
PATH="\$HOME/bin:\$HOME/.local/bin:\$PATH"
PATH="\$PATH:/c/Program\ Files/Docker\ Toolbox/"
export DISPLAY=:0
alias docker-machine="docker-machine.exe"
EOF
}

function macOSDependencies
{
    # Check for brew:
    if hash brew; then
        print "Homebrew is installed." $GREEN
    else
        print "Homebrew is not installed." $RED
        print "We're going to try to install it now:" $BROWN
        print "(Enter your password when prompted)" $BOLD

        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
        source "$HOME/.profile"
    fi

    # Brew will save us if we try to install something that's already installed, hopefully:
    brew install socat
    brew cask install xquartz

    return 0
}

function macOS
{
    print "Hey there macOS user!" $CYAN

    {
        macOSDependencies && \
        checkForDockerGroup
    } || print "macOS Dependencies failed to install. Please try again." $RED && badEnv 1

    DEPENDENCIES+=("brew socat xquartz")
}

function linuxDependency_Generic
{
    return 0
}

function linuxDependency_Docker
{
    print "Checking for docker..." $PURPLE

    if hash docker 2>/dev/null; then
        print "Docker is already installed!" $GREEN
        return 0
    else
        print "Docker is not installed." $RED

        if ! hash apt; then
            print "Your installation does not use apt. Please install docker manually and try again." $RED
            print "https://docs.docker.com/engine/installation/" $RED
            return 1
        fi

        print "We're going to try to install it with apt now:" $BROWN
        print "(Enter your password when prompted)" $BOLD

        sudo echo Installing Docker...
        sudo apt -qq update && \
        sudo apt-get install -y -qq \
            apt-transport-https \
            ca-certificates \
            curl \
            software-properties-common && \
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository -y \
           "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is)\
           $(lsb_release -cs) \
           stable" && \
        sudo apt-get update -qq && \
        sudo apt-get install -y -qq --allow-unauthenticated docker-ce

        return $?
    fi
}

function linuxDependencies
{
    {
    linuxDependency_Generic && \
    linuxDependency_Docker && \
    checkForDockerGroup && \
    return 0
    } || print "Failed to configure Docker." $RED && badEnv 1
}

function linux
{
    print "Another Linux user!" $CYAN

    linuxDependencies

    return 0
}

# # # # # # # # # #

function checkOS
{
    #Creds to SO: http://bit.ly/1pHeRRa
    if [ "$(uname)" == "Darwin" ]; then
        OS=${MACOS}
        macOS
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        if grep -q Microsoft /proc/version; then
            OS=${WSLIN}
            windows
        else
            OS=${LINUX}
            linux
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
    if [ "$(docker ps -qa -f name=${CNTNR_NAME})" ]; then

        print "Container already exists; do you which to proceed? (enter option #)" $BOLD
        print "(Existing container will be stopped and deleted)" $RED

        select yn in "Yes" "No"; do
            case $yn in
                Yes )  break;;
                No  )  exit 1;;
            esac
        done

        if [ ! "$(docker ps -aq -f status=exited -f name=${CNTNR_NAME})" ]; then
            docker stop "${CNTNR_NAME}" -t 0
        fi

        docker rm "${CNTNR_NAME}"
    fi

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

    if grep -q "# ${CNTNR_NAME} Aliases v0.1.0 #" ${ALIAS_FILE}; then
        print "Aliases already installed." $PURPLE
        return $?
    fi

    cat << EOF >> "${ALIAS_FILE}"
# ${CNTNR_NAME} Aliases v0.1.0 #
alias uava='cd "${PRJCT_DIR}"'
alias uavai='docker exec -it ${CNTNR_NAME} bash -c "intellij-idea-community"'
alias uavas='docker exec -it ${CNTNR_NAME} bash -c "subl"'
alias uavad='docker exec -it ${CNTNR_NAME} bash -c "gnome-terminal"'
alias uavaD='docker exec -it ${CNTNR_NAME} /bin/zsh'
EOF

    if [[ ${OS} -eq ${MACOS} ]]; then
        cat << EOF >> "${ALIAS_FILE}"
function uavaS
{
    socat TCP-LISTEN:6000,reuseaddr,fork UNIX-CLIENT:/tmp/x11_display > /dev/null 2>&1 &
    xquartz > /dev/null 2>&1 &
    docker start ${CNTNR_NAME}
}

function uavaE
{
    docker stop ${CNTNR_NAME} -t 1
    pkill socat > /dev/null 2>&1
    pkill xquartz > /dev/null 2>&1
}

EOF
    elif [[ ${OS} -eq ${WSLIN} ]]; then
         cat << EOF >> "${ALIAS_FILE}"
function uavaS
{
    \$("${CMD}" /C "$(windowsCMD "echo %programfiles(x86)%")\\Xming\\Xming.exe" :0 -clipboard -multiwindow -ac >nul 2>&1) &
    docker start ${CNTNR_NAME}
}
alias uavaE='docker stop ${CNTNR_NAME} -t 1'

EOF
    else
        cat << EOF >> "${ALIAS_FILE}"
alias uavaS='docker start ${CNTNR_NAME}'
alias uavaE='docker stop ${CNTNR_NAME} -t 1'

EOF
    fi

print "Some helpful aliases:" $CYAN
print "    uava  => Switch to project directory" $BOLD
print "    uavaS => Start Container" $BOLD
print "    uavaE => Stop (End) Container" $BOLD
print "    uavaD => Open tty shell" $BOLD
print "    uavai => Start IntelliJ" $BOLD
print "    uavas => Start Sublime Text" $BOLD
print "    uavaD => Open gnome-terminal" $BOLD
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
    checkDependenciesFinal && \
    processArguments "$*" && \
    projectDirectory && \
    dockerRun && \
    installAliases && \
    print "You are all set up! Adieu, mon ami!" $CYAN && \
    print "(Reopen your terminal for best results)" $CYAN
} || badEnv 1


#Notes:
# It's actually possible to automate the WSL installation, but I don't want to do this.
# (https://github.com/xezpeleta/bowinstaller)

##########################
# AUTHOR:  Rahul Butani  #
# DATE:    Sept 26, 2017 #
# VERSION: 0.9.3         #
##########################
