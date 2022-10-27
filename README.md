# Scrap Metal

<img align="right" width="40%" height="50%" src="https://raw.githubusercontent.com/cloudymax/Scrap-Metal/main/media/Virtualization.drawio.svg">

The boring boilerplate you need to create performant
QEMU/KVM Virtual Machines on your own hardware. 

## Features:

- Free and Open-Source
- Seamless provisioning via cloud-init 
- Compatible with Azure/AWS/GCP and other clouds
- VM creation from LiveUSB/ISO images
- Static IP address assignment via Tap/Tun networking
- PCI-e/iommu pass-through
- GPU acceleration
- VNC and RDP support

## Why QEMU?

[QEMU](https://www.qemu.org/documentation/) is an open source machine emulator and virtualizer. It can be used for __system emulation__, where it provides a virtual model of an entire machine to run a guest OS or it may work with a another hypervisor like KVM or Xen. QEMU can also provide __user mode emulation__, where QEMU can launch processes compiled for one CPU on another CPU via emulation.

QEMU is special amongst its counterparts for a couple important reasons:

  - Like [ESXi](https://www.vmware.com/nl/products/esxi-and-esx.html), its capable of PCI passthrough for GPUs ([VirtualBox](https://docs.oracle.com/en/virtualization/virtualbox/6.0/user/guestadd-video.html) cant help us here)
  - Unlike ESXi, it's free
  - It's multi-platform
  - It's fast - not as fast as [LXD](https://linuxcontainers.org/lxd/introduction/), [FireCracker](https://firecracker-microvm.github.io/), or [Cloud-Hypervisor](https://github.com/cloud-hypervisor/cloud-hypervisor) (formerly [NEMU](https://github.com/intel/nemu)), but its far more mature and thoroughly documented. 
  - Unlike a [system container](https://linuxcontainers.org/lxd/introduction/) or [Multipass](https://multipass.run/docs) it can create windows hosts 
  - [Unlike Firecracker](https://github.com/firecracker-microvm/firecracker/issues/849#issuecomment-464731628) it supports pinning memmory addresses where firecracker cannot because it would break their core feature of over-subscription.

These qualities make QEMU well-suited for those seeking a general-purpose hypervisor running the first layer of virtualization. In your second layer though, you should consider the lighter and faster LXD, Firecracker, or Cloud-Hypervisor.

## Host OS Support

Scrap metal is built to run on X86 AMD64 Ubuntu Server host machines that have
been pre-provisioned with a tools like [Pxeless](https://github.com/cloudymax/pxeless), 
[Cloud-Init](https://cloudinit.readthedocs.io/en/latest/), [Ansible](https://www.ansible.com/overview/how-ansible-works) etc...

## Guest OS support

- Ubuntu Linux guests created from cloud images

- Other Linux distros supported via ISO/LiveUSB install.

- Windows guests installed from ISO

- MacOS guest support is enabled via [MacOS-KVM](https://github.com/kholia/OSX-KVM).

## Disclaimers and Warnings

* There are system-specific kernel modules that must be in-place for features 
like IOMMU/VirtIO passthrough to work properly. While non-accelerated 
Linux/Windows guests will work without these steps, they are a hard requirement 
for MacOS and GPU-enabled guests.

* Support for other Debian-Based distros on the host is a W.I.P 
and blocked by pre-seed support.

* GPU passthrough is supported for Intel CPU's and Nvidia GPU's ONLY.
This is because I don't have any AMD hardware, not because it isnt possible. 

* GPU Acceleration relies on [X11vnc](https://github.com/LibVNC/x11vnc) or [Nvidia Container Runtime](https://github.com/NVIDIA/nvidia-container-runtime). This means you need a screen, or [monitor stub](https://finddiffer.com/hdmi-dummy-plug-what-is-it-and-how-do-you-use-it/) attached to the host machine. Laptops that use Nvidia Optimus or Prime don't need to worry about this as theres a monitor hard-wired into your GPU anyway.
 
* Support for the process for preparing a Host for GPU-passthrough is best-effort only. 
There are garunteed to be issues across hardware models and vendors. 
To minimize the chances of misconfiguration follow the full-process of 
re-imaging your host with the supported ISO.

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

## Helper Scripts still to add to the TUI and CLI (WiP)

The TUI and CLI are being created to wrap the multitude of small helper scripts and functions needed to make your Virtual machines work.

`latest-kernel.sh`: downloads the latest ubuntu mainline kernel to the /tmp/new_kernel directory

`bridge.sh`: documents the full process for creating a bridged network and tap interface and the needed IPtables rules.

`bridge.conf`: file to allow netwok traffic over the bridge

`ip-tables.sh`: the required IPtables rules to allow bridged traffic

`tap.sh`: script to create a tap interface

`netplan config`: bridge host netplan config

`netplan config`: dynamic IP guest config

`netplan config`: static ip guest config

`governor.sh`: script to control CPU power states

`vmhost.sh`: get the PCI IDs of the GPU and alter grub and other config files to enable pass-
through

## Tunnels

rdp tunnel over ssh:
```bash
 ssh -L 3389:10.0.2.15:3389 176.9.44.19 -p23 -l max -N
 ssh -L 3389:<vm-private-ip>:3389 <host-ip> -p<vm-ssh-port> -l max -N
```
 
## Roadmap

- CLI (WiP)
- TUI (WiP)
- Support for [LookingGlass](https://github.com/gnif/LookingGlass)
- GPU Sharding via [LibVF.IO](https://github.com/Arc-Compute/LibVF.IO) integration
- Intel iGPU acceleration for non-GPU enabled hosts
- VNC security options
- Wireguard networking (WiP)

## Resources and Help

Scrap-Metal is not a new development or an original work. It's bits and pieces of knowledge from people much smart than myself that have been cut-and-pasted into a sligjtly easier-to-use format.

GPU Passthrough resources:

- [GPU Passthrough on a Dell Precision 7540 and other high end laptops](https://leduccc.medium.com/simple-dgpu-passthrough-on-a-dell-precision-7450-ebe65b2e648e) - leduccc

- [Improving the performance of a Windows Guest on KVM/QEMU](https://leduccc.medium.com/improving-the-performance-of-a-windows-10-guest-on-qemu-a5b3f54d9cf5) - leduccc

- [Comprehensive guide to performance optimizations for gaming on virtual machines with KVM/QEMU and PCI passthrough](https://mathiashueber.com/performance-tweaks-gaming-on-virtual-machines/) - Mathias Hüber

- [Virtual machines with PCI passthrough on Ubuntu 20.04, straightforward guide for gaming on a virtual machine](https://mathiashueber.com/pci-passthrough-ubuntu-2004-virtual-machine/) - Mathias Hüber

- [gpu-virtualization-with-kvm-qemu](https://medium.com/@calerogers/gpu-virtualization-with-kvm-qemu-63ca98a6a172) - Cale Rogers

- [Faster Virtual Machines on Linux Hosts with GPU Acceleration](https://adamgradzki.com/2020/04/06/faster-virtual-machines-linux/) - Adam Gradzki

  |Author| Year |CPU | GPU | OS | modules method | pci-ids medthod |
  |--|--|--|--|--|--|--|
  | Leducc | 2020 | Intel | Nvidia | Manjaro |/etc/mkinitcpio.conf |GRUB_CMDLINE_LINUX_DEFAULT| 
  | Mathias Hüber | 2021 | AMD | Nvidia | Ubuntu 18.04 & 20.04 | /etc/initramfs-tools/modules|GRUB_CMDLINE_LINUX_DEFAULT and /etc/initramfs-tools/scripts/init-top/vfio.sh|
  | Cale Rogers | 2016 | Intel | Nvidia | Ubuntu 16.04 | GRUB_CMDLINE_LINUX and /etc/initram-fs/modules|/etc/modprobe.d/local.conf|
  | Adam Gradzki | 2020 | Intel | Intel | ?? | ---| created by i915-GVTg_V5_2 |

Cloud-Init Resources:

- [My Magical Adventure With cloud-init](https://christine.website/blog/cloud-init-2021-06-04) - Xe Iaso

Hypervisor Resources:

- [A Study of Performance and Security Across the Virtualization Spectrum](https://repository.tudelft.nl/islandora/object/uuid:34b3732e-2960-4374-94a2-1c1b3f3c4bd5/datastream/OBJ/download) - Vincent van Rijn

- [virtualization-hypervisors-explaining-qemu-kvm-libvirt](https://sumit-ghosh.com/articles/virtualization-hypervisors-explaining-qemu-kvm-libvirt/) by Sumit Ghosh

Kubernetes/Docker Resources:

- [Schedule GPUs in K8s](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/#deploying-amd-gpu-device-plugin)

- [NVIDIA Container Toolkit install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

Kernel Options Docs:

- [Linux Kernel Params](https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html)

- [Intel i915 Driver Options](https://www.kernel.org/doc/html/latest/gpu/i915.html?highlight=vfio%20pci)

- [PCI VFIO options](https://www.kernel.org/doc/html/latest/driver-api/vfio-pci-device-specific-driver-acceptance.html?highlight=vfio%20pci)

- [KMV Ignore MSRs](https://www.kernel.org/doc/html/latest/virt/kvm/x86/msr.html?highlight=kvm%20ignore%20msrs)

- [root device (rd) kernel options](https://man7.org/linux/man-pages/man7/dracut.cmdline.7.html)
