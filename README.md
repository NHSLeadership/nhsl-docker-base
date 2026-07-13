# Base Docker Images

> Clean and functional base images providing PHP versions 7.2 to 8.5 and OpenResty web server.
>
> By NHS Leadership Academy

This repository provides two images; one containing [PHP-FPM](https://www.php.net/manual/en/install.fpm.php) (able to run either as a fastcgi server or cron/worker via [supercronic](https://github.com/aptible/supercronic)) and another running [Openresty](https://openresty.org/en/). They are customised to the NHS Leadership Academy's various needs and include "nice to haves" such as Prometheus exporters, service management, and sane configuration for running inside a Kubernetes environment.

## Rationale

We use Kubernetes to make the most of our infrastructure. The majority of our applications are built on PHP and so it made sense to create base images providing a standard build to run our applications from. In keeping with Kubernetes best practice we moved to an architecture running PHP-FPM in a separate container to the Openresty web server within the same pod. Worker (or cron) is deployed separately.

This README will assume Kubernetes for context and so may make references to Kubernetes terminology such as jobs, pods etc.

## Availability

Images are currently built and pushed to GitHub's container registry. Available tags are:

- `ghcr.io/nhsleadership/nhsl-ubuntu-openresty:latest`
- `ghcr.io/nhsleadership/nhsl-ubuntu-phpv2:7.2-master`
- `ghcr.io/nhsleadership/nhsl-ubuntu-phpv2:7.3-master`
- `ghcr.io/nhsleadership/nhsl-ubuntu-phpv2:7.4-master`
- `ghcr.io/nhsleadership/nhsl-ubuntu-phpv2:8.0-master`
- `ghcr.io/nhsleadership/nhsl-ubuntu-phpv2:8.1-master`
- `ghcr.io/nhsleadership/nhsl-ubuntu-phpv2:8.2-master`
- `ghcr.io/nhsleadership/nhsl-ubuntu-phpv2:8.3-master`
- `ghcr.io/nhsleadership/nhsl-ubuntu-phpv2:8.4-master`
- `ghcr.io/nhsleadership/nhsl-ubuntu-phpv2:8.5-master`

## Assumptions

- These images have been built to run as the `nhsla` user with uid/gid `1000`.
- These images assume they are running with a read-only root filesystem.
- Writable volumes should be mounted at **/nhsla/etc**, **/run**, and **/tmp** otherwise the containers will fail to start. We use Kubernetes emptyDir volumes for this.

## Cron

By default the PHP-FPM container runs in FPM mode. If you need to run cron jobs you should add a second container deployment, using the PHP-FPM container with the `ROLE` environment variable set to `CRON` or `WORKER`.

We utilise [Supercronic](https://github.com/aptible/supercronic) to provide Cron functionality in our image. It provides a modern Cron binary that can run as a non-root user and provides more rich logging capability.

Your crontab file should be stored at `/nhsla/cron` in the image with a structure such as:

`* * * * * /usr/bin/echo "This is a test cron."`

The file should be owned by the `nhsla` user as this is what cron runs as.

## Configuration overrides

We ship a basic configuration for both PHP-FPM and Openresty which should work for most situations however there is a need to override these occasionally.

We no longer use a long list of runtime variables to do this - instead we simply overwrite the configuration using Kubernetes ConfigMaps which also allows us to work around the readOnlyRootFilesystem easily whilst keeping application specific configurations in their relevant Git repositories.

You may wish to override the following configuration files with ConfigMaps or a layered image build:

**Openresty:**
Openresty config (Nginx compatible): `/usr/local/openresty/nginx/conf/nginx.conf`
Openresty default site: `/user/local/openresty/nginx/conf/site.conf`

**PHP-FPM**:
php.ini: `/nhsla/etc/php.ini`
www pool: `/nhsla/etc/www.conf`
additional configuration files may be added into `/etc/php/fpm/conf.d/*.ini`

## Scaling PHP-FPM

These images are designed to scale **horizontally**: the OpenResty and PHP-FPM containers run together in a Pod, and you add capacity by increasing the replica count (typically via an HPA), not by growing the number of workers inside a Pod.

Because of this, the PHP-FPM pool defaults (in `www.conf`) use a **static** process manager:

```
pm = static
pm.max_children = 10          # fixed number of always-on workers
pm.max_requests = 1000        # recycle each worker to bound memory leaks
request_terminate_timeout = 60s
```

`pm = static` gives each Pod a predictable, fixed memory and CPU footprint, which is exactly what Kubernetes resource requests/limits and the HPA need to reason about. Elasticity comes from replicas, so a fixed per-Pod concurrency is the point.

### Sizing `pm.max_children`

`max_children` is a **memory bet** and must be kept in sync with the PHP container's memory limit:

- Worst case memory ≈ `pm.max_children × memory_limit` (default `128M`) plus the OPcache shared segment and base overhead. With the defaults that is roughly `10 × 128M ≈ 1.3 GB` of request memory at peak.
- Idle workers are far smaller (tens of MB), but heavy requests (e.g. Moodle, image processing) can approach the `memory_limit` ceiling.
- Rule of thumb: `pm.max_children ≈ (memory limit − OPcache − base) / realistic peak worker RSS`.

**If you change the PHP container's resource limits (e.g. in an upstream Helm chart), tune `pm.max_children` to match**, by overriding `www.conf`. Giving a Pod less memory without lowering `max_children` risks OOM kills under load; giving it more memory without raising `max_children` leaves that headroom unused. Different applications (Laravel, WordPress, Moodle) have very different footprints, so treat the default of `10` as a conservative starting point, not a universal value.

### Scaling signal for the HPA

A static, I/O-bound pool can have **all workers busy waiting on a database or upstream API while CPU looks idle** — so a CPU-based HPA may fail to scale out even though requests are queuing behind a full pool. These images already run [`php-fpm_exporter`](https://github.com/sysdiglabs/php-fpm_exporter) (metrics on port `9253`), scraping the pool's `/status` page. Prefer scaling on pool saturation — **active processes / listen queue length** — or on request latency, rather than raw CPU.

## Environment Variables

|Variable      |Description      |Default      |
| ---- | ---- | ---- |
|ATATUS_APM_LICENSE_KEY |Provides a licence key to enable the Atatus APM PHP module. Disabled Atatus APM if not set. | |
|AWS_HOST_ENVIRONMENT |If exists, then application data will be copied from /app into /app-shared | |
|BUILD |A build number from your CICD system, used to form the app version in Atatus. | |
|ENVIRONMENT |Name of environment container is deployed to. Mainly used to configure PHP logging and the Atatus release stage | |
| MAIL_HOST | Set the SMTP mail host for the system's SSMTP mail relay service | outbound.kube-mail |
| MAIL_PORT | Set the SMTP mail port for the system's SSMTP mail relay service | 25 |
| REDIS_SESSIONS | Tells PHP FPM to use Redis for a session store. | false |
| REDIS_HOST | Combined with above. Sets the redis hostname and port | redis:6379 |
| ROLE | Set to CRON or WORKER on the PHP-FPM container to swap the php-fpm service for supercronic. Place cron files in /nhsla/cron |  |
| SITE_NAME | A name for the site. Mainly used for the Atatus application name |  |
| SITE_BRANCH | A branch from your code repository. Used to form the app version in Atatus |  |

## Ports

The following ports are listening by default. Because of the unprivileged nature of this container all ports must be above 1024.

| Port     | Service              | Use                                              |
| -------- | -------------------- | ------------------------------------------------ |
| 8080/tcp | Openresty            | Openresty main web service port                  |
| 9145/tcp | nginx-lua-prometheus | Prometheus compatible Openresty metrics exporter |
| 9253/tcp | php-fpm_exporter     | Prometheus compatible metrics exporter           |



## PHP Modules



| Module / PHP Version | 7.2   | 7.3   | 7.4   | 8.0   | 8.1   | 8.2   | 8.3   | 8.4   | 8.5   |
| -------------------- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| apcu                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| apcu-bc              | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| bcmath               | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| calendar             | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| ctype                | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| curl                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| dom                  | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| exif                 | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| ftp                  | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| gd                   | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| gettext              | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| iconv                | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| imagick              | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| intl                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| json                 | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| ldap                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| mbstring             | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| memcached            | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| mysql                | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| mysqli               | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| opcache              | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️*   | 
| pdo                  | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| pgsql                | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| phar                 | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| posix                | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| redis                | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| soap                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| sockets              | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| sqlite3              | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| tidy                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| xml                  | ❌    | ❌    | ❌    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| xmlreader            | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| xsl                  | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    |
| zip                  | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |



> *opcache is compiled into the PHP 8.5 core, so it is present and enabled by default without a separate `php8.5-opcache` package (which no longer exists upstream).

## Running commands on startup

Each container uses [s6-overlay](https://github.com/just-containers/s6-overlay) as its init system; the image `ENTRYPOINT` is `/init`. On boot it runs the scripts in `/etc/cont-init.d` in order, then starts the long-running services (php-fpm/openresty, the metrics exporter, and supercronic as appropriate).

If the `AWS_HOST_ENVIRONMENT` environment variable exists we assume the two images are running inside a Kubernetes Pod together and application code is copied from `/app` into a shared emptyDir volume at `/app-shared`.

Scripts should be placed into `/etc/cont-init.d` in the format `03-script.sh`. 01 and 02 are used for initial setup. You may use the ROLE environment variable to limit scripts to run on different containers.

## A note on ReadOnlyRootFileSystem

These images were created with a [read only root filesystem](https://kubernetes.io/docs/concepts/policy/pod-security-policy/) in mind, hence the inclusion of three emptyDir volumes in the examples in this repository.

This means that the only writable directories in the container are /nhsla/run, /tmp, and /app-shared. This means that packages cannot be installed in a running container and scope for troubleshooting issues or changing things directly in a Production system is severely limited. Instead the stack should be run locally or other tools such as our logging stack should be consulted.

## Non-root use

These images also run as the `nhsla` user with a UID/GID of 1000. This means that running services have no access to system directories and have a severely restricted permissions list. This generally shouldn't be an issue but your application may need special attention or slightly rearchitecting to work under these restricted permissions.
