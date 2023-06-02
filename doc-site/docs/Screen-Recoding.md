# Screen Recording Notes


## Pre-reqs for Bare-Metal and Virtual Machines

For screen recording to work we need to ensure that we ensure certain capabilities:

1. Disable Wayland:

    Wayland needs to be disabled because MOST Desktops and Graphical applications/tools have not migrated away from X11/xorg yet.

    - [Example /etc/gdm3/daemon.conf](https://github.com/cloudymax/Scrap-Metal/blob/main/virtual-machines/qemu/configs/gdm3.custom)

2. Enable Auto-Login

    Similar to above. RDP and other applications will only work when a X session is already started and a user already logged in. Enable auto-login to avoid needing to use VNC to init the session.

    - On Debain systems, the file is called [/etc/gdm3/daemon.conf](https://github.com/cloudymax/Scrap-Metal/blob/main/virtual-machines/qemu/configs/gdm3.custom)
    - On ubuntu systems, the file is called [/etc/gdm3/custom.conf](https://github.com/cloudymax/Scrap-Metal/blob/main/virtual-machines/qemu/configs/gdm3.custom)

3. Enable Xorg/X11:

    Aside from disabling Wayland, we need to explicitly enable Xorg/X11 by creating a `/etx/X11/xorg.conf` configuration file. This file tells the X11 system how to find and use various display, input, and graphical devices. Importantly, we can use this file to create virtual displays for headless systems to use as output devices. 
    
    X11 has a HUGE number of options and is nearly infinotely customisable, but also very fragile. Due to the sheer size, scope and age of X11 finding the correct documentation for your hardware, drivers, monitors, operating system etc.. can be very difficult. For that reason I reccommend the following steps for setting it up on your system.
    
    - Install the GPU drivers and dont do anything else. For Bare-Metal systems with an attached physical monitor Debian12 and Ubuntu 22.04+ can often get everythign working on their own after the driver is installed.
    
    - If the above failed to get uour screen working 

    - [Example Xorg.conf](https://github.com/cloudymax/Scrap-Metal/blob/main/virtual-machines/qemu/configs/xorg.conf)

4. Install a VNC Server and VNC/RDP Client:

    For some rescue operations we need a more featured remote-desktop than RDP can provide. For example:
    - If the RPD session application gets full-screened, we will have to use VNC to resize it.
    - If the session goes to sleep, we need VNC to be able to enter a password.
    - You will need VNC in order to set the initial RDP password.
    - Reccommended Packages:
        - [X11vnc]()
        - [TurboVNC]()
        - [TigerVNC]()
        - [Remmenia]()
        - [Microsoft Remote Desktop]()

5. Disable Screen Sleep:

    Similar to above, we don't want the screen sleeping and killing RDP via a password screen.

6. Set up locales:

    Locales need to be setup to prevent errors when trying to find the current active OpenGL application.

    Setup Instructions:

    ```bash
    sudo apt-get install locales-all
    sudo locale-gen en_US
    sudo locale-gen en_US.UTF-8
    sudo update-locale LC_ALL=en_US.UTF-8
    . /etc/default/locale
    ```

## Compile ffmpeg with nvidia nvenc support

```bash
git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
cd nv-codec-headers && sudo make install 
cd..

git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg/

sudo apt-get install -y 
    build-essential \
    yasm \
    cmake \
    libtool \
    libc6 \
    libc6-dev \
    unzip \
    wget \
    libnuma1 \
    libnuma-dev

cd ffmpeg

./configure --enable-nonfree \
    --enable-cuda-nvcc \
    --enable-libnpp \
    --extra-cflags=-I/usr/local/cuda/include \
    --extra-ldflags=-L/usr/local/cuda/lib64 \
    --disable-static \
    --enable-shared

make -j 8

sudo make install
```

Record screen with ffmpeg

For more options see: https://docs.nvidia.com/video-technologies/video-codec-sdk/11.1/ffmpeg-with-nvidia-gpu/index.html

```bash
export DISPLAY=:0
export FRAME_RATE=60
export SHOW_MOUSE=1
export RESOLUTION=1920x1080
export CODEC=h264_nvenc
export OUTPUT_FILE=recording.mp4

ffmpeg -r $FRAME_RATE \
    -f x11grab \
    -draw_mouse $SHOW_MOUSE \
    -s $RESOLUTION \
    -i $DISPLAY \
    -c:v $CODEC \
    -b:v 384k \
    -qmin 0 \
    -qmax 20 \
    $OUTPUT_FILE
```


