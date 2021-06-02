#!/usr/bin/with-contenv bash

# Create directories if they don't exist otherwise container wont run.
[[ -d /nhsla/etc ]] || mkdir -p /nhsla/etc

# Copy configs from RO directory to writable one (when using K8s)
cp /nhsla/setup/* /nhsla/etc/

if [ ! -z "$AWS_HOST_ENVIRONMENT" ]; then
  cp -rp /app/. /app-shared/
fi

# Start the service
#if [ "$ROLE" == "CRON" ]; then
#    exec /usr/local/bin/supercronic -debug -overlapping -split-logs /nhsla/cron 1>/dev/stdout
#else
#    exec /usr/sbin/php-fpm${PHP_VERSION} -F --fpm-config /etc/php/${PHP_VERSION}/fpm/php-fpm.conf
#fi
