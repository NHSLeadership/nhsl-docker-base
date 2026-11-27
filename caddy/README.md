# nhsl-caddy

A [Caddy](https://caddyserver.com/) image built `FROM scratch`. It replaces
OpenResty in front of PHP-FPM, in the same pod layout: Caddy on 8080, PHP-FPM
on 127.0.0.1:9000, and the app shared through `/app-shared`.

The image contains only the static `caddy` binary (taken from the official
`caddy:<version>-alpine` image), the CA bundle, `mime.types`, a passwd entry
for `nhsla`, and our config. There's no OS, shell or package manager, so
there's very little for a vulnerability scanner to flag, and very little an
attacker could use.

**Moving a chart from OpenResty?** See [MIGRATING.md](MIGRATING.md).

Configuration that every site needs lives in the image:
- error pages
- `security.txt`
- path blocking
- `X-NHSLA-*` headers
- JSON access logs
- Prometheus metrics
- trusted-proxy handling

A site picks a **profile** for its app type, and can add a few lines of its
own if it needs to.

```
ghcr.io/nhsleadership/nhsl-caddy:2.11.9   # upstream Caddy version, rebuilt weekly. Pin this one.
ghcr.io/nhsleadership/nhsl-caddy:master   # latest build from master
```

## How the config fits together

```
/etc/caddy/
  Caddyfile             global options, the :8080 site and the :9145 metrics server
  snippets/common.caddy shared snippets (headers, errors, blocking, security.txt…)
  profiles/
    laravel.caddy       front controller, web root public/   (default)
    wordpress.caddy     WordPress, including subdirectory multisite
    moodle.caddy        Moodle 4.x
    moodle5.caddy       Moodle 5.x (r.php router, X-Accel-Redirect downloads)
  site.d/*.caddy        per-site additions: mount a ConfigMap here (empty by default)
  php.d/*.caddy         extra php_fastcgi subdirectives: mount a ConfigMap here
/srv/errors/error.html  one error page (16 KB), templated for each status code
/srv/well-known/security.txt  served at /.well-known/security.txt on every site
```

Every site gets:

| | |
|---|---|
| `/healthz` | `200 OK`, not logged |
| Blocked with a 404 | dotfiles and dot-directories except `/.well-known/`; `*.bak .dist .conf .yml .yaml .cfg .fla .ini .inc .log .psd .sh .sql`; names ending `~`; `composer.json` and `composer.lock` |
| Error pages | For errors Caddy raises itself: blocked paths, missing files, 502 when PHP-FPM is down, 504 on timeout, 413 when a body is too large. Errors returned by the app pass through unchanged. |
| Headers | `X-NHSLA-Pod` and `X-NHSLA-Site` on every response, including errors. `Server` is removed. |
| Compression | zstd or gzip, for bodies over 512 bytes |
| Logs | JSON access log on stdout. Caddy's own log on stderr, at WARN and above. |
| Metrics | `:9145/metrics` (`caddy_http_*`, labelled by host). Other paths get a 403. |
| Proxies | `X-Forwarded-*` headers from private ranges (Traefik) are kept, so the apps' trusted-proxy settings keep working |

The blocking rules run right after the web root is set (`order error after
root`), before any profile rewrites or handlers, so a profile can't skip them.

### Profiles

| Profile | Web root (default) | Behaviour | Charts |
|---|---|---|---|
| `laravel` | `/app-shared/public` | Unknown paths go to `index.php`. Static assets that exist are cached for 24h; missing ones get a plain 404 without booting Laravel. 30s PHP timeout. `/vendor/` is **not** blocked, because Livewire serves its JS from `public/vendor/livewire`. | apply, assess, certificates, profiledashboard, profileman, tmdiagnostic |
| `wordpress` | `/app-shared/wordpress` | Unknown paths go to `index.php`, except under `/wp-content/uploads/`, which is static only: a missing upload is a 404 without PHP, as with nginx. Subdirectory multisite rewrites (`/<site>/wp-…`, `/<site>/….php`). `/wp-admin` redirects to `/wp-admin/`. PHP under `wp-content/uploads/` is never run (403). Static assets cached for 12h. 30s PHP timeout. | wordpress, wordpress-multisite, wp-satispress (`NHSLA_ROOT=/gp2/wordpress`) |
| `moodle` | `/app-shared/vendor/moodle/moodle` | No front controller: missing paths, including missing `.php` scripts, are a 404. Slash arguments (`/pluginfile.php/…`) set `PATH_INFO`. Source paths are blocked (below). 600s PHP timeout. Adds `X-NHSLA-OSS: moodle`. | moodle |
| `moodle5` | `/app-shared/vendor/moodle/moodle/public` | Unknown paths go to `r.php`. X-Accel-Redirect downloads are served from `NHSLA_MOODLE_DATAROOT` (see below). Source paths blocked. 600s PHP timeout. Adds `X-Frame-Options`, `X-Content-Type-Options` and `X-XSS-Protection`. | moodle5x |

The Moodle profiles also import `nhsla_block_source`, which returns a 404 for:
- path segments `vendor`, `node_modules`, `behat` and `fixtures`
- `readme*` files and `*.md`
- `upgrade.txt` and `UPGRADE`
- `environment.xml`, `install.xml` and `phpunit.xml`
- `doesnotexist`

Unlike the old nginx regexes, these match whole path segments and filenames,
so a URL that merely *contains* `vendor` or `md` isn't blocked by accident. In
Moodle 4.x they now also apply to `.php` URLs, which the old nginx location
order skipped.

Moodle 5 X-Accel-Redirect needs this in `config.php`:

```php
$CFG->xsendfile = 'X-Accel-Redirect';
$CFG->xsendfilealiases = ['/dataroot/' => $CFG->dataroot];
```

## Environment variables

| Variable | Default | |
|---|---|---|
| `NHSLA_PROFILE` | `laravel` | Profile to load. An unknown name stops Caddy at startup. |
| `SITE_NAME` | `unknown` | Value of the `X-NHSLA-Site` header |
| `NHSLA_ROOT` | per profile | Web root |
| `NHSLA_PHP_UPSTREAM` | `127.0.0.1:9000` | PHP-FPM address |
| `NHSLA_PHP_TIMEOUT` | per profile (30s or 600s) | FastCGI read timeout. Exceeding it gives a 504. |
| `NHSLA_MAX_BODY_SIZE` | `1GB` | Larger request bodies get a 413 |
| `NHSLA_MOODLE_DATAROOT` | `/efs/data` | `moodle5` only: where X-Accel-Redirect files are served from |
| `NHSLA_LOG_LEVEL` | `WARN` | Level for Caddy's own log on stderr |
| `NHSLA_SHUTDOWN_DELAY` | `5s` | After SIGTERM, how long to keep serving while Traefik stops routing to the pod |
| `NHSLA_GRACE_PERIOD` | `10s` | Then, how long in-flight requests get to finish. Keep the sum under `terminationGracePeriodSeconds`. |

## Per-site additions

For anything a profile doesn't cover, mount `*.caddy` files into the image
rather than replacing the Caddyfile:

```yaml
# Chart ConfigMap, mounted at /etc/caddy/site.d
data:
  scorm.caddy: |
    handle_path /local/external_manifests/* {
      reverse_proxy {{ .Values.app.SCORMPROXY }} {
        header_up Host {upstream_hostport}
      }
    }
```

```yaml
# Chart ConfigMap, mounted at /etc/caddy/php.d: lines go inside php_fastcgi { }
data:
  cloudflare.caddy: |
    env REMOTE_ADDR {header.CF-Connecting-IP}
```

`site.d` lines become part of the `:8080` site block. Caddy sorts directives
into its own order, so where they go in the file doesn't matter. The shared
blocking rules still apply to `site.d` routes, and a `site.d` handler takes
priority over the profile's PHP and static-file handling.

## security.txt

Every site serves the same [RFC 9116](https://www.rfc-editor.org/rfc/rfc9116)
file at `/.well-known/security.txt`, from
[`rootfs/srv/well-known/security.txt`](rootfs/srv/well-known/security.txt). It's
sent as `text/plain` and the app is never involved. If the file is removed (or
a site mounts an empty directory over `/srv/well-known`), the request goes to
the app as usual.

**`Expires` must stay in the future, and no more than a year ahead.** An
expired file tells researchers the contact details are stale. The smoke test
fails once `Expires` is 30 days or less away, so the weekly scheduled build
gives a month's warning. To renew it, set `Expires` to about a year ahead and
merge. The next image build publishes it to every site.

## Running in Kubernetes

```yaml
- name: web
  image: ghcr.io/nhsleadership/nhsl-caddy:2.11.9
  env:
    - { name: NHSLA_PROFILE, value: laravel }
    - { name: SITE_NAME, value: profiledashboard }
  ports:
    - { name: web, containerPort: 8080 }
    - { name: web-metrics, containerPort: 9145 }
  securityContext:
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    capabilities: { drop: [ALL] }
    # Go doesn't see the container memory limit on its own. This makes the GC
    # work harder near the limit instead of getting OOM-killed.
    - name: GOMEMLIMIT
      valueFrom: { resourceFieldRef: { resource: limits.memory } }
  volumeMounts:
    - { name: shared-app, mountPath: /app-shared }
    - { name: caddy-tmp, mountPath: /tmp }   # emptyDir
  livenessProbe:  { httpGet: { path: /healthz, port: web } }
  readinessProbe: { httpGet: { path: /, port: web } }   # or /healthz (see below)

# In the PHP-FPM container: SIGTERM stops php-fpm immediately, so delay it
# until Caddy has stopped sending requests (shutdown delay + grace period)
- name: phpfpm
  lifecycle:
    preStop: { sleep: { seconds: 15 } }
```

### Probes, shutdown and scaling

- **Liveness:** use `/healthz`. Caddy answers it itself, without PHP, so a slow
  or saturated PHP-FPM never gets the web container restarted.
- **Readiness:** there are two reasonable choices.
  - `/` goes through the app, so a deploy that returns errors never becomes
    ready and the rollout stops. The downside is that if the app's dependencies
    fail (e.g. the database), every pod goes unready at once. The Laravel charts
    do this today.
  - `/healthz` (or a TCP check, as the WordPress and Moodle charts use today)
    leaves PHP readiness to the PHP-FPM container's own probe
    (`php-fpm-healthcheck --listen-queue=…`). The pod is only ready when both
    containers are.
- **Shutdown** (rollouts and HPA scale-in): Kubernetes sends SIGTERM to both
  containers while it's still removing the pod from the Service.
  - Caddy keeps serving for `NHSLA_SHUTDOWN_DELAY`, then drains for up to
    `NHSLA_GRACE_PERIOD`. It needs no `preStop`.
  - php-fpm stops immediately on SIGTERM, so give its container a
    `preStop: sleep` at least as long as Caddy's delay plus grace period (15s
    with the defaults). Without it, requests that are in flight, or that arrive
    during the delay, get a 502.
  - Both must fit in `terminationGracePeriodSeconds`, which is 20s in the
    charts.
- **HPA:** the charts scale on CPU/memory or on PHP-FPM's
  `phpfpm_active_processes_utilization` (from the exporter on 9253). Neither
  depends on the web server. A CPU/memory HPA sums all containers against
  their requests, so check the web container's requests against real usage
  after switching. Caddy (Go) uses a little more memory at idle than nginx,
  and comparable CPU.

### Metrics

Caddy serves Prometheus metrics on `:9145/metrics`, including
`caddy_http_requests_total`, `caddy_http_request_duration_seconds` and
`caddy_http_requests_in_flight`. They're labelled by `host` (the real Host header, not `_other`), and the duration histogram also by `code` and `method`.

Caddy records metrics **per handler**: a request is counted once for each
middleware it passes through (`vars`, `headers`, …). Don't sum across
handlers. For dashboards and alerts, use:
- `handler="subroute"` for PHP requests (rate, latency, status codes).
  `php_fastcgi` runs as a subroute, as do `handle` blocks such as
  security.txt or `site.d` handlers.
- `handler="file_server"` for static files and Caddy's own error pages

kube-prometheus-stack scrapes pods through PodMonitors (every PodMonitor in the
cluster is picked up). To scrape Caddy, add a PodMonitor for the `web-metrics`
port and let the `prometheus-stack` namespace reach 9145 in the chart's
CiliumNetworkPolicy:

```yaml
# templates/podmonitor_caddy.yaml (see profiledashboard or moodle in helm-charts)
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: {{ .Values.shortName }}-caddy
spec:
  jobLabel: app
  podMetricsEndpoints:
    - port: web-metrics
      path: /metrics
      interval: 15s
  selector:
    matchLabels:
      app: {{ .Values.shortName }}
```

The image runs as `nhsla` (1000:1000), and only `/tmp` needs to be writable.
The upstream binary's `cap_net_bind_service` file capability is removed (and
the build checks it), so `allowPrivilegeEscalation: false` and dropping all
capabilities both work.

There's no shell, so `kubectl exec … sh` won't work. To look inside a running
pod, attach a debug container that shares its process namespace:

```bash
kubectl debug -it <pod> --image=busybox --target=<caddy container> -- sh
# the caddy container's filesystem is at /proc/1/root
```

## Testing

```bash
make test-caddy
```

This builds the image and runs it the same way Kubernetes does (read-only,
uid 1000, no capabilities, `no-new-privileges`) in front of the PHP-FPM image,
serving `tests/app`. It then runs `tests/caddy/smoke.sh`.

```bash
CADDY=caddy PHP_FPM=php-fpm ./tests/caddy/profiles.sh
```

This tests every profile end to end against stub Laravel, WordPress and Moodle
apps, using local `caddy` and `php-fpm` binaries (no Docker needed). It covers:
- routing, PATH_INFO and slash arguments
- multisite rewrites
- X-Accel downloads
- blocking rules
- error pages
- the `site.d` and `php.d` hooks
- 413 and 504 responses

CI runs both on every pull request that touches `caddy/` or `tests/`. The
Docker build also runs `caddy validate` for every profile.
