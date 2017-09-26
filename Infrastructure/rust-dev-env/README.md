# The Rust Development Environment for UAV Austin (2017-2018) (in a [Docker Container!](https://hub.docker.com/r/uavaustin/rust-dev-env/))

#### Currently at Version 0.0.0
Contains:
* Rust 1.20.0
* IntelliJ 2017.2.3-1
* Sublime Text 3 Build 3126
* cargo, racer, rustfmt, rust-src, etc.
* Rust IntelliJ Plugin 0.1.0.2066
* Misc. Sublime Text Rust Plugins
* And other goodies

On Windows, install WSL/Bash on Windows before running the install script. Requires Windows 1703 (Spring Creators Update) or newer. If you're really lazy, run [this](https://github.com/xezpeleta/bowinstaller/releases/download/v0.1.1/bowinstaller.exe) to install Bash on Windows for you.

On Linux, ensure you have a supported distribution. We're using Docker CE Stable [which currently supports](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/) Ubuntu Trusty (14.04 LTS), Xenial (16.04 LTS), and Zesty (17.04).

Other Linux Distros are supported as well ([check the compatability pages under Docker CE](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/)), however our script will only install Docker for you on systems that use apt (Debian/Ubuntu-based systems). If you're using something that isn't apt-based (Fedora/Arch/openSUSE/etc.) or isn't supported by the Docker CE Stable Release, you're on your own. Make sure you install docker and can run `docker run hello-world` without sudo before you run our script again.

On macOS, you'll have to install Docker yourself. This script has been tested with Docker Toolbox/Kitematic but it _should_ work with Docker for Mac too. [Docker for Mac](https://download.docker.com/mac/stable/Docker.dmg) will perform better and if you're running macOS Yosemite or newer (10.10+) try installing that first. If you're running an older version of macOS install (Docker Toolbox/Kitematic)[https://download.docker.com/mac/stable/DockerToolbox.pkg].

`curl https://raw.githubusercontent.com/uavaustin/ops/0.1.0/Infrastructure/rust-dev-env/install-uav-rust-dev-env.sh -o install-env.sh && chmod +x install-env.sh && ./install-env.sh`

N.B: curl is no longer installed by deafault on Ubuntu 17.10. Either install curl or use wget.
