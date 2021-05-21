FROM debian:buster-slim
LABEL maintainer="devops@nhsx.uk"

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --chown=1000:1000 overlay /

RUN apt-get update \
  && apt-get install --no-install-recommends \
    -o Dpkg::Options::=--force-confdef -y \
    tini nginx libnginx-mod-http-lua \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd -g 1000 nhsla \
  && useradd -g 1000 -l -M -s /bin/false -u 1000 nhsla \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && mkdir -p /var/run/nginx \
  && chown 1000:1000 /var/run/nginx \
  && chmod +x /entrypoint.sh
  
STOPSIGNAL SIGQUIT

USER 1000:1000
CMD ["nginx"]

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
