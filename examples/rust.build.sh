#!/usr/bin/env bash

set -x


################################################################################
# Setup
################################################################################

mkdir -p rust
cd rust


################################################################################
# Download Base Image
################################################################################

wget http://cdimage.ubuntu.com/ubuntu-base/releases/16.04.2/release/ubuntu-base-16.04-core-amd64.tar.gz


################################################################################
# Start Image Build
################################################################################

acbuild begin ./ubuntu-base-16.04-core-amd64.tar.gz
acbuild set-name woofwoofinc.dog/rust


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
# Rust
################################################################################

acbuild run -- apt-get install -qq curl graphviz cmake libssl-dev

acbuild run -- curl -sSf https://sh.rustup.rs -o rustup.sh
acbuild run -- sh rustup.sh -y
acbuild run -- rm rustup.sh

acbuild run -- /root/.cargo/bin/cargo install rustfmt
acbuild run -- /root/.cargo/bin/cargo install cargo-watch
acbuild run -- /root/.cargo/bin/cargo install cargo-outdated
acbuild run -- /root/.cargo/bin/cargo install cargo-graph
acbuild run -- /root/.cargo/bin/cargo install cargo-modules
acbuild run -- /root/.cargo/bin/cargo install cargo-count

acbuild run -- /root/.cargo/bin/rustup install nightly
acbuild run -- /root/.cargo/bin/rustup run nightly cargo install clippy


################################################################################
# Finalise Image
################################################################################

acbuild run -- apt-get -qq autoclean
acbuild run -- apt-get -qq autoremove
acbuild run -- apt-get -qq clean

acbuild set-exec -- /bin/bash
acbuild write --overwrite rust.aci

acbuild end


################################################################################
# Install Image
################################################################################

rkt --insecure-options=image fetch ./rust.aci


################################################################################
# Cleanup
################################################################################

cd ..
rm -fr rust
