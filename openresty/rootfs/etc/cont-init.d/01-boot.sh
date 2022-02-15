#!/command/with-contenv bash

# Create directories if they don't exist otherwise container wont run.
mkdir -p /tmp/openresty

if [ ! -f /usr/local/openresty/nginx/conf/site.conf ]; then
  mv /usr/local/openresty/nginx/conf/site.conf.default /usr/local/openresty/nginx/conf/site.conf
fi

#if [ ! -z "$AWS_HOST_ENVIRONMENT" ]; then
#  cp -rp /app/. /app-shared/
#fi