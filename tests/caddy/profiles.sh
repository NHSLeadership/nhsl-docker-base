#!/usr/bin/env bash
# Tests every profile in caddy/rootfs end to end: a real caddy and php-fpm
# serving stub Laravel, WordPress and Moodle apps. It checks routing,
# blocking, PATH_INFO, X-Accel downloads, the site.d/php.d hooks and error
# pages. The image's absolute paths are remapped into a temp dir, so no
# Docker is needed.
#
#   CADDY=caddy PHP_FPM=php-fpm ./tests/caddy/profiles.sh
#
# Uses ports 18080, 19145 and 19000.
set -uo pipefail

CADDY=${CADDY:-caddy}
PHP_FPM=${PHP_FPM:-php-fpm}
HERE=$(cd "$(dirname "$0")" && pwd)
ROOTFS=$HERE/../../caddy/rootfs

T=$(mktemp -d)
cleanup() { kill ${CADDY_PID:-} ${FPM:-} 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

# Copy the image's config, pointing its absolute paths and ports into $T
cp -R "$ROOTFS" "$T/root"
find "$T/root/etc/caddy" -type f \( -name '*.caddy' -o -name Caddyfile \) -print0 | xargs -0 perl -pi -e "
  s#/etc/caddy#$T/root/etc/caddy#g; s#(root \*? ?)/srv/#\1$T/root/srv/#g; s#^:8080#:18080#; s#^:9145#:19145#"
head -c 2000000 /dev/zero > "$T/big"

A=$T/apps; D=$T/data
export XDG_DATA_HOME=$T/xdg XDG_CONFIG_HOME=$T/xdg SITE_NAME=e2e NHSLA_MAX_BODY_SIZE=1MB
mkdir -p "$A" "$D"
dump='<?php header("Content-Type: text/plain"); foreach (["SCRIPT_NAME","SCRIPT_FILENAME","PATH_INFO","REQUEST_URI","QUERY_STRING","REMOTE_ADDR","HTTP_X_FORWARDED_FOR","HTTP_X_FORWARDED_PROTO","SERVER_NAME","HTTP_HOST","NHSLA_TEST"] as $k) echo "$k=", $_SERVER[$k] ?? "", "\n";'
mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }

# --- stub apps
L=$A/laravel/public
mk $L/index.php "$dump"; mk $L/build/app.css 'body{color:red}'; mk $L/vendor/livewire/livewire.min.js 'console.log(1)'
mk $L/.env SECRET; mk $L/composer.json '{}'; mk $L/backup.sql x; mk $L/.well-known/acme.txt acme
mk $L/sleep.php '<?php sleep(5);'
W=$A/wp
mk $W/index.php "$dump"; mk $W/wp-login.php "$dump"; mk $W/wp-admin/index.php "$dump"; mk $W/wp-admin/options.php "$dump"
mk $W/wp-content/uploads/evil.php '<?php echo "EXECUTED";'; mk $W/wp-content/themes/t/style.css 'a{}'
mk $W/wp-content/plugins/p/vendor/lib.js 'x'
M=$A/moodle
mk $M/index.php "$dump"; mk $M/course/index.php "$dump"; mk $M/pluginfile.php "$dump"; mk $M/lib/vendor/x.js x; mk $M/README.md x
mk $M/admin/environment.xml x; mk $M/local/x/readme_moodle.txt x; mk $M/theme/styles.php "$dump"; mk $M/admin/tool/behat/index.php x
M5=$A/moodle5/public
mk $M5/index.php "$dump"; mk $M5/r.php "$dump"
mk $M5/pluginfile.php '<?php header("Content-Type: application/pdf"); header("Content-Disposition: attachment; filename=\"report.pdf\""); header("X-Accel-Redirect: /dataroot/filedir/ab/cdef"); '
mk $D/filedir/ab/cdef 'PDFBYTES'

# --- php-fpm
cat > $T/fpm.conf <<EOF
[global]
error_log = $T/fpm.log
daemonize = no
[www]
listen = 127.0.0.1:19000
pm = static
pm.max_children = 4
clear_env = no
EOF
"$PHP_FPM" -y $T/fpm.conf & FPM=$!
for i in $(seq 50); do (exec 3<>/dev/tcp/127.0.0.1/19000) 2>/dev/null && break; sleep 0.1; done

C=$T/root/etc/caddy/Caddyfile
pass=0; fail=0
check() { # desc expected-status url [curl args...] [-- grep-pattern]
  local desc=$1 want=$2 url=$3; shift 3
  local args=() pat=""
  while (($#)); do if [[ $1 == -- ]]; then pat=$2; break; fi; args+=("$1"); shift; done
  local got; got=$(curl -s -o $T/body -D $T/hdr -w '%{http_code}' "${args[@]}" "http://localhost:18080$url")
  local ok=1
  [[ $got == "$want" ]] || ok=0
  if [[ -n $pat ]] && ! grep -qiE -- "$pat" $T/hdr $T/body; then ok=0; fi
  if ((ok)); then pass=$((pass+1)); printf '  ok   %-58s %s\n' "$desc" "$got"
  else fail=$((fail+1)); printf '  FAIL %-58s got %s want %s %s\n' "$desc" "$got" "$want" "${pat:+(expected /$pat/)}"
       head -c 300 $T/body | tr '\n' ' ' | sed 's/^/         body: /'; echo; fi
}
run() { # profile root [extra env...]
  local p=$1 r=$2; shift 2
  echo "== $p"
  env NHSLA_PROFILE=$p NHSLA_ROOT=$r NHSLA_PHP_UPSTREAM=127.0.0.1:19000 NHSLA_MOODLE_DATAROOT=$D "$@" \
    "$CADDY" run --config $C --adapter caddyfile > $T/caddy-$p.log 2>&1 & CADDY_PID=$!
  for i in $(seq 50); do curl -s -o /dev/null localhost:18080/healthz && break; sleep 0.1; done
}
stop() { kill $CADDY_PID 2>/dev/null; wait $CADDY_PID 2>/dev/null; }

sleep 0.5

# ---------------- shared behaviour (on the laravel profile)
mkdir -p $T/root/srv/well-known; echo 'Contact: mailto:test@example.invalid' > $T/root/srv/well-known/security.txt
printf 'respond /site-d-test "site.d works" 200\nhandle /proxied.js {\n\trespond "site.d js" 200\n}\n' > $T/root/etc/caddy/site.d/test.caddy
echo 'env NHSLA_TEST php.d-works' > $T/root/etc/caddy/php.d/test.caddy
run laravel $L NHSLA_PHP_TIMEOUT=2s
check "healthz"                          200 /healthz -- '^OK'
check "security.txt served"              200 /.well-known/security.txt -- 'Contact: mailto'
check "other .well-known reaches app"    200 /.well-known/acme.txt -- 'acme'
check ".env blocked"                     404 /.env -- '404 Page Not Found'
check ".git/config blocked"              404 /.git/config
check "composer.json blocked"            404 /composer.json
check "backup.sql blocked"               404 /backup.sql
check "error page keeps X-NHSLA-Site"    404 /.env -- '^x-nhsla-site: e2e'
check "no Server header on errors"       404 /.env
grep -qi '^server:' $T/hdr && { fail=$((fail+1)); echo "  FAIL Server header present on error"; } || { pass=$((pass+1)); echo "  ok   Server header absent on error"; }
check "site.d hook"                      200 /site-d-test -- 'site.d works'
check "site.d handle beats profile rules" 200 /proxied.js -- 'site.d js'
check "shared blocks still apply"        404 /proxied.js/.env
check "php.d hook (env reaches PHP)"     200 / -- 'NHSLA_TEST=php.d-works'
check "504 on PHP timeout"               504 /sleep.php -- '504 Gateway Timeout'
check "413 over NHSLA_MAX_BODY_SIZE"     413 / -X POST --data-binary @$T/big -H 'Content-Type: application/octet-stream'
rm -f $T/root/srv/well-known/security.txt $T/root/etc/caddy/site.d/test.caddy $T/root/etc/caddy/php.d/test.caddy
stop

# ---------------- laravel
run laravel $L
check "front controller"                 200 /some/route?x=1 -- 'SCRIPT_NAME=/index.php'
check "query string kept"                200 /some/route?x=1 -- 'QUERY_STRING=x=1'
check "X-Forwarded-For kept (trusted)"   200 / -H 'X-Forwarded-For: 203.0.113.9' -- 'HTTP_X_FORWARDED_FOR=203.0.113.9'
check "X-Forwarded-Proto kept"           200 / -H 'X-Forwarded-Proto: https' -- 'HTTP_X_FORWARDED_PROTO=https'
check "static cached 24h"                200 /build/app.css -- 'cache-control: max-age=86400'
check "vendor/livewire allowed"          200 /vendor/livewire/livewire.min.js
check "missing asset is plain 404"       404 /build/nope.js -- '404 Page Not Found'
check "gzip"                             200 /vendor/livewire/livewire.min.js -H 'Accept-Encoding: gzip'
check "security.txt absent -> app"       200 /.well-known/security.txt -- 'SCRIPT_NAME=/index.php'
stop
kill $FPM; wait $FPM 2>/dev/null
check_502() { run laravel $L; check "502 when php-fpm is down" 502 / -- '502 Bad Gateway'; stop; }
check_502
"$PHP_FPM" -y $T/fpm.conf & FPM=$!; for i in $(seq 50); do (exec 3<>/dev/tcp/127.0.0.1/19000) 2>/dev/null && break; sleep 0.1; done

# ---------------- wordpress
run wordpress $W
check "front controller"                 200 /2024/01/hello/ -- 'SCRIPT_NAME=/index.php'
check "wp-login.php"                     200 /wp-login.php -- 'SCRIPT_NAME=/wp-login.php'
check "multisite /site/wp-login.php"     200 /site1/wp-login.php -- 'SCRIPT_NAME=/wp-login.php'
check "multisite /site/wp-admin/x.php"   200 /site1/wp-admin/options.php -- 'SCRIPT_NAME=/wp-admin/options.php'
check "multisite static /site/wp-content" 200 /site1/wp-content/themes/t/style.css
check "wp-admin trailing-slash redirect" 301 /site1/wp-admin -- 'location: /site1/wp-admin/'
check "uploads PHP not executed"         403 /wp-content/uploads/evil.php
grep -q EXECUTED $T/body && { fail=$((fail+1)); echo "  FAIL uploads PHP executed"; }
check "plugin vendor asset allowed"      200 /wp-content/plugins/p/vendor/lib.js
check "static cached 12h"                200 /wp-content/themes/t/style.css -- 'cache-control: max-age=43200'
check "multisite still blocks .env"      404 /site1/.env
# Subdomain multisite with mapped domains (wp-multisite): WordPress picks the
# site from the Host header, and the subdirectory rewrites must not get in the way
check "subdomain: Host reaches PHP"      200 /about-us/ -H 'Host: london.leadershipacademy.nhs.uk' -- 'HTTP_HOST=london\.leadershipacademy\.nhs\.uk'
check "subdomain: SERVER_NAME"           200 /about-us/ -H 'Host: london.leadershipacademy.nhs.uk' -- 'SERVER_NAME=london\.leadershipacademy\.nhs\.uk'
check "mapped domain: Host reaches PHP"  200 / -H 'Host: topol.digitalacademy.nhs.uk' -- 'HTTP_HOST=topol\.digitalacademy\.nhs\.uk'
check "subdomain: wp-login.php"          200 /wp-login.php -H 'Host: eoe.leadershipacademy.nhs.uk' -- 'SCRIPT_NAME=/wp-login\.php'
check "subdomain: wp-admin/options.php"  200 /wp-admin/options.php -H 'Host: eoe.leadershipacademy.nhs.uk' -- 'HTTP_HOST=eoe\.leadershipacademy\.nhs\.uk'
check "subdomain: wp-admin redirect keeps host" 301 /wp-admin -H 'Host: eoe.leadershipacademy.nhs.uk' -- '^location: /wp-admin/'
check "subdomain: page slug + /wp- path" 200 '/category/wp-tips/?x=1' -H 'Host: eoe.leadershipacademy.nhs.uk' -- 'REQUEST_URI=/category/wp-tips/\?x=1'
check "subdomain: REST API"              200 /wp-json/wp/v2/posts -H 'Host: eoe.leadershipacademy.nhs.uk' -- 'REQUEST_URI=/wp-json/wp/v2/posts'
check "subdomain: static asset"          200 /wp-content/themes/t/style.css -H 'Host: eoe.leadershipacademy.nhs.uk' -- 'cache-control: max-age=43200' 
stop

# ---------------- moodle 4.x
run moodle $M
check "index.php"                        200 / -- 'SCRIPT_NAME=/index.php'
check "slash args PATH_INFO"             200 /pluginfile.php/12/mod_x/content/0/f.png -- 'PATH_INFO=/12/mod_x/content/0/f.png'
check "slash args SCRIPT_NAME"           200 /pluginfile.php/12/mod_x/content/0/f.png -- 'SCRIPT_NAME=/pluginfile.php'
check "theme/styles.php slash args"      200 /theme/styles.php/boost/123/all -- 'PATH_INFO=/boost/123/all'
check "missing path is 404 (no router)"  404 /no/such/page -- '404 Page Not Found'
check "missing .php is 404 page"        404 /nope.php -- '404 Page Not Found'
check "directory index.php"             200 /course/ -- 'SCRIPT_NAME=/course/index.php'
check "lib/vendor blocked"               404 /lib/vendor/x.js
check "README.md blocked"                404 /README.md
check "environment.xml blocked"          404 /admin/environment.xml
check "readme_moodle.txt blocked"        404 /local/x/readme_moodle.txt
check "admin/tool/behat blocked"         404 /admin/tool/behat/index.php
check "X-NHSLA-OSS header"               200 / -- '^x-nhsla-oss: moodle'
stop

# ---------------- moodle 5.x
run moodle5 $M5
check "router for unknown paths"         200 /course/view/42?x=1 -- 'SCRIPT_NAME=/r.php'
check "router keeps request URI"         200 /course/view/42?x=1 -- 'REQUEST_URI=/course/view/42\?x=1'
check "X-Accel download body"            200 /pluginfile.php/1/f -- 'PDFBYTES'
check "X-Accel keeps content-disposition" 200 /pluginfile.php/1/f -- 'content-disposition: attachment; filename="report.pdf"'
check "X-Accel keeps content-type"       200 /pluginfile.php/1/f -- 'content-type: application/pdf'
grep -qi '^x-accel-redirect' $T/hdr && { fail=$((fail+1)); echo "  FAIL X-Accel-Redirect leaked to client"; } || { pass=$((pass+1)); echo "  ok   X-Accel-Redirect not leaked"; }
mk $M5/missingfile.php '<?php header("Content-Type: application/pdf"); header("Content-Disposition: attachment; filename=x.pdf"); header("X-Accel-Redirect: /dataroot/filedir/zz/nope");'
check "X-Accel missing file -> HTML 404" 404 /missingfile.php -- '404 Page Not Found'
check "/dataroot not reachable directly" 200 /dataroot/filedir/ab/cdef -- 'SCRIPT_NAME=/r.php'
check "security headers"                 200 / -- '^x-frame-options: SAMEORIGIN'
stop

kill $FPM; wait $FPM 2>/dev/null
echo; echo "passed=$pass failed=$fail"
((fail == 0))
