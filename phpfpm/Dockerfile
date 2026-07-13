FROM ubuntu:noble
LABEL maintainer="devops@nhsx.uk"

ARG PHP_VERSION
ARG PHP_PACKAGES
ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV S6_OVERLAY_VERSION=3.2.3.0 \
    SUPERCRONIC_VERSION=0.2.46 \
    SUPERCRONIC_SHA1_AMD64=5bcefed628e32adc08e32634db2d10e9230dbca0 \
    SUPERCRONIC_SHA1_ARM64=639ab81a72771990790df7ee87d9acfe88e5fa83 \
    ATATUS_VERSION=1.18.0 \
    HEALTHCHECK_URL=https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/master/php-fpm-healthcheck \
    S6_KEEP_ENV=1 \
    S6_FIX_ATTRS_HIDDEN=1 \
    S6_READ_ONLY_ROOT=1 \
    S6_LOGGING=0 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    PHP_VERSION=$PHP_VERSION

COPY --chown=1000:1000 /rootfs/ /

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        busybox-static \
        ca-certificates \
        curl \
        git \
        less \
        libfcgi-bin \
        nano \
        openssh-client \
        ssmtp \
        unzip \
        zip \
        xz-utils; \
    \
    # Resolve target architecture
    DPKG_ARCH="$(dpkg --print-architecture)"; \
    case "$DPKG_ARCH" in \
        amd64) S6_ARCH="x86_64";  SUPERCRONIC_ARCH="amd64"; SUPERCRONIC_SHA1="${SUPERCRONIC_SHA1_AMD64}"; ATATUS_TAR_ARCH="x64"   ;; \
        arm64) S6_ARCH="aarch64"; SUPERCRONIC_ARCH="arm64"; SUPERCRONIC_SHA1="${SUPERCRONIC_SHA1_ARM64}"; ATATUS_TAR_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $DPKG_ARCH" >&2; exit 1 ;; \
    esac; \
    \
    # Install s6-overlay
    S6_BASE="https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}"; \
    curl --proto "=https" --tlsv1.3 -fsSL "${S6_BASE}/s6-overlay-noarch.tar.xz"     -o /tmp/s6-noarch.tar.xz; \
    curl --proto "=https" --tlsv1.3 -fsSL "${S6_BASE}/s6-overlay-${S6_ARCH}.tar.xz" -o /tmp/s6-arch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-arch.tar.xz; \
    rm /tmp/s6-*.tar.xz; \
    \
    # Set up Ondrej PHP PPA (signed-by, no apt-key)
    mkdir -p /etc/apt/keyrings; \
    curl --proto "=https" --tlsv1.3 -fsSL \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x4F4EA0AAE5267A6C" \
        -o /etc/apt/keyrings/ondrej-php.asc; \
    . /etc/os-release; \
    echo "deb [signed-by=/etc/apt/keyrings/ondrej-php.asc] https://ppa.launchpadcontent.net/ondrej/php/ubuntu ${VERSION_CODENAME} main" \
        > /etc/apt/sources.list.d/ondrej-php.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends ${PHP_PACKAGES}; \
    \
    # PHP-FPM health check
    curl --proto "=https" --tlsv1.3 -fsSL "$HEALTHCHECK_URL" -o /usr/local/bin/php-fpm-healthcheck; \
    chmod +x /usr/local/bin/php-fpm-healthcheck; \
    \
    # Composer
    curl --proto "=https" --tlsv1.3 -fsSL https://getcomposer.org/installer \
        | php -- --install-dir=/usr/local/bin --filename=composer; \
    chmod +x /usr/local/bin/composer; \
    \
    # Atatus PHP agent (tarball install — supports both amd64 and arm64)
    ATATUS_DIR="atatus-php-${ATATUS_VERSION}-${ATATUS_TAR_ARCH}-debian"; \
    curl --proto "=https" --tlsv1.3 -fsSL \
        "https://s3.amazonaws.com/atatus-artifacts/atatus-php/downloads/${ATATUS_DIR}.tar.gz" \
        -o /tmp/atatus.tar.gz; \
    tar -xzf /tmp/atatus.tar.gz -C /tmp; \
    ATATUS_LICENSE_KEY="placeholder" ATATUS_APP_NAME="placeholder" \
        bash /tmp/${ATATUS_DIR}/install.sh; \
    rm -rf /tmp/atatus.tar.gz /tmp/${ATATUS_DIR}; \
    \
    # Supercronic
    SUPERCRONIC="supercronic-linux-${SUPERCRONIC_ARCH}"; \
    curl --proto "=https" --tlsv1.3 -fsSLO \
        "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/${SUPERCRONIC}"; \
    echo "${SUPERCRONIC_SHA1}  ${SUPERCRONIC}" | sha1sum -c -; \
    chmod +x "$SUPERCRONIC"; \
    mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}"; \
    ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic; \
    \
    # User and directory setup
    userdel -r ubuntu 2>/dev/null || true; \
    useradd --create-home --shell /bin/bash --uid 1000 nhsla; \
    mkdir -p /app/public /nhsla; \
    chown -R nhsla:nhsla /app /nhsla; \
    \
    # PHP-FPM master config tweaks. Note: php.ini and www.conf are supplied
    # wholesale via the /nhsla/etc symlinks below, so only php-fpm.conf (which
    # is not symlinked) is edited in place here.
    sed -i \
        -e 's|error_log =.*|error_log = /dev/stderr|' \
        -e 's|;daemonize\s*=\s*yes|daemonize = no|g' \
        -e 's|pid =.*|pid = /nhsla/etc/php-fpm.pid|' \
        -e 's|;log_level = notice|log_level = warning|g' \
        /etc/php/${PHP_VERSION}/fpm/php-fpm.conf; \
    \
    # Symlink config files to /nhsla/etc/
    rm -f /etc/php/${PHP_VERSION}/fpm/php.ini \
          /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
          /etc/php/${PHP_VERSION}/fpm/conf.d/atatus.ini \
          /etc/php/${PHP_VERSION}/cli/conf.d/atatus.ini; \
    ln -s /nhsla/etc/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini; \
    ln -s /nhsla/etc/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf; \
    ln -s /nhsla/etc/atatus.ini /etc/php/${PHP_VERSION}/fpm/conf.d/20-atatus.ini; \
    ln -s /etc/php/${PHP_VERSION}/fpm /etc/php/fpm; \
    ln -s /etc/php/${PHP_VERSION}/cli /etc/php/cli; \
    rm -f /etc/ssmtp/ssmtp.conf; \
    ln -s /nhsla/etc/ssmtp.conf /etc/ssmtp/ssmtp.conf; \
    \
    chmod +x /etc/cont-init.d/01-boot.sh /etc/cont-init.d/02-setup.sh; \
    date > /image_base_build_date; \
    \
    # Cleanup
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/*

USER 1000:1000

ENTRYPOINT ["/init"]
