FROM caddy:2.11.9-alpine
LABEL maintainer="devops@nhsx.uk"

# NHSLA_PROFILE picks /etc/caddy/profiles/<name>.caddy: laravel, wordpress, moodle or moodle5.
# Caddy's data/config dirs go under /tmp so the root filesystem can be read-only.
ENV NHSLA_PROFILE=laravel \
    XDG_DATA_HOME=/tmp/caddy/data \
    XDG_CONFIG_HOME=/tmp/caddy/config

COPY rootfs/ /

RUN set -eux; \
    addgroup -g 1000 nhsla; \
    adduser -D -H -u 1000 -G nhsla nhsla; \
    \
    # The upstream binary carries cap_net_bind_service so it can bind :80/:443
    # as non-root. We only listen on 8080 and 9145, and a file capability makes
    # exec fail under allowPrivilegeEscalation: false, so remove it.
    apk add --no-cache --virtual .setcap libcap; \
    setcap -r /usr/bin/caddy; \
    apk del .setcap; \
    \
    # Fail the build if any profile doesn't produce a valid config
    for p in /etc/caddy/profiles/*.caddy; do \
        NHSLA_PROFILE="$(basename "$p" .caddy)" caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; \
    done; \
    rm -rf /tmp/caddy; \
    date > /image_base_build_date

USER 1000:1000

EXPOSE 8080 9145

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
