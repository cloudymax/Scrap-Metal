#!/bin/bash
##########################################################################
# Simple template modification script to customize cloud-init user-data 
# cloud-init logs are in /run/cloud-init/result.json
# <3 max
#########################################################################
set -o pipefail

parse_params() {
        while :; do
                case "${1-}" in
                -h | --help) usage ;;
                -v | --verbose) set -x ;;
                -s | --slim) export SLIM="true" ;;
                -upd | --update) export UPDATE="true" ;;
                -upg | --upgrade) export UPGRADE="true" ;;
                -p | --password)
                        export PASSWD="${2-}"
                        shift
                        ;;
                -u | --username)
                        export USER="${2-}"
                        shift
                        ;;
                -gh | --github-username)
                        export GITHUB_USER="${2-}"
                        shift
                        ;;
                -n | --vm-name)
                        export VM_NAME="${2-}"
                        export VM_ADMIN="${VM_NAME}admin"
                        shift
                        ;;
                -ip | --ip-address)
                        export IP_ADDRESS="${2-}"
                        shift
                        ;;
                -gw | --gateway)
                        export GATEWAY="${2-}"
                        shift
                        ;;
                -dns | --dns-server)
                        export DNS="${2-}"
                        shift
                        ;;
                -?*) die "Unknown option: $1" ;;
                *) break ;;
                esac
                shift
        done

        if [ ! $UPDATE ]; then
            export UPDATE="false"
        fi

        if [ ! $UPGRADE ]; then
            export UPGRADE="false"
        fi

        if [ ! $SLIM ]; then
            export SLIM="false"
        fi

        return 0
}

# help text
usage(){
        cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-s] [-upd] [-upg] [-p <password>] [-u <user>] [-gh <user>] [-n <name>]

💁 This script will quickly modify a cloud-init user-data template that can be used to provision virtual-machines, metal, and containers.

Available options:

-h, --help              Print this help and exit

-v, --verbose           Print script debug info

-s, --slim              Use a minimal version of the user-data template.

-upd, --update          Update apt packages during provisioning

-upg, --upg             Upgrade packages during provisioning

-p, --password          Password to set up for the VM Users.

-u, --username          Username for non-system account

-i, --ip-address        IP address for netplan to apply.

-gw, --gateway          IP address for the default network gateway

-dns, --dns-server      IP address for your DNS server

-gh, --github-username  Github username from which to pull public keys

-n, --vm-name           Hostname/name for the Virtual Machine. Influences the name of the syste account - no special chars plz.

EOF
        exit
}

# create a ssh key for the user and save as a file w/ prompt
create_ssh_key(){
  log "🔐 Create an SSH key for the VM admin user"

  yes |ssh-keygen -C "$VM_ADMIN" \
    -f "${VM_ADMIN}" \
    -N '' \
    -t rsa 1> /dev/null

  export VM_KEY_FILE=$(find "$(cd ..; pwd)" -name "${VM_ADMIN}")
  export VM_KEY=$(cat "${VM_KEY_FILE}".pub)
  log " - Done."

}

verify_deps(){
    log "🔎 Checking for required utilities..."
    [[ ! -x "$(command -v whois)" ]] && die "💥 whois is not installed. On Ubuntu, install  the 'whois' package."
    log " - All required utilities are installed."
}

create_ansible_user_data(){
log "📝 Create a minimal user-data file"

cat > user-data <<EOF
#cloud-config
hostname: ${VM_NAME}
fqdn: ${VM_NAME}
disable_root: false
users:
  - name: ${USER}
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: ${PASSWD}
    ssh_import_id:
      - gh:${GITHUB_USER}
  - name: ${VM_ADMIN}
    gecos: system acct
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: ${PASSWD}
    ssh_authorized_keys:
      - ${VM_KEY}
package_update: ${UPDATE}
package_upgrade: ${UPGRADE}
packages:
  - wget
  - curl
  - git
  - build-essential
  - python3-pip
runcmd:
  - sudo -u ${VM_ADMIN} echo "export PATH=\"/home/${VM_ADMIN}/.local/bin:\$PATH\"" >> /home/${VM_ADMIN}/.profile 
  - git clone https://github.com/cloudymax/pxeless.git
  - sudo -u ${VM_ADMIN} env "PATH=$PATH:/home/$VM_ADMIN/.local/bin" /pxeless/provisioner/provision.sh --ansible-user ${VM_ADMIN} --profile jax --cows random
EOF

log " - Done."
}

create_slim_user_data(){
log "📝 Create a minimal user-data file"

cat > user-data <<EOF
#cloud-config
hostname: ${VM_NAME}
fqdn: ${VM_NAME}
disable_root: false
network:
  config: disabled
users:
  - name: ${USER}
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: ${PASSWD}
    ssh_import_id:
      - gh:${GITHUB_USER}
  - name: ${VM_USER}
    gecos: system acct
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: ${PASSWD}
    ssh_authorized_keys:
      - ${VM_KEY}
write_files:
- path: /etc/netplan/99-my-new-config.yaml
  permissions: '0644'
  content: |
    network:
      ethernets:
        enp0s2:
          dhcp4: no
          dhcp6: no
          addresses: [${IP_ADDRESS}/24]
          routes:
            - to: default
              via: ${GATEWAY}
          mtu: 1500
          nameservers:
            addresses: [$DNS]
      renderer: networkd
      version: 2
runcmd:
  - rm /etc/netplan/50-cloud-init.yaml
  - netplan --debug generate
  - netplan --debug apply
  - sed -i -e '/^Port/s/^.*$/Port 22/' /etc/ssh/sshd_config
  - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
  - sed -i -e '/^PasswordAuthentication/s/^.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - systemctl restart sshd
EOF

log " - Done."
}

create_full_user_data(){
log "📝 Create a full user-data file"

cat > user-data <<EOF
#cloud-config
hostname: ${VM_NAME}
fqdn: ${VM_NAME}
disable_root: false
users:
  - name: ${USER}
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: ${PASSWD}
    ssh_import_id:
      - gh:${GITHUB_USER}
  - name: ${VM_USER}
    gecos: system acct
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: ${PASSWD}
    ssh_authorized_keys:
      - ${VM_KEY}
write_files:
- path: /etc/netplan/99-my-new-config.yaml
  permissions: '0644'
  content: |
    network:
      ethernets:
        enp0s2:
          dhcp4: no
          dhcp6: no
          addresses: [${IP_ADDRESS}/24]
          routes:
            - to: default
              via: ${GATEWAY}
          mtu: 1500
          nameservers:
            addresses: [$DNS]
      renderer: networkd
      version: 2
apt:
  primary:
    - arches: [default]
      uri: http://us.archive.ubuntu.com/ubuntu/
  sources:
    kubectl.list:
      source: deb [arch=amd64] https://apt.kubernetes.io/ kubernetes-xenial main
      keyid: 59FE0256827269DC81578F928B57C5C2836F4BEB
    helm.list:
      source: deb https://baltocdn.com/helm/stable/debian/ all main
      keyid: 81BF832E2F19CD2AA0471959294AC4827C1A168A
package_update: ${UPDATE}
package_upgrade: ${UPGRADE}
packages:
  - neofetch
  - kubectl
  - wget
  - helm
  - htop
  - docker.io
  - build-essential
  - python3-pip
  - procps
  - file
  - ubuntu-drivers-common
  - xinit
  - xterm
  - xfce4
  - xfce4-goodies
  - x11vnc
runcmd:
  - mkdir -p /new_kernel
  - wget -O /new_kernel/linux-headers-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-headers-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb
  - wget -O /new_kernel/linux-headers-5.19.0-051900_5.19.0-051900.202207312230_all.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-headers-5.19.0-051900_5.19.0-051900.202207312230_all.deb
  - wget -O /new_kernel/linux-image-unsigned-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-image-unsigned-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb
  - wget -O /new_kernel/linux-modules-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-modules-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb
  - dpkg -i /new_kernel/*
  - apt-get purge linux-headers-5.15*
  - apt-get purge linux-image-5.15*
  - apt-get --purge autoremove
  - ubuntu-drivers autoinstall
  - wget https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  - chmox +x /install.sh
  - chmod 777 /install.sh
  - sudo -u ${VM_USER} NONINTERACTIVE=1 /bin/bash /install.sh
  - sudo -u ${VM_USER} /home/linuxbrew/.linuxbrew/bin/brew shellenv >> /home/${VM_USER}/.profile
  - sudo -u ${USER} /home/linuxbrew/.linuxbrew/bin/brew shellenv >> /home/${USER}/.profile
  - sudo -u ${USER} /home/linuxbrew/.linuxbrew/bin/brew install gotop krew
  - sudo -u ${USER} echo "export PATH=\"${PATH}:${HOME}/.krew/bin\"" > /home/${USER}/.bashrc 
  - reboot now
final_message: "Installation Completed."
EOF

log " - Done."
}

log() {
    echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}

# kill on error
die() {
        local MSG=$1
        local CODE=${2-1} # Bash parameter expansion - default exit status 1. See https://wiki.bash-hackers.org/syntax/pe#use_a_default_value
        log "${MSG}"
        exit "${CODE}"
}

main(){
create_ssh_key

if [ "$SLIM" == "true" ]; then
  create_slim_user_data
else
  #create_ansible_user_data
  create_full_user_data
fi
}

parse_params "$@"
main

