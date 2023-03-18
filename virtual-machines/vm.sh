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
        tmux \
        whois \
        git \
        jq \
        git-extras \
        guestfs-tools \
        bridge-utils

    # yq
    VERSION="v4.31.1"
    BINARY="yq_linux_amd64"
    wget -O  $BINARY.tar.gz https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz
    tar -xvf $BINARY.tar.gz
    sudo mv $BINARY /usr/bin/yq
    rm yq*

    # Cleanup apt
    sudo apt-get autoremove -y

    docker pull deserializeme/cigen:latest
}

read_config(){
  # VM OPTIONS
  export VM_NAME="${1}"
  export VM_USER=$(cat ${VM_NAME}/config.yaml | yq '.VM.VM_USER')
  export GITHUB_USER=$(cat ${VM_NAME}/config.yaml | yq '.VM.GITHUB_USER')
  export USER=$(cat ${VM_NAME}/config.yaml | yq '.VM.USER')
  export DISK_NAME=$(cat ${VM_NAME}/config.yaml | yq '.VM.DISK_NAME')
  export DISK_SIZE=$(cat ${VM_NAME}/config.yaml | yq '.VM.DISK_SIZE')
  export MEMORY=$(cat ${VM_NAME}/config.yaml | yq '.VM.MEMORY')
  export SOCKETS=$(cat ${VM_NAME}/config.yaml | yq '.VM.SOCKETS')
  export PHYSICAL_CORES=$(cat ${VM_NAME}/config.yaml | yq '.VM.PHYSICAL_CORES')
  export THREADS=$(cat ${VM_NAME}/config.yaml | yq '.VM.THREADS')
  export SMP=$(( $SOCKETS * $PHYSICAL_CORES * $THREADS ))
  export VM_KEY=""
  export VM_KEY_FILE=$(cat ${VM_NAME}/config.yaml | yq '.VM.VM_KEY_FILE')
  export MAC_ADDR=$(cat ${VM_NAME}/config.yaml | yq '.VM.MAC_ADDR')
  export PASSWD=$(cat ${VM_NAME}/config.yaml | yq '.VM.PASSWD')

  # GPU Options
  export GPU_ACCEL=$(cat ${VM_NAME}/config.yaml | yq '.GPU.GPU_ACCEL')
  export GPU_VENDOR=$(cat ${VM_NAME}/config.yaml | yq '.GPU.GPU_VENDOR')
  export GPU_PCI_ID=$(lspci |grep VGA |grep -ai $GPU_VENDOR |awk '{print $1}')

  # IMAGE OPTIONS
  export CLOUD_IMAGE_URL=$(cat ${VM_NAME}/config.yaml | yq '.IMAGE.CLOUD_IMAGE_URL')
  export CLOUD_IMAGE_NAME=$(basename "$CLOUD_IMAGE_URL")
  export CLOUD_INIT_TEMPLATE=$(cat ${VM_NAME}/config.yaml | yq '.IMAGE.CLOUD_INIT_TEMPLATE')
  export ISO_FILE=$(cat ${VM_NAME}/config.yaml | yq '.IMAGE.ISO_FILE')

  # Host Networking options
  export HOST_ADDRESS=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.HOST.HOST_ADDRESS')
  export DNS_SERVER=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.HOST.DNS_SERVER')
  export IP_GATEWAY=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.HOST.IP_GATEWAY')
  export HOST_SSH_PORT=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.HOST.HOST_SSH_PORT')
  export HOST_INTERFACE=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.HOST.HOST_INTERFACE')
  export BRIDGE_NAME=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.HOST.BRIDGE_NAME')

  # Guest Networking Options
  export STATIC_IP=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.GUEST.STATIC_IP')
  export STATIC_IP_ADDRESS=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.GUEST.STATIC_IP_ADDRESS')
  export VM_SSH_PORT=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.GUEST.VM_SSH_PORT')
  export VNC_PORT=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.GUEST.VNC_PORT')
  export TAP_DEVICE_NUMBER=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.GUEST.TAP_DEVICE_NUMBER')
  export NETWORK_NUMBER=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.GUEST.NETWORK_NUMBER')
  export INTERFACE=$(cat ${VM_NAME}/config.yaml | yq '.NETWORK.GUEST.INTERFACE')
}

write_config(){
    export_metatdata
    cp config.yaml "${VM_NAME}"/config.yaml
    yq e -i '(.. | select(tag == "!!str")) |= envsubst' "$(pwd)/${VM_NAME}/config.yaml"
    yq "$(pwd)/${VM_NAME}/config.yaml"
}

# set network options
set_network(){
  log "📞 Setting networking options."

  if [[ "$STATIC_IP" == "true" ]]; then
    log " - Static IP selected."

    BRIDGE_EXISTS=$(sudo brctl show |grep -w -c "$BRIDGE_NAME")
    if [ "$BRIDGE_EXISTS" -gt "0" ]; then
        echo "bridge exists"
    else
        echo "Bridge $BRIDGE_NAME not found. Creating..."
        sudo ip link add "$BRIDGE_NAME" type bridge
        sudo ip link set "$BRIDGE_NAME" up
        sudo ip link set "$HOST_INTERFACE" up
        sudo ip link set "$HOST_INTERFACE" master "$BRIDGE_NAME"
        sudo ip addr flush dev "$HOST_INTERFACE"
        sudo ip addr add "$HOST_ADDRESS/24" brd + dev "$BRIDGE_NAME"
        sudo ip route add default via "$IP_GATEWAY" dev "$BRIDGE_NAME"
    fi

    TAP_EXISTS=$(sudo brctl show |grep -c "tap$TAP_DEVICE_NUMBER")
    if [ "$TAP_EXISTS" -gt "0" ]; then
        echo "tap$TAP_DEVICE_NUMBER exists."
    else
        sudo ip tuntap add dev "tap$TAP_DEVICE_NUMBER" mode tap user root
        sudo ip link set dev "tap$TAP_DEVICE_NUMBER" up
        sudo ip link set "tap$TAP_DEVICE_NUMBER" master "$BRIDGE_NAME"
        sudo iptables -F FORWARD
        sudo iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
        sudo brctl show
        sudo sysctl -w net.ipv4.ip_forward=1
    fi

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
    export PCI_GPU="-device vfio-pci,host=$GPU_PCI_ID,multifunction=on,x-vga=on \\"
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
      qemu-img create -b ${CLOUD_IMAGE_NAME} -f qcow2 \
          -F qcow2 disk.qcow2 \
          "$DISK_SIZE" 1> /dev/null
      #cp ${CLOUD_IMAGE_NAME} disk.qcow2
      #qemu-img resize disk.qcow2 "$DISK_SIZE"
      #sudo virt-resize --expand /dev/sda1 ${CLOUD_IMAGE_NAME} disk.qcow2
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
  tmux attach-session -t "${1}_session"
}

ssh_to_vm(){
  read_config "${1}"
  set_network
    # clear known_hosts and connect to the ip
    if [[ "$STATIC_IP" == "true" ]]; then
      if [ -f "/home/${USER}/.ssh/known_hosts" ]; then
        ssh-keygen -f "/home/${USER}/.ssh/known_hosts" -R "${STATIC_IP_ADDRESS}"
      fi

      ssh -o "StrictHostKeyChecking no" \
        -X \
        -i "$VM_NAME"/"$VM_USER" \
        "${VM_NAME}admin"@"$STATIC_IP_ADDRESS" "${2}"

    else
      # clear known_hosts and connect to the port on the host
      if [ -f "/home/${USER}/.ssh/known_hosts" ]; then
        ssh-keygen -f "/home/${USER}/.ssh/known_hosts" -R "[${HOST_ADDRESS}]:${VM_SSH_PORT}"
      fi

      ssh -o "StrictHostKeyChecking no" \
        -X \
        -i "$VM_NAME"/"$VM_USER" \
        -p"${VM_SSH_PORT}" "${VM_NAME}admin"@"${HOST_ADDRESS}" "${2}"
    fi
}

watch_progress(){
  READY=0
  log "Watching progress: "

  while [ "${READY}" == "0" ]
  do
      SCREEN=$(tmux capture-pane -t "${VM_NAME}_session" -p)
      READY_CHECK=$(echo "$SCREEN" |grep "Cloud-init" |grep -c "finished")
      TEXT=$(echo "$SCREEN" |tail -1)

      if [[ "$READY_CHECK" == "1" ]]; then
        READY=1
      else
        echo -ne "$TEXT \r"
      fi
  done
  log " - Cloud-init complete."
}

vnc_tunnel(){
  read_config "${1}"
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
    watch_progress
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
    watch_progress
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
      watch_progress
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
      watch_progress
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
    -drive id=disk0,if=virtio,cache=none,format=qcow2,file=hdd.img \
    -drive file=Win10_22H2_EnglishInternational_x64.iso,index=1,media=cdrom \
    -drive file=virtio-win-0.1.215.iso,index=2,media=cdrom \
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
    -drive id=disk0,if=virtio,cache=none,format=qcow2,file=hdd.img \
    -drive id=disk1,if=virtio,cache=none,format=qcow2,file=hdd2.img \
    -drive file=Win10_22H2_EnglishInternational_x64.iso,index=1,media=cdrom \
    -drive file=virtio-win-0.1.215.iso,index=2,media=cdrom \
    -boot menu=on \
    -serial none \
    -parallel none \
    -bios /usr/share/ovmf/OVMF.fd \
    -usbdevice tablet \
    $VGA_OPT
    $PCI_GPU
    $NETDEV
    $DEVICE
    -vnc $HOST_ADDRESS:$VNC_PORT \
    $@" ENTER
}

create_user_data(){
  log "👤 Generating user data"

  cd ..

  wget -O cloud-init-template.yaml "${CLOUD_INIT_TEMPLATE}"

  docker run -it -v $(pwd)/cloud-init-template.yaml:/cloud-init-template.yaml \
    -v $(pwd)/$VM_NAME:/output \
    deserializeme/cigen:latest ./cigen.sh --update --upgrade \
    --password "${PASSWD}" \
    --github-username "${GITHUB_USER}" \
    --username "${USER}" \
    --vm-name "${VM_NAME}" \
    --template "/cloud-init-template.yaml" \
    --extra-vars "VM_KEY=$VM_KEY,STATIC_IP_ADDRESS=$STATIC_IP_ADDRESS,GATEWAY_IP=$IP_GATEWAY,DNS_SERVER_IP=$DNS_SERVER,INTERFACE=$INTERFACE"
  cd $VM_NAME
}

create-windows-vm(){
  read_config $1
  set_network
  select_image
  set_gpu
  set_vnc
  create_dir
  create_virtual_disk
  qemu-img create -f qcow2 hdd2.img 256G
  create_windows_vm
}

boot-windows-vm(){
  read_config $1
  set_network
  select_image
  set_gpu
  set_vnc
  create_dir
  boot_windows_vm
}

create-cloud-vm(){
  read_config $1
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
  read_config $1
  set_network
  set_gpu
  set_vnc
  create_dir
  create_virtual_disk
  create_vm_from_iso
}

boot-cloud-vm(){
  read_config $1
  set_network
  set_gpu
  set_vnc
  create_dir
  boot_ubuntu_cloud_vm
}

boot-iso-vm(){
  read_config $1
  set_network
  set_gpu
  set_vnc
  create_dir
  boot_vm_from_iso
}

"$@"
