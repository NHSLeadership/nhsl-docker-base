#!/usr/bin/env bash
# Runs tests/php/security.sh against the PHP-FPM image under test behind each
# way we serve it: nhsl-caddy with the image's own settings, nhsl-caddy for
# Moodle with the charts' cgi.fix_pathinfo=1 override, and OpenResty with the
# Moodle and Laravel site.confs from our charts.
#
#   PHPFPM_IMAGE=nhsl-ubuntu-phpv2:8.4-test ./tests/php/run.sh
#
# DOCKER=podman works too (podman compose). HOST_PORT moves it off 8080.
set -uo pipefail
cd "$(dirname "$0")/../.."
: "${PHPFPM_IMAGE:?set PHPFPM_IMAGE to the image under test}"
DOCKER=${DOCKER:-docker}
export PHPFPM_IMAGE HOST_PORT=${HOST_PORT:-8080}
export BASE=${BASE:-http://localhost:$HOST_PORT}
# The charts mount PHP overrides at /etc/php/<version>/fpm/conf.d, so do the same
PHP_VERSION=$($DOCKER run --rm --entrypoint php "$PHPFPM_IMAGE" -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;') \
  || { echo "FAIL could not read the PHP version from $PHPFPM_IMAGE"; exit 1; }
export PHP_VERSION
echo "PHP $PHP_VERSION in $PHPFPM_IMAGE"; echo
status=0

stack() { # name "compose -f args" [VAR=value...]   (the VARs are for compose and security.sh)
  local name=$1 files=$2; shift 2
  local c="$DOCKER compose $files"
  echo "=== $name"
  env "$@" $c down -v --remove-orphans >/dev/null 2>&1
  if env "$@" $c up -d --quiet-pull >/dev/null 2>&1; then
    env "$@" COMPOSE="$c" ./tests/php/security.sh || { status=1; env "$@" $c logs --tail 50; }
  else
    echo "FAIL could not start $name"; env "$@" $c logs --tail 50; status=1
  fi
  env "$@" $c down -v --remove-orphans >/dev/null 2>&1
  echo
}

stack "nhsl-caddy, laravel profile, image settings" \
  "-f tests/php/compose.caddy.yml" \
  EXPECT_FIX_PATHINFO=0 SLASH_ARGS=none
stack "nhsl-caddy, moodle profile, charts' cgi.fix_pathinfo=1 override" \
  "-f tests/php/compose.caddy.yml -f tests/php/compose.caddy-moodle.yml" \
  EXPECT_FIX_PATHINFO=1 SLASH_ARGS=script
stack "OpenResty, Moodle site.conf, image settings" \
  "-f tests/php/compose.openresty.yml" \
  SITE_CONF=./openresty-moodle.conf EXPECT_FIX_PATHINFO=0 SLASH_ARGS=script
stack "OpenResty, Laravel site.conf, image settings" \
  "-f tests/php/compose.openresty.yml" \
  SITE_CONF=../shared-app-openresty.conf EXPECT_FIX_PATHINFO=0 SLASH_ARGS=front

exit $status
