# GPU Accelerated VMs using QEMU.

A manual walk-though of https://github.com/small-hack/smol-gpu-passthrough. This Guide assumes a fresh install of Debian 12, or Ubuntnu Server.

## Enabling IOMMU

 - Enable IOMMU by changing the `GRUB_CMDLINE_LINUX_DEFAULT` line in your `/etc/default/grub` file to the following:

   ```bash
    GRUB_CMDLINE_LINUX_DEFAULT="quiet preempt=voluntary iommu=pt amd_iommu=on intel_iommu=on"
    ```
    Then run `sudo update-grub`.
    
    > The `preempt` option is also enabled here to reduce boot-times for systems with large amounts of RAM.
    
 - Install dependancies 

   ```bash
   sudo apt-get -y install \
         qemu-kvm \
         bridge-utils \
         virtinst \
         ovmf \
         qemu-utils \
         cloud-image-utils \
         curl
   ```

 - Reboot (Required)

## Gathering IOMMU data

  Now that IOMMU is enabled we can look for devices in `/sys/kernel/iommu_groups`. The formatting is awful by default so here is a small script to list it in a more readable way courtesy of leduccc.medium.com 

   - [SOURCE](https://leduccc.medium.com/simple-dgpu-passthrough-on-a-dell-precision-7450-ebe65b2e648e)
   
   ```bash
   /bin/bash -c "curl -fsSL https://raw.githubusercontent.com/cloudymax/Scrap-Metal/yaml-config/virtual-machines/host-config-resources/iommu-groups.sh"
   ```
   
   The output of the above script will list all IOMMU groups, as well as the PCI ID, a description of each of your PCI devices, and at the end of the line is the IOMMU ID that we require. You will need to find the group number that your graphics card belongs to, and the IOMMU IDs of each item in that group. In the case of the example blow, the IOMMU IDs we need are `10de:1f08`, `10de:10f9`, `10de:1ada`, and `10de:1adb`.


<details>
  <summary>Click to expand</summary>
   
   ```bash
   IOMMU Group 0 00:02.0 VGA compatible controller [0300]: Intel Corporation RocketLake-S GT1 [UHD Graphics 750] [8086:4c8a] (rev 04)
   IOMMU Group 1 00:00.0 PCI bridge [0604]: Intel Corporation Device [8086:4c43] (rev 01)
   IOMMU Group 2 00:01.0 PCI bridge [0604]: Intel Corporation Device [8086:4c01] (rev 01)
   IOMMU Group 3 00:04.0 Signal processing controller [1180]: Intel Corporation Device [8086:4c03] (rev 01)
   IOMMU Group 4 00:08.0 System peripheral [0880]: Intel Corporation Device [8086:4c11] (rev 01)
   IOMMU Group 5 00:12.0 Signal processing controller [1180]: Intel Corporation Comet Lake PCH Thermal Controller [8086:06f9]
   IOMMU Group 6 00:14.0 USB controller [0c03]: Intel Corporation Comet Lake USB 3.1 xHCI Host Controller [8086:06ed]
   IOMMU Group 6 00:14.2 RAM memory [0500]: Intel Corporation Comet Lake PCH Shared SRAM [8086:06ef]
   IOMMU Group 7 00:14.3 Network controller [0280]: Intel Corporation Comet Lake PCH CNVi WiFi [8086:06f0]
   IOMMU Group 8 00:15.0 Serial bus controller [0c80]: Intel Corporation Comet Lake PCH Serial IO I2C Controller #0 [8086:06e8]
   IOMMU Group 9 00:16.0 Communication controller [0780]: Intel Corporation Comet Lake HECI Controller [8086:06e0]
   IOMMU Group 10 00:17.0 SATA controller [0106]: Intel Corporation Comet Lake SATA AHCI Controller [8086:06d2]
   IOMMU Group 11 00:1b.0 PCI bridge [0604]: Intel Corporation Comet Lake PCI Express Root Port #21 [8086:06ac] (rev f0)
   IOMMU Group 12 00:1c.0 PCI bridge [0604]: Intel Corporation Device [8086:06bc] (rev f0)
   IOMMU Group 13 00:1f.0 ISA bridge [0601]: Intel Corporation H470 Chipset LPC/eSPI Controller [8086:0684]
   IOMMU Group 13 00:1f.3 Audio device [0403]: Intel Corporation Device [8086:f1c8]
   IOMMU Group 13 00:1f.4 SMBus [0c05]: Intel Corporation Comet Lake PCH SMBus Controller [8086:06a3]
   IOMMU Group 13 00:1f.5 Serial bus controller [0c80]: Intel Corporation Comet Lake PCH SPI Controller [8086:06a4]
   IOMMU Group 14 02:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU106 [GeForce RTX 2060 Rev. A] [10de:1f08] (rev a1)
   IOMMU Group 14 02:00.1 Audio device [0403]: NVIDIA Corporation TU106 High Definition Audio Controller [10de:10f9] (rev a1)
   IOMMU Group 14 02:00.2 USB controller [0c03]: NVIDIA Corporation TU106 USB 3.1 Host Controller [10de:1ada] (rev a1)
   IOMMU Group 14 02:00.3 Serial bus controller [0c80]: NVIDIA Corporation TU106 USB Type-C UCSI Controller [10de:1adb] (rev a1)
   IOMMU Group 15 03:00.0 Non-Volatile memory controller [0108]: ADATA Technology Co., Ltd. XPG SX8200 Pro PCIe Gen3x4 M.2 2280 Solid State Drive [1cc1:8201] (rev 03)
   ```
</details>

## Enable VFIO-PCI and disable conflicting kernel modules

5. In order to pass control of the GPU to the VM we will need to hand over control of the PCI devices to VFIO. This only works though if VFIO has control of ALL items in the GPU's IOMMU group.

   - edit/create `/etc/initramfs-tools/modules` (Debina), or `/etc/initram-fs/modules` (Ubuntu) to include the following:
   
      ```bash
      vfio
      vfio_iommu_type1
      vfio_pci
      vfio_virqfd
      options vfio-pci ids=<your IOMMU IDs go here>
      ```
   
   - edit/create `/etc/modprobe.d/blacklist.conf` (Debian), or `/etc/modprobe.d/local.conf` (Ubuntu)
      
      ```bash
      options vfio-pci ids=<your IOMMU IDs go here>
      ```
      
   - edit the `GRUB_CMDLINE_LINUX_DEFAULT` line of your `/etc/default/grub` file again to the following:
   
      ```bash
      GRUB_CMDLINE_LINUX_DEFAULT="quiet preempt=voluntary iommu=pt amd_iommu=on intel_iommu=on vfio-pci.ids=<your IOMMU IDs go here> rd.driver.pre=vfio-pci video=efifb:off kvm.ignore_msrs=1 kvm.report_ignored_msrs=0
      ```
      
    - Now run `sudo update-grub` again
 
    - A common issue I have seen others encounter with this process is that VFIO is not given control of all devices in the GPU's IOMMU group. Most often this is due to the xhci_hcd USB module retaining control of the GPU's USB controller. 

         > As per the [Debian Wiki](https://wiki.debian.org/KernelModuleBlacklisting) - to disable this kernel module, or any other you can:
         > 
         > - Create a file `/etc/modprobe.d/<modulename>.conf` containing `blacklist <modulename>`.
         > - Run `sudo depmod -ae` as root
         > - Recreate your initrd with `sudo update-initramfs -u`
 
      So I will now edit/create `/etc/modprobe.d/xhci_hcd.conf` to contain
      
      ```bash
      blacklist xhci_hcd
      ```
   
6. Run `sudo update-initramfs -u`, `sudo depmod -ae` and then reboot. (Required)

## Verify VFIO control over PCI Devices

   After your machien reboots, run `lspci -nnk` to show which kernel driver has control over each PCI device. All devices should show `vfio-pci` as the kernel driver in use. If not, you will need to repeat the previous steps to disable that driver.


<details>
  <summary>Click to expand</summary>
   
   ```bash
   02:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU106 [GeForce RTX 2060 Rev. A] [10de:1f08] (rev a1)
	   Subsystem: ASUSTeK Computer Inc. TU106 [GeForce RTX 2060 Rev. A] [1043:86f0]
	   Kernel driver in use: vfio-pci
	   Kernel modules: nouveau
   02:00.1 Audio device [0403]: NVIDIA Corporation TU106 High Definition Audio Controller [10de:10f9] (rev a1)
	   Subsystem: ASUSTeK Computer Inc. TU106 High Definition Audio Controller [1043:86f0]
	   Kernel driver in use: vfio-pci
	   Kernel modules: snd_hda_intel
   02:00.2 USB controller [0c03]: NVIDIA Corporation TU106 USB 3.1 Host Controller [10de:1ada] (rev a1)
	   Subsystem: ASUSTeK Computer Inc. TU106 USB 3.1 Host Controller [1043:86f0]
	   Kernel driver in use: vfio-pci
	   Kernel modules: xhci_pci
   02:00.3 Serial bus controller [0c80]: NVIDIA Corporation TU106 USB Type-C UCSI Controller [10de:1adb] (rev a1)
	   Subsystem: ASUSTeK Computer Inc. TU106 USB Type-C UCSI Controller [1043:86f0]
	   Kernel driver in use: vfio-pci
   ```
</details>

