#!/usr/bin/env bash
# Runs tests/php/security.sh against the PHP-FPM image under test behind each
# web server we use: nhsl-caddy, and OpenResty with the Moodle and Laravel
# site.confs from our charts.
#
#   PHPFPM_IMAGE=nhsl-ubuntu-phpv2:8.4-test ./tests/php/run.sh
#
# DOCKER=podman works too (podman compose). HOST_PORT moves it off 8080.
set -uo pipefail
cd "$(dirname "$0")/../.."
: "${PHPFPM_IMAGE:?set PHPFPM_IMAGE to the image under test}"
export PHPFPM_IMAGE HOST_PORT=${HOST_PORT:-8080}
export BASE=${BASE:-http://localhost:$HOST_PORT}
DOCKER=${DOCKER:-docker}
status=0

stack() { # name compose-file PATH_INFO_URLS [env...]
  local name=$1 file=$2 pi=$3; shift 3
  echo "=== $name"
  local c="$DOCKER compose -f $file"
  env "$@" $c down -v --remove-orphans >/dev/null 2>&1
  if env "$@" $c up -d --quiet-pull >/dev/null 2>&1; then
    env "$@" COMPOSE="$c" PATH_INFO_URLS=$pi ./tests/php/security.sh || { status=1; env "$@" $c logs --tail 50; }
  else
    echo "FAIL could not start $name"; env "$@" $c logs --tail 50; status=1
  fi
  env "$@" $c down -v --remove-orphans >/dev/null 2>&1
  echo
}

stack "nhsl-caddy (laravel profile)" tests/php/compose.caddy.yml 1
stack "OpenResty, Moodle site.conf"  tests/php/compose.openresty.yml 1 SITE_CONF=./openresty-moodle.conf
stack "OpenResty, Laravel site.conf" tests/php/compose.openresty.yml 0 SITE_CONF=../shared-app-openresty.conf

exit $status
