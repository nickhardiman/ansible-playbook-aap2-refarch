#!/usr/bin/bash -x
#-------------------------
# Set up each hypervisor.
#
# Prerequisites
# 
#-------------------------
# Description
#
#-------------------------
# Instructions
#
#-------------------------
# Variables
#
source ./aap-lab-bootstrap.cfg
#
#-------------------------
# functions
#
does_ansible_user_exist() {
     ansible_user_exists=false
     id $USER_ANSIBLE_NAME
     res_id=$?
     if [ $res_id -eq 0 ]
     then
       ansible_user_exists=true
     fi
}


# Create the $USER_ANSIBLE_NAME account (not using --system). 
setup_local_ansible_user_account() {
    log_this "add an Ansible user account"
     sudo useradd $USER_ANSIBLE_NAME
}


setup_ansible_user_keys() {
    log_this "Create a new keypair. Put keys in /home/$USER_ANSIBLE_NAME/.ssh/ and keep copies in /home/nick/.ssh/"
    ssh-keygen -f ./ansible-key -C "$USER_ANSIBLE_NAME@installer" -q -N ""
    mv ansible-key  ansible-key.priv
    # Copy the keys to $USER_ANSIBLE_NAME's SSH config directory. 
    sudo mkdir                               /home/$USER_ANSIBLE_NAME/.ssh
    sudo chmod 0700                          /home/$USER_ANSIBLE_NAME/.ssh
    sudo cp ansible-key.priv                 /home/$USER_ANSIBLE_NAME/.ssh/id_rsa
    sudo chmod 0600                          /home/$USER_ANSIBLE_NAME/.ssh/id_rsa
    sudo cp ansible-key.pub                  /home/$USER_ANSIBLE_NAME/.ssh/id_rsa.pub
    sudo cp $HOME/.ssh/known_hosts           /home/$USER_ANSIBLE_NAME/.ssh/known_hosts
    sudo chmod 0600                          /home/$USER_ANSIBLE_NAME/.ssh/known_hosts
    sudo chown -R $USER_ANSIBLE_NAME:$USER_ANSIBLE_NAME  /home/$USER_ANSIBLE_NAME/.ssh
    # Keep a spare set of keys handy. 
    # This location is set in ansible.cfg. 
    # private_key_file = /home/nick/.ssh/ansible-key.priv
    # Copy the keys to your SSH config directory. 
    cp ansible-key.priv  ansible-key.pub  $HOME/.ssh/
    # Clean up.
    # rm ansible-key.priv  ansible-key.pub
}


# These RPMs add files to 
#   /usr/share/ansible/roles/rhel-system-roles.*/
#   /usr/lib/python3.9/site-packages/ansible/
# and elsewhere.
#
# !!! how about installing the CLI tool "awx"?
# reference
#   https://docs.ansible.com/automation-controller/latest/html/controllercli/index.html
# install
#   sudo dnf --enablerepo=ansible-automation-platform-2.4-for-rhel-9-x86_64-rpms  install automation-controller-cli
#
# !!! how about ansible-lint and other tools?
# reference
#   https://github.com/nickhardiman/articles-ansible/blob/main/modules/use-ansible-tools/pages/index.adoc
# install
#   dnf --enablerepo=ansible-automation-platform-2.4-for-rhel-9-x86_64-rpms install ansible-lint
#
install_ansible_packages() {
     log_this "install Ansible"
     sudo dnf install --assumeyes ansible-core rhel-system-roles
}


# I'm not using ansible-galaxy because I make frequent changes.
# Check out the directive in ansible.cfg in some playbooks.
# If the repo has already been cloned, git exits with this error message. 
#   fatal: destination path 'libvirt-host' already exists and is not an empty directory.
#
clone_my_ansible_collections() {
    log_this "get my libvirt, OS and app roles, all bundled into a couple collections"
    mkdir -p $HOME/ansible/collections/ansible_collections/nick/
    pushd    $HOME/ansible/collections/ansible_collections/nick/
    # !!! when finished, move to requirements.yml 
    #   - git+https://github.com/nickhardiman/ansible-collection-aap2-refarch
    # !!! hacked copy of ansible-collection-platform
    # ansible-collection-aap2-refarch is a temporary copy of ansible-collection-platform
    # git clone https://github.com/nickhardiman/ansible-collection-platform.git platform
    git clone https://github.com/nickhardiman/ansible-collection-aap2-refarch.git platform
    git clone https://github.com/nickhardiman/ansible-collection-app.git      app
    popd
}


clone_my_ansible_playbook() {
     log_this "get my playbook"
     mkdir -p $HOME/ansible/playbooks/
     pushd    $HOME/ansible/playbooks/
     git clone https://github.com/nickhardiman/ansible-playbook-aap2-refarch.git aap-refarch
     # cd ansible-playbook-$LAB_BUILD_NET_SHORT_NAME/
     popd
}


download_ansible_libraries() {
    log_this "install collections and roles from Ansible Galaxy and from Ansible Automation Hub"
    # Ansible Galaxy - https://galaxy.ansible.com
    # Ansible Automation Hub - https://console.redhat.com/ansible/automation-hub
    # Installing from Ansible Automation Hub requires the env var 
    # ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN.
    # install Ansible libvirt collection to the central location.
    sudo ansible-galaxy collection install community.libvirt \
        --collections-path /usr/share/ansible/collections
    # check 
    ls /usr/share/ansible/collections/ansible_collections/community/
    # Install other collections to ~/.ansible/collections/
    # (https://github.com/nickhardiman/ansible-playbook-build/blob/main/ansible.cfg#L13)
    cd ~/ansible/playbooks/aap-refarch/
    ansible-galaxy collection install -r collections/requirements.yml 
    # Install roles. 
    ansible-galaxy role install -r roles/requirements.yml 
}


distribute_ansible_user_RSA_pubkey() {
     USER_ANSIBLE_PUBLIC_KEY=$(<$HOME/.ssh/ansible-key.pub)
    log_this "copy $USER_ANSIBLE_NAME RSA public key from here to machines for passwordless login"
    for NAME in host.site1.example.com host.site2.example.com host.site3.example.com
    do
        ssh $USER@$NAME << EOF
            sudo --user=$USER_ANSIBLE_NAME mkdir /home/$USER_ANSIBLE_NAME/.ssh
            sudo --user=$USER_ANSIBLE_NAME chmod 0700 /home/$USER_ANSIBLE_NAME/.ssh
            sudo --user=$USER_ANSIBLE_NAME touch /home/$USER_ANSIBLE_NAME/.ssh/authorized_keys
            sudo grep -qxF "$USER_ANSIBLE_PUBLIC_KEY" /home/$USER_ANSIBLE_NAME/.ssh/authorized_keys || echo "$USER_ANSIBLE_PUBLIC_KEY" | sudo tee -a /home/$USER_ANSIBLE_NAME/.ssh/authorized_keys
EOF
    done
}


log_this () {
    echo
    echo -n $(date)
    echo "  $1"
}


#-------------------------
# main

cd $WORK_DIR || exit 1
does_ansible_user_exist
if $ansible_user_exists 
then
    log_this "ansible user already exists"
else
    setup_local_ansible_user_account
    setup_ansible_user_keys
fi
install_ansible_packages
clone_my_ansible_collections
clone_my_ansible_playbook
download_ansible_libraries
