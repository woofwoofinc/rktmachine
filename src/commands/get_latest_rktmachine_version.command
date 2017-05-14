#!/bin/bash

RKTMACHINE_VERSION=$(
  curl -Ss https://api.github.com/repos/woofwoofinc/rktmachine/releases |
    grep "tag_name" |
    awk '{ print $2 }' |
    sed -e 's/"\(.*\)"./\1/' |
    head -1
)

echo "${RKTMACHINE_VERSION}"
