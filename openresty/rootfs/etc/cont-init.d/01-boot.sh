#!/bin/bash

with-contenv

# Create directories if they don't exist otherwise container wont run.

#[[ -d /nhsla/etc ]] || mkdir -p /nhsla/etc
mkdir -p /tmp/openresty

if [ ! -z "$AWS_HOST_ENVIRONMENT" ]; then
  cp -rp /app/. /app-shared/
fi
