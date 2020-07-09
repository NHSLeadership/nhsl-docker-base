#!/bin/bash
# Create directories if they don't exist otherwise container wont run.
[[ -d /nhsla/config ]] || mkdir -p /nhsla/config
[[ -d /nhsla/run ]] || mkdir -p /nhsla/run
# Copy configs from RO directory to writable one (when using K8s)
cp /setup/config/* /nhsla/config/
# Configure during runtime
source /setup/setup.sh

if [ -f /setup/scripts/startup-all.sh ]; then
    source /setup/scripts/startup-all.sh
fi

if [ -f /setup/scripts/startup-php.sh ]; then
    source /setup/scripts/startup-php.sh
fi

if [ [ -f /setup/scripts/startup-cron.sh ] && [ "$ROLE" == "cron" || "$ROLE" == "CRON" ] ]; then
    source /setup/scripts/startup-cron.sh
fi


# Move application into shared storage if AWS_HOST_ENVIRONMENT is set
#    it's likely we're running in our kube environment in this case.
if [ ! -z "$AWS_HOST_ENVIRONMENT"]; then
  cp -rp /app/. /app-shared/
fi

# Start the service
if [ "$ROLE" == "cron" || "$ROLE" == "CRON"]; then
    exec /usr/local/bin/supercronic -split-logs /nhsla/cron 1>/dev/stdout
else
    exec /usr/sbin/php-fpm${PHP_VERSION} -F --fpm-config /etc/php/${PHP_VERSION}/fpm/php-fpm.conf
fi