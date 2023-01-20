#!/bin/bash

log() {
    echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}

deps(){

    # Install required Apt Packages
    sudo apt-get install -y qemu-kvm \
        bridge-utils \
        virtinst\
        ovmf \
        qemu-utils \
        cloud-image-utils \
        ubuntu-drivers-common \
        whois \
        git \
        git-extras \
        guestfs-tools

        # Cleanup apt
        sudo apt-get autoremove -y

        # Get the latest cigen
        git-force-clone \
        https://github.com/cloudymax/cloud-init-generator \
        cloud-init-generator

        # Get the latest community templates
        git-force-clone \
        https://github.com/cloudymax/cigen-community-templates \
        cigen-community-templates

        # Build the Cigen docker image
        # Todo: publish this image so we dont have to build it
        docker pull deserializeme/cigen:latest
}

# VM metadata
export_metatdata(){
  # Base Image Options
  export CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/daily/latest/debian-12-generic-amd64-daily.qcow2"
  export CLOUD_IMAGE_NAME=$(basename "$CLOUD_IMAGE_URL")
  export CLOUD_INIT_TEMPLATE="/home/$USER/repos/Scrap-Metal/virtual-machines/cigen-community-templates/debian-gnome.yaml"
  export ISO_FILE="/home/${USER}/repos/pxeless/ubuntu-autoinstall.iso"

  # VM Options
  export VM_NAME="test"
  export VM_USER="${VM_NAME}admin"
  export GITHUB_USER="cloudymax"
  export USER="max"
  export DISK_NAME="boot.img"
  export DISK_SIZE="32G"
  export MEMORY="8G"
  export SOCKETS="1"
  export PHYSICAL_CORES="2"
  export THREADS="2"
  export SMP=$(( $SOCKETS * $PHYSICAL_CORES * $THREADS ))
  export VM_KEY=""
  export VM_KEY_FILE="$VM_USER"
  export UUID="none"
  export MAC_ADDR=$(printf 'AC:AB:13:12:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)))
  export PASSWD="password"

  # GPU Options
  export GPU_ACCEL="true"

  # Networking Options
  export STATIC_IP="true"
  export STATIC_IP_ADDRESS="192.168.50.101"
  export DNS_SERVER="192.168.50.50"
  export IP_GATEWAY="192.168.50.1"
  export HOST_ADDRESS="192.168.50.100"
  export HOST_SSH_PORT="22"
  export VM_SSH_PORT="1234"
  export VNC_PORT="0"
  export TAP_DEVICE_NUMBER="0"
  export NETWORK_NUMBER="0"
  export BRIDGE_NAME="br0"

}

# set network options
set_network(){
  log "📞 Setting networking options."

  BRIDGE=$(brctl show |grep -w -c "$BRIDGE_NAME")
  if [ "$BRIDGE" -gt "0" ]; then
      echo "bridge exists"
  else
      echo "no bridge exists. Creating..."
      #sudo ip link add "$BRIDGE_NAME" type bridge
      #sudo ip link set "$BRIDGE_NAME" up
      #sudo ip link set enp4s0 up
      #sudo ip link set enp4s0 master "$BRIDGE_NAME"
      #sudo ip addr flush dev enp4s0
      #sudo ip addr add "$HOST_ADDRESS/24" brd + dev "$BRIDGE_NAME"
      #sudo ip route add default via "$IP_GATEWAY" dev "$BRIDGE_NAME"
  fi

  #sudo ip tuntap add dev tap0 mode tap user root
  #sudo ip link set dev tap0 up
  #sudo ip link set tap0 master br0
  #iptables -F FORWARD
  #iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
  #brctl show
  #sysctl -w net.ipv4.ip_forward=1


  if [[ "$STATIC_IP" == "true" ]]; then
    log " - Static IP selected."
    export DEVICE="-device virtio-net-pci,netdev=network$NETWORK_NUMBER,mac=$MAC_ADDR \\"
    export NETDEV="-netdev tap,id=network$NETWORK_NUMBER,ifname=tap$TAP_DEVICE_NUMBER,script=no,downscript=no \\"
  else
    log " - Port Forwarding selected."
    export DEVICE="-device virtio-net-pci,netdev=network$NETWORK_NUMBER \\"
    export NETDEV="-netdev user,id=network$NETWORK_NUMBER,hostfwd=tcp::"${VM_SSH_PORT}"-:"${HOST_SSH_PORT}" \\"
  fi
}

# set gpu acceleration options
set_gpu(){
  log "j🖥 Set graphics options based on gpu presence."
  if [[ "$GPU_ACCEL" == "false" ]]; then
    export VGA_OPT="-serial stdio -vga virtio -parallel none \\"
    export PCI_GPU="\\"
    log " - GPU not attached"
  else
    export VGA_OPT="-vga virtio -serial stdio -parallel none \\"
    export PCI_GPU="-device vfio-pci,host=02:00.0,multifunction=on,x-vga=on \\"
    log " - GPU attached"
  fi
}

# set VNC options
set_vnc(){
  export KEYBOARD="en-us"
  export VNC_OPTIONS="-vnc $HOST_ADDRESS:$VNC_PORT -k $KEYBOARD"
}

download_cloud_image(){
  log "⬇️ Downloading cloud image..."
    wget -c -O "$CLOUD_IMAGE_NAME" "$CLOUD_IMAGE_URL" -q --show-progress
}

# Create and expanded image
expand_cloud_image(){
  log "📈 Expanding image"

  export CLOUD_IMAGE_FILE_TYPE=$(echo "${CLOUD_IMAGE_NAME#*.}")

  case $CLOUD_IMAGE_FILE_TYPE in
    "img")
      echo "img"
      qemu-img create -b ${CLOUD_IMAGE_NAME} -f qcow2 \
          -F qcow2 disk.qcow2 \
          "$DISK_SIZE" 1> /dev/null
      ;;
    "qcow2")
      echo "qcow2"
      cp ${CLOUD_IMAGE_NAME} disk.qcow2
      qemu-img resize disk.qcow2 "$DISK_SIZE"
      sudo virt-resize --expand /dev/sda1 ${CLOUD_IMAGE_NAME} disk.qcow2
      ;;
    *)
      echo "error"
      exit
  esac

  log " - Done!"
}


# create an ssh keyi
create_ssh_key(){
  log "🔐 Create an SSH key for the VM admin user"

  yes |ssh-keygen -C "$VM_USER" \
    -f "${VM_USER}" \
    -N '' \
    -t rsa 1> /dev/null

  export VM_KEY_FILE=$(find "$(cd ..; pwd)" -name "${VM_USER}")
  export VM_KEY=$(cat "${VM_KEY_FILE}".pub)
  log " - Done."

}

# create a directory to hold the VM assets
create_dir(){
  log "📂 Creating VM directory."
  mkdir -p "$VM_NAME"
  cd "$VM_NAME"
  export UUID=$(uuidgen)
  log " - Done!"
}

# create a disk
create_virtual_disk(){
  log "💾 Creating virtual disk"
  qemu-img create -f qcow2 hdd.img $DISK_SIZE &>/dev/null
  log " - Done!"
}

# Generate an ISO image
generate_seed_iso(){
  log "🌱 Generating seed iso containing user-data"
  cloud-localds seed.img user-data.yaml
  log " - Done!"
}

tmux_to_vm(){
  export_metatdata
  tmux attach-session -t "${VM_NAME}_session"
}

# tail out a remote tmux window
tmux_stream(){
  STAGE=1
  STAGE_DONE=$(tmux capture-pane -t "${VM_NAME}_session" -p |grep -ai -c "${VM_NAME} Login:" )
  while [[ "$STAGE" != "1" ]]; do
      STAGE_DONE=$(tmux capture-pane -t "${VM_NAME}_session" -p |grep -ai -c "${VM_NAME} Login:" )
      printf '\r%s' "  " "$(tmux capture-pane -t "${VM_NAME}_session" -p |tail -2 |head -1)"
      if [[ $STAGE_DONE == "1" ]]; then
        let "++$STAGE"
      fi
  done
  printf "\n"
  log " - Done!"
  tmux_to_vm
}

ssh_to_vm(){
  export_metatdata
  set_network
    # clear known_hosts and connect to the ip
    if [[ "$STATIC_IP" == "true" ]]; then
      if [ -f "/home/${USER}/.ssh/known_hosts" ]; then
        ssh-keygen -f "/home/${USER}/.ssh/known_hosts" -R "${STATIC_IP_ADDRESS}"
      fi

      ssh -o "StrictHostKeyChecking no" \
        -X \
        -i "$VM_NAME"/"$VM_USER" \
        "$VM_USER"@"$STATIC_IP_ADDRESS"

    else
      # clear known_hosts and connect to the port on the host
      if [ -f "/home/${USER}/.ssh/known_hosts" ]; then
        ssh-keygen -f "/home/${USER}/.ssh/known_hosts" -R "[${HOST_ADDRESS}]:${VM_SSH_PORT}"
      fi

      ssh -o "StrictHostKeyChecking no" \
        -X \
        -i "$VM_NAME"/"$VM_USER" \
        -p"${VM_SSH_PORT}" "${VM_USER}"@"${HOST_ADDRESS}"
    fi
}

vnc_tunnel(){
  export_metatdata
  ssh -o "StrictHostKeyChecking no" \
    -N -L 5001:"$HOST_ADDRESS":5900 \
    -i "/home/max/repos/Scrap-Metal/virtual-machines/$VM_NAME/$VM_USER" \
    -p "$VM_SSH_PORT" "$VM_USER"@"$HOST_ADDRESS"
}

# luanch the VM to install from ISO to Disk
create_vm_from_iso(){
  log "💿 Creating VM from iso file"
  tmux new-session -d -s "${VM_NAME}_session"
  tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64 \
    -machine accel=kvm,type=q35 \
    -cpu host,kvm="off",hv_vendor_id="null" \
    -smp $SMP,sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS",maxcpus=$SMP \
    -m "$MEMORY" \
    -cdrom $ISO_FILE \
    -object iothread,id=io1 \
    -device virtio-blk-pci,drive=disk0,iothread=io1 \
    -drive if=none,id=disk0,cache=none,format=qcow2,aio=threads,file=hdd.img \
    $NETDEV
    $DEVICE
    $VGA_OPT
    $PCI_GPU
    -bios /usr/share/ovmf/OVMF.fd \
    -usbdevice tablet \
    -vnc $HOST_ADDRESS:$VNC_PORT \
    $@" ENTER
    tmux_stream
}

boot_vm_from_iso(){
  log "🥾 Booting VM"
  tmux new-session -d -s "${VM_NAME}_session"
  tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64 \
    -machine accel=kvm,type=q35 \
    -cpu host,kvm="off",hv_vendor_id="null" \
    -smp $SMP,sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS",maxcpus=$SMP \
    -m "$MEMORY" \
    -object iothread,id=io1 \
    -device virtio-blk-pci,drive=disk0,iothread=io1 \
    -drive if=none,id=disk0,cache=none,format=qcow2,aio=threads,file=hdd.img \
    -device intel-hda \
    -device hda-duplex \
    $PCI_GPU
    $VGA_OPT
    $NETDEV
    $DEVICE
    -bios /usr/share/ovmf/OVMF.fd \
    -usbdevice tablet \
    -vnc $HOST_ADDRESS:$VNC_PORT \
    $@" ENTER
    tmux_stream
}

# start the cloud-init backed VM
create_ubuntu_cloud_vm(){
  log "🌥 Creating cloud-image based VM"
  if tmux has-session -t "${VM_NAME}_session" 2>/dev/null; then
    echo "session exists"
  else
    tmux new-session -d -s "${VM_NAME}_session"
    tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64  \
      -machine accel=kvm,type=q35 \
      -cpu host,kvm="off",hv_vendor_id="null" \
      -smp $SMP,sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS",maxcpus=$SMP \
      -m "$MEMORY" \
      $VGA_OPT
      $PCI_GPU
      $NETDEV
      $DEVICE
      -drive if=virtio,format=qcow2,file=disk.qcow2,index=1,media=disk \
      -drive if=virtio,format=raw,file=seed.img,index=0,media=disk  \
      -bios /usr/share/ovmf/OVMF.fd \
      -usbdevice tablet \
      -vnc $HOST_ADDRESS:$VNC_PORT \
      $@" ENTER
      tmux_stream
  fi
}

boot_ubuntu_cloud_vm(){
  log "🥾 Booting VM"
  if tmux has-session -t "${VM_NAME}_session" 2>/dev/null; then
    echo "session exists"
  else
    tmux new-session -d -s "${VM_NAME}_session"
    tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64  \
      -machine accel=kvm,type=q35 \
      -cpu host,kvm="off",hv_vendor_id=null  \
      -smp $SMP,sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS",maxcpus=$SMP \
      -m "$MEMORY" \
      $VGA_OPT
      $PCI_GPU
      $NETDEV
      $DEVICE
      -drive if=virtio,format=qcow2,file=disk.qcow2 \
      -bios /usr/share/ovmf/OVMF.fd \
      -usbdevice tablet \
      -vnc $HOST_ADDRESS:$VNC_PORT \
      $@" ENTER
      tmux_stream
  fi
}

# create a windows vm
create_windows_vm(){
  log "📎 Looks like you're creating a Windows VM"
  tmux new-session -d -s "${VM_NAME}_session"
  tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64 \
    -machine accel=kvm,type=q35 \
    -cpu host,kvm="off",hv_vendor_id="null" \
    -smp $SMP,sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS",maxcpus=$SMP \
    -m "$MEMORY" \
    -drive id=disk0,if=virtio,cache=none,format=qcow2,file=/home/max/pxeless/virtual-machines/${VM_NAME}/$DISK_NAME \
    -drive file=/home/max/pxeless/virtual-machines/images/Windows.iso,index=1,media=cdrom \
    -drive file=/home/max/pxeless/virtual-machines/images/virtio-win-0.1.215.iso,index=2,media=cdrom \
    -boot menu=on \
    -serial none \
    -parallel none \
    -bios /usr/share/ovmf/OVMF.fd \
    -usbdevice tablet \
    $NETDEV
    $DEVICE
    -vnc $HOST_ADDRESS:$VNC_PORT \
    $@" ENTER
}

boot_windows_vm(){
  log "🥾 Booting VM"
  tmux new-session -d -s "${VM_NAME}_session"
  tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64 \
    -machine accel=kvm,type=q35 \
    -cpu host,kvm="off",hv_vendor_id="null" \
    -smp $SMP,sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS",maxcpus=$SMP \
    -m "$MEMORY" \
    -hda /home/max/pxeless/virtual-machines/${VM_NAME}/$DISK_NAME \
    -drive file=/home/max/pxeless/virtual-machines/images/Windows.iso,index=1,media=cdrom \
    -drive file=/home/max/pxeless/virtual-machines/images/virtio-win-0.1.215.iso,index=2,media=cdrom \
    -boot c \
    -serial stdio \
    -parallel none \
    $PCI_GPU
    -bios /usr/share/ovmf/OVMF.fd \
    $NETDEV
    $DEVICE
    -vnc $HOST_ADDRESS:$VNC_PORT \
    $@" ENTER
}

create_user_data(){
  log "👤 Generating user data"
  cd ..
  docker run -it -v "${CLOUD_INIT_TEMPLATE}":/cloud-init-template.yaml \
    -v $(pwd)/$VM_NAME:/output \
    deserializeme/cigen:latest ./cigen.sh --update --upgrade \
    --password "${PASSWD}" \
    --github-username "${GITHUB_USER}" \
    --username "${USER}" \
    --vm-name "${VM_NAME}" \
    --template "/cloud-init-template.yaml" \
    --extra-vars "VM_KEY=$VM_KEY,IP_ADDRESS=$STATIC_IP_ADDRESS,GATEWAY_IP=$IP_GATEWAY,DNS_SERVER_IP=$DNS_SERVER"
  cd $VM_NAME

}

create-windows-vm(){
  export_metatdata
  set_network
  select_image
  set_gpu
  set_vnc
  create_dir
  create_virtual_disk
  create_windows_vm
  tmux_to_vm
}

boot-windows-vm(){
  export_metatdata
  set_network
  select_image
  set_gpu
  set_vnc
  create_dir
  boot_windows_vm
  tmux_to_vm
}

create-cloud-vm(){
  export_metatdata
  set_network
  set_gpu
  set_vnc
  create_dir
  create_ssh_key
  download_cloud_image
  expand_cloud_image
  create_user_data
  generate_seed_iso
  #create_virtual_disk
  create_ubuntu_cloud_vm
}

create-from-iso(){
  ISO_FILE=$1
  export_metatdata
  set_network
  set_gpu
  set_vnc
  create_dir
  create_user_data
  generate_seed_iso
  create_virtual_disk
  create_vm_from_iso
}

boot-cloud-vm(){
  export_metatdata
  set_network
  set_gpu
  set_vnc
  create_dir
  boot_ubuntu_cloud_vm
  tmux_to_vm
}

boot-iso-vm(){
  export_metatdata
  set_network
  set_gpu
  set_vnc
  create_dir
  boot_vm_from_iso
  tmux_to_vm
}

"$@"
