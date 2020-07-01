#!/bin/bash
cp -rp /app/. /app-shared/

if [ -z "$ROLE" ]; then
  # Default to php-fpm service if not specified.
  export ROLE=php
fi


if [ "$ROLE" == "cron" ]; then
    exec /bin/busybox crond -f -c /etc/cron.d -L /dev/null
else
    exec /usr/sbin/php-fpm${PHPV} -F --fpm-config /etc/php/${PHPV}/fpm/php-fpm.conf
fi