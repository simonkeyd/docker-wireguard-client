FROM debian:11 as build
ARG WIREGUARD_RELEASE

RUN echo "**** install dependencies ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    jq \
    libc6

RUN mkdir /app && \
  cd /tmp && \
  echo "**** install wireguard-tools ****" && \
  if [ -z ${WIREGUARD_RELEASE+x} ]; then \
    WIREGUARD_RELEASE=$(curl -sX GET "https://api.github.com/repos/WireGuard/wireguard-tools/tags" | \
    jq -r .[0].name); \
  fi && \
  git clone https://git.zx2c4.com/wireguard-tools && \
  cd wireguard-tools && \
  git checkout "${WIREGUARD_RELEASE}" && \
  export PREFIX="../wireguard-tools/" && \
  make -C src -j$(nproc) && \
  make -C src install && \
  mv wireguard-tools/bin /app/wireguard-tools && \
  cd /app && \
  git clone https://git.zx2c4.com/wireguard-linux-compat && \
  rm -fr wireguard-linux-compat/.git

FROM debian:11-slim

ARG BUILD_DATE
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.version=$VERSION
LABEL org.label-schema.name="wireguard-client"
LABEL maintainer="simonkeyd"

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  dkms \
  iproute2 \
  iptables \
  iputils-ping \
  net-tools \
  openresolv \
  procps && \
  apt-get clean

COPY --from=build /app /app

COPY /init.sh /

CMD /bin/bash /init.sh
HEALTHCHECK --timeout=6s CMD ping -c 3 -W 1 -I wg0 8.8.8.8 || bash -c 'kill -s 15 -1 && (sleep 10; kill -s 9 -1)'
