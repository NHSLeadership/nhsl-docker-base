# Base Docker Images

> Clean and functional base images providing PHP versions 7.2 to 8.3 and OpenResty web server.
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
php-fpm: `/nhsla/etc/php-fpm.conf`
www pool: `/nhsla/etc/www.conf`
additional configuration files may be added into `/etc/php/fpm/conf.d/*.ini`

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

| Module / PHP Version | 7.2  | 7.3  | 7.4  | 8.0  | 8.1  | 8.2  | 8.3  |
| -------------------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| apcu                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| apcu-bc              | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| bcmath               | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| calendar             | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| ctype                | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| curl                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| dom                  | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| exif                 | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| ftp                  | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| gd                   | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| gettext              | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| iconv                | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| imagick              | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| intl                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| json                 | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| ldap                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| mbstring             | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| memcached            | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| mysql                | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| mysqli               | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| opcache              | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| pdo                  | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| pgsql                | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| phar                 | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| posix                | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| redis                | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| soap                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| sockets              | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| sqlite3              | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| tidy                 | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |
| xml                  | ❌    | ❌    | ❌    | ✔️    | ✔️    | ✔️    | ✔️    |
| xmlreader            | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| xsl                  | ✔️    | ✔️    | ✔️    | ❌    | ❌    | ❌    | ❌    |
| zip                  | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    | ✔️    |



## Running commands on startup

Each container starts up using Docker's Entryfile directive. This calls the script at /entryfile.sh which will run various scripts in succession.

If the `AWS_HOST_ENVIRONMENT` environment variable exists we assume the two images are running inside a Kubernetes Pod together and application code is copied from `/app` into a shared emptyDir volume at `/app-shared`.

Scripts should be placed into `/etc/cont-int.d`in the format `03-script.sh`. 01 and 02 are used for initial setup. You may use the ROLE environment variable to limit scripts to run on different containers.

## A note on ReadOnlyRootFileSystem

These images were created with a [read only root filesystem](https://kubernetes.io/docs/concepts/policy/pod-security-policy/) in mind, hence the inclusion of three emptyDir volumes in the examples in this repository.

This means that the only writable directories in the container are /nhsla/run, /tmp, and /app-shared. This means that packages cannot be installed in a running container and scope for troubleshooting issues or changing things directly in a Production system is severely limited. Instead the stack should be run locally or other tools such as our logging stack should be consulted.

## Non-root use

These images also run as the `nhsla` user with a UID/GID of 1000. This means that running services have no access to system directories and have a severely restricted permissions list. This generally shouldn't be an issue but your application may need special attention or slightly rearchitecting to work under these restricted permissions.
