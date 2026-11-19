# Moving a site from OpenResty to nhsl-caddy

This guide covers what has to change in a Helm chart to swap the
`nhsl-ubuntu-openresty` web container for `nhsl-caddy`. It also covers what
behaves differently, and how to roll out and roll back.
[`caddy/README.md`](README.md) describes the image itself.

**The worked example is the profiledashboard chart (1.5.0 and later)** in
`NHSLeadership/helm-charts`. It has a `webServer: openresty|caddy` value, so
each environment can switch on its own and switch back.

## What moves where

| | OpenResty today | nhsl-caddy |
|---|---|---|
| Web server config | a `site.conf` ConfigMap in each chart | baked into the image, with the app type chosen by `NHSLA_PROFILE` |
| Error pages | five ~210 KB pages in the OpenResty image | one 16 KB template in the image |
| Path blocking | regexes in each `site.conf` | shared rules in the image, plus a profile's extras |
| Site-specific rules | in `site.conf` | a small `*.caddy` ConfigMap mounted at `/etc/caddy/site.d` (or `/etc/caddy/php.d` for PHP settings) |
| Metrics | Lua exporter on 9145 (not scraped) | built in on 9145, scraped by Prometheus through a `PodMonitor` (see [Metrics](#metrics)) |
| Base | Ubuntu + s6 + OpenResty, `:latest` | `FROM scratch`: one static binary, `:latest` (rebuilt weekly) |

## Chart changes for every site

In the web container:

1. **Image:** `ghcr.io/nhsleadership/nhsl-caddy:latest` with
   `imagePullPolicy: Always`, so every new pod gets the newest weekly build.
   This is the same approach as OpenResty. With `IfNotPresent`, a node that
   has already pulled `latest` keeps running that copy.
   - Running pods only change when they're replaced (a deploy, a rollout,
     scaling), so `kubectl rollout restart` picks up a new build.
   - Pods can briefly run different builds.
   - To pin a site, use the Caddy version tag (e.g. `2.11.9`) with
     `IfNotPresent`.
2. **Environment:**
   - `NHSLA_PROFILE`: `laravel`, `wordpress`, `moodle` or `moodle5` (see the
     table below)
   - `SITE_NAME`: as now
   - `GOMEMLIMIT`, from `resourceFieldRef: { resource: limits.memory }`.
     Drop the OpenResty-only variables (`ROLE`, `ENVIRONMENT`,
     `AWS_HOST_ENVIRONMENT`, `SITE_BRANCH`, `K8S_ENV`).
3. **Volumes:** keep `/app-shared` (and `/app-shared/storage` on EFS where
   there is one), and add an emptyDir at `/tmp`. Remove the `openresty-etc`,
   `openresty-s6` and `openresty-tmp` volumes and the `webconf` (`site.conf`)
   ConfigMap.
4. **Ports:** name 8080 `web` and 9145 `web-metrics`. The PodMonitor finds
   the second by name. Update the probes to the new port name.
5. **securityContext:** `readOnlyRootFilesystem: true`,
   `runAsNonRoot: true`, `allowPrivilegeEscalation: false` and
   `capabilities: { drop: [ALL] }`. All of these work with this image.
6. **Probes:**
   - liveness: `httpGet /healthz`
   - readiness: keep what the chart has today. The Laravel charts use `/`;
     WordPress and Moodle use a TCP check. See [probes](README.md#probes-shutdown-and-scaling).

In the PHP-FPM container:

7. **`lifecycle.preStop.sleep.seconds: 15`.** php-fpm stops immediately on
   SIGTERM. Caddy keeps serving for 5s after SIGTERM and then drains for up
   to 10s, so PHP has to outlive that. Without it, rollouts and HPA scale-in
   return 502s. The 15s must fit inside `terminationGracePeriodSeconds`
   (20s in our charts).

For metrics:

8. **Add a `PodMonitor`** for the `web-metrics` port, and **allow the
   `prometheus-stack` namespace to reach 9145** in the CiliumNetworkPolicy.
   Both are shown under [Metrics](#metrics).

## Per-chart notes

| Chart | Sites | `NHSLA_PROFILE` | Extra changes |
|---|---|---|---|
| apply, assess, certificates, profiledashboard, profileman, tmdiagnostic | 1 each | `laravel` | none. All six `site.conf`s are identical. |
| wordpress | wp-corporate, wp-graduates | `wordpress` | none (`openresty.redisCache` is `false` everywhere and isn't carried over) |
| wp-satispress | 1 | `wordpress` | `NHSLA_ROOT=/gp2/wordpress` |
| wordpress-multisite | 1 (21 domains) | `wordpress` | `php.d` file: `env REMOTE_ADDR {header.CF-Connecting-IP}` (the old config set `REMOTE_ADDR` from Cloudflare). Subdomain multisite and mapped domains are tested. |
| moodle | 15 | `moodle` | if `app.SCORMPROXY` is set, a `site.d` file with the proxy (example in the README) |
| moodle5x | 1 | `moodle5` | SCORM proxy as above. Check `NHSLA_MOODLE_DATAROOT` matches the old `/dataroot/` alias (`/efs/data`) and that `config.php` sets `xsendfile` and `xsendfilealiases`. |

## Behaviour differences to check on staging

These are deliberate, but they're still changes:

- **Dotfiles return 404 everywhere**, except under `/.well-known/`.
  Previously:
  - the Laravel charts and WordPress returned 403
  - the Laravel charts and WordPress also blocked `/.well-known`
  - Moodle used the base 404 rule
- **Moodle's source-path blocking matches whole path segments and filenames**
  (`/vendor/`, `readme*`, `*.md` …). The old regexes matched substrings, so
  `(.*).md` caught any URL containing "md". In Moodle 4.x the rules now also
  apply to `.php` URLs, which the old location order let through.
- **Missing static assets** in the Laravel profile get Caddy's 404 page
  without booting Laravel, as nginx did.
- **PHP uploaded to WordPress `wp-content/uploads/`** returns 403. nginx
  served the source as a plain file.
- **Error pages** carry `X-NHSLA-*` headers, and `Server` is removed.
  nginx's `add_header` skipped error responses.
- **Compression** applies only to bodies over 512 bytes (zstd or gzip),
  rather than nginx's type list.
- **The `PHP_VALUE "atatus.enabled=on;"` parameter is gone.** Atatus has been
  removed, and the line logged an error on every request.
- **Access logs are JSON** (one object per request on stdout). Check the
  field mapping in VictoriaLogs.

## Metrics

Caddy serves `:9145/metrics`. In both clusters, metrics are collected by
**Prometheus (kube-prometheus-stack)**. It scrapes every `PodMonitor`
(`podMonitorSelector: {}`), and `prometheus-adapter` feeds the HPAs from it.
Charts opt in the way their PHP-FPM metrics already do
(`podmonitor_phpmetrics.yaml` in moodle, wordpress, wordpress-multisite and
profileman).

There's nothing to change centrally. Each chart needs:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: {{ .Values.shortName }}-caddy
  labels:
    app: {{ .Values.shortName }}
spec:
  jobLabel: app
  podMetricsEndpoints:
    - port: web-metrics
      path: /metrics
      interval: 15s
      scrapeTimeout: 10s
  selector:
    matchLabels:
      app: {{ .Values.shortName }}
```

and an ingress rule for Prometheus in its CiliumNetworkPolicy:

```yaml
# in the chart's CiliumNetworkPolicy ingress rules
- fromEndpoints:
    - matchLabels:
        io.kubernetes.pod.namespace: prometheus-stack
  toPorts:
    - ports:
        - port: "9145"
```

The profiledashboard chart does both in Caddy mode. Nothing scraped OpenResty's 9145.

Two things to know:
- **The `victoriametrics` rules in the charts are stale.** The
  `victoriametrics` namespace on staging has been stuck `Terminating` since
  November 2024, and production runs no VictoriaMetrics pods. Its scrape
  config in `argocd: charts/infrastructure/victoriametrics` isn't used, and
  nor are the `prometheus.io/*` pod annotations.
- **Some charts have no PHP-FPM PodMonitor** (profiledashboard, apply, assess,
  certificates, tmdiagnostic and wp-satispress). Their CPU/memory HPAs don't need one, but
  their PHP-FPM pool metrics aren't being collected.

Mapping from the old metric names, for dashboards and alerts:

| OpenResty | nhsl-caddy |
|---|---|
| `nginx_http_requests_total{host,status}` | `caddy_http_request_duration_seconds_count{host,code,handler="subroute"}` (`caddy_http_requests_total` has no `code` label) |
| `nginx_http_request_duration_seconds{host}` | `caddy_http_request_duration_seconds{host,code,method,handler}` |
| `nginx_http_connections{state}` | `caddy_http_requests_in_flight` (closest equivalent) |

Caddy records metrics **per handler**, so one request is counted once for
each middleware it passes through. Filter by handler:
- `handler="subroute"` for PHP, plus any `handle` blocks
- `handler="file_server"` for static files and error pages

`host` is the real Host header (`observe_catchall_hosts` is on), so
multisite domains appear separately.

## Scaling and HPAs

- **No HPA uses web-server metrics.** They scale on CPU/memory or on
  `phpfpm_active_processes_utilization` (the PHP-FPM exporter on 9253), so
  the switch doesn't change the scaling signal.
- **CPU/memory HPAs** add up every container's usage against its requests.
  After switching, compare the web container's real usage
  (`kubectl top pod --containers`) with its requests, which are copied from
  OpenResty's. Caddy uses a little more memory at idle and about the same
  CPU.
- **Rollouts and scale-in** depend on the shutdown handling above. Caddy's
  `NHSLA_SHUTDOWN_DELAY` and `NHSLA_GRACE_PERIOD`, plus PHP-FPM's `preStop`,
  must add up to less than `terminationGracePeriodSeconds`.

## Rolling out

1. **Image:** merge nhsl-docker-base so `nhsl-caddy:<version>` is published.
   CI smoke-tests it and runs every profile end to end.
2. **Chart:** add the `webServer` toggle (copy profiledashboard), with
   `openresty` as the default. Check that the default render is unchanged:
   `diff` the `helm template` output before and after. Both the staging and
   production Argo apps follow new chart versions automatically.
3. **Staging:** set `webServer: caddy` in the argocd staging values. Then:
   - compare responses with OpenResty for the same paths (status codes,
     `content-type`, `cache-control`, `content-encoding`, `location`)
   - exercise login and forms, uploads and downloads, and admin pages
   - roll the Deployment while sending traffic, and watch for 502s
4. **Production:** set it in the production values once staging looks right.
5. **Rollback:** set `webServer: openresty`. Argo redeploys with the old
   container, so nothing else needs undoing.
6. **When every environment is on Caddy:** remove the toggle and the
   OpenResty branch from the chart.
