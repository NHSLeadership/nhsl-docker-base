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
sed -i -e "s|;sendmail_path =|sendmail_path = /usr/sbin/ssmtp -t|g" /nhsla/etc/php.ini
#####

#####
# Email relay configuration
#####
if [ -n "$REDIS_SESSIONS" ]; then
    if [ -z "$REDIS_HOST" ]; then
      export REDIS_HOST="redis:6379"
    fi
    sed -i -e "s|session.save_handler = files|session.save_handler = redis|g" /nhsla/etc/php.ini
    sed -i -e "s|session.save_path = \"/tmp\"|session.save_path = \"tcp://$REDIS_HOST\"|g" /nhsla/etc/php.ini
fi

####

#####
# Atatus configuration
#####
if [ ! -z "$ATATUS_APM_LICENSE_KEY" ]; then
  # If API key set then configure Atatus
  sed -i -e "s/atatus.license_key = \"\"/atatus.license_key = \"$ATATUS_APM_LICENSE_KEY\"/g" /nhsla/etc/atatus.ini
  sed -i -e "s/atatus.release_stage = \"production\"/atatus.release_stage = \"$ENVIRONMENT\"/g" /nhsla/etc/atatus.ini
  sed -i -e "s/atatus.app_name = \"PHP App\"/atatus.app_name = \"$SITE_NAME\"/g" /nhsla/etc/atatus.ini
  sed -i -e "s/atatus.app_version = \"\"/atatus.app_version = \"$SITE_BRANCH-$BUILD\"/g" /nhsla/etc/atatus.ini
  sed -i -e "s/atatus.tags = \"\"/atatus.tags = \"$SITE_BRANCH-$BUILD, $SITE_BRANCH\"/g" /nhsla/etc/atatus.ini
  #printf " %-30s %-30s\n" "Atatus:" "Enabled"
else
  # Atatus - if api key is not set then disable
  sed -i -e "s|atatus.enabled = true|atatus.enabled = false|g" /nhsla/etc/atatus.ini
  #printf " %-30s %-30s\n" "Atatus: " "Disabled"
  rm -f /nhsla/etc/atatus.ini
fi
#####

#####
# Force PHP errors in Staging and Production
#####
if [ "$ENVIRONMENT" != "production" ]; then
  sed -i "s|display_errors = Off|display_errors = On|" /nhsla/etc/php.ini
fi
#####

# This isn't an S6 service because it spawns children that get lost, and it isn't exactly critical
exec /usr/bin/atatus-php-collector --conn /tmp/.atatus.sock --log-file /dev/stdout --log-level warning --pidfile /nhsla/etc/atatus.pid > /dev/null 2>&1
