# Build stage: the official image supplies the (static) caddy binary and the
# few files it needs at runtime. Validate our config here, where there's a shell.
FROM caddy:2.11.9-alpine AS build

COPY rootfs/ /

RUN set -eux; \
    mkdir -p /out/usr/bin /out/etc/ssl/certs /out/tmp; \
    \
    # The upstream binary carries cap_net_bind_service so it can bind :80/:443
    # as non-root. We only listen on 8080 and 9145, and a file capability makes
    # exec fail under allowPrivilegeEscalation: false, so remove it.
    cp /usr/bin/caddy /out/usr/bin/caddy; \
    apk add --no-cache libcap; \
    setcap -r /out/usr/bin/caddy 2>/dev/null || true; \
    test -z "$(getcap /out/usr/bin/caddy)"; \
    \
    # Everything else the binary uses at runtime: CA roots (for reverse_proxy to
    # HTTPS upstreams), MIME types (Go's built-in table lacks woff2, ico, docx…),
    # and a passwd/group entry so uid 1000 has a name.
    cp /etc/ssl/certs/ca-certificates.crt /out/etc/ssl/certs/; \
    cp /etc/mime.types /out/etc/; \
    echo 'nhsla:x:1000:1000:nhsla:/tmp:/sbin/nologin' > /out/etc/passwd; \
    echo 'nhsla:x:1000:' > /out/etc/group; \
    chmod 1777 /out/tmp; \
    \
    # Fail the build if any profile doesn't produce a valid config
    for p in /etc/caddy/profiles/*.caddy; do \
        NHSLA_PROFILE="$(basename "$p" .caddy)" XDG_DATA_HOME=/tmp/v XDG_CONFIG_HOME=/tmp/v \
            /out/usr/bin/caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; \
    done; \
    date > /out/image_base_build_date

# Final image: no OS, no shell, no package manager. Just Caddy and our config.
FROM scratch
LABEL maintainer="devops@nhsx.uk"

COPY --from=build /out/ /
COPY rootfs/ /

# NHSLA_PROFILE picks /etc/caddy/profiles/<name>.caddy: laravel, wordpress, moodle or moodle5.
# Caddy's data/config dirs go under /tmp so the root filesystem can be read-only.
ENV NHSLA_PROFILE=laravel \
    XDG_DATA_HOME=/tmp/caddy/data \
    XDG_CONFIG_HOME=/tmp/caddy/config

USER 1000:1000

EXPOSE 8080 9145

ENTRYPOINT ["/usr/bin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
