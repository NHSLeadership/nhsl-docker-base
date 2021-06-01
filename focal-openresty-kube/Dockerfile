FROM ubuntu:focal
LABEL maintainer="devops@nhsx.uk"

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --chown=1000:1000 setup /setup

RUN apt-get update \
  && apt-get install \
    ca-certificates \
    curl \
    gnupg \
    tini \
    --no-install-recommends -y \
  && curl -L https://openresty.org/package/pubkey.gpg | apt-key add - \
  && echo "deb http://openresty.org/package/ubuntu focal main" \
    | tee /etc/apt/sources.list.d/openresty.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends openresty openresty-opm \
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
  && chmod 755 /setup/scripts/entrypoint.sh \
  && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
  && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

COPY --chown=nhsla:nhsla error_pages/* /usr/local/openresty/nginx/html/
COPY --chown=nhsla:nhsla setup/config/nginx.conf /etc/openresty/nginx.conf
COPY --chown=nhsla:nhsla setup/config/site.conf /etc/openresty/site.conf

USER 1000:1000
CMD ["/usr/local/openresty/bin/openresty", "-c", "/etc/openresty/nginx.conf"]
ENTRYPOINT ["/usr/bin/tini", "--", "/setup/scripts/entrypoint.sh"]
