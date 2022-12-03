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

These qualities make QEMU well-suited for those seeking a general-purpose hypervisor running the first layer of virtualization. For maximum speed or density though, you should consider if the lighter, but less generalized LXD, Firecracker, or Cloud-Hypervisor better suits your needs.

## Other projects to check out:

- [Quickemu](https://github.com/quickemu-project/quickemu) After using scrap-metal to get your host configured, use quick-emu to launch all kinds of virtual machines, not just ubuntu and debian server.
- [cannoli](https://github.com/MarginResearch/cannoli) Use Cannoli to profile your QEMU virtual machines to identity performance issues in code.
- [multipass](https://github.com/canonical/multipass) Multipass is a cross-platform VMM that can get you to a linux environment from anywhere. Especially useful since it has great support for ARM64 and supports cloud-init. No GPU passthrough possible though.
- [Cloud Hypervisor](https://github.com/cloud-hypervisor/cloud-hypervisor) Intel's spin off of QEMU, this porject (formerly called NEMU) is based on the Rust VMM just like Amazon's Firecracker but it supports PCI passthrough and other useful features that firecracker cannot accomodate. Cloud Hypervisor also  powers the [Kubevirt](https://kubevirt.io/) project.
- [Metal3](https://metal3io.netlify.app/) The Metal³ project (pronounced: “Metal Kubed”) provides components for bare metal host management with Kubernetes. You can enrol your bare metal machines, provision operating system images, and then, if you like, deploy Kubernetes clusters to them. 

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

- Support for [LookingGlass](https://github.com/gnif/LookingGlass)
- GPU Sharding via [LibVF.IO](https://github.com/Arc-Compute/LibVF.IO) integration
- Intel iGPU acceleration for non-GPU enabled hosts
- VNC security options
- Wireguard networking (WiP)
