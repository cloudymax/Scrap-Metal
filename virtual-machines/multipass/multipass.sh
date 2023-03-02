#!/bin/bash

set -o nounset
set -o pipefail

#program verbosity
export VERBOSITY="-vvvvv"
export DEBUG="true"
export SQUASH="false"

# Virtual Machine Configuration
export VM_NAME="test"
export VM_IMAGE="jammy"
export VM_CPUS="4"
export VM_DISK="32G"
export VM_MEM="4G"
export VM_IP="none"
export VM_USER="max"
export VM_KEY=""
export VM_IP=""
export SSH_PORT="22"

# temporary files
export VM_INIT="cloud-init.yaml"
export VM_KEY_FILE="$(pwd)/$VM_USER"

create_ssh_key(){
# create a ssh key for the user and save as a file w/ prompt
    yes | ssh-keygen -C "$VM_USER" \
        -f "$VM_KEY_FILE" \
        -N '' \
        -t rsa \
	-q
}

push_ssh_key(){
    scp -i $VM_KEY_FILE $VM_KEY_FILE $VM_USER@$REMOTE_HOST:~/.ssh/authorized_keys
}

load_ssh_key(){
# return the absolute path of the key file
    VM_KEY_FILE=$(find "$(cd ..; pwd)" -wholename $(pwd)/$VM_USER)
    VM_KEY=$(cat "$VM_KEY_FILE".pub)
}

create_cloud_init(){
# write a cloud-init file that provisions the base VM/container etc..
load_ssh_key
    cat << EOF > ${VM_INIT}
#cloud-config
groups:
  - docker
users:
  - default
  - name: ${VM_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    groups: docker, admin, sudo, users
    no_ssh_fingerprints: true
    ssh-authorized-keys:
      - ${VM_KEY}
packages:
  - docker.io
  - docker-compose
runcmd:
  - [ sed , -i , "s/#Port 22/Port ${SSH_PORT}/g" , /etc/ssh/sshd_config ]
  - [ sed , -i , "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" , /etc/ssh/sshd_config ]
EOF
}

clear_multipass() {
# delete hanging vms

    VM_LIST=$(multipass list --format json |jq '.list[].name' )
    TARGET_PRESENT=$(echo $VM_LIST |grep -c "$VM_NAME")

    if [[ "$TARGET_PRESENT" -gt "0" ]]; then

	VM_IP=$(multipass list --format json \
		|jq --arg VM_NAME "$VM_NAME" '.list[]
		| select(.name==$VM_NAME)
		| .ipv4[0]' -r)

	multipass stop "$VM_NAME"
        multipass delete "$VM_NAME"
    	multipass purge
    	# sudo snap restart multipass
    	sleep 2
    	ssh-keygen -R $VM_IP
    else
	echo "VM $VM_NAME does not exist. Skipping."
    fi

}

create_vm(){
# provision the base VM in a new tmux session
    EXISTS=$(tmux list-sessions |grep -c "${VM_NAME}_boot_session")

    if [[ "$EXISTS" -gt "0" ]]; then

	echo "Session Exists."
    else
	tmux new-session -d -s "${VM_NAME}_boot_session"
	sleep 3
	EXISTS=$(tmux list-sessions |grep -c "${VM_NAME}_boot_session")

	if [[ "$EXISTS" == "1" ]]; then
            tmux send-keys -t "${VM_NAME}_boot_session" ENTER "multipass launch --name $VM_NAME \
            --cpus $VM_CPUS \
            --disk $VM_DISK \
            --mem $VM_MEM \
            $VM_IMAGE \
            --cloud-init $VM_INIT \
            --timeout 300 \
            $VERBOSITY" ENTER
	fi
    fi

#tmux attach-session -t "${VM_NAME}_session"
}

set_vm_ip(){
# grab the new VM's IP

  IP_READY=0
  START=$(date +%s)
  NOW=0
  END=0
  DURATION=0


  echo "waiting for VM's ip-address to become available..."

  while [ "${IP_READY}" == "0" ]
  do

    VM_IP=$(multipass list --format json \
                |jq --arg VM_NAME "$VM_NAME" '.list[]
                | select(.name==$VM_NAME)
                | .ipv4[0]' -r)

    if [[ $VM_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      IP_READY=1
      END=$(date +%s)
    else
      NOW=$(date +%s)
      DURATION=$(($NOW - $START))
      #echo "Duration: ${DURATION}"
      SCREEN=$(tmux capture-pane -t "${VM_NAME}_boot_session" -p)
      STATUS=$(echo "$SCREEN" |tail -1)
      echo -ne "$STATUS \033[0K\r"
    fi
  done

  DURATION=$(($END - $START))
  echo "VM Ready at ${VM_IP}. Ran in ${DURATION}"
  tmux kill-session -t "${VM_NAME}_boot_session"
}

ssh_to_vm(){
# open a ssh connections into the VM
    VM_IP=$(multipass list |grep "${VM_NAME}" |awk '{print $3}')
    load_ssh_key

    ssh -i $VM_KEY_FILE \
        $VM_USER@$VM_IP \
        -o StrictHostKeyChecking=no \
        -p $SSH_PORT \
        -t \
        /bin/bash
}

watch_cloud_init(){
    EXISTS=$(tmux list-sessions |grep -c "$VM_NAME"_logs_session)

    if [[ "$EXISTS" -gt "0" ]]; then

	echo "Session Exists."
    else
	tmux new-session -d -s "${VM_NAME}_logs_session"
	sleep 1
	EXISTS=$(tmux list-sessions |grep -c "$VM_NAME")

	if [[ "$EXISTS" == "1" ]]; then
            tmux send-keys -t "${VM_NAME}_logs_session" ENTER "ssh -i $VM_KEY_FILE \
            $VM_USER@$VM_IP \
            -o StrictHostKeyChecking=no \
            -p $SSH_PORT \
            -t \
            sudo tail -f /var/log/cloud-init-output.log" ENTER
	fi
    fi


  READY=0
  echo "Watching cloud-init progress:"
  sleep 2

  while [ "${READY}" == "0" ]
  do
      SCREEN=$(tmux capture-pane -t "${VM_NAME}_logs_session" -p)
      READY_CHECK=$(echo "$SCREEN" |grep -c "Cloud-init v.")
      TEXT=$(echo "$SCREEN" |tail -1)

      if [[ "$READY_CHECK" == "1" ]]; then
        READY=1
      else
        echo -ne "$TEXT \033[0K\r"
      fi
  done

  echo "Cloud-init finished."
  tmux kill-session -t "${VM_NAME}_logs_session"
}

start(){
# main program
    create_ssh_key
    create_cloud_init
    clear_multipass
    create_vm
    set_vm_ip
    watch_cloud_init
    ssh_to_vm
}

stop(){
  clear_multipass
}

connect(){
  set_vm_ip
  ssh_to_vm
}

"$@"

