#!/bin/bash

WORKING_DIR=~/.rktmachine
RESOURCES_DIR=$(cat "${WORKING_DIR}/resources_path")


cat "${WORKING_DIR}/motd"

"${RESOURCES_DIR}/bin/corectl" ssh rktmachine
