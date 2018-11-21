#!/usr/bin/env bash
#The script will create the nfs shares in the nfs vm

set -eu
set -o pipefail
set -o nounset

OLDPWD=$PWD
_ME=$(basename "${0}")

#Usage loop.
usage() {
    cat <<DOC

The script will create a nfs share for openshift purpose.

Usage:
  $_ME exportname
    Give the exportname to be created in the NFS.

Options:
  -h, --help to show this screen.
DOC
}

#If the no of arguments passed while executing the script are null.
if [[ $# -eq 0 ]] ; then
  usage
  exit 0
elif [[ ( $# == "--help") ||  $# == "-h" ]]; then
  usage
  exit 0
else
  echo "NFS share with name $1 will be created."
  sudo mkdir -p "$1"
  sudo sh -c "echo '$1 *(rw,root_squash)' >> /etc/exports.d/openshift.exports"
  exportfs -ar
  echo "New nfs share created"
  showmount -e localhost
fi
