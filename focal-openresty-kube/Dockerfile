FROM ubuntu:focal
LABEL maintainer="devops@nhsx.uk"

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ADD entrypoint.sh /entrypoint.sh

RUN apt-get update \
  && apt-get install \
    ca-certificates \
    gnupg \
    curl \
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
  && mkdir -p /app/public \
  && mkdir -p /nhsla \
  && chown -R nhsla:nhsla /nhsla \
  && chown -R nhsla:nhsla /app \
  && chmod 755 /entrypoint.sh \
  && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
  && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

ADD error_pages/* /usr/local/openresty/nginx/html/
ADD conf/nginx.conf /etc/openresty/nginx.conf
ADD conf/site.conf /etc/openresty/site.conf

USER 1000:1000
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/local/openresty/bin/openresty"]