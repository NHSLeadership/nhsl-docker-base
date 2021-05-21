#!/bin/bash

if [ -f /startup-nginx.sh ]; then
    source /startup-nginx.sh
fi

exec "$@"
