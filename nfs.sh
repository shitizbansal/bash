#!/usr/bin/env bash

#The script will create the nfs shares in the nfs vm

set -eu
set -o pipefail
set -o nounset

OLDPWD=$PWD
_ME=$(basename "${0}")

#Usage loop.
usage() {
    cat <<HEREDOC

The script will create a nfs share inside the /nfsexports directory.

Usage:
  $_ME exportname
    Give the exportname to be created in the NFS.

Options:
  -h Show this screen.
HEREDOC
}


while getopts ":h" opt ; do
  case $opt in
    h | *)
      usage
      ;;
  esac
done


#If the no of arguments passed while executing the script are null.
if [[ $# -eq 0 ]] ; then
  usage
else
  echo "NFS share with name $1 will be created "
  sudo mkdir -p /nfsexports/$exportname
  sudo sh -c "echo '/nfsexports/${exportname} *(rw,root_squash)' >> /etc/exports"
  exportfs -ar
fi


echo "New nfs share created"
showmount -e localhost
