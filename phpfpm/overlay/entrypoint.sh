#!/bin/bash

# Runtime configuration
source /setup/scripts/setup.sh

# Move application into shared storage if AWS_HOST_ENVIRONMENT is set
#    it's likely we're running in our kube environment in this case.
if [ ! -z "$AWS_HOST_ENVIRONMENT" ]; then
  cp -rp /app/. /app-shared/
fi

if [ -f /startup-all.sh ]; then
    source /startup-all.sh
fi

if [ -f /startup-php.sh ]; then
    source /startup-php.sh
fi

if { [ -f /startup-cron.sh ] ; } && { [ "$ROLE" == "cron" ] || [ "$ROLE" == "CRON" ] ; } ; then
    source /startup-cron.sh
fi

# Start the service
if [ "$ROLE" == "CRON" ]; then
    exec /usr/local/bin/supercronic -split-logs /crontab 1>/dev/stdout
else
    exec /usr/sbin/php-fpm${PHP_VERSION} -F --fpm-config /etc/php/${PHP_VERSION}/fpm/php-fpm.conf
fi
