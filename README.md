# Scrap-Metal

Scrap-Metal is a tool to help you ["Pave the Road"](https://kgb1001001.github.io/cloudadoptionpatterns/Strangler-Patterns/Pave-the-Road/) using off-the-shelf harware, Linux, QEMU, and Cloud-Init.

Scrap-Metal does not replace or compete with tools like [Nova](https://docs.openstack.org/nova/latest/), [Metal-As-A-Service](https://maas.io/docs/get-started-with-maas), [Kubevirt](https://kubevirt.io/user-guide/operations/installation/), [Metal3](https://metal3.io/) but rather should be used to create homogenous and ephemeral compute environments from which to deploy and test the afore mentioned tools.

Commands:
```bash
./vm.sh create-cloud-vm
./vm.sh boot-cloud-vm

./vm.sh create-from-iso <path-to-iso>
./vm.sh boot-iso-vm
  
./vm.sh create-windows-vm
./vm.sh boot-windows-vm
```
