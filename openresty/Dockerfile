FROM ubuntu:jammy
LABEL maintainer="devops@nhsx.uk"

ENV S6_OVERLAY_NOARCH=https://github.com/just-containers/s6-overlay/releases/download/v3.1.6.2/s6-overlay-noarch.tar.xz \
    S6_OVERLAY_AMD64=https://github.com/just-containers/s6-overlay/releases/download/v3.1.6.2/s6-overlay-x86_64.tar.xz \
    S6_KEEP_ENV=1 \
    S6_FIX_ATTRS_HIDDEN=1 \
    S6_READ_ONLY_ROOT=1 \
    S6_KEEP_ENV=1 \
    S6_LOGGING=0 \
    DEBIAN_FRONTEND=noninteractive

COPY --chown=1000:1000 /rootfs/ /

RUN apt-get update \
  && apt-get install \
     ca-certificates \
     curl \
     gnupg \
     xz-utils \
     --no-install-recommends -y \
  && curl -L "$S6_OVERLAY_NOARCH" --output /tmp/s6-overlay-noarch.tar.xz \
  && curl -L "$S6_OVERLAY_AMD64" --output /tmp/s6-overlay-amd64.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-amd64.tar.xz \
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
  && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log \
  && chmod +x /etc/cont-init.d/01-boot.sh \
  && date > /image_base_build_date

USER 1000:1000

ENTRYPOINT ["/init"]
CMD ["/usr/local/openresty/bin/openresty", "-c", "/etc/openresty/nginx.conf"]
