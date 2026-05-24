ARG ALPINE_VER=3.19
ARG GOLANG_VER=1.22

FROM ghcr.io/linuxserver/baseimage-alpine:arm64v8-3.19-version-0c4be44f AS base

FROM alpine:${ALPINE_VER} AS binary-downloader

RUN apk add --no-cache curl tar gzip ca-certificates

RUN mkdir -p /bar/usr/local/bin && \
    curl -fsSL \
      https://github.com/windtf/wireproxy/releases/download/v1.0.4/wireproxy_linux_arm64.tar.gz \
      | tar -xz -C /bar/usr/local/bin wireproxy && \
    curl -fsSL \
      https://github.com/ViRb3/wgcf/releases/download/v2.2.29/wgcf_2.2.29_linux_arm64 \
      -o /bar/usr/local/bin/wgcf && \
    chmod +x /bar/usr/local/bin/wireproxy /bar/usr/local/bin/wgcf

FROM base AS collector

COPY --from=binary-downloader /bar/usr/local/bin/wireproxy /bar/usr/local/bin/wireproxy
COPY --from=binary-downloader /bar/usr/local/bin/wgcf /bar/usr/local/bin/wgcf

COPY root/ /bar/

RUN chmod a+x \
        /bar/usr/local/bin/* \
        /bar/etc/s6-overlay/s6-rc.d/*/run \
        /bar/etc/s6-overlay/s6-rc.d/*/finish \
        /bar/etc/s6-overlay/s6-rc.d/*/data/*

FROM base AS publisher

LABEL maintainer="kingcc"
LABEL org.opencontainers.image.source="https://github.com/kingcc/warproxy"

COPY --from=collector /bar/ /

RUN apk add --no-cache grep sed python3 py3-pip && \
    if [ ! -e /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi && \
    pip3 install --break-system-packages --no-cache-dir requests toml && \
    rm -rf /tmp/* /root/.cache

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Shanghai \
    WARP_ENABLED=true \
    WARP_PLUS=false \
    SOCKS5_PORT=1080

VOLUME /config
WORKDIR /config

HEALTHCHECK --interval=25s --timeout=5s --retries=1 \
    CMD /usr/local/bin/healthcheck

ENTRYPOINT ["/init"]
