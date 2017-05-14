#!/bin/bash

WORKING_DIR=~/.rktmachine
RESOURCES_DIR=$(cat "${WORKING_DIR}/resources_path")


cat "${WORKING_DIR}/motd"

# Have to be in ${WORKING_DIR} for the cloud-init relative file link in the
# rktmachine.toml file to be correct.
cd ${WORKING_DIR} || exit

"${RESOURCES_DIR}/bin/corectl" load "${WORKING_DIR}/rktmachine.toml"

echo " "
read -r -p 'Press [Enter] to continue.'
