#!/usr/bin/env bash

set -x


################################################################################
# Setup
################################################################################

mkdir -p jupyter
pushd jupyter > /dev/null


################################################################################
# Download Base Image
################################################################################

wget http://cdimage.ubuntu.com/ubuntu-base/releases/16.04.2/release/ubuntu-base-16.04-core-amd64.tar.gz


################################################################################
# Start Image Build
################################################################################

acbuild begin ./ubuntu-base-16.04-core-amd64.tar.gz
acbuild set-name woofwoofinc.dog/jupyter


################################################################################
# Basic Development Tools
################################################################################

acbuild run -- apt-get update -qq
acbuild run -- apt-get upgrade -qq

acbuild run -- apt-get install -qq wget
acbuild run -- apt-get install -qq bzip2


################################################################################
# Miniconda
################################################################################

acbuild run -- wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
acbuild run -- bash Miniconda3-latest-Linux-x86_64.sh -b -p /usr -f
acbuild run -- rm -fr Miniconda3-latest-Linux-x86_64.sh


################################################################################
# Python Data Science Stack
################################################################################

acbuild run -- conda install -y numpy matplotlib pandas scikit-learn jupyter


################################################################################
# PyTorch
################################################################################

acbuild run -- conda install -y pytorch torchvision -c soumith


################################################################################
# Set Image Executable
################################################################################

acbuild run -- mkdir -p /home/jupyter
acbuild port add http tcp 80
acbuild set-exec -- \
    jupyter notebook --no-browser --allow-root --ip='*' --port=80 --notebook-dir=/home/jupyter --NotebookApp.token=''


################################################################################
# Finalise Image
################################################################################

acbuild run -- apt-get -qq autoclean
acbuild run -- apt-get -qq autoremove
acbuild run -- apt-get -qq clean

acbuild write --overwrite jupyter.aci

acbuild end


################################################################################
# Install Image
################################################################################

rkt --insecure-options=image fetch ./jupyter.aci


################################################################################
# Cleanup
################################################################################

popd > /dev/null
rm -fr jupyter
