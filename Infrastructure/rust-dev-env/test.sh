docker run -it \
    --name uava-dev \
    -v /media/data/Documents/Development/UAV/Two/:/opt/Projects \
    -v /tmp/.X11-unix/X0:/tmp/.X11-unix/X0 \
    -e DISPLAY=${DISPLAY} \
    rust-dev-env \
    /bin/zsh

# docker run -it \
# 	--name uava-dev \
# 	-v /media/data/Documents/Development/UAV/Two/:/opt/Projects \
# 	-v /tmp/.X11-unix/X0:/tmp/.X11-unix/X0 \
# 	-e DISPLAY=${DISPLAY} \
# 	rust-dev-env \
# 	/bin/zsh

# docker run -it -d --name uava-dev-2 \
#     -v ${DISPLAY}:/tmp/.X11-unix/X0
#     uavaustin/rust-dev-env:latest \
#     /bin/zsh