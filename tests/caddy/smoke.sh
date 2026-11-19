#!/usr/bin/env bash
# Smoke test for the nhsl-caddy image, run against tests/caddy/compose.yml
# (laravel profile serving tests/app). Exits non-zero on any failure.
#
#   BASE=http://localhost:8080 METRICS=http://localhost:9145 ./tests/caddy/smoke.sh
set -uo pipefail

BASE=${BASE:-http://localhost:8080}
METRICS=${METRICS:-http://localhost:9145}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# Wait for Caddy, then for PHP-FPM (which copies the app into /app-shared on boot)
for i in $(seq 60); do
  [[ $(curl -s -o /dev/null -w '%{http_code}' "$BASE/") == 200 ]] && break
  sleep 1
done

check() { # description expected-status path [curl args...] [-- regex the headers or body must match]
  local desc=$1 want=$2 path=$3; shift 3
  local args=() pat=""
  while (($#)); do if [[ $1 == -- ]]; then pat=$2; break; fi; args+=("$1"); shift; done
  local got; got=$(curl -s -o "$TMP/body" -D "$TMP/hdr" -w '%{http_code}' "${args[@]}" "$BASE$path")
  if [[ $got == "$want" ]] && { [[ -z $pat ]] || grep -qiE -- "$pat" "$TMP/hdr" "$TMP/body"; }; then
    pass=$((pass+1)); printf 'ok   %-45s %s\n' "$desc" "$got"
  else
    fail=$((fail+1)); printf 'FAIL %-45s got %s, want %s %s\n' "$desc" "$got" "$want" "${pat:+matching /$pat/}"
  fi
}
absent() { # description header-regex (checked against the last response)
  if grep -qiE "$2" "$TMP/hdr"; then fail=$((fail+1)); printf 'FAIL %s\n' "$1"; else pass=$((pass+1)); printf 'ok   %s\n' "$1"; fi
}

check "healthz"                            200 /healthz -- '^OK'
check "PHP front controller"               200 /some/route -- 'SCRIPT_NAME.{0,20}/index\.php'
check "slash args (index.php/foo/bar)"     200 /index.php/foo/bar -- 'PATH_INFO.{0,20}/foo/bar'
check "PHP runs as nhsla"                  200 / -- 'Process user:</b> nhsla'
check "X-NHSLA-Site header"                200 / -- '^x-nhsla-site: caddy-test'
absent "no Server header"                  '^server:'
check "static file with 24h cache"         200 /test/files/style.css -- '^cache-control: max-age=86400'
check "gzip (bodies over 512 bytes)"       200 / -H 'Accept-Encoding: gzip' -- '^content-encoding: gzip'
check "missing asset is a 404 page"        404 /test/files/nope.css -- '404 Page Not Found'
check ".env blocked"                       404 /.env -- '404 Page Not Found'
check "error page keeps X-NHSLA-Site"      404 /.env -- '^x-nhsla-site: caddy-test'
absent "no Server header on errors"        '^server:'
check ".git/config blocked"                404 /.git/config
check "composer.json blocked"              404 /composer.json
check "backup.sql blocked"                 404 /backup.sql
check ".well-known not blocked"            200 /.well-known/anything -- 'SCRIPT_NAME.{0,20}/index\.php'
check "security.txt served"                200 /.well-known/security.txt -- '^Contact: mailto:'
# RFC 9116: Expires must be in the future (and under a year away). Fail a
# month ahead so the weekly scheduled build gives warning.
exp=$(grep -i '^Expires:' "$TMP/body" | awk '{print $2}' | tr -d '\r')
exp_s=$(date -u -d "$exp" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$exp" +%s 2>/dev/null || echo 0)
days=$(( (exp_s - $(date -u +%s)) / 86400 ))
if (( days > 30 && days <= 366 )); then pass=$((pass+1)); echo "ok   security.txt Expires in $days days"
else fail=$((fail+1)); echo "FAIL security.txt Expires ($exp) is $days days away: update caddy/rootfs/srv/well-known/security.txt"; fi
check "413 over body limit"                413 / -X POST -H 'Content-Length: 1073741825' -H 'Content-Type: application/octet-stream' --data-binary ''

got=$(curl -s -o "$TMP/m" -w '%{http_code}' "$METRICS/metrics")
if [[ $got == 200 ]] && grep -q '^caddy_http_requests_total' "$TMP/m"; then pass=$((pass+1)); echo "ok   metrics endpoint"; else fail=$((fail+1)); echo "FAIL metrics endpoint ($got)"; fi
got=$(curl -s -o /dev/null -w '%{http_code}' "$METRICS/")
if [[ $got == 403 ]]; then pass=$((pass+1)); echo "ok   metrics port denies other paths"; else fail=$((fail+1)); echo "FAIL metrics port other paths ($got)"; fi

echo; echo "passed=$pass failed=$fail"
((fail == 0))
