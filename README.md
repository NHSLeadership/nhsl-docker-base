# Base Docker Images

> Clean and functional base images providing PHP versions 7.2 to 8.1 and OpenResty web server.
>
> By NHS Leadership Academy

This repository provides two images, one containing PHP-FPM (also able to run cron) and another running OpenResty. They are designed to be used together in a single Kubernetes pod to support our own web applications.

## Rationale

We use Kubernetes to make the most of our infrastructure. The majority of our applications (~90%) are built on PHP and so it made sense to create base images providing a standard build to run our applications from. In keeping with Kubernetes best practice we moved to an architecture running PHP-FPM in a separate container to the OpenResty web server within the same pod.

In future it would be nice to split PHP-FPM and OpenResty into separately scalable pods, but this poses issues when both services need access to the same application data. Within a pod this is easily solved using emptyDir volumes with little performance impact whereas with separate pods we would need shared storage (AWS EFS) which is slower and more awkward to manage application code in.

This README will assume Kubernetes for context and so may make references to Kubernetes terminology such as jobs, pods etc.

## Assumptions

PHP expects Redis to be available at tcp://redis:6379 for session storage.

## Cron

We try to run cron jobs within Kubernetes it self but it doesn't handle things well when you need to run jobs reliably every minute - in these instances we run a single PHP-FPM pod in "cron" mode.

By default the PHP-FPM container runs in "web" mode. If you need to run cron jobs you should add a second pod deployment, using the PHP-FPM container only with the `ROLE` environment variable set to `cron`.

We utilise [Supercronic](https://github.com/aptible/supercronic) to provide Cron functionality in our image. It provides a modern Cron binary that can run as a non-root user and provides more rich logging capability.

Your crontab file should be stored at `/nhsla/cron` in the image with a structure such as:

`* * * * * /usr/bin/echo "This is a test cron."`

The file should be owned by the `nhsla` user (UID 1000) as this is what Cron runs as.

## Configuration overrides

We ship a basic configuration for both PHP-FPM and OpenResty which should work for most situations however there is a need to override these occasionally.

We no longer use a long list of runtime variables to do this - instead we simply overwrite the configuration using Kubernetes ConfigMaps which also allows us to work around the readOnlyRootFilesystem easily whilst keeping application specific configurations in their relevant Git repositories.

You may wish to override the following configuration files with ConfigMaps or a layered image build:

OpenResty:
Base OpenResty (Nginx compatible): `/nhsla/config/nginx.conf`
OpenResty site configuration: `/nhsla/config/site.conf`

PHP-FPM:
PHP-FPM php.ini: `/nhsla/config/php.ini`
PHP-FPM www pool: `/nhsla/config/www.conf`

## Environment Variables

|Variable      |Description      |Default      |Image      |      |
| ---- | ---- | ---- | ---- | ---- |
| MAIL_HOST | Set the SMTP mail host for the system's SSMTP mail relay service | outbound.kube-mail |PHP-FPM      |      |
| MAIL_PORT | Set the SMTP mail port for the system's SSMTP mail relay service | 25 |PHP-FPM      |      |
| ATATUS_APM_LICENSE_KEY     | Provides a licence key to enable the Atatus APM PHP module      | NONE      |PHP-FPM      |      |
|      |      |      |      |      |
|      |      |      |      |      |
|      |      |      |      |      |
|      |      |      |      |      |
|      |      |      |      |      |
|      |      |      |      |      |

## Running commands on startup

Each container starts up using Docker's Entryfile directive. This calls the script at /entryfile.sh which will run various scripts in succession.

If the `AWS_HOST_ENVIRONMENT` environment variable exists we assume the two images are running inside a Kubernetes Pod together and application code is copied from `/app` into a shared emptyDir volume at `/app-shared`.

Each container looks for a relevant startup script. If found it will be executed last but before the services are started:

| Path               | Runs on                   | Priority |
| ------------------ | ------------------------- | -------- |
| /nhsla/scripts/startup-all.sh    | All containers            | 1        |
| /nhsla/scripts/startup-web.sh    | OpenResty only            | 2        |
| /nhsla/scripts/startup-php.sh    | PHP-FPM only, not workers | 2        |
| /nhsla/scripts/startup-worker.sh | PHP-FPM workers only      | 3        |

In the case you have mixed scripts where multiple may run in a single container then scripts are executed from lowest priority number first to highest (i.e. 1, then 2, then 3).

## A note on ReadOnlyRootFileSystem

These images were created with a [read only root filesystem](https://kubernetes.io/docs/concepts/policy/pod-security-policy/) in mind, hence the inclusion of three emptyDir volumes in the examples in this repository.

This means that the only writable directories in the container are /nhsla/run, /tmp, and /app-shared. This means that packages cannot be installed in a running container and scope for troubleshooting issues or changing things directly in a Production system is severely limited. Instead the stack should be run locally or other tools such as our logging stack should be consulted.

## Non-root use

These images also run as the `nhsla` user with a UID/GID of 1000. This means that running services have no access to system directories and have a severely restricted permissions list. This generally shouldn't be an issue but your application may need special attention or slightly rearchitecting to work under these restricted permissions.
