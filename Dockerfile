FROM debian:11 as build
ARG WIREGUARD_RELEASE

RUN echo "**** install dependencies ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    bc \
    build-essential \
    ca-certificates \
    curl \
    dkms \
    git \
    gnupg \
    ifupdown \
    iproute2 \
    iptables \
    iputils-ping \
    jq \
    libc6 \
    libelf-dev \
    net-tools \
    openresolv \
    perl \
    pkg-config \
    qrencode

RUN echo "**** install services ****" && \
  mkdir /app && \
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
  procps \
  qrencode && \
  apt-get clean

COPY --from=build /app /app

COPY /root /

# ports and volumes
EXPOSE 51820/udp
