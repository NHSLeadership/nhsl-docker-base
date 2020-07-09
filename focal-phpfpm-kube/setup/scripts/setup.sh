#!/bin/bash

#####
# Email relay configuration
#####
if [ -z "$MAIL_HOST" ]; then
         export MAIL_HOST=outbound.kube-mail
fi

if [ -z "$MAIL_PORT" ]; then
    export MAIL_PORT=25
fi

echo "mailhub=$MAIL_HOST:$MAIL_PORT" >> /nhsla/etc/ssmtp.conf
echo "root=devops@nhsx.uk" >> /nhsla/etc/ssmtp.conf
echo "FromLineOverride=YES" >> /nhsla/etc/ssmtp.conf
sed -i -e "s|;sendmail_path =|sendmail_path = /usr/sbin/ssmtp -t|g" /nhsla/etc/php.ini
#####

#####
# Atatus configuration
#####
if [ ! -z "$ATATUS_APM_LICENSE_KEY" ]; then
  # If API key set then configure Atatus
  sed -i -e "s/atatus.license_key = \"\"/atatus.license_key = \"$ATATUS_APM_LICENSE_KEY\"/g" /nhsla/etc/20-atatus.ini
  sed -i -e "s/atatus.release_stage = \"production\"/atatus.release_stage = \"$ENVIRONMENT\"/g" /nhsla/etc/20-atatus.ini
  sed -i -e "s/atatus.app_name = \"PHP App\"/atatus.app_name = \"$SITE_NAME\"/g" /nhsla/etc/20-atatus.ini
  sed -i -e "s/atatus.app_version = \"\"/atatus.app_version = \"$SITE_BRANCH-$BUILD\"/g" /nhsla/etc/20-atatus.ini
  sed -i -e "s/atatus.tags = \"\"/atatus.tags = \"$SITE_BRANCH-$BUILD, $SITE_BRANCH\"/g" /nhsla/etc/20-atatus.ini
  printf " %-30s %-30s\n" "Atatus:" "Enabled"
else
  # Atatus - if api key is not set then disable
  sed -i -e "s|atatus.enabled = true|atatus.enabled = false|g" /nhsla/etc/atatus.ini
  printf " %-30s %-30s\n" "Atatus: " "Disabled"
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