FROM ubuntu:jammy
LABEL maintainer="devops@nhsx.uk"

ENV S6_READ_ONLY_ROOT=1 \
    S6_KEEP_ENV=1 \
    S6_LOGGING=0 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install \
     ca-certificates \
     curl \
     gnupg \
     xz-utils \
     --no-install-recommends -y \
  && curl -L https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer --output /tmp/s6-overlay-amd64-installer \
  && chmod +x /tmp/s6-overlay-amd64-installer && /tmp/s6-overlay-amd64-installer / \
  && rm -rf /tmp/* \
  && curl -L https://openresty.org/package/pubkey.gpg | apt-key add - \
  && echo "deb http://openresty.org/package/ubuntu jammy main" \
     | tee /etc/apt/sources.list.d/openresty.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends openresty openresty-opm \
  && opm get knyar/nginx-lua-prometheus \
  && apt-get remove -y --purge curl gnupg \
  && apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --create-home --shell /bin/bash --uid 1000 nhsla \
  && chown -R nhsla:nhsla /usr/local/openresty \
  && chown -R nhsla:nhsla /etc/openresty \
  && chmod a+r /usr/local/openresty/nginx/conf/nginx.conf \
  && mkdir -p /app/public \
  && mkdir -p /nhsla \
  && chown -R nhsla:nhsla /nhsla \
  && chown -R nhsla:nhsla /app \
  && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
  && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

COPY --chown=1000:1000 /rootfs/ /

USER 1000:1000

ENTRYPOINT ["/init"]
CMD ["/usr/local/openresty/bin/openresty", "-c", "/etc/openresty/nginx.conf"]
