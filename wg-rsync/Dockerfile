# wg-rsync helper image -- rsync + ssh + WireGuard userspace.
# Built remotely on the source host by wg-rsync.sh on first run; ~120 MB.
# No tailscale; this image is dedicated to wg-quick + rsync transfers.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
      rsync \
      openssh-client \
      ca-certificates \
      iproute2 \
      iputils-ping \
      iptables \
      wireguard-tools \
      wireguard-go && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
LABEL purpose="wg-rsync helper -- rsync+ssh+wireguard userspace"
