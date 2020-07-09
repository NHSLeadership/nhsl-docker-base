#!/bin/bash
# Create directories if they don't exist otherwise container wont run.
[[ -d /nhsla/config ]] || mkdir -p /nhsla/config
[[ -d /nhsla/run ]] || mkdir -p /nhsla/run
mkdir -p /tmp/openresty
# Copy configs from RO directory to writable one (when using K8s)
cp /setup/* /nhsla/config/
# Configure during runtime
source /setup/scripts/setup.sh

if [ -f /nhsla/scripts/startup-all.sh ]; then
    source /nhsla/scripts/startup-all.sh
fi

if [ -f /nhsla/scripts/startup-web.sh ]; then
    source /nhsla/scripts/startup-web.sh
fi

# Move application into shared storage if AWS_HOST_ENVIRONMENT is set
#    it's likely we're running in our kube environment in this case.
if [ ! -z "$AWS_HOST_ENVIRONMENT"]; then
  cp -rp /app/. /app-shared/
fi


echo "Starting OpenResty..."
exec "$@"