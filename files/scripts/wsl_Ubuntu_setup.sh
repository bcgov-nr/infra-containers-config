#!/bin/bash

# Install Ansible, if it is not already
if ( ! ( which ansible))
then
    sudo apt install ansible -y
fi

# Install sshpass, if it is not already
if ( ! ( which sshpass))
then
    sudo apt install sshpass -y
fi

# Install the podman plugin
ansible-galaxy collection install containers.podman

# Capture the SSH and OCIO Artifactory account information, to be encrypted & consumed by Ansible-Vault
./vault_setup.sh