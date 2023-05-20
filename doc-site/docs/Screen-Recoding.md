# Screen Recording Notes


## Pre-reqs

For screen recording to work we need to ensure that we ensure certain capabilities:

1. Disable Wayland:

    Wayland needs to be disabled because MOST Desktops and Graphical applications/tools have not migrated away from X11/xorg yet.

    - [Example /etc/gdm3/daemon.conf](https://github.com/cloudymax/Scrap-Metal/blob/main/virtual-machines/qemu/configs/gdm3.custom)

2. Enable Auto-Login

    Similar to above. RDP will only work when a X session is already started and a user already logged in. Enable auto-login to avoid needing to use VNC to init the session.

    - Also handled by [/etc/gdm3/daemon.conf](https://github.com/cloudymax/Scrap-Metal/blob/main/virtual-machines/qemu/configs/gdm3.custom)

3. Enable Xorg/X11:

    Aside form disabling Wayland, we need to enable Xorg/X11 bu creating `/etx/X11/xorg.conf` and specifying the GPU BusID, a screen, and a monitor.

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

## CPU

```bash
./ffmpeg -r 30 \
-f x11grab \
-draw_mouse 0 \
-s 1280x800 \
-i :99 \
-c:v libvpx \
-quality realtime \
-cpu-used 0 \
-b:v 384k \
-qmin 10 \
-qmax 42 \
-maxrate 384k \
-bufsize 1000k \
-an screen.webm
```

## GPU

https://git.dec05eba.com/gpu-screen-recorder/about/
git clone https://repo.dec05eba.com/gpu-screen-recorder

```bash
sudo apt-get install -y libglvnd-dev \
    ffmpeg \
    libx11-dev \
    libxcomposite-dev \
    libxrandr-dev \
    libxfixes-dev \
    libpulse-dev \
    libnvidia-compute-525 \
    libnvidia-encode-525 \
    libva-dev \
    libdrm-dev \
    libcap-dev \
    libavformat-dev \
    libavfilter-dev \
git clone https://repo.dec05eba.com/gpu-screen-recorder
cd gpu-screen-recorder
sudo ./install.sh
```

```bash
#!/bin/bash
APP_NAME="OpenGl"
FRAME_RATE="60"
FILE_FORMAT="mp4"
SCREEN_SIZE="1920x1080"
AUDIO_DEVICE=""
QUALITY="ultra"
CODEC="auto"
OUTPUT_FILE="my-video"

# Gets the ID of a X-App and converts it from
# hexadecimal to decimal form.
HEX_ID=$(xwininfo -root -tree \
|grep -ai $APP_NAME \
|awk '{print $1}')
WINDOW_ID=$(printf %i "$HEX_ID")

# Starts the screen recording using the -w flag to
# record a window.
# SCREEN_SIZE is not used when -w is specified.
gpu-screen-recorder -w $WINDOW_ID \
-c $FILE_FORMAT \
-f $FRAME_RATE \
-a "$(pactl get-default-sink).monitor" \
-q $QUALITY \
-k $CODEC \
-o "$OUTPUT_FILE.$FILE_FORMAT"
# -s "$SCREEN_SIZE" \
```
