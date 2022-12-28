## Host OS Support

Scrap metal is built to run on X86 AMD64 Ubuntu Server host machines that have
been pre-provisioned with a tools like [Pxeless](https://github.com/cloudymax/pxeless), 
[Cloud-Init](https://cloudinit.readthedocs.io/en/latest/), [Ansible](https://www.ansible.com/overview/how-ansible-works) etc...

## Guest OS support

- Ubuntu Linux guests created from cloud images

- Other Linux distros supported via ISO/LiveUSB install.

- Windows guests installed from ISO

- MacOS guest support is enabled via [MacOS-KVM](https://github.com/kholia/OSX-KVM).

### Ubuntu Cloud Images

Ubuntu cloud images use an overlay file system and have a serial console availble when gpu acceleration is disabled. These must be accessed via VNC when a GPU is enabled. When Ubuntu Desktop 22.04 is chosen as the GUI, RDP may be used instead.

```bash
./vm.sh create-cloud-vm
./vm.sh boot-cloud-vm
```

### Live-Installer Images

Live installers boot into a bios screen and require VNC to configure.

```bash
./vm.sh create-from-iso <path-to-iso>
./vm.sh boot-iso-vm
```

### Windows Images

Windows images require VNC and or RDP to access and configure

```bash
./vm.sh create-windows-vm
./vm.sh boot-windows-vm
```

### MacOS Images

MacOS images have been validated as working, but are not implimented yet.
To reproduce initial results see https://github.com/kholia/OSX-KVM.
Specifically, you will need to alter the vm creation script to remove the VGA device and instead add a VNC host.

```bash
  -enable-kvm -m "$ALLOCATED_RAM" -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,"$MY_OPTIONS"
  -machine q35
  -usb -device usb-kbd -device usb-tablet
  -smp "$CPU_THREADS",cores="$CPU_CORES",sockets="$CPU_SOCKETS"
  -device usb-ehci,id=ehci
  # -device usb-kbd,bus=ehci.0
  # -device usb-mouse,bus=ehci.0
  -device nec-usb-xhci,id=xhci
  -global nec-usb-xhci.msi=off
  # -device usb-host,vendorid=0x8086,productid=0x0808  # 2 USD USB Sound Card
  # -device usb-host,vendorid=0x1b3f,productid=0x2008  # Another 2 USD USB Sound Card  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"  -drive if=pflash,format=raw,readonly=on,file="$REPO_PATH/$OVMF_DIR/OVMF_CODE.fd"
  -drive if=pflash,format=raw,file="$REPO_PATH/$OVMF_DIR/OVMF_VARS-1024x768.fd"
  -smbios type=2
  -device ich9-intel-hda -device hda-duplex
  -device ich9-ahci,id=sata
  -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore/OpenCore.qcow2"  -device ide-hd,bus=sata.2,drive=OpenCoreBoot
  -device ide-hd,bus=sata.3,drive=InstallMedia
  -drive id=InstallMedia,if=none,file="$REPO_PATH/BaseSystem.img",format=raw
  -drive id=MacHDD,if=none,file="$REPO_PATH/mac_hdd_ng.img",format=qcow2
  -device ide-hd,bus=sata.4,drive=MacHDD
  # -netdev tap,id=net0,ifname=tap0,script=no,downscript=no -device virtio-net-pci,netdev=net0,id=net0,mac=52:54:00:c9:18:27  -netdev user,id=net0 -device virtio-net-pci,netdev=net0,id=net0,mac=52:54:00:c9:18:27
  # -netdev user,id=net0 -device vmxnet3,netdev=net0,id=net0,mac=52:54:00:c9:18:27  # Note: Use this line for High Sierra
  #-monitor stdio
  -nographic
  #-device VGA,vgamem_mb=128
  -vnc "192.168.50.100":"0"
```
