#!/bin/bash

# vault_setup.sh
#
# This script will automatically create an Ansible vault file to be used with 
# playbooks.
# 
# ----------------------------------------------------------------------------


VAULTDIR=~/.vault
VAULTFILE=$VAULTDIR/vault.yml
VAULTPASS=$VAULTDIR/.pass
NOVAULT=$VAULTDIR/no_vault
NOCLEANUP=$VAULTDIR/no_cleanup


# Do nothing if the user has opted to not set up the vault file
# -------------------------------------------------------------
if [ -e $NOVAULT ]; then exit 0; fi

# Exit if the user has opted out of automatic file recreation upon each login
# ---------------------------------------------------------------------------
if [ -e $NOCLEANUP -a -e $VAULTFILE -a -e $VAULTPASS ]; then

  exit 0

else

  if [ ! -d $VAULTDIR ]; then mkdir $VAULTDIR; fi

  # Allow the user to opt out of vault file setup
  # ---------------------------------------------
  printf "\nPerform Ansible setup? [Y,n] "
  read choice
  choice=`echo "$choice" | tr '[:upper:]' '[:lower:]'`
  case "$choice" in
    n|no)
      touch $NOVAULT
      exit 0
      ;;
    *)
      printf "\nCreating Ansible vault file...\n"
      ;;
  esac

  # Prompt for credentials
  # ----------------------
  printf "Enter the IDIR account you use for server admin (e.g., wgretzky_a): "
  read server_admin_username

  printf "Enter server admin IDIR password: "
  read -s server_admin_password

  printf "\nEnter the service account you use for OCIO Artifactory if different than above (e.g. wgretzky - leave blank if unknown): "
  read artifactory_username

  printf "Enter OCIO Artifactory service account password (leave blank if unknown): "
  read -s artifactory_password

  # Create vault and password files
  # -------------------------------
  printf "\n\nCreating ANSIBLE_VAULT_PASSWORD_FILE...\n"
  # printf "artifactory_username: $artifactory_username\nartifactory_password: $artifactory_password\nssh_user: $server_admin_username\nssh_pass: $server_admin_password\nssh_dmz_user: IDIR\\$server_admin_username\nssh_dmz_pass: $server_admin_password\nwindows_user: $server_admin_username@IDIR.BCGOV\nwindows_pass: $server_admin_password\nansible_become_pass: $server_admin_password\n" > $VAULTFILE
  printf "ssh_user: $server_admin_username\nssh_pass: $server_admin_password\nansible_become_pass: $server_admin_password\nartifactory_username: $artifactory_username\nartifactory_password: $artifactory_password\n" > $VAULTFILE  

  # Generate a random vault password and save it to a file
  # ------------------------------------------------------
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-12} | head -n 1 > $VAULTPASS
  chmod 600 $VAULTPASS
  printf "\nSetting environment variable ANSIBLE_VAULT_PASSWORD_FILE...\n\n"
  export ANSIBLE_VAULT_PASSWORD_FILE=$VAULTPASS

  # Encrypt the vault file
  # ----------------------
  ansible-vault encrypt $VAULTFILE

  # Give the user the option to override file recreation on each login
  # ------------------------------------------------------------------
  printf "\nRecreate vault files at each login? [Y,n] "
  read choice
  choice=`echo "$choice" | tr '[:upper:]' '[:lower:]'`
  case "$choice" in
    n|no) touch $NOCLEANUP;;
    *) ;;
  esac

  printf "\nDone\n"
fi
