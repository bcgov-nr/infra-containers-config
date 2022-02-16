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

# Install Hashicorp Vault
# Reference: https://www.vaultproject.io/downloads, Linux tab, Ubuntu/Debian
# if ( ! ( which vault))
# then
#     curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
#     sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
#     sudo apt-get update && sudo apt-get install vault
# fi

# Vault vars
# export VAULT_ADDR="https://vault-iit.apps.silver.devops.gov.bc.ca"
# export VAULT_TOKEN="$(vault login -method=oidc -format json 2>/dev/null | jq -r '.auth.client_token')"
