#!/usr/bin/env bash

set -x


################################################################################
# Setup
################################################################################

mkdir -p webpack
pushd webpack > /dev/null


################################################################################
# Download Base Image
################################################################################

wget http://cdimage.ubuntu.com/ubuntu-base/releases/16.04.2/release/ubuntu-base-16.04-core-amd64.tar.gz


################################################################################
# Start Image Build
################################################################################

acbuild begin ./ubuntu-base-16.04-core-amd64.tar.gz
acbuild set-name woofwoofinc.dog/webpack


################################################################################
# Basic Development Tools
################################################################################

acbuild run -- apt-get update -qq
acbuild run -- apt-get upgrade -qq

acbuild run -- apt-get install -qq wget
acbuild run -- apt-get install -qq build-essential gcc
acbuild run -- apt-get install -qq git


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
# Travis
################################################################################

acbuild run -- apt-get install -qq ruby ruby-dev
acbuild run -- gem install --no-ri --no-rdoc travis travis-lint


################################################################################
# Image Processing
################################################################################

acbuild run -- apt-get install -qq imagemagick


################################################################################
# Node
################################################################################

NODE_VERSION=6.10.2

acbuild run -- wget -q https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz
acbuild run -- tar xJf node-v${NODE_VERSION}-linux-x64.tar.xz -C /usr/ --strip-components=1
acbuild run -- rm node-v${NODE_VERSION}-linux-x64.tar.xz


################################################################################
# Yarn
################################################################################

acbuild run -- wget -q https://yarnpkg.com/latest.tar.gz
acbuild run -- tar xzf latest.tar.gz -C /usr/ --strip-components=1
acbuild run -- rm latest.tar.gz


################################################################################
# Webpack
################################################################################

acbuild run -- yarn global add --no-progress webpack@2.2.1
acbuild run -- yarn global add --no-progress webpack-dev-server@2.2.1


################################################################################
# Firebase Tools
################################################################################

acbuild run -- npm install -g firebase-tools


################################################################################
# Finalise Image
################################################################################

acbuild run -- apt-get -qq autoclean
acbuild run -- apt-get -qq autoremove
acbuild run -- apt-get -qq clean

acbuild port add http tcp 8080
acbuild port add firebase tcp 5000

acbuild set-exec -- /bin/bash
acbuild write --overwrite webpack.aci

acbuild end


################################################################################
# Install Image
################################################################################

rkt --insecure-options=image fetch ./webpack.aci


################################################################################
# Cleanup
################################################################################

popd > /dev/null
rm -fr webpack
