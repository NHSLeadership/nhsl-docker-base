FROM ubuntu:jammy
LABEL maintainer="devops@nhsx.uk"

ARG PHP_VERSION
ARG PHP_PACKAGES
ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV METRICS_URL=https://github.com/hipages/php-fpm_exporter/releases/download/v2.2.0/php-fpm_exporter_2.2.0_linux_amd64 \
    HEALTHCHECK_URL=https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/master/php-fpm-healthcheck \
    SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.1/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=d7f4c0886eb85249ad05ed592902fa6865bb9d70 \
    S6_FIX_ATTRS_HIDDEN=1 \
    S6_READ_ONLY_ROOT=1 \
    S6_KEEP_ENV=1 \
    S6_LOGGING=0 \
    PHP_VERSION=$PHP_VERSION

RUN apt-get update \
  && apt-get install \
    busybox-static \
    ca-certificates \
    curl \
    git \
    gnupg \
    gpg-agent \
    less \
    libfcgi-bin \
    nano \
    openssh-client \
    ssmtp \
    unzip \
    zip \
    xz-utils \
    -y rm -rf /var/lib/apt/lists/* \
  && curl -L https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer --output /tmp/s6-overlay-amd64-installer \
  && chmod +x /tmp/s6-overlay-amd64-installer && /tmp/s6-overlay-amd64-installer / \
  && rm -rf /tmp/* \
  && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C \
  && echo "deb http://ppa.launchpad.net/ondrej/php/ubuntu jammy main" \
    | tee /etc/apt/sources.list.d/ondrej.list \
  && apt-get update \
  && apt-get install -y ${PHP_PACKAGES} && rm -rf /var/lib/apt/lists/* \
  ## Adds in PHP-FPM Prometheus metrics scraper
  && curl -L "$METRICS_URL" --output /usr/local/bin/php-fpm_exporter \
  && chmod +x /usr/local/bin/php-fpm_exporter \
  ## Add PHP-FPM Health check script
  && curl "$HEALTHCHECK_URL" --output /usr/local/bin/php-fpm-healthcheck \
  && chmod +x /usr/local/bin/php-fpm-healthcheck \
  ## Add global Composer
  && curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && chmod a+x /usr/local/bin/composer \
  ## Add Atatus GPG key and repo
  && curl https://s3.amazonaws.com/atatus-artifacts/gpg/atatus.gpg | apt-key add - \
    && echo "deb https://s3.amazonaws.com/atatus-artifacts/atatus-php/debian stable main" \
      | tee -a /etc/apt/sources.list.d/atatus-php-agent.list \
    && apt-get update \
    && apt-get install atatus-php-agent -y && rm -rf /var/lib/apt/lists/* \
  && apt-get remove -y --purge gnupg \
  && useradd --create-home --shell /bin/bash --uid 1000 nhsla \
  && mkdir -p /app/public \
  && chown -R nhsla:nhsla /app \
  && mkdir -p /nhsla \
  && chown -R nhsla:nhsla /nhsla \
  && sed -i -e 's|variables_order = "GPCS"|variables_order = "EGPCS"|g' /etc/php/${PHP_VERSION}/fpm/php.ini \
  && sed -i -e 's|;clear_env = no|clear_env = no|g' /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
  && sed -i "s|;date.timezone =.*|date.timezone = UTC|" /etc/php/${PHP_VERSION}/fpm/php.ini \
  && sed -i "s|upload_max_filesize = .*|upload_max_filesize = 1G|" /etc/php/${PHP_VERSION}/fpm/php.ini \
  && sed -i "s|post_max_size = .*|post_max_size = 512M|" /etc/php/${PHP_VERSION}/fpm/php.ini \
  && sed -i "s|;cgi.fix_pathinfo=1|cgi.fix_pathinfo=0|" /etc/php/${PHP_VERSION}/fpm/php.ini \
  && sed -i -e "s|error_log =.*|error_log = \/dev\/stderr|" /etc/php/${PHP_VERSION}/fpm/php-fpm.conf \
  && sed -i -e "s|;daemonize\s*=\s*yes|daemonize = no|g" /etc/php/${PHP_VERSION}/fpm/php-fpm.conf \
  && sed -i "s|;catch_workers_output = .*|catch_workers_output = yes|" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
  && sed -i -e "s|pid =.*|pid = \/nhsla\/etc\/php-fpm.pid|" /etc/php/${PHP_VERSION}/fpm/php-fpm.conf \
   && sed -i -e 's|;log_level = notice|log_level = warning|g' /etc/php/${PHP_VERSION}/fpm/php-fpm.conf \
  && rm -rf /etc/php/${PHP_VERSION}/fpm/php.ini \
  && rm -rf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
  && rm -rf /etc/php/${PHP_VERSION}/fpm/conf.d/20-atatus.ini \
  && rm -rf /etc/php/${PHP_VERSION}/cli/conf.d/20-atatus.ini \
  && ln -s /nhsla/etc/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini \
  && ln -s /nhsla/etc/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
  && ln -s /nhsla/etc/atatus.ini /etc/php/${PHP_VERSION}/fpm/conf.d/20-atatus.ini \
  && rm -rf /etc/ssmtp/ssmtp.conf \
  && ln -s /nhsla/etc/ssmtp.conf /etc/ssmtp/ssmtp.conf \
  && curl -fsSLO "$SUPERCRONIC_URL" \
  && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
  && chmod +x "$SUPERCRONIC" \
  && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
  && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic \
  && date > /image_base_build_date


COPY --chown=1000:1000 /rootfs/ /

USER 1000:1000

ENTRYPOINT ["/init"]
