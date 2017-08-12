#!/usr/bin/env bash

set -x


################################################################################
# Setup
################################################################################

mkdir -p dev-rktmachine
pushd dev-rktmachine > /dev/null


################################################################################
# Download Base Image
################################################################################

wget http://cdimage.ubuntu.com/ubuntu-base/releases/16.04.3/release/ubuntu-base-16.04-core-amd64.tar.gz


################################################################################
# Start Image Build
################################################################################

acbuild begin ./ubuntu-base-16.04-core-amd64.tar.gz
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
# acbuild Master Build
################################################################################

acbuild run -- apt-get install -qq git
acbuild run -- apt-get install -qq golang


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
acbuild write --overwrite dev-rktmachine.aci

acbuild end


################################################################################
# Install Image
################################################################################

rkt --insecure-options=image fetch ./dev-rktmachine.aci


################################################################################
# Cleanup
################################################################################

popd > /dev/null
rm -fr dev-rktmachine
