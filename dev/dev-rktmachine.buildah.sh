#!/usr/bin/env bash

set -xe


################################################################################
# Setup
################################################################################

IMAGE=dev-rktmachine
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP_DIR="$(mktemp -d -p "$DIR" $IMAGE.XXXXXX)"
pushd "$TMP_DIR" > /dev/null


################################################################################
# Start Image Build
################################################################################

buildah from scratch --name $IMAGE


################################################################################
# Base Image
################################################################################

wget http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04-base-amd64.tar.gz

MOUNT=$(buildah mount $IMAGE)
tar xzf ubuntu-base-18.04-base-amd64.tar.gz -C "$MOUNT"
buildah umount $IMAGE


################################################################################
# Basic Development Tools
################################################################################

buildah run $IMAGE -- apt-get update -qq
buildah run $IMAGE -- apt-get upgrade -qq

buildah run $IMAGE -- apt-get install -qq wget
buildah run $IMAGE -- apt-get install -qq build-essential
buildah run $IMAGE -- apt-get install -qq git


################################################################################
# Sphinx
################################################################################

# Python pip is in Ubuntu universe.
buildah run $IMAGE -- apt-get install -qq software-properties-common
buildah run $IMAGE -- apt-add-repository universe
buildah run $IMAGE -- apt-get update -qq

buildah run $IMAGE -- apt-get install -qq python2.7
buildah run $IMAGE -- apt-get install -qq python-pip
buildah run $IMAGE -- pip install -q --upgrade pip==9.0.3

buildah run $IMAGE -- pip install -q Sphinx
buildah run $IMAGE -- pip install -q sphinx_bootstrap_theme


################################################################################
# QEMU
################################################################################

# QEMU is also in Ubuntu universe.
buildah run $IMAGE -- apt-get install -qq qemu


################################################################################
# Go 1.8
################################################################################

buildah run $IMAGE -- apt-get install -qq golang-1.8 go-md2man
buildah run $IMAGE -- update-alternatives --install /usr/bin/go go /usr/lib/go-1.8/bin/go 1


################################################################################
# Buildah Build
################################################################################

buildah run $IMAGE -- apt-get install -qq btrfs-tools gpgsm libassuan-dev
buildah run $IMAGE -- apt-get install -qq libapparmor-dev libgpg-error-dev
buildah run $IMAGE -- apt-get install -qq libseccomp-dev


################################################################################
# Skopeo Build
################################################################################

buildah run $IMAGE -- apt-get install -qq libglib2.0-dev


################################################################################
# Avahi Build
################################################################################

buildah run $IMAGE -- apt-get install -qq autoconf gettext intltool libtool
buildah run $IMAGE -- apt-get install -qq libexpat1-dev pkg-config shtool


################################################################################
# Finalise Image
################################################################################

buildah run $IMAGE -- apt-get -qq autoremove
buildah run $IMAGE -- apt-get -qq clean

echo "nameserver 8.8.8.8" > resolv.conf
buildah copy $IMAGE resolv.conf /etc/resolv.conf

buildah config $IMAGE --entrypoint /bin/bash

buildah commit -rm $IMAGE $IMAGE


################################################################################
# Output Image
################################################################################

buildah push $IMAGE oci:$IMAGE:latest
tar cf ../$IMAGE.oci -C $IMAGE .


################################################################################
# Teardown
################################################################################

buildah rmi $IMAGE

popd > /dev/null
rm -fr "$TMP_DIR"
