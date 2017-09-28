###############################################################################
# Dockerfile to create the Rust Dev Environment to be used by UAV Austin for  
# the 2017-2018 school year. Visit docs.uavaustin.org/ops for more information.
###############################################################################

FROM ubuntu:16.04

LABEL maintainer="r.R..B.utAn.i+uavaustin@gmail.com"

# Input Arguments: (Username + Friendly Username)
ARG NEWUSER=padawan
ARG NEWUSERF=Padawan

ARG SUBLIME_BUILD="3143"
ARG INTELLIJ_MAJOR="2017.2"
ARG INTELLIJ_MINOR="5-1"

ARG VERSION="0.9.7"

ARG PRJCT_DIR="/opt/Projects"

# Env:
ENV LANG C.UTF-8
ENV RUST_VERSION=1.20.0
ENV INTELLIJ_BUILD="${INTELLIJ_MAJOR}.${INTELLIJ_MINOR}"

ENV USER="${NEWUSER}"
ENV CNTR_VER="${VERSION}"

LABEL   uava.version="${VERSION}" \
        uava.subteam="integration" \
        uava.rust-dev.rustc="${RUST_VERSION}" \
        username="${NEWUSER}"

# Install dependencies:
RUN apt-get update -qq && \
    echo 'Installing dependencies' && \
    # Not 100% sure DEBCONF_NONINTERACTIVE is needed...
    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    apt-get install -qq -y --fix-missing \
        build-essential ca-certificates curl git \
        pkg-config libssl-dev openssh-client \
        sudo software-properties-common unzip wget \
        emacs nano zsh \
        apt-utils apt-transport-https \
        fortune sl cowsay figlet \
        x11-apps man \
        thefuck python-pkg-resources \
        telnet ssh && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
        apt-get upgrade -qq -y && \
    # Sublime:
    wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add - && \
    echo "deb https://download.sublimetext.com/ apt/stable/" > /etc/apt/sources.list.d/sublime-text.list && \
    # Intellij:
    apt-add-repository -y ppa:mmk2410/intellij-idea && \
    # Aaand Install:
    apt-get update -qq && \
    echo 'Installing Sublime & IntelliJ' && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    apt-get install -qq -y --fix-missing \
        sublime-text=${SUBLIME_BUILD} \
        intellij-idea-community=${INTELLIJ_BUILD} && \
    echo 'Cleaning up dependencies' && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    apt-get clean -y && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    apt-get autoremove -y && \
    rm -rf \
        /var/tmp/* \
        /var/lib/apt/lists/*

# Make new user:
RUN echo "Creating user: ${NEWUSER}" && \
    mkdir -p /home/"${NEWUSER}" && \
    echo "${NEWUSER}:x:1000:1000:${NEWUSERF},,,:/home/${NEWUSER}:/bin/bash" >> /etc/passwd && \
    echo "${NEWUSER}:x:1000:" >> /etc/group && \
    sudo echo "${NEWUSER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/"${NEWUSER}" && \
    sudo chmod 0440 /etc/sudoers.d/"${NEWUSER}" && \
    sudo chown "${NEWUSER}":"${NEWUSER}" -R /home/"${NEWUSER}" && \
    sudo chown root:root /usr/bin/sudo && \
    chmod 4755 /usr/bin/sudo

# Switch to new user:
USER "${NEWUSER}"
WORKDIR /home/"${NEWUSER}"/

# Install Rust:
RUN curl -sO https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init && \
    chmod +x rustup-init && \
    ./rustup-init -y --default-toolchain $RUST_VERSION

# Install oh-my-zsh
RUN wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O install.sh && \
    sed -i '/TEST_CURRENT_SHELL=/c\#Removed' install.sh && \
    echo 'TEST_CURRENT_SHELL="zsh"' | cat - install.sh > install-patched.sh && \
    sudo chmod +x install-patched.sh && \
    ./install-patched.sh && \
    rm install*.sh

# Add rustup completions:
RUN mkdir -p ~/.oh-my-zsh/plugins/rustup && \
    cat ~/.cargo/env >> ~/.zshrc && \
    PATH="$HOME/.cargo/bin:$PATH" rustup completions zsh > ~/.oh-my-zsh/plugins/rustup/_rustup && \
    sed -i '/plugins=(git)/a plugins+=(rust rustup command-not-found chucknorris dirhistory docker lol)' ~/.zshrc

# Install Rust Tools:
RUN PATH="$HOME/.cargo/bin:$PATH" cargo install rustfmt && \
    PATH="$HOME/.cargo/bin:$PATH" cargo install racer && \
    PATH="$HOME/.cargo/bin:$PATH" rustup component add rust-src

# Configure Sublime:
RUN bash -c "mkdir -p ~/.config/sublime-text-3/{Installed\ Packages,Packages/User}" && \
    wget https://packagecontrol.io/Package%20Control.sublime-package -O \
        "/home/${NEWUSER}/.config/sublime-text-3/Installed Packages/Package Control.sublime-package"

COPY "sublime-settings" "/home/${NEWUSER}/.config/sublime-text-3/Packages/User"
COPY subs .

RUN  sudo chmod +x subs && bash subs ${NEWUSER} ${RUST_VERSION}
# TODO: Add proper config files for racer/ycmd, etc.

# Configure IntelliJ:
RUN bash -c "mkdir -p /home/${NEWUSER}/.IdeaIC${INTELLIJ_MAJOR}/config/{options,plugins}" && \
    wget 'https://plugins.jetbrains.com/plugin/download?updateId=38203' -O \
        /home/${NEWUSER}/.IdeaIC${INTELLIJ_MAJOR}/config/plugins/rust.zip -q && \
    cd /home/${NEWUSER}/.IdeaIC${INTELLIJ_MAJOR}/config/plugins/ && \
    unzip -q rust.zip && \
    rm rust.zip && cd -

# Make friendly:
RUN echo "# UAVA Aliases #" >> "/home/${NEWUSER}/.aliases" && \
    echo "alias uava='cd ${PRJCT_DIR}'" >> "/home/${NEWUSER}/.aliases" && \
    echo "alias uavai='intellij-idea-community'" >> "/home/${NEWUSER}/.aliases" && \
    echo "alias uavas='subl'" >> "/home/${NEWUSER}/.aliases" && \
    echo "alias starwars='telnet towel.blinkenlights.nl'" >> "/home/${NEWUSER}/.aliases" && \
    echo "alias moo='apt moo'" >> "/home/${NEWUSER}/.aliases" && \
    echo "alias \?='fortune | cowsay -f stegosaurus'" >> "/home/${NEWUSER}/.aliases" && \
    echo "" >> "/home/${NEWUSER}/.aliases" && \
    # And now:
    thefuck -a rip >> "/home/${NEWUSER}/.aliases" && \
    # And our friendly guide:
    echo "figlet UAV Austin" >> "/home/${NEWUSER}/.aliases" && \
    echo "" >> "/home/${NEWUSER}/.aliases" && \
    echo "cat << EOF" >> "/home/${NEWUSER}/.aliases" && \
    echo "        ----|------------|-----------|----" >> "/home/${NEWUSER}/.aliases" && \
    echo "            |        --/ - \\--       |" >> "/home/${NEWUSER}/.aliases" && \
    echo "           -|---------   o   --------|-" >> "/home/${NEWUSER}/.aliases" && \
    echo "                      /\\ _ /\\ " >> "/home/${NEWUSER}/.aliases" && \
    echo "                   []/       \\[]" >> "/home/${NEWUSER}/.aliases" && \
    echo "" >> "/home/${NEWUSER}/.aliases" && \
    echo "    UAV Austin Development Environment v${CNTR_VER}" >> "/home/${NEWUSER}/.aliases" && \
    echo "----------------------------------------------------" >> "/home/${NEWUSER}/.aliases" && \
    echo " uava     :: Jumps to Project Directory" >> "/home/${NEWUSER}/.aliases" && \
    echo " uavai    :: Starts IntelliJ" >> "/home/${NEWUSER}/.aliases" && \
    echo " uavas    :: Starts Sublime Text 3 (subl works too)" >> "/home/${NEWUSER}/.aliases" && \
    echo "" >> "/home/${NEWUSER}/.aliases" && \
    echo " fortune  :: A source of great wisdom" >> "/home/${NEWUSER}/.aliases" && \
    echo " cowsay   :: Your best friend" >> "/home/${NEWUSER}/.aliases" && \
    echo " cowthink :: A pensive friend" >> "/home/${NEWUSER}/.aliases" && \
    echo " sl       :: Learn to type" >> "/home/${NEWUSER}/.aliases" && \
    echo " starwars :: Excellent way to waste time" >> "/home/${NEWUSER}/.aliases" && \
    echo " moo      :: Moooooo" >> "/home/${NEWUSER}/.aliases" && \
    echo " ?        :: ?" >> "/home/${NEWUSER}/.aliases" && \
    echo "" >> "/home/${NEWUSER}/.aliases" && \
    echo " rip      :: Magic" >> "/home/${NEWUSER}/.aliases" && \
    echo "" >> "/home/${NEWUSER}/.aliases" && \
    echo "EOF" >> "/home/${NEWUSER}/.aliases" && \
    # Finally, actually source the file in .zshrc
    echo "source \${HOME}/.aliases" >> "/home/${NEWUSER}/.zshrc"


# Final clean up:
RUN rm -rf \
    rustup-init \
    subs \
    /var/lib/apt/lists/* \
    /var/tmp/*

WORKDIR "${PRJCT_DIR}"

CMD ["cat"]
