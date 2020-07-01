# Base Docker Images

> Clean and functional base images providing PHP versions 7.1 to 7.4 and OpenResty web server.
>
> By NHS Leadership Academy
>
> Special shout-out to [Parallax](https://parall.ax) for help and inspiration.

## Rationale

We use Kubernetes to make the most of our infrastructure. The majority of our applications (~90%) are built on PHP and so it made sense to create base images providing a standard build to run our applications from. In keeping with Kubernetes best practice we moved to an architecture running PHP-FPM in a separate container to the OpenResty web server within the same pod.

In future it would be nice to split PHP-FPM and OpenResty into separately scalable pods, but this poses issues when both services need access to the same application data. Within a pod this is easily solved using emptyDir volumes with little performance impact whereas with separate pods we would need shared storage (AWS EFS) which is slower and more awkward to manage application code in.

This README will assume Kubernetes for context and so may make references to Kubernetes terminology such as jobs, pods etc.

## Modes (CRON)

We try to run cron jobs within Kubernetes it self but it doesn't handle things well when you need to run jobs reliably every minute (such as with WordPress) - in these instances we run a single PHP-FPM pod in "worker" mode.

By default the PHP-FPM container runs in "web" mode. If you need to run cron jobs you should add a second pod deployment, using the PHP-FPM container with command `/startup-worker.sh`.

## OpenResty configuration override

We found multiple situations where we needed to override the configuration used by OpenResty. For this reason if you include a configuration file (or mount a ConfigMap) at /openresty-web.conf we will ignore all other configuration set via Environment Variables and use this for your site definition instead.

## Environment Variables

|      |      |      |      |      |
| ---- | ---- | ---- | ---- | ---- |
|      |      |      |      |      |
|      |      |      |      |      |
|      |      |      |      |      |
|      |      |      |      |      |
|      |      |      |      |      |
|      |      |      |      |      |
|      |      |      |      |      |
|      |      |      |      |      |
|      |      |      |      |      |

## Running commands on startup

Each container looks for a relevant startup script. If found it will be executed last but before the services are started:

| Path               | Runs on                   | Priority |
| ------------------ | ------------------------- | -------- |
| /startup-all.sh    | All containers            | 1        |
| /startup-web.sh    | OpenResty only            | 2        |
| /startup-php.sh    | PHP-FPM only, not workers | 2        |
| /startup-worker.sh | PHP-FPM workers only      | 3        |

In the case you have mixed scripts where multiple may run in a single container then scripts are executed from lowest priority number first to highest (i.e. 1, then 2, then 3).

## A note on ReadOnlyRootFileSystem

These images were created with a [read only root filesystem](https://kubernetes.io/docs/concepts/policy/pod-security-policy/) in mind, hence the inclusion of three emptyDir volumes in the examples in this repository.

This means that the only writable directories in the container are /nhsla/run, /tmp, and /app-shared. This means that packages cannot be installed in a running container and scope for troubleshooting issues or changing things directly in a Production system is severely limited. Instead the stack should be run locally or other tools such as our logging stack should be consulted.

## Non-root use

These images also run as the `nhsla` user with a UID/GID of 1000. This means that running services have no access to system directories and have a severely restricted permissions list. This generally shouldn't be an issue but your application may need special attention or slightly rearchitecting to work under these restricted permissions.