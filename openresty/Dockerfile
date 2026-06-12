FROM ubuntu:noble
LABEL maintainer="devops@nhsx.uk"

ENV S6_OVERLAY_VERSION=3.2.2.0 \
    S6_KEEP_ENV=1 \
    S6_FIX_ATTRS_HIDDEN=1 \
    S6_READ_ONLY_ROOT=1 \
    S6_LOGGING=0 \
    DEBIAN_FRONTEND=noninteractive

COPY --chown=1000:1000 /rootfs/ /

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        xz-utils; \
    \
    # Resolve target architecture for s6-overlay and openresty
    DPKG_ARCH="$(dpkg --print-architecture)"; \
    case "$DPKG_ARCH" in \
        amd64) S6_ARCH="x86_64";  OPENRESTY_PATH="package/ubuntu" ;; \
        arm64) S6_ARCH="aarch64"; OPENRESTY_PATH="package/arm64/ubuntu" ;; \
        *) echo "Unsupported architecture: $DPKG_ARCH" >&2; exit 1 ;; \
    esac; \
    \
    # Install s6-overlay
    S6_BASE="https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}"; \
    curl --proto "=https" --tlsv1.3 -fsSL "${S6_BASE}/s6-overlay-noarch.tar.xz"      -o /tmp/s6-noarch.tar.xz; \
    curl --proto "=https" --tlsv1.3 -fsSL "${S6_BASE}/s6-overlay-${S6_ARCH}.tar.xz"  -o /tmp/s6-arch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-arch.tar.xz; \
    rm /tmp/s6-*.tar.xz; \
    \
    # Set up OpenResty APT repo (modern signed-by, no gnupg needed)
    mkdir -p /etc/apt/keyrings; \
    curl --proto "=https" --tlsv1.3 -fsSL https://openresty.org/package/pubkey.gpg \
        -o /etc/apt/keyrings/openresty.asc; \
    . /etc/os-release; \
    echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/openresty.asc] https://openresty.org/${OPENRESTY_PATH} ${VERSION_CODENAME} main" \
        > /etc/apt/sources.list.d/openresty.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends openresty openresty-opm; \
    opm get knyar/nginx-lua-prometheus; \
    \
    # Cleanup build-time tools
    apt-get purge -y --auto-remove curl; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    \
    # User and directory setup
    userdel -r ubuntu 2>/dev/null || true; \
    useradd --create-home --shell /bin/bash --uid 1000 nhsla; \
    chown -R nhsla:nhsla /usr/local/openresty /etc/openresty; \
    chmod a+r /usr/local/openresty/nginx/conf/nginx.conf; \
    mkdir -p /app/public /nhsla; \
    chown -R nhsla:nhsla /nhsla /app; \
    ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log; \
    ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log; \
    chmod +x /etc/cont-init.d/01-boot.sh; \
    date > /image_base_build_date

USER 1000:1000

ENTRYPOINT ["/init"]
CMD ["/usr/local/openresty/bin/openresty", "-c", "/etc/openresty/nginx.conf"]
