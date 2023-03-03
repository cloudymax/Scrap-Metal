

## Optimizations

- kernel upgrade:

  Get the latest from here: https://kernel.ubuntu.com/~kernel-ppa/mainline/?C=N;O=D

  ```zsh
  mkdir kernel_upgrade 
  cd kernel_upgrade

  wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-headers-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb

  wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-headers-5.18.0-051800_5.18.0-051800.202205222030_all.deb

  wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-image-unsigned-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb

  wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-modules-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb

  sudo dpkg -i *.deb
  ```

1. CPU Topology
    
    This one is pretty simple, when we allow QEMU/KVM to access the Host's CPU firectly without emulation, performance is better.


1. CPU Pinning

    ```zsh
     <vcpu placement='static'>14</vcpu>
     <iothreads>1</iothreads>
     <cputune>
        <vcpupin vcpu='0' cpuset='1'/>
        <vcpupin vcpu='1' cpuset='2'/>
        <vcpupin vcpu='2' cpuset='3'/>
        <vcpupin vcpu='3' cpuset='4'/>
        <vcpupin vcpu='4' cpuset='5'/>
        <vcpupin vcpu='5' cpuset='6'/>
        <vcpupin vcpu='6' cpuset='7'/>
        <vcpupin vcpu='7' cpuset='9'/>
        <vcpupin vcpu='8' cpuset='10'/>
        <vcpupin vcpu='9' cpuset='11'/>
        <vcpupin vcpu='10' cpuset='12'/>
        <vcpupin vcpu='11' cpuset='13'/>
        <vcpupin vcpu='12' cpuset='14'/>
        <vcpupin vcpu='13' cpuset='15'/>
        <emulatorpin cpuset='0,8'/>
        <iothreadpin iothread='1' cpuset='0,8'/>
     </cputune>
    ```
 
 
## VM creation (revision in progress)

Once we can get into the GUI we must update some group policy values to set the proper GPU for use with RDP connections

```zsh
qemu-system-x86_64 \
    -hda win10.img \
    -boot c \
    -machine type=q35,accel=kvm \
    -cpu host,kvm="off" \
    -smp sockets=1,cores=2,threads=2 \
    -m 8G \
    -vga std
    -serial none \
    -parallel none \
    -device vfio-pci,host=01:00.0,multifunction=on \
    -device vfio-pci,host=01:00.1 \
    -net nic,model=e1000 \
    -net user 
```

We also need to record the ip address for the vm. 
For this example is "10.0.2.15"

Now we can connect via rdp

## Set up a networking bridge, before RDP will work
Make sure bridge-utils is installed:
`sudo apt install bridge-utils`


edit `/etc/network/interfaces`:

```bash
auto lo
iface lo inet loopback

auto br0
iface br0 inet static
        address 192.168.50.100
        network 192.168.50.0
        netmask 255.255.255.0
        broadcast 192.168.50.255
        gateway 192.168.50.1
        dns-nameservers 192.168.50.1 1.1.1.1
        bridge_ports eth0
        bridge_stp off
        bridge_fd 0
        bridge_maxwait 0
```

reboot the host pc.


The XML for the networking in virtual manager:
```xml
<interface type="network">
  <mac address="52:54:00:1b:70:45"/>
  <source network="default"/>
  <model type="e1000e"/>
  <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
</interface>
```

What we're gonna change it to:
```xml
<interface type="bridge">
  <mac address="52:54:00:1b:70:45"/>
  <source brdige="br0"/>
</interface>
```


## with vnc
```zsh
qemu-system-x86_64 \
  -drive id=disk0,if=virtio,cache=none,format=raw,file=Win10-AlternateInstall.img \
  -drive file=Win10_21H2_EnglishInternational_x64.iso,index=1,media=cdrom \
  -boot c \
  -machine type=q35,accel=kvm \
  -cpu host,kvm="off" \
  -smp sockets=1,cores=2,threads=2 \
  -m 8G \
  -vga none -nographic -serial none -parallel none \
  -device vfio-pci,host=01:00.0,multifunction=on \
  -device vfio-pci,host=01:00.1 \
  -device virtio-net,netdev=vmnic \
  -netdev user,id=vmnic \
  -net nic,model=e1000 \
  -net user \
  -vnc 127.0.0.1:2
```

To get to bios, this worked, and spits you into a shell, which you then hit exit on and select boot manager.
  
```zsh
sudo qemu-system-x86_64 \
   # primary hard disk \
   -drive id=disk0,if=virtio,cache=none,format=raw,file=Win10-AlternateInstall.img \
   # Windows Installer ISO Image \
   -drive file=Win10_21H2_EnglishInternational_x64.iso,index=1,media=cdrom \
   # Driver installer ISO \
   #-drive file=virtio-win-0.1.141.iso,index=0,media=cdrom \
   -boot c \
   -machine type=q35,accel=kvm \
   -cpu host,kvm="off" \
   -smp sockets=1,cores=2,threads=2 \
   -m 8G \
   -serial none \
   -parallel none \
   # GTX 1070 TI \
   -device vfio-pci,host=01:00.0,multifunction=on \
   # GTX 1070 TI HDMI Audio \
   -device vfio-pci,host=01:00.1 \
   -net nic,model=e1000 \
   -net user \
   -bios /usr/share/qemu/OVMF.fd \
   # if you need a remote connection
   -vnc 127.0.0.1:2


sudo qemu-system-x86_64 \
   -hda Win10-AlternateInstall.img \
   -boot c \
   -machine type=q35,accel=kvm \
   -cpu host,kvm="off" \
   -smp sockets=1,cores=2,threads=2 \
   -m 8G \
   -serial none \
   -parallel none \
   -device vfio-pci,host=01:00.0,multifunction=on \
   -device vfio-pci,host=01:00.1 \
   -device virtio-net,netdev=vmnic \
   -netdev user,id=vmnic \
   -net nic,model=e1000 \
   -net user \
   -bios /usr/share/qemu/OVMF.fd
```

## Microkernel

1. Download files

```bash
# initrd
wget -O initrd https://cloud-images.ubuntu.com/jammy/current/unpacked/jammy-server-cloudimg-amd64-initrd-generic

# vmlinuz
wget -O vmlinuz https://cloud-images.ubuntu.com/jammy/current/unpacked/jammy-server-cloudimg-amd64-vmlinuz-generic

# KVM disk image
wget -O kvm.img https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64-disk-kvm.img
```

2. Prep disk image

```bash
qemu-img create -f qcow2 -F qcow2 -b `pwd`/kvm.img hdd0.img
```

3. Create a cloud-init config and image

```bash

/usr/bin/cat << EOF > user-data
#cloud-config

hostname: ubuntu1
fqdn: ubuntu1.localdomain
manage_etc_hosts: true

ssh_pwauth: true
disable_root: true

users:
  - name: ubuntu
    home: /home/ubuntu
    shell: /bin/bash
    groups: sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh-authorized-keys:
      - `cat ~/.ssh/id_rsa.pub`
EOF

cloud-localds user-data.img user-data
```

4. Create the microvm

```bash
export KERNEL="vmlinuz"
export INITRD="initrd"
export HDD0="hdd0.img"
export TAP_NUMBER="tap0"
export SEED_ISO="user-data.img"
   
sudo qemu-system-x86_64 \
   -M microvm,x-option-roms=off,pit=off,pic=off,isa-serial=off,rtc=off \
   -enable-kvm -cpu host -m 512m -smp 2 \
   -kernel vmlinuz -append "earlyprintk=hvc0 console=hvc0 root=/dev/vda1" \
   -initrd initrd \
   -nodefaults -no-user-config -nographic \
   -chardev stdio,id=virtiocon0 \
   -device virtio-serial-device \
   -device virtconsole,chardev=virtiocon0 \
   -netdev tap,id=network0,ifname=tap0,script=no,downscript=no \
   -device virtio-net-device,netdev=network0 \
   -device virtio-blk-device,drive=hdd0 \
   -drive id=hdd0,file=hdd0.img,format=qcow2,if=none \
   -device virtio-blk-device,drive=hdd1 \
   -drive id=hdd1,file=user-data.img,format=raw,if=none \
```

## Packages

```bash
sudo apt-get install qemu-kvm libvirt-bin bridge-utils virtinst ovmf qemu-utils
```

## Terms and Definitions

What do all the acronyms and buzzwords even *mean*?

|Term | Definition|
|---|---|
|**KMV**| Kernel Virtual Machine |
|**ESXi**| Elastic Sky X Integrated |
|**VFIO**| Virtual FunctionI/O |
|**QEMU**| Quick Emulator |
|**Metal Host**| A physical computer that runs VMs or containers |
|**Guest**| A VM or Container running on a Host |
