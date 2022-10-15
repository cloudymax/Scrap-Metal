# Scrap-Metal (WIP)

ScrapMetal is the Bash/Python boilerplate you need to create performant
QEMU/KVM Virtual Machines using your own hardware. 

Features:
- Seamless provisioning via cloud-init 
- VM creation from LiveUSB/ISO images
- Static IP address assignment via Tap/Tun networking
- PCI-e/iommu pass-through
- GPU acceleration
- VNC and RDP support

## Supported Hosts

Scrap metal is built to run on X86 AMD64 Ubuntu Server host machines that have
been pre-provisioned with a tools like [Pxeless](https://github.com/cloudymax/pxeless), 
Cloud-Init, Ansible etc... 

## Disclaimers and Warnings

* There are system-specific kernel modules that must be in-place for features 
like IOMMU/VirtIO passthrough to work properly. While non-accelerated 
Linux/Windows guests will work without these steps, they are a hard requirement 
for MacOS and GPU-enabled guests.

* Support for other Debian-Based distros on the host is a W.I.P 
and blocked by pre-seed support.

* GPU passthrough is supported for Intel CPU's and Nvidia GPU's ONLY.
This is because I don't have any AMD hardware, not because it isnt possible. 

* The process for preparing the Host for GPU-passthrough is best-effort only. 
There are garunteed to be issues across hardware models and vendors. 
To minimize the chances of misconfiguration follow the full-process of 
re-imaging your host with the supported ISO.

## Supported Guests

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

## Helper scripts

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
 


```bash
./install.sh --disable=servicelb \
    --disable=traefik \
    --write-kubeconfig-mode=647

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.6/config/manifests/metallb-native.yaml

helm upgrade --install ingress-nginx ingress-nginx  \
    --repo https://kubernetes.github.io/ingress-nginx  \
    --namespace ingress-nginx \
    --create-namespace
```

pools.yaml:

```yaml
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 192.168.50.102-192.168.50.110
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
```

```bash
kubectl apply -f pools.yaml

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

kubectl create deployment demo --image=nginxdemos/hello --port=80
kubectl expose deployment demo
kubectl create ingress demo-localhost \
    --class=nginx \
    --rule="ingress.raccoon.cloud/*=demo:80"i

helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace  \
    --version v1.9.1 \
    --set installCRDs=true
```

certs.yaml
```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: garbage@raccoon.cloud
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            class: nginx
```

```bash
kubectl apply -f certs.yaml
```

hello-nginx.yaml:

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-hello
  namespace: default
spec:
  ingressClassName: nginx
  rules:
    - host: ingress.raccoon.cloud
      http:
        paths:
          - pathType: Prefix
            backend:
              service:
                name: nginx-hello
                port:
                  number: 80
            path: /
  tls:
    - hosts:
      - ingress.raccoon.cloud
      secretName: example-tls
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-hello
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-hello
  template:
    metadata:
      labels:
        app: nginx-hello
    spec:
      containers:
        - name: nginx-hello
          image: nginxdemos/hello
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-hello
spec:
  selector:
    app: nginx-hello
  ports:
    - protocol: TCP
      port: 80
```

```bash
kubectl apply -f hello-nginx.yaml
```

argo.yaml

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    # If you encounter a redirect loop or are getting a 307 response code
    # then you need to force the nginx ingress to connect to the backend using HTTPS.
    #
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: argocd.raccoon.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              name: https
  tls:
  - hosts:
    - argocd.raccoon.cloud
    secretName: argocd-secret # do not change, this is provided by Argo CD
```
values.yaml:

```yaml
configs: 
  secret: 
    argocdServerAdminPassword: ""
  server: 
    ingress: 
      annotations: 
        nginx.ingress.kubernetes.io/backend-protocal: HTTPS
        nginx.ingress.kubernetes.io/force-ssl-redirect: true
        nginx.ingress.kubernetes.io/ssl-passthrough: true
      enabled: true
      hosts: 
        - argo_cd_domain
      ingressClassName: nginx
    insecure: true
dex: 
  enabled: false
```

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --namespace argocd --values values.yaml
kubectl apply -f argo.yaml
```
