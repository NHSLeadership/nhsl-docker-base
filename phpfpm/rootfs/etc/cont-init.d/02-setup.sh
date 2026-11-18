#!/command/with-contenv bash

#####
# Email relay configuration
#####
if [ -z "$MAIL_HOST" ]; then
         export MAIL_HOST=outbound.kube-mail
fi

if [ -z "$MAIL_PORT" ]; then
    export MAIL_PORT=25
fi

if [ -z "$MAIL_ROOT" ]; then
    export MAIL_ROOT=devops@nhsx.uk
fi

echo "mailhub=$MAIL_HOST:$MAIL_PORT" >> /nhsla/etc/ssmtp.conf
echo "root=$MAIL_ROOT" >> /nhsla/etc/ssmtp.conf
echo "FromLineOverride=YES" >> /nhsla/etc/ssmtp.conf
#####

#####
# Email relay configuration
#####
if [ -n "$REDIS_SESSIONS" ]; then
    if [ -z "$REDIS_HOST" ]; then
      export REDIS_HOST="redis:6379"
    fi
    # If the redis host doesn't have a port then append
    # the default of 6379 for PHP's Redis use.
    if [ -n "$REDIS_HOST" ]; then
      if [[ "$REDIS_HOST" != *":"* ]]; then
        REDIS_HOST="${REDIS_HOST}:6379"
      fi
    fi
    sed -i -e "s|session.save_handler = files|session.save_handler = redis|g" /nhsla/etc/php.ini
    sed -i -e "s|session.save_path = \"/tmp\"|session.save_path = \"tcp://$REDIS_HOST\"|g" /nhsla/etc/php.ini
fi

####

#####
# Force PHP errors in Staging and Production
#####
if [ "$ENVIRONMENT" != "production" ]; then
  sed -i "s|display_errors = Off|display_errors = On|" /nhsla/etc/php.ini
fi
#####
