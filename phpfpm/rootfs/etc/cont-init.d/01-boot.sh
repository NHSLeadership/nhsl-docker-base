#!/command/with-contenv bash

# Create directories if they don't exist otherwise container wont run.
[[ -d /nhsla/etc ]] || mkdir -p /nhsla/etc

# Copy configs from RO directory to writable one
cp /nhsla/setup/* /nhsla/etc/

if [ ! -z "$AWS_HOST_ENVIRONMENT" ]; then
  cp -r --preserve=ownership /app/. /app-shared/
fi