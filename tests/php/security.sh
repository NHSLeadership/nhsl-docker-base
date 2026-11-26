#!/usr/bin/env bash
# Checks the PHP-FPM image's PATH_INFO handling and its upload-execution
# guards, against a running tests/php/compose.*.yml stack (serving tests/app).
#
# cgi.fix_pathinfo=1 is needed behind nhsl-caddy. It's only safe because:
#   1. php-fpm's security.limit_extensions = .php refuses to run anything that
#      isn't a .php file, whatever SCRIPT_FILENAME it is sent
#   2. the web server only passes on requests whose .php part exists
# This checks each guard on its own (1 by talking FastCGI to php-fpm directly,
# so the web server can't help), and that an uploaded image containing PHP
# never runs through the web server.
#
#   COMPOSE="docker compose -f tests/php/compose.caddy.yml" PATH_INFO_URLS=1 ./tests/php/security.sh
#
# PATH_INFO_URLS=1 when the web server passes /index.php/foo/bar to PHP with
# PATH_INFO (Caddy, and OpenResty with the Moodle site.conf). The Laravel
# site.conf sends it to the front controller instead.
set -uo pipefail

BASE=${BASE:-http://localhost:8080}
COMPOSE=${COMPOSE:?set COMPOSE to the compose command for the running stack}
PATH_INFO_URLS=${PATH_INFO_URLS:-1}
ROOT=/app-shared/public
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [[ -n ${2:-} ]] && head -c 300 "$2" | tr '\n' ' ' | sed 's/^/     /' && echo; }

# Wait for the web server, then for PHP-FPM (which copies the app into /app-shared on boot)
for i in $(seq 90); do
  [[ $(curl -s -o /dev/null -w '%{http_code}' "$BASE/index.php") == 200 ]] && break
  sleep 1
done

# FastCGI straight to php-fpm, from inside its container: fcgi SCRIPT_FILENAME [SCRIPT_NAME]
fcgi() {
  $COMPOSE exec -T phpfpm env REQUEST_METHOD=GET SCRIPT_FILENAME="$1" SCRIPT_NAME="${2:-/x.php}" \
    REQUEST_URI="${2:-/x.php}" DOCUMENT_ROOT=$ROOT cgi-fcgi -bind -connect 127.0.0.1:9000 > "$TMP/f" 2> "$TMP/fe"
}
get() { curl -s --path-as-is -o "$TMP/b" -w '%{http_code}' "$BASE$1"; }

# --- The image's settings are in effect
get /ini.php > /dev/null
if grep -qx 'cgi.fix_pathinfo=1' "$TMP/b"; then ok "php-fpm runs with cgi.fix_pathinfo=1"
else bad "cgi.fix_pathinfo is not 1" "$TMP/b"; fi

# --- PATH_INFO URLs reach PHP
code=$(get /index.php/foo/bar)
if [[ $PATH_INFO_URLS == 1 ]]; then
  if [[ $code == 200 ]] && grep -qE 'PATH_INFO</b>: /foo/bar' "$TMP/b"; then ok "/index.php/foo/bar runs index.php with PATH_INFO=/foo/bar"
  else bad "/index.php/foo/bar: got $code, want 200 with PATH_INFO=/foo/bar" "$TMP/b"; fi
else
  if [[ $code == 200 ]] && grep -qE 'SCRIPT_NAME</b>: /index\.php' "$TMP/b"; then ok "/index.php/foo/bar reaches the front controller"
  else bad "/index.php/foo/bar: got $code, want 200 from index.php" "$TMP/b"; fi
fi

# --- Guard 1: php-fpm itself only runs .php files
fcgi $ROOT/index.php /index.php
if grep -q 'Process user' "$TMP/f"; then ok "control: direct FastCGI runs index.php"
else bad "control: direct FastCGI didn't run index.php (the checks below prove nothing)" "$TMP/f"; fi
for f in uploads/avatar.jpg/x.php uploads/avatar.jpg uploads/avatar.phar; do
  fcgi "$ROOT/$f" "/$f"
  if grep -q 'UPLOAD-EXECUTED' "$TMP/f"; then bad "php-fpm ran $f when sent it directly" "$TMP/f"
  elif grep -q 'Access denied' "$TMP/f"; then ok "php-fpm refuses to run $f (limit_extensions)"
  else bad "php-fpm didn't refuse $f with limit_extensions (got: $(tr -d '\r' < "$TMP/f" | grep -m1 . || echo 'no response'))"; fi
done

# --- Guard 2 (and both together): uploads never run through the web server
for u in /uploads/avatar.jpg/x.php /uploads/avatar.jpg/.php /uploads/avatar.jpg%2fx.php \
         /uploads/avatar.jpg/index.php /uploads/avatar.phar /uploads/avatar.phar/x.php \
         /uploads/avatar.jpg; do
  code=$(get "$u")
  if grep -q 'UPLOAD-EXECUTED' "$TMP/b"; then bad "$u ran the uploaded file as PHP ($code)" "$TMP/b"
  else ok "$u does not run the upload ($code)"; fi
done

echo; echo "passed=$pass failed=$fail"
((fail == 0))
