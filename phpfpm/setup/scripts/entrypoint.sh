#!/bin/bash
# Create directories if they don't exist otherwise container wont run.
[[ -d /nhsla/etc ]] || mkdir -p /nhsla/etc
# Copy configs from RO directory to writable one (when using K8s)
cp /setup/config/* /nhsla/etc/
# Configure during runtime
source /setup/scripts/setup.sh

# Move application into shared storage if AWS_HOST_ENVIRONMENT is set
#    it's likely we're running in our kube environment in this case.
if [ ! -z "$AWS_HOST_ENVIRONMENT" ]; then
  cp -rp /app/. /app-shared/
fi

if [ -f /nhsla/startup-all.sh ]; then
    source /nhsla/startup-all.sh
fi

if [ -f /nhsla/startup-php.sh ]; then
    source /nhsla/startup-php.sh
fi

if { [ -f /nhsla/startup-cron.sh ] ; } && { [ "$ROLE" == "cron" ] || [ "$ROLE" == "CRON" ] ; } ; then
    source /nhsla/startup-cron.sh
fi

# Start the service
if [ "$ROLE" == "CRON" ]; then
    exec /usr/local/bin/supercronic -debug -overlapping -split-logs /nhsla/cron 1>/dev/stdout
else
    exec /usr/sbin/php-fpm${PHP_VERSION} -F --fpm-config /etc/php/${PHP_VERSION}/fpm/php-fpm.conf
fi
