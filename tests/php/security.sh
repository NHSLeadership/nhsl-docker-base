#!/usr/bin/env bash
# Checks the PHP-FPM image's PATH_INFO handling and its upload-execution
# guards, against a running tests/php/compose.*.yml stack (serving tests/app).
#
# The image keeps cgi.fix_pathinfo=0. Moodle behind Caddy needs 1, which its
# charts set in a conf.d drop-in. Wherever it is 1, an uploaded evil.jpg must
# still never run as PHP, because:
#   1. php-fpm's security.limit_extensions = .php refuses to run anything that
#      isn't a .php file, whatever SCRIPT_FILENAME it is sent
#   2. the web server only passes on requests whose .php part exists
# This checks guard 1 by talking FastCGI to php-fpm directly (so the web
# server can't help), and both together through the web server.
#
#   COMPOSE="docker compose -f tests/php/compose.caddy.yml" ./tests/php/security.sh
#
# EXPECT_FIX_PATHINFO  the cgi.fix_pathinfo php-fpm should be running with (0)
# SLASH_ARGS           how a .php/... URL should be handled:
#                        script  SLASH_URL runs SLASH_SCRIPT with SLASH_PATH_INFO
#                        front   /index.php/foo/bar reaches the front controller
#                        none    not checked (generic profiles don't need it)
set -uo pipefail

BASE=${BASE:-http://localhost:8080}
COMPOSE=${COMPOSE:?set COMPOSE to the compose command for the running stack}
EXPECT_FIX_PATHINFO=${EXPECT_FIX_PATHINFO:-0}
SLASH_ARGS=${SLASH_ARGS:-none}
SLASH_URL=${SLASH_URL:-/theme/styles.php/boost/1700000000/all}
SLASH_SCRIPT=${SLASH_SCRIPT:-/theme/styles.php}
SLASH_PATH_INFO=${SLASH_PATH_INFO:-/boost/1700000000/all}
ROOT=/app-shared/public
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [[ -n ${2:-} ]] && head -c 300 "$2" | tr '\n' ' ' | sed 's/^/     /' && echo; }

# Wait for the web server, then for PHP-FPM (which copies the app into /app-shared on boot)
for i in $(seq 90); do
  [[ $(curl -s -o /dev/null -w '%{http_code}' "$BASE/ini.php") == 200 ]] && break
  sleep 1
done

# FastCGI straight to php-fpm, from inside its container: fcgi SCRIPT_FILENAME [SCRIPT_NAME]
fcgi() {
  $COMPOSE exec -T phpfpm env REQUEST_METHOD=GET SCRIPT_FILENAME="$1" SCRIPT_NAME="${2:-/x.php}" \
    REQUEST_URI="${2:-/x.php}" DOCUMENT_ROOT=$ROOT cgi-fcgi -bind -connect 127.0.0.1:9000 > "$TMP/f" 2> "$TMP/fe"
}
get() { curl -s --path-as-is -o "$TMP/b" -w '%{http_code}' "$BASE$1"; }
first() { tr -d '\r' < "$1" | grep -m1 . || echo 'no response'; }

# --- php-fpm runs with the expected setting
get /ini.php > /dev/null
if grep -qx "cgi.fix_pathinfo=$EXPECT_FIX_PATHINFO" "$TMP/b"; then ok "php-fpm runs with cgi.fix_pathinfo=$EXPECT_FIX_PATHINFO"
else bad "want cgi.fix_pathinfo=$EXPECT_FIX_PATHINFO, got: $(first "$TMP/b")"; fi

# --- Slash-argument URLs
case $SLASH_ARGS in
  script)
    code=$(get "$SLASH_URL")
    if [[ $code == 200 ]] && grep -qx "SCRIPT_NAME=$SLASH_SCRIPT" "$TMP/b" && grep -qx "PATH_INFO=$SLASH_PATH_INFO" "$TMP/b"; then
      ok "$SLASH_URL runs $SLASH_SCRIPT with PATH_INFO=$SLASH_PATH_INFO"
    else bad "$SLASH_URL: got $code, want 200 from $SLASH_SCRIPT with PATH_INFO=$SLASH_PATH_INFO" "$TMP/b"; fi ;;
  front)
    code=$(get /index.php/foo/bar)
    if [[ $code == 200 ]] && grep -qE 'SCRIPT_NAME</b>: /index\.php' "$TMP/b"; then ok "/index.php/foo/bar reaches the front controller"
    else bad "/index.php/foo/bar: got $code, want 200 from index.php" "$TMP/b"; fi ;;
  none) ;;
  *) bad "unknown SLASH_ARGS=$SLASH_ARGS" ;;
esac

# --- Guard 1: php-fpm itself only runs .php files
fcgi $ROOT/index.php /index.php
if grep -q 'Process user' "$TMP/f"; then ok "control: direct FastCGI runs index.php"
else bad "control: direct FastCGI didn't run index.php (the checks below prove nothing)" "$TMP/f"; fi
# Existing non-.php files: refused by limit_extensions whatever cgi.fix_pathinfo is
for f in uploads/avatar.jpg uploads/avatar.phar; do
  fcgi "$ROOT/$f" "/$f"
  if grep -q 'UPLOAD-EXECUTED' "$TMP/f"; then bad "php-fpm ran $f when sent it directly" "$TMP/f"
  elif grep -q 'Access denied' "$TMP/f"; then ok "php-fpm refuses to run $f (limit_extensions)"
  else bad "php-fpm didn't refuse $f with limit_extensions (got: $(first "$TMP/f"))"; fi
done
# The classic attack. With cgi.fix_pathinfo=1, php-fpm walks back from the
# missing x.php to avatar.jpg, and only limit_extensions stops it running.
# With 0 it doesn't walk back, so "not found" is the safe answer.
f=uploads/avatar.jpg/x.php
fcgi "$ROOT/$f" "/$f"
if grep -q 'UPLOAD-EXECUTED' "$TMP/f"; then bad "php-fpm ran avatar.jpg via $f" "$TMP/f"
elif grep -q 'Access denied' "$TMP/f"; then ok "php-fpm refuses $f (limit_extensions)"
elif [[ $EXPECT_FIX_PATHINFO == 0 ]] && grep -q '^Status: 404' "$TMP/f"; then ok "php-fpm doesn't resolve $f (cgi.fix_pathinfo=0)"
else bad "php-fpm: unexpected answer for $f (got: $(first "$TMP/f"))"; fi

# --- Both guards together: uploads never run through the web server
for u in /uploads/avatar.jpg/x.php /uploads/avatar.jpg/.php /uploads/avatar.jpg%2fx.php \
         /uploads/avatar.jpg/index.php /uploads/avatar.phar /uploads/avatar.phar/x.php \
         /uploads/avatar.jpg; do
  code=$(get "$u")
  if [[ $code == 000 ]]; then bad "$u: no response (is the stack up?)"
  elif grep -q 'UPLOAD-EXECUTED' "$TMP/b"; then bad "$u ran the uploaded file as PHP ($code)" "$TMP/b"
  else ok "$u does not run the upload ($code)"; fi
done

echo; echo "passed=$pass failed=$fail"
((fail == 0))
