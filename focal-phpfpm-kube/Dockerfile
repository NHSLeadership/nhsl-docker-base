FROM ubuntu:focal
LABEL maintainer="devops@nhsx.uk"

ARG PHP_VERSION
ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.1.9/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=5ddf8ea26b56d4a7ff6faecdd8966610d5cb9d85 \
    PHP_VERSION=$PHP_VERSION

COPY entrypoint.sh /nhsla/scripts/entrypoint.sh
COPY --chown=1000:1000 setup /setup

RUN apt-get update \
  && apt-get install \
    busybox-static \
    ca-certificates \
    gnupg \
    libfcgi-bin \
    nano \
    ssmtp \
    curl \
    --no-install-recommends -y \
  && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C \
  && echo "deb http://ppa.launchpad.net/ondrej/php/ubuntu focal main" \
    | tee /etc/apt/sources.list.d/ondrej.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-mysqli \
    php${PHP_VERSION}-memcached \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-dom \
    php${PHP_VERSION}-exif \
    php${PHP_VERSION}-ftp \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-iconv \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-pdo \
    php${PHP_VERSION}-posix \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-ldap \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-calendar \
    php${PHP_VERSION}-gettext \
    php${PHP_VERSION}-json \
    php${PHP_VERSION}-apcu \
    php${PHP_VERSION}-phar \
    php${PHP_VERSION}-sockets \
    php${PHP_VERSION}-tidy \
    php${PHP_VERSION}-wddx \
    php${PHP_VERSION}-xmlreader \
    php${PHP_VERSION}-xsl \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-imagick \
    php${PHP_VERSION}-ctype \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-redis \
  ## Add PHP-FPM Health check script
  && curl https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/master/php-fpm-healthcheck --output /usr/local/bin/php-fpm-healthcheck \
  && chmod +x /usr/local/bin/php-fpm-healthcheck \
  && sed -i -e 's|;pm.status_path = /status|pm.status_path = /status|g' /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
  ## Add global Composer
  && curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && chmod a+x /usr/local/bin/composer \
  ## Add Atatus GPG key and repo
  && curl https://s3.amazonaws.com/atatus-artifacts/gpg/atatus.gpg | apt-key add - \
    && echo "deb https://s3.amazonaws.com/atatus-artifacts/atatus-php/debian stable main" \
      | tee -a /etc/apt/sources.list.d/atatus-php-agent.list \
    && apt-get update \
    && apt-get install atatus-php-agent --no-install-recommends -y \
  && apt-get remove -y --purge gnupg \
  && apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && useradd --create-home --shell /bin/bash --uid 1000 nhsla \
  && mkdir -p /app/public \
  && mkdir -p /nhsla \
  && chown -R nhsla:nhsla /nhsla \
  && chown -R nhsla:nhsla /app \
  && chmod 755 /entrypoint.sh \
  && sed -i -e 's|variables_order = "GPCS"|variables_order = "EGPCS"|g' /etc/php/${PHP_VERSION}/fpm/php.ini \
  && sed -i -e 's|variables_order = "GPCS"|variables_order = "EGPCS"|g' /etc/php/${PHP_VERSION}/cli/php.ini \
  && sed -i -e 's|;clear_env = no|clear_env = no|g' /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
  && sed -i "s|;date.timezone =.*|date.timezone = UTC|" /etc/php/${PHP_VERSION}/fpm/php.ini \
  && sed -i "s|upload_max_filesize = .*|upload_max_filesize = 1G|" /etc/php/${PHP_VERSION}/fpm/php.ini \
  && sed -i "s|post_max_size = .*|post_max_size = 512M|" /etc/php/${PHP_VERSION}/fpm/php.ini \
  && sed -i "s|;cgi.fix_pathinfo=1|cgi.fix_pathinfo=0|" /etc/php/${PHP_VERSION}/fpm/php.ini \
  && sed -i -e "s|error_log =.*|error_log = \/proc\/self\/fd\/2|" /etc/php/${PHP_VERSION}/fpm/php-fpm.conf \
  && sed -i -e "s|;daemonize\s*=\s*yes|daemonize = no|g" /etc/php/${PHP_VERSION}/fpm/php-fpm.conf \
  && sed -i "s|;catch_workers_output = .*|catch_workers_output = yes|" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
  && sed -i "s|listen = .*|listen = 127.0.0.1:9000|" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
  && sed -i -e "s|pid =.*|pid = \/nhsla\/run\/php-fpm.pid|" /etc/php/${PHP_VERSION}/fpm/php-fpm.conf \
  && sed -i -e 's|atatus.trace.response_time = 2000|atatus.trace.response_time = 1500|g' /etc/php/${PHP_VERSION}/fpm/conf.d/20-atatus.ini \
  && sed -i -e 's|atatus.agent.log_file = "/var/log/atatus/agent.log"|atatus.agent.log_file = "/dev/stdout"|g' /etc/php/${PHP_VERSION}/fpm/conf.d/20-atatus.ini \
  && sed -i -e 's|atatus.collector.log_file = "/var/log/atatus/collector.log"|atatus.collector.log_file = "/dev/stdout"|g' /etc/php/${PHP_VERSION}/fpm/conf.d/20-atatus.ini \
  && sed -i -e 's|atatus.collector.pidfile = "/var/run/atatus-php-collector.pid"|atatus.collector.pidfile = "/nhsla/run/atatus.pid"|g' /etc/php/${PHP_VERSION}/fpm/conf.d/20-atatus.ini \
  && sed -i -e 's|;log_level = notice|log_level = warning|g' /etc/php/${PHP_VERSION}/fpm/php-fpm.conf \
  && rm -rf /etc/php/${PHP_VERSION}/fpm/php.ini \
  && rm -rf /etc/php/${PHP_VERSION}/php-fpm.conf \
  && rm -rf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
  && rm -rf /etc/php/${PHP_VERSION}/fpm/conf.d/atatus.ini \
  && ln -s /nhsla/config/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini \
  && ln -s /nhsla/config/php-fpm.conf /etc/php/${PHP_VERSION}/php-fpm.conf \
  && ln -s /nhsla/config/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
  && ln -s /nhsla/config/atatus.ini /etc/php/${PHP_VERSION}/fpm/conf.d/atatus.ini \
  && rm -rf /etc/ssmtp/ssmtp.conf \
  && ln -s /nhsla/config/ssmtp.conf /etc/ssmtp/ssmtp.conf \
  && chmod +x /setup/setup.sh \
  && curl -fsSLO "$SUPERCRONIC_URL" \
  && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
  && chmod +x "$SUPERCRONIC" \
  && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
  && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic \
  && date > /image_base_build_date

COPY --chown=nhsla:nhsla setup/cron /nhsla/

USER nhsla:nhsla
ENTRYPOINT ["/nhsla/scripts/entrypoint.sh"]