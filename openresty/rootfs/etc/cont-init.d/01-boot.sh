#!/command/with-contenv bash

# Create directories if they don't exist otherwise container wont run.
mkdir -p /tmp/openresty

# Copy over default config if we dont already have one from elsewhere
if [ ! -f /usr/local/openresty/nginx/conf/site.conf ]; then
  mv /usr/local/openresty/nginx/conf/site.conf.default /usr/local/openresty/nginx/conf/site.conf
fi