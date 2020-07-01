#!/bin/bash
echo "This is the entrypoint script."
mkdir -p /tmp/openresty

exec "$@"