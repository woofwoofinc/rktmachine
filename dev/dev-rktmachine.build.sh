#!/usr/bin/env bash

set -xe


################################################################################
# Setup
################################################################################

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP_DIR="$(mktemp -d -p "$DIR" dev-rktmachine.XXXXXX)"
pushd "$TMP_DIR" > /dev/null


################################################################################
# Download Base Image
################################################################################

wget http://cdimage.ubuntu.com/ubuntu-base/releases/16.04/release/ubuntu-base-16.04.3-base-amd64.tar.gz


################################################################################
# Start Image Build
################################################################################

acbuild begin ./ubuntu-base-16.04.3-base-amd64.tar.gz
acbuild set-name woofwoofinc.dog/dev-rktmachine


################################################################################
# Basic Development Tools
################################################################################

acbuild run -- apt-get update -qq
acbuild run -- apt-get upgrade -qq

acbuild run -- apt-get install -qq wget
acbuild run -- apt-get install -qq build-essential


################################################################################
# Sphinx
################################################################################

# Python pip is in Ubuntu universe.
acbuild run -- apt-get install -qq software-properties-common
acbuild run -- apt-add-repository universe
acbuild run -- apt-get update -qq

acbuild run -- apt-get install -qq python2.7
acbuild run -- apt-get install -qq python-pip
acbuild run -- pip install -q --upgrade pip

acbuild run -- pip install -q Sphinx
acbuild run -- pip install -q sphinx_bootstrap_theme


################################################################################
# QEMU
################################################################################

# QEMU is also in Ubuntu universe.
acbuild run -- apt-get install -qq qemu


################################################################################
# Go
################################################################################

GO_VERSION=1.8.3

acbuild run -- apt-get install -qq git

acbuild run -- wget -q https://storage.googleapis.com/golang/go${GO_VERSION}.linux-amd64.tar.gz
acbuild run -- tar -xzf go${GO_VERSION}.linux-amd64.tar.gz -C /usr/local
acbuild run -- rm go${GO_VERSION}.linux-amd64.tar.gz

acbuild run -- ln -s /usr/local/go/bin/go /usr/bin/go


################################################################################
# Skopeo Build
################################################################################

acbuild run -- apt-get install -qq btrfs-tools libglib2.0-dev libgpgme11-dev


################################################################################
# Avahi Build
################################################################################

acbuild run -- apt-get install -qq autoconf gettext intltool libtool
acbuild run -- apt-get install -qq libexpat1-dev libdaemon-dev pkg-config shtool


################################################################################
# Finalise Image
################################################################################

acbuild run -- apt-get -qq autoclean
acbuild run -- apt-get -qq autoremove
acbuild run -- apt-get -qq clean

acbuild set-exec -- /bin/bash
acbuild write --overwrite ../dev-rktmachine.aci

acbuild end


################################################################################
# Teardown
################################################################################

popd > /dev/null
rm -fr "$TMP_DIR"
