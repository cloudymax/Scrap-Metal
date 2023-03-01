# GPU Acceleration for QEMU VMs via pci-passthrough.

Guide assumes a fresh install of Debian 12, or Ubuntnu Server


1. Enable IOMMU by changing the `GRUB_CMDLINE_LINUX_DEFAULT` line in your `/etc/default/grub` file to the following:

   ```bash
    GRUB_CMDLINE_LINUX_DEFAULT="quiet preempt=voluntary iommu=pt amd_iommu=on intel_iommu=on"
    ```
    Then run `sudo update-grub`.
    
    > The `preempt` option is also enabled here to reduce boot-times for systems with large amounts of RAM.
    

